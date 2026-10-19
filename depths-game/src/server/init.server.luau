-- DEPTHS: RISE OR DIE, server entry point.
--
-- Round loop:
--   Intermission  everyone (re)spawns on the chasm floor, countdown
--   Climbing      fog rises; touch it and you die, reach the gate to escape
--   Draining      fog sinks back down, then the next round starts
--
-- The server owns everything that matters: who is alive, who escaped, the
-- fog height (via the shared Fog formula), and when gargoyles break.
-- Grapple physics run on each player's own client for responsiveness; the
-- server only validates which anchor they claim to be hooked to.
--
-- Location: ServerScriptService > Server (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Fog = require(Shared.Fog)
local Anchors = require(script.Anchors)
local Catacombs = require(script.Catacombs)

-- We spawn players ourselves, at the start of each round.
Players.CharacterAutoLoads = false

local GREEN = Color3.fromRGB(110, 255, 160)
local GOLD = Color3.fromRGB(255, 215, 90)
local RED = Color3.fromRGB(255, 100, 100)

-- Remotes ----------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local GrappleRemote = Instance.new("RemoteEvent") -- client -> server: anchor (BasePart) or nil
GrappleRemote.Name = "Grapple"
GrappleRemote.Parent = remotes
local NotifyRemote = Instance.new("RemoteEvent") -- server -> client: text, color
NotifyRemote.Name = "Notify"
NotifyRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local function notifyAll(text: string, color: Color3?)
	NotifyRemote:FireAllClients(text, color or Color3.new(1, 1, 1))
end

-- Atmosphere --------------------------------------------------------------------

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(22, 28, 26)
	Lighting.OutdoorAmbient = Color3.fromRGB(34, 44, 40)
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(52, 74, 64)
	atmosphere.Decay = Color3.fromRGB(14, 24, 20)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.9
	bloom.Size = 28
	bloom.Threshold = 0.95
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Contrast = 0.14
	grade.Saturation = -0.2
	grade.TintColor = Color3.fromRGB(226, 240, 232)
	grade.Parent = Lighting
end

setupLighting()
local map = Catacombs.build()

-- Player state ------------------------------------------------------------------

type PlayerState = {
	escaped: boolean,
	inRound: boolean,
	lastGrapple: number,
}
local states: { [Player]: PlayerState } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function aliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function grappleValue(player: Player): ObjectValue?
	local character = player.Character
	return character and character:FindFirstChild("GrappleTarget") :: ObjectValue?
end

local function onPlayerAdded(player: Player)
	states[player] = { escaped = false, inRound = false, lastGrapple = 0 }
	player.CharacterAdded:Connect(function(character)
		-- Replicated to every client so they can draw this player's rope.
		local target = Instance.new("ObjectValue")
		target.Name = "GrappleTarget"
		target.Parent = character
	end)
	if Workspace:GetAttribute("RoundState") == Fog.Climbing then
		NotifyRemote:FireClient(player, "A climb is underway. You'll drop in next round.", GREEN)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

-- Grapple validation ---------------------------------------------------------------

GrappleRemote.OnServerEvent:Connect(function(player, anchor)
	local state = states[player]
	local value = grappleValue(player)
	local root = rootOf(player)
	if not (state and value and root and aliveHumanoid(player)) then
		return
	end
	-- Light rate limit; the client fires at most twice per hook.
	local now = os.clock()
	if now - state.lastGrapple < 0.05 then
		return
	end
	state.lastGrapple = now

	if anchor == nil then
		value.Value = nil
		return
	end
	if typeof(anchor) ~= "Instance" or not anchor:IsA("BasePart") then
		return
	end
	if not CollectionService:HasTag(anchor, Anchors.TAG) or anchor:GetAttribute("Broken") then
		return
	end
	-- Generous margin for latency, but no hooking across the map.
	if (anchor.Position - root.Position).Magnitude > Config.Grapple.Range + 30 then
		return
	end
	value.Value = anchor
	Anchors.crumble(anchor)
end)

-- When a gargoyle shatters, unhook everyone holding it.
Anchors.onBroken = function(orb)
	for _, player in Players:GetPlayers() do
		local value = grappleValue(player)
		if value and value.Value == orb then
			value.Value = nil
		end
	end
end

-- Round loop ------------------------------------------------------------------------

local function setState(state: string, extra: { [string]: any }?)
	Workspace:SetAttribute("StateStart", Workspace:GetServerTimeNow())
	for key, value in (extra or {}) :: { [string]: any } do
		Workspace:SetAttribute(key, value)
	end
	Workspace:SetAttribute("RoundState", state)
end

local function formatTime(seconds: number): string
	return string.format("%d:%04.1f", seconds // 60, seconds % 60)
end

local function kill(player: Player, humanoid: Humanoid)
	humanoid.Health = 0
	local value = grappleValue(player)
	if value then
		value.Value = nil
	end
	notifyAll(player.DisplayName .. " was consumed by the fog", RED)
end

local function escape(player: Player, elapsed: number)
	local state = states[player]
	state.escaped = true
	local character = player.Character
	if character then
		local value = grappleValue(player)
		if value then
			value.Value = nil
		end
		character:PivotTo(CFrame.new(map.sanctum.Position + Vector3.new(math.random(-12, 12), 5, math.random(-12, 12))))
	end
	player:SetAttribute("EscapeTime", elapsed)
	notifyAll(string.format("%s ESCAPED in %s", player.DisplayName, formatTime(elapsed)), GOLD)
end

-- Runs one Climbing phase; returns when nobody is left climbing or the fog
-- reaches the top.
local function climb()
	setState(Fog.Climbing)
	local start = Workspace:GetAttribute("StateStart") :: number
	local hadClimbers = false
	while true do
		local now = Workspace:GetServerTimeNow()
		local fogY = Fog.height(now)
		local climbing = 0
		for player, state in states do
			if not state.inRound or state.escaped then
				continue
			end
			local humanoid = aliveHumanoid(player)
			local root = rootOf(player)
			if not (humanoid and root) then
				continue
			end
			climbing += 1
			hadClimbers = true
			if root.Position.Y < fogY - 0.5 then
				kill(player, humanoid)
			elseif (root.Position - map.escapeZone.Position).Magnitude < map.escapeZone.Size.X / 2 + 2 then
				escape(player, now - start)
			end
		end
		if (hadClimbers and climbing == 0) or fogY >= Config.Tower.Height + 5 then
			return fogY
		end
		task.wait(0.1)
	end
end

local function intermission()
	setState(Fog.Intermission, { StateDuration = Config.Fog.Intermission })
	for _, player in Players:GetPlayers() do
		local state = states[player]
		if state then
			state.escaped = false
			state.inRound = true
			player:SetAttribute("EscapeTime", nil)
			task.spawn(player.LoadCharacter, player)
		end
	end
	task.wait(Config.Fog.Intermission)
end

task.spawn(function()
	while true do
		-- Wait for at least one player before starting a round.
		while #Players:GetPlayers() == 0 do
			task.wait(0.5)
		end
		intermission()
		local finalFog = climb()
		local anyEscaped = false
		for _, state in states do
			anyEscaped = anyEscaped or state.escaped
		end
		if not anyEscaped then
			notifyAll("Nobody escaped. The fog claims the Catacombs.", RED)
		end
		setState(Fog.Draining, { DrainFrom = finalFog })
		task.wait(Config.Fog.DrainTime)
		for _, state in states do
			state.inRound = false
		end
	end
end)

if RunService:IsStudio() then
	print("[Depths] Catacombs built. Hold left click / R2 / the GRAPPLE button to hook.")
end
