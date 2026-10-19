-- DEPTHS: RISE OR DIE, client entry point.
--
-- Starts every client system. When the player has no character (joined
-- mid-climb and waiting for the next round), the camera slowly orbits the
-- chasm so they can watch.
--
-- Location: StarterPlayerScripts > Client (LocalScript). The modules
-- Audio, CameraFX, Grapple, Ropes, SpeedFX, FogFX and Hud sit inside it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local CameraFX = require(script.CameraFX)
local Grapple = require(script.Grapple)
local Ropes = require(script.Ropes)
local SpeedFX = require(script.SpeedFX)
local FogFX = require(script.FogFX)
local Hud = require(script.Hud)

local player = Players.LocalPlayer

FogFX.init()
SpeedFX.init()
Grapple.init()
Ropes.init()
Hud.init()

-- Spectator orbit while there is no character.
local angle = 0
local spectating = false
RunService:BindToRenderStep("SpectateOrbit", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local camera = Workspace.CurrentCamera
	local wantSpectate = player.Character == nil
	if wantSpectate ~= spectating then
		spectating = wantSpectate
		CameraFX.setEnabled(not spectating)
		camera.CameraType = if spectating then Enum.CameraType.Scriptable else Enum.CameraType.Custom
	end
	if not spectating then
		return
	end
	angle += dt * 0.08
	local radius = Config.Tower.Radius * 0.75
	local height = Config.Tower.Height * 0.55
	local position = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	camera.CFrame = CFrame.lookAt(position, Vector3.new(0, height * 0.6, 0))
	camera.FieldOfView = 70
end)
