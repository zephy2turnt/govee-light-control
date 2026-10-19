-- AimCamera: a precise first-person camera for training.
--
-- Roblox's default camera adds smoothing and its own sensitivity curve.
-- Aim training needs raw, consistent input, so while a round runs we take
-- the camera over completely:
--   * mouse: raw pixel delta x sensitivity (degrees per pixel), no smoothing
--   * touch: drag anywhere that isn't a button
--   * gamepad: right stick
-- The mouse is locked to the centre of the screen and hidden; the
-- crosshair is drawn by the HUD.
--
-- Location: StarterPlayerScripts > Client > AimCamera (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AimCamera = {}

local BIND = "AimCamera"
local PITCH_LIMIT = 80
local TOUCH_FACTOR = 1.6 -- touch drags cover fewer pixels than mouse flicks
local STICK_SPEED = 220 -- degrees per second at full stick

local active = false
local eye = CFrame.identity
local yaw, pitch = 0, 0
local sensitivity = 0.15
local fov = 75
local touchConnection: RBXScriptConnection? = nil

function AimCamera.setSensitivity(degreesPerPixel: number)
	sensitivity = degreesPerPixel
end

function AimCamera.setFov(value: number)
	fov = value
	if active then
		Workspace.CurrentCamera.FieldOfView = fov
	end
end

-- Hide our own character so the head doesn't block the view.
local function hideCharacter(hidden: boolean)
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- Starts first-person aiming from `eyeCFrame`, looking where it looks.
function AimCamera.start(eyeCFrame: CFrame)
	if active then
		return
	end
	active = true
	eye = eyeCFrame
	local look = eyeCFrame.LookVector
	yaw = math.deg(math.atan2(-look.X, -look.Z))
	pitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))

	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fov
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseDeltaSensitivity = 1

	touchConnection = UserInputService.TouchMoved:Connect(function(touch, processed)
		if processed then
			return -- dragging a button, not the view
		end
		yaw -= touch.Delta.X * sensitivity * TOUCH_FACTOR
		pitch = math.clamp(pitch - touch.Delta.Y * sensitivity * TOUCH_FACTOR, -PITCH_LIMIT, PITCH_LIMIT)
	end)

	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		-- Default scripts can reset these; keep re-asserting while aiming.
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false

		local delta = UserInputService:GetMouseDelta()
		yaw -= delta.X * sensitivity
		pitch = math.clamp(pitch - delta.Y * sensitivity, -PITCH_LIMIT, PITCH_LIMIT)

		for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if input.KeyCode == Enum.KeyCode.Thumbstick2 then
				local stick = input.Position
				if stick.Magnitude > 0.12 then
					yaw -= stick.X * STICK_SPEED * dt * (sensitivity / 0.15)
					pitch = math.clamp(pitch + stick.Y * STICK_SPEED * dt * (sensitivity / 0.15), -PITCH_LIMIT, PITCH_LIMIT)
				end
			end
		end

		camera.CFrame = CFrame.new(eye.Position) * CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), 0)
		hideCharacter(true)
	end)
end

function AimCamera.stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(BIND)
	if touchConnection then
		touchConnection:Disconnect()
		touchConnection = nil
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	hideCharacter(false)
end

-- Where the crosshair points: the centre of the screen.
function AimCamera.ray(): Ray
	local camera = Workspace.CurrentCamera
	return Ray.new(camera.CFrame.Position, camera.CFrame.LookVector)
end

function AimCamera.isActive(): boolean
	return active
end

return AimCamera
