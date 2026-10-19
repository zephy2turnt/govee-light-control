-- CameraFX: one owner for field of view and camera shake, so speed,
-- grapple impacts and fog danger can all contribute without fighting.
--
--   CameraFX.setFOV(fov)              base FOV this frame (speed sets it)
--   CameraFX.punch(degrees)           quick FOV kick that springs back
--   CameraFX.setShake(source, amp)    continuous shake from a named source
--   CameraFX.kick(amp)                one-off jolt that decays
--
-- Shake moves Humanoid.CameraOffset, which works with the default camera.
--
-- Location: StarterPlayerScripts > Client > CameraFX (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local CameraFX = {}

local baseFOV = Config.SpeedFX.BaseFOV
local punch = 0
local kickAmp = 0
local sources: { [string]: number } = {}
local enabled = true

function CameraFX.setFOV(fov: number)
	baseFOV = fov
end

function CameraFX.punch(degrees: number)
	punch = math.max(punch, degrees)
end

function CameraFX.kick(amount: number)
	kickAmp = math.max(kickAmp, amount)
end

function CameraFX.setShake(source: string, amount: number)
	sources[source] = amount
end

-- Turned off while a scripted camera (spectating) is in control.
function CameraFX.setEnabled(on: boolean)
	enabled = on
end

RunService:BindToRenderStep("CameraFX", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	punch *= math.exp(-7 * dt)
	kickAmp *= math.exp(-9 * dt)
	if not enabled then
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
		return
	end

	local goal = baseFOV + punch
	camera.FieldOfView += (goal - camera.FieldOfView) * (1 - math.exp(-12 * dt))

	local amp = kickAmp
	for _, a in sources do
		amp += a
	end
	if humanoid then
		if amp > 0.001 then
			local t = os.clock() * 22
			humanoid.CameraOffset = Vector3.new(math.noise(t, 1.7), math.noise(t, 5.3), math.noise(t, 9.1)) * amp * 2
		else
			humanoid.CameraOffset = Vector3.zero
		end
	end
end)

return CameraFX
