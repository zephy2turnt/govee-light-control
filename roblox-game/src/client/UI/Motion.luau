-- Motion: shared animation helpers so every menu moves the same way.
--
-- Panels are built as CanvasGroups (so the whole panel can fade as one
-- image) with a UIScale child (so it can grow/shrink without disturbing
-- layout). open/close tween both together.
--
-- Location: StarterPlayerScripts > Client > UI > Motion (ModuleScript)

local TweenService = game:GetService("TweenService")

local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Theme"))

local Motion = {}

function Motion.tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

-- Returns (creating if needed) the UIScale used for scale animations.
function Motion.scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("MotionScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local s = Instance.new("UIScale")
	s.Name = "MotionScale"
	s.Parent = gui
	return s
end

-- Tracks the running open/close so a fast double-click can't leave a
-- panel half-faded.
local token: { [GuiObject]: number } = {}

local function setFade(gui: GuiObject, value: number)
	if gui:IsA("CanvasGroup") then
		gui.GroupTransparency = value
	end
end

local function fadeGoal(gui: GuiObject, value: number): { [string]: any }
	if gui:IsA("CanvasGroup") then
		return { GroupTransparency = value }
	end
	return {}
end

function Motion.isOpen(gui: GuiObject): boolean
	return gui.Visible and gui:GetAttribute("MotionOpen") == true
end

-- Pops a panel in: scale 0.82 -> 1 with a Back overshoot, fade 1 -> 0.
function Motion.open(gui: GuiObject)
	token[gui] = (token[gui] or 0) + 1
	gui:SetAttribute("MotionOpen", true)
	local scale = Motion.scaleOf(gui)
	if not gui.Visible then
		scale.Scale = Theme.Scale.OpenFrom
		setFade(gui, 1)
	end
	gui.Visible = true
	Motion.tween(scale, Theme.Tween.Open, { Scale = 1 })
	Motion.tween(gui, Theme.Tween.Fade, fadeGoal(gui, 0))
end

-- Shrinks and fades a panel out, then hides it. Yields until finished.
function Motion.close(gui: GuiObject)
	token[gui] = (token[gui] or 0) + 1
	local myToken = token[gui]
	gui:SetAttribute("MotionOpen", false)
	if not gui.Visible then
		return
	end
	local scale = Motion.scaleOf(gui)
	Motion.tween(scale, Theme.Tween.Close, { Scale = Theme.Scale.OpenFrom })
	Motion.tween(gui, Theme.Tween.Close, fadeGoal(gui, 1))
	task.wait(Theme.Tween.Close.Time)
	if token[gui] == myToken then
		gui.Visible = false
	end
end

-- Slides an element in from an offset (in design pixels) to where it is now.
-- `delay` staggers groups of elements for a cascading entrance.
function Motion.slideIn(gui: GuiObject, from: Vector2, delay: number?)
	-- Remember the layout position the first time, so slideOut/slideIn
	-- cycles always return to the same spot.
	local home = gui:GetAttribute("HomePosition")
	if typeof(home) ~= "UDim2" then
		home = gui.Position
		gui:SetAttribute("HomePosition", home)
	end
	local target = home :: UDim2
	gui.Position = target + UDim2.fromOffset(from.X, from.Y)
	local fade = gui:IsA("CanvasGroup")
	if fade then
		(gui :: CanvasGroup).GroupTransparency = 1
	end
	gui.Visible = true
	task.delay(delay or 0, function()
		Motion.tween(gui, Theme.Tween.Slide, { Position = target })
		if fade then
			Motion.tween(gui, Theme.Tween.Fade, { GroupTransparency = 0 })
		end
	end)
end

-- Slides an element out by an offset and fades it. Yields until finished.
function Motion.slideOut(gui: GuiObject, by: Vector2, delay: number?)
	if delay and delay > 0 then
		task.wait(delay)
	end
	local info = Theme.Tween.Close
	Motion.tween(gui, info, { Position = gui.Position + UDim2.fromOffset(by.X, by.Y) })
	if gui:IsA("CanvasGroup") then
		Motion.tween(gui, info, { GroupTransparency = 1 })
	end
	task.wait(info.Time)
end

-- Quick "pop" used when a value changes (e.g. currency counter).
function Motion.pop(gui: GuiObject, amount: number?)
	local scale = Motion.scaleOf(gui)
	scale.Scale = 1 + (amount or 0.12)
	Motion.tween(scale, Theme.Tween.Release, { Scale = 1 })
end

return Motion
