-- AIM RANGE: client entry point.
--
-- Flow:  menu -> countdown -> playing -> results -> (retry | menu)
--
--   menu       camera floats behind you looking at your booth's wall
--   countdown  first-person aim camera on, 3-2-1-GO
--   playing    Round runs targets/hits; HUD updates every frame
--   results    server validates the result; results screen shows it
--
-- Controls: shoot = left click / R2 / FIRE button; quit = Backspace / B / X.
--
-- Location: StarterPlayer > StarterPlayerScripts > Client (LocalScript),
-- with every other client ModuleScript inside it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Modes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modes"))
local Audio = require(script.Audio)
local Ui = require(script.Ui)
local AimCamera = require(script.AimCamera)
local Settings = require(script.Settings)
local Round = require(script.Round)
local Menu = require(script.Menu)
local Hud = require(script.Hud)
local Results = require(script.Results)
local SettingsPanel = require(script.SettingsPanel)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetProfile = remotes:WaitForChild("GetProfile") :: RemoteFunction
local StartRound = remotes:WaitForChild("StartRound") :: RemoteFunction
local SubmitResult = remotes:WaitForChild("SubmitResult") :: RemoteFunction

-- An aim trainer doesn't need these.
for _, coreGui in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health } do
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGui, false)
end
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
	end)
	if ok then
		(playerModule :: any):GetControls():Disable()
	end
end)

-- Booth -----------------------------------------------------------------------

local function waitForEye(): CFrame
	while not player:GetAttribute("Booth") do
		player:GetAttributeChangedSignal("Booth"):Wait()
	end
	local booth = Workspace:WaitForChild("Range"):WaitForChild("Booth" .. player:GetAttribute("Booth"))
	return booth:GetAttribute("EyeCFrame") :: CFrame
end

-- Screens ---------------------------------------------------------------------

local _, root = Ui.screen("AimRange", 10)

-- "loading" | "menu" | "countdown" | "playing" | "results". Kept as a plain
-- string: it changes while the countdown yields (quitting mid-countdown).
local state: string = "loading"
local function stateIs(name: string): boolean
	return state == name
end
local eye = CFrame.identity
local bests: { [string]: any } = {}
local round: Round.Round? = nil
local currentMode: Modes.Mode = Modes.list[Modes.order[1]]
local currentToken: string? = nil

local hud, menu, results, settingsPanel
local startRound, quitRound

local function fire()
	if state == "playing" and round then
		round:fire()
	end
end

hud = Hud.new(root, {
	onFire = fire,
	onQuit = function()
		quitRound()
	end,
})
settingsPanel = SettingsPanel.new(root)
menu = Menu.new(root, {
	onPlay = function(modeId)
		startRound(modeId)
	end,
	onSettings = function()
		settingsPanel:open()
	end,
})
results = Results.new(root, {
	onRetry = function()
		startRound(currentMode.id)
	end,
	onMenu = function()
		if state ~= "results" then
			return
		end
		state = "menu"
		results:hide()
		menu:show()
	end,
})

local function applyCrosshair()
	hud.crosshair:apply(Settings.all())
end
Settings.onChanged(applyCrosshair)
applyCrosshair()

-- Menu camera -------------------------------------------------------------------

local MENU_CAM = "MenuCamera"
local function setMenuCamera(on: boolean)
	RunService:UnbindFromRenderStep(MENU_CAM)
	if not on then
		return
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	local wall = (eye * CFrame.new(0, 0, -Modes.TargetDistance)).Position
	RunService:BindToRenderStep(MENU_CAM, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock()
		local position = (eye * CFrame.new(5 + math.sin(t * 0.25) * 2, 2.5 + math.sin(t * 0.17) * 0.6, 11)).Position
		camera.CFrame = CFrame.lookAt(position, wall)
	end)
end

-- Input -------------------------------------------------------------------------------

local function bindRoundInput()
	ContextActionService:BindActionAtPriority("AimFire", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("AimQuit", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			quitRound()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
end

local function unbindRoundInput()
	ContextActionService:UnbindAction("AimFire")
	ContextActionService:UnbindAction("AimQuit")
end

-- Round flow -----------------------------------------------------------------------------

local function finish(stats: Modes.Stats)
	if state ~= "playing" then
		return
	end
	state = "results"
	unbindRoundInput()
	hud:flash("TIME!", currentMode.color)
	task.wait(0.7)
	AimCamera.stop()
	task.spawn(hud.hide, hud)
	setMenuCamera(true)

	local result = nil
	if currentToken then
		local ok, reply = pcall(function()
			return SubmitResult:InvokeServer(currentToken, stats)
		end)
		result = if ok then reply else { error = "couldn't reach server" }
	end
	currentToken = nil
	if type(result) == "table" and result.newBest then
		bests[currentMode.id] = { score = result.score, accuracy = result.accuracy, hits = stats.hits }
		menu:setBests(bests)
	end
	results:show(currentMode, stats, result)
end

function startRound(modeId: string)
	if state ~= "menu" and state ~= "results" then
		return
	end
	local mode = Modes.list[modeId]
	if not mode then
		return
	end
	state = "countdown"
	currentMode = mode
	task.spawn(menu.hide, menu)
	task.spawn(results.hide, results)
	setMenuCamera(false)

	-- Ask the server for a round token (needed for the score to count).
	currentToken = nil
	task.spawn(function()
		local ok, token = pcall(function()
			return StartRound:InvokeServer(modeId)
		end)
		if ok and type(token) == "string" then
			currentToken = token
		end
	end)

	AimCamera.start(eye)
	hud:show(mode)
	bindRoundInput()
	local thisRound = Round.new(mode, eye, {
		onHit = function(combo)
			hud:onHit(combo)
		end,
		onMiss = function()
			hud:onMiss()
		end,
		onEnd = finish,
	})
	round = thisRound

	for n = Modes.Countdown, 1, -1 do
		if not stateIs("countdown") or round ~= thisRound then
			return
		end
		hud:flash(tostring(n))
		Audio.play("Tick", 1 + (Modes.Countdown - n) * 0.12, false)
		task.wait(1)
	end
	if not stateIs("countdown") or round ~= thisRound then
		return
	end
	hud:flash("GO!", mode.color)
	Audio.play("Go")
	state = "playing"
	thisRound:begin()
end

function quitRound()
	if state ~= "countdown" and state ~= "playing" then
		return
	end
	state = "menu"
	if round then
		round:cancel()
		round = nil
	end
	currentToken = nil
	unbindRoundInput()
	AimCamera.stop()
	task.spawn(hud.hide, hud)
	setMenuCamera(true)
	menu:show()
end

RunService.RenderStepped:Connect(function()
	if state == "playing" and round then
		hud:update(round:remaining(), round:liveStats())
	end
end)

-- Boot ----------------------------------------------------------------------------------

eye = waitForEye()
setMenuCamera(true)

local ok, profile = pcall(function()
	return GetProfile:InvokeServer()
end)
if ok and type(profile) == "table" then
	Settings.load(profile.settings)
	bests = profile.bests or {}
	menu:setBests(bests)
	if not profile.canSave then
		warn("[AimRange] Saving is off on this server (DataStores unavailable). Scores won't be kept.")
	end
end
state = "menu"
menu:show()
