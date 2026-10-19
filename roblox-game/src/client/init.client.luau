-- Client entry point.
--
-- On join: lock controls, hide gameplay UI, orbit the camera over the map
-- and show the main menu. When the player's data is loaded the PLAY button
-- unlocks; pressing it animates the menu away, flies the camera down to the
-- character and hands control back.
--
-- Location: StarterPlayerScripts > Client (LocalScript). Every ModuleScript
-- in the UI, Systems and Screens folders sits underneath this script.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local UI = script.UI
local Responsive = require(UI.Responsive)
local Sound = require(UI.Sound)
local MenuCamera = require(script.Systems.MenuCamera)
local SettingsController = require(script.Systems.SettingsController)
local MainMenu = require(script.Screens.MainMenu)
local SettingsScreen = require(script.Screens.SettingsScreen)
local Hud = require(script.Hud)

local player = Players.LocalPlayer

-- Screen ---------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "MenuUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local root = Responsive.attach(gui)
gui.Parent = player:WaitForChild("PlayerGui")

-- Gameplay lock ----------------------------------------------------------------

local controls = nil
local playing = false
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
	end)
	if ok then
		controls = (playerModule :: any):GetControls()
		-- The module can finish loading after the menu is up; start locked.
		if not playing then
			controls:Disable()
		end
	end
end)

local CORE_GUIS = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health }

local function setGameplayEnabled(enabled: boolean)
	for _, coreGui in CORE_GUIS do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGui, enabled)
	end
	ProximityPromptService.Enabled = enabled
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
	Hud.setVisible(enabled)
end

-- Screens ------------------------------------------------------------------------

local settingsScreen = SettingsScreen.new(root)
local menu

menu = MainMenu.new(root, {
	onPlay = function()
		if playing or not menu.ready then
			return
		end
		playing = true
		if settingsScreen:isOpen() then
			task.spawn(settingsScreen.close, settingsScreen)
		end
		Sound.playMusic(nil, 1.2)
		menu:hide()
		MenuCamera.stop()
		setGameplayEnabled(true)
	end,
	onSettings = function()
		settingsScreen:open()
	end,
})

-- Boot -----------------------------------------------------------------------------

setGameplayEnabled(false)

MenuCamera.start()
Sound.playMusic("Menu")
menu:show()

task.spawn(SettingsController.init)

-- PLAY unlocks once the server has created the player's profile.
task.spawn(function()
	player:WaitForChild("leaderstats")
	menu:setReady()
end)
