-- FogFX: the rising necro-fog and everything that makes it scary.
--
-- Visuals are client-side and follow the shared Fog formula every frame, so
-- the fog rises perfectly smoothly. The server uses the same formula to
-- decide who dies.
--
-- Danger (how close the fog is beneath you) drives:
--   * a heartbeat that gets louder and faster
--   * a drum track that fades in over the ambient drone
--   * a green vignette creeping in from the screen edges
--   * screen shake
--
-- Location: StarterPlayerScripts > Client > FogFX (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Fog = require(Shared.Fog)
local Audio = require(script.Parent.Audio)
local CameraFX = require(script.Parent.CameraFX)

local FogFX = {}

local player = Players.LocalPlayer
local FOG_GREEN = Color3.fromRGB(70, 255, 150)
local FOG_DEEP = Color3.fromRGB(6, 40, 24)

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function localPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function buildFog(parent: Instance): (Part, Part, Part)
	local width = Config.Tower.Radius * 2 + 40

	-- Glowing surface.
	local surface = localPart({
		Name = "FogSurface",
		Size = Vector3.new(width, 1, width),
		Color = FOG_GREEN,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Parent = parent,
	})
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Top
	glow.Color = FOG_GREEN
	glow.Brightness = 3
	glow.Range = 45
	glow.Angle = 120
	glow.Parent = surface

	-- Bubbles bursting on the surface.
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(180, 255, 210))
	bubbles.LightEmission = 1
	bubbles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.8, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Speed = NumberRange.new(2, 7)
	bubbles.Rate = 70
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Shape = Enum.ParticleEmitterShape.Box
	bubbles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	bubbles.Parent = surface

	-- Opaque body underneath so you can't see the floor through it.
	local body = localPart({
		Name = "FogBody",
		Size = Vector3.new(width, 200, width),
		Color = FOG_DEEP,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.05,
		Parent = parent,
	})

	-- Thick smoke billowing above the surface.
	local mist = localPart({
		Name = "FogMist",
		Size = Vector3.new(width - 30, 10, width - 30),
		Transparency = 1,
		Parent = parent,
	})
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(80, 255, 160), Color3.fromRGB(20, 120, 80))
	smoke.LightEmission = 0.6
	smoke.LightInfluence = 0.2
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new(8, 22)
	smoke.Lifetime = NumberRange.new(4, 7)
	smoke.Speed = NumberRange.new(1, 4)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.Rate = 55
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Shape = Enum.ParticleEmitterShape.Box
	smoke.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	smoke.Parent = mist

	return surface, body, mist
end

-- Four gradient strips around the screen edges.
local function buildVignette(gui: ScreenGui): { Frame }
	local strips = {}
	local specs = {
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(1, 0.35), rotation = 90 },
		{ anchor = Vector2.new(0, 1), size = UDim2.fromScale(1, 0.35), rotation = 270 },
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(0.3, 1), rotation = 0 },
		{ anchor = Vector2.new(1, 0), size = UDim2.fromScale(0.3, 1), rotation = 180 },
	}
	for _, spec in specs do
		local strip = Instance.new("Frame")
		strip.AnchorPoint = spec.anchor
		strip.Position = UDim2.fromScale(spec.anchor.X, spec.anchor.Y)
		strip.Size = spec.size
		strip.BorderSizePixel = 0
		strip.BackgroundColor3 = Color3.fromRGB(10, 70, 40)
		strip.BackgroundTransparency = 1
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.rotation
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = strip
		strip.Parent = gui
		table.insert(strips, strip)
	end
	return strips
end

function FogFX.init()
	local folder = Instance.new("Folder")
	folder.Name = "FogFX"
	folder.Parent = Workspace.CurrentCamera
	local surface, body, mist = buildFog(folder)

	local gui = Instance.new("ScreenGui")
	gui.Name = "FogDanger"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local strips = buildVignette(gui)

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = FOG_GREEN
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local drone = Audio.loop("Drone")
	local drums = Audio.loop("Drums")
	local heartbeat = Audio.loop("Heartbeat")

	-- Consumed: green flash and a deep boom.
	local function bindCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				Audio.play("Consumed")
				CameraFX.kick(0.8)
				flash.BackgroundTransparency = 0.25
				TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
			end)
		end
	end
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	local danger = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local fogY = Fog.height()
		surface.CFrame = CFrame.new(0, fogY - 0.5, 0)
		body.CFrame = CFrame.new(0, fogY - 1 - body.Size.Y / 2, 0)
		mist.CFrame = CFrame.new(0, fogY + 4, 0)

		local state = Workspace:GetAttribute("RoundState")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local target = 0
		if state == Fog.Climbing and root and humanoid and humanoid.Health > 0 and not player:GetAttribute("EscapeTime") then
			local gap = root.Position.Y - fogY
			target = math.clamp(1 - (gap - 4) / Config.Fog.DangerRange, 0, 1)
		end
		-- Ease so the effects swell rather than snap.
		danger += (target - danger) * (1 - math.exp(-4 * dt))

		heartbeat.Volume = danger * 0.9
		heartbeat.PlaybackSpeed = 0.9 + danger * 0.4
		drums.Volume = smoothstep(0.25, 0.8, danger) * 0.6
		drone.Volume = if state == Fog.Climbing then 0.4 else 0.2
		CameraFX.setShake("fog", danger * danger * 0.16)
		for _, strip in strips do
			strip.BackgroundTransparency = 1 - danger * 0.8
		end
	end)
end

return FogFX
