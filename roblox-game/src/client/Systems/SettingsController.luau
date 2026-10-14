-- SettingsController: owns the player's settings on the client.
--
-- Loads saved settings from the server, applies them (volumes, graphics),
-- and sends changes back to be saved. The server validates and stores them
-- in the player's DataStore profile, so settings follow the player across
-- devices.
--
-- Location: StarterPlayerScripts > Client > Systems > SettingsController (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Sound = require(script.Parent.Parent.UI.Sound)
local Graphics = require(script.Parent.Graphics)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetSettings = remotes:WaitForChild("GetSettings") :: RemoteFunction
local SaveSettings = remotes:WaitForChild("SaveSettings") :: RemoteEvent

export type Settings = { music: number, sfx: number, quality: string }

local SettingsController = {}

local current: Settings = table.clone(Theme.DefaultSettings)
local saved: Settings = table.clone(current)

local function apply()
	Sound.setVolumes(current.music, current.sfx)
	Graphics.apply(current.quality)
end

-- Fetches saved settings (yields until the server has loaded the profile).
function SettingsController.init()
	apply()
	local ok, result = pcall(function()
		return GetSettings:InvokeServer()
	end)
	if ok and type(result) == "table" then
		current = {
			music = tonumber(result.music) or current.music,
			sfx = tonumber(result.sfx) or current.sfx,
			quality = if table.find(Theme.QualityLevels, result.quality) then result.quality else current.quality,
		}
		saved = table.clone(current)
		apply()
	else
		warn("[Settings] could not load settings:", result)
	end
end

function SettingsController.get(): Settings
	return table.clone(current)
end

-- Applies a change immediately (so sliders feel live) without saving yet.
function SettingsController.set(key: string, value: any)
	if key == "music" or key == "sfx" then
		current[key] = math.clamp(tonumber(value) or 0, 0, 1)
	elseif key == "quality" and table.find(Theme.QualityLevels, value) then
		current.quality = value
	else
		return
	end
	apply()
end

-- Sends the settings to the server if anything changed since the last save.
function SettingsController.commit()
	if current.music == saved.music and current.sfx == saved.sfx and current.quality == saved.quality then
		return
	end
	saved = table.clone(current)
	SaveSettings:FireServer(saved)
end

return SettingsController
