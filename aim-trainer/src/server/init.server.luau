-- AIM RANGE: server entry point.
--
-- The aim training itself runs on each player's client (targets, hit
-- detection, timing), because it has to be instant. The server's jobs:
--   * give every player a private booth and keep them standing in it
--   * hand out a one-time round token when a round starts
--   * check every submitted result (timing + Modes.validate) before it can
--     become a personal best or reach the leaderboard
--   * save profiles and serve leaderboards
--
-- Location: ServerScriptService > Server (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Modes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modes"))
local Range = require(script.Range)
local Data = require(script.Data)

local booths = Range.build()
local boothOwners: { [number]: Player } = {}

-- Remotes ----------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function fn(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = remotes
	return r
end
local GetProfile = fn("GetProfile") -- () -> { bests, settings, canSave }
local StartRound = fn("StartRound") -- (modeId) -> token
local SubmitResult = fn("SubmitResult") -- (token, stats) -> result
local GetLeaderboard = fn("GetLeaderboard") -- (modeId) -> entries
local SaveSettings = Instance.new("RemoteEvent") -- (settings)
SaveSettings.Name = "SaveSettings"
SaveSettings.Parent = remotes
remotes.Parent = ReplicatedStorage

-- Player state -------------------------------------------------------------------

type Round = { token: string, modeId: string, startedAt: number }
type State = {
	profile: Data.Profile,
	canSave: boolean,
	booth: number,
	round: Round?,
	lastRequest: number,
	lastSettingsSave: number,
}
local states: { [Player]: State } = {}

-- Keeps the character standing still on its booth's platform.
local function placeCharacter(player: Player, character: Model)
	local state = states[player]
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not (state and root) then
		return
	end
	local stand = booths[state.booth]:GetAttribute("StandCFrame") :: CFrame
	character:PivotTo(stand)
	root.Anchored = true
end

local function onPlayerAdded(player: Player)
	local boothIndex: number? = nil
	for i = 1, #booths do
		if not boothOwners[i] then
			boothIndex = i
			break
		end
	end
	if not boothIndex then
		player:Kick("All booths are full. Try another server!")
		return
	end
	boothOwners[boothIndex] = player
	player:SetAttribute("Booth", boothIndex)

	local profile, canSave = Data.load(player.UserId)
	if not player.Parent then
		boothOwners[boothIndex] = nil
		return
	end
	states[player] = {
		profile = profile,
		canSave = canSave,
		booth = boothIndex,
		round = nil,
		lastRequest = 0,
		lastSettingsSave = 0,
	}
	player:SetAttribute("Ready", true)

	player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	for i, owner in boothOwners do
		if owner == player then
			boothOwners[i] = nil
		end
	end
	states[player] = nil
	if state and state.canSave then
		Data.save(player.UserId, state.profile)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	local pending = 0
	for player, state in states do
		if state.canSave then
			pending += 1
			task.spawn(function()
				Data.save(player.UserId, state.profile)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end)

-- Waits briefly for a player's profile (the client asks as soon as it starts).
local function waitForState(player: Player): State?
	local waited = 0
	while not states[player] and player.Parent and waited < 20 do
		waited += task.wait(0.25)
	end
	return states[player]
end

-- Simple per-player rate limit for the remotes below.
local function throttled(state: State): boolean
	local now = os.clock()
	if now - state.lastRequest < 0.2 then
		return true
	end
	state.lastRequest = now
	return false
end

-- Remote handlers ---------------------------------------------------------------------

GetProfile.OnServerInvoke = function(player)
	local state = waitForState(player)
	if not state then
		return nil
	end
	return { bests = state.profile.bests, settings = state.profile.settings, canSave = state.canSave }
end

StartRound.OnServerInvoke = function(player, modeId)
	local state = states[player]
	if not state or throttled(state) or type(modeId) ~= "string" or not Modes.list[modeId] then
		return nil
	end
	local round = { token = HttpService:GenerateGUID(false), modeId = modeId, startedAt = os.clock() }
	state.round = round
	return round.token
end

SubmitResult.OnServerInvoke = function(player, token, stats)
	local state = states[player]
	if not state or throttled(state) then
		return nil
	end
	local round = state.round
	if not round or type(token) ~= "string" or token ~= round.token then
		return { error = "no active round" }
	end
	state.round = nil -- every token can be used exactly once

	local mode = Modes.list[round.modeId]
	-- The round can't have finished faster than countdown + duration.
	local elapsed = os.clock() - round.startedAt
	if elapsed < Modes.Countdown + mode.duration - 1.5 or elapsed > Modes.Countdown + mode.duration + 30 then
		return { error = "round timing didn't add up" }
	end
	local problem = Modes.validate(mode, stats)
	if problem then
		warn(string.format("[AimRange] rejected result from %s: %s", player.Name, problem))
		return { error = "result rejected" }
	end

	local score = Modes.score(mode, stats)
	local accuracy = Modes.accuracy(mode, stats)
	local previous = state.profile.bests[mode.id]
	local newBest = previous == nil or score > previous.score
	if newBest then
		state.profile.bests[mode.id] = {
			score = score,
			accuracy = accuracy,
			hits = stats.hits,
			at = os.time(),
		}
		if state.canSave then
			task.spawn(Data.submitScore, mode.id, player.UserId, score)
			task.spawn(Data.save, player.UserId, state.profile)
		end
	end
	return {
		score = score,
		accuracy = accuracy,
		best = state.profile.bests[mode.id].score,
		previousBest = if previous then previous.score else nil,
		newBest = newBest,
	}
end

GetLeaderboard.OnServerInvoke = function(player, modeId)
	local state = states[player]
	if not state or type(modeId) ~= "string" or not Modes.list[modeId] then
		return {}
	end
	return Data.top(modeId)
end

SaveSettings.OnServerEvent:Connect(function(player, raw)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	if now - state.lastSettingsSave < 0.5 then
		return
	end
	state.lastSettingsSave = now
	state.profile.settings = Data.sanitizeSettings(raw)
end)
