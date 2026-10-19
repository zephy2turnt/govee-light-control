-- Settings: the player's settings on the client.
--
-- Applies them live (camera sensitivity/FOV, volume, crosshair) and sends
-- them to the server to be validated and saved with the player's profile.
--
-- Location: StarterPlayerScripts > Client > Settings (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modes"))
local Audio = require(script.Parent.Audio)
local AimCamera = require(script.Parent.AimCamera)

local SaveSettings = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SaveSettings") :: RemoteEvent

local Settings = {}

local current: { [string]: any } = table.clone(Modes.DefaultSettings)
local saved = table.clone(current)
local listeners: { () -> () } = {}

local function apply()
	AimCamera.setSensitivity(current.sensitivity)
	AimCamera.setFov(current.fov)
	Audio.setVolume(current.volume)
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function Settings.load(raw: { [string]: any }?)
	if raw then
		for k, v in raw do
			if Modes.DefaultSettings[k] ~= nil then
				current[k] = v
			end
		end
	end
	saved = table.clone(current)
	apply()
end

function Settings.get(key: string): any
	return current[key]
end

function Settings.set(key: string, value: any)
	current[key] = value
	apply()
end

-- A copy of every setting (used to draw the crosshair).
function Settings.all(): { [string]: any }
	return table.clone(current)
end

-- Called whenever any setting changes (e.g. to redraw the crosshair).
function Settings.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

-- Sends settings to the server if anything changed since the last save.
function Settings.commit()
	local changed = false
	for k, v in current do
		if saved[k] ~= v then
			changed = true
			break
		end
	end
	if changed then
		saved = table.clone(current)
		SaveSettings:FireServer(saved)
	end
end

return Settings
