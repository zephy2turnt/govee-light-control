-- SpeedFX: makes speed feel like speed.
--
--   * Wind lines streaking out from the edges of the screen; they appear
--     above Config.SpeedFX.Start and get denser and faster up to .Full
--   * FOV widens with speed (via CameraFX)
--   * Rushing wind sound that rises in volume and pitch
--   * Slight camera shake at top speed
--   * Landing thud + dust burst after a fast fall
--
-- Location: StarterPlayerScripts > Client > SpeedFX (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Audio = require(script.Parent.Audio)
local CameraFX = require(script.Parent.CameraFX)

local SpeedFX = {}

local cfg = Config.SpeedFX
local player = Players.LocalPlayer
local LINE_COUNT = 44

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

type Line = { frame: Frame, angle: number, phase: number, rate: number, width: number }

function SpeedFX.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedLines"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui

	local rng = Random.new()
	local lines: { Line } = {}
	for i = 1, LINE_COUNT do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.fromRGB(225, 255, 240)
		frame.BackgroundTransparency = 1
		frame.Parent = holder
		lines[i] = {
			frame = frame,
			angle = (i / LINE_COUNT) * math.pi * 2 + rng:NextNumber(-0.06, 0.06),
			phase = rng:NextNumber(),
			rate = rng:NextNumber(0.7, 1.3),
			width = rng:NextNumber(1.5, 3),
		}
	end

	local wind = Audio.loop("Wind")

	-- Dust puff at the feet when landing hard.
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(120, 125, 120))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new(1.5, 4)
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(8, 14)
	dust.SpreadAngle = Vector2.new(80, 10)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, -10, 0)
	dust.Drag = 4
	dust.Rate = 0

	local fallSpeed = 0
	local function bindCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not (root and humanoid) then
			return
		end
		local a = Instance.new("Attachment")
		a.Name = "DustAttachment"
		a.Position = Vector3.new(0, -2.8, 0)
		a.Parent = root
		dust.Parent = a
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed and fallSpeed > 55 then
				local k = math.clamp((fallSpeed - 55) / 100, 0, 1)
				Audio.play("Land", 1.1 - k * 0.25, 0.5 + k * 0.5)
				CameraFX.kick(0.15 + k * 0.35)
				dust:Emit(math.floor(10 + k * 20))
			end
		end)
	end
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	RunService.RenderStepped:Connect(function(dt: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
		local speed = velocity.Magnitude
		fallSpeed = if velocity.Y < 0 then -velocity.Y else 0

		local k = smoothstep(cfg.Start, cfg.Full, speed)
		CameraFX.setFOV(cfg.BaseFOV + (cfg.MaxFOV - cfg.BaseFOV) * k)
		CameraFX.setShake("speed", k * k * 0.1)
		wind.Volume = k * 0.8
		wind.PlaybackSpeed = 0.85 + k * 0.45

		if k < 0.01 then
			holder.Visible = false
			return
		end
		holder.Visible = true

		local view = Workspace.CurrentCamera.ViewportSize
		local centre = view / 2
		local halfDiagonal = view.Magnitude / 2
		for _, line in lines do
			line.phase = (line.phase + dt * line.rate * (0.8 + k * 2.8)) % 1
			local p = line.phase
			local direction = Vector2.new(math.cos(line.angle), math.sin(line.angle))
			local position = centre + direction * (0.48 + 0.55 * p) * halfDiagonal
			local length = (30 + 190 * k) * (0.4 + p)
			line.frame.Position = UDim2.fromOffset(position.X, position.Y)
			line.frame.Size = UDim2.fromOffset(length, line.width)
			line.frame.Rotation = math.deg(line.angle)
			line.frame.BackgroundTransparency = 1 - k * 0.75 * math.sin(math.pi * p)
		end
	end)
end

return SpeedFX
