-- MenuCamera: slow cinematic orbit over the map behind the main menu, and
-- a smooth hand-off back to the normal player camera with an FOV punch.
--
-- Location: StarterPlayerScripts > Client > Systems > MenuCamera (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MenuCamera = {}

local BIND_NAME = "MenuCameraOrbit"
local CENTER = Vector3.new(0, 6, 0)
local RADIUS = 150
local HEIGHT = 62
local SPEED = 0.05 -- radians per second
local MENU_FOV = 50
local PLAY_FOV = 70

local running = false
local angle = math.rad(35)

local function orbitCFrame(a: number): CFrame
	local position = CENTER + Vector3.new(math.cos(a) * RADIUS, HEIGHT, math.sin(a) * RADIUS)
	return CFrame.lookAt(position, CENTER)
end

function MenuCamera.start()
	if running then
		return
	end
	running = true
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = MENU_FOV
	camera.CFrame = orbitCFrame(angle)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		angle += dt * SPEED
		local cam = Workspace.CurrentCamera
		-- The default camera scripts can reset the type when the character
		-- spawns, so keep re-asserting it while the menu is up.
		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
		end
		cam.CFrame = orbitCFrame(angle)
	end)
end

-- Flies the camera down to the player's character, then gives control back
-- to the default camera with a quick FOV "punch" for impact. Yields ~1.2s.
function MenuCamera.stop()
	if not running then
		return
	end
	running = false
	RunService:UnbindFromRenderStep(BIND_NAME)

	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local look = root.CFrame.LookVector
		local target = CFrame.lookAt(root.Position - look * 14 + Vector3.new(0, 7, 0), root.Position + Vector3.new(0, 2, 0))
		local fly = TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		TweenService:Create(camera, fly, { CFrame = target, FieldOfView = PLAY_FOV }):Play()
		task.wait(fly.Time)
	end

	camera.CameraType = Enum.CameraType.Custom
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.FieldOfView = PLAY_FOV + 8
	TweenService:Create(camera, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		FieldOfView = PLAY_FOV,
	}):Play()
end

return MenuCamera
