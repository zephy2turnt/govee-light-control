-- Responsive: makes one layout work on PC, tablet and phone.
--
-- Screens are designed in "design pixels" for a 1280x720 reference screen.
-- Every ScreenGui gets a UIScale that maps design pixels to the real
-- viewport. Touch-only devices use a smaller reference (960x540) so the same
-- layout comes out bigger and stays easy to tap.
--
-- Location: StarterPlayerScripts > Client > UI > Responsive (ModuleScript)

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Responsive = {}

local DESKTOP_REFERENCE = Vector2.new(1280, 720)
local TOUCH_REFERENCE = Vector2.new(960, 540)

local scales: { UIScale } = {}
local listeners: { (number) -> () } = {}
local currentScale = 1

function Responsive.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function compute(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else DESKTOP_REFERENCE
	local reference = if Responsive.isTouch() then TOUCH_REFERENCE else DESKTOP_REFERENCE
	local s = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	return math.clamp(s, 0.5, 1.6)
end

local function apply()
	currentScale = compute()
	for _, s in scales do
		s.Scale = currentScale
	end
	for _, fn in listeners do
		task.spawn(fn, currentScale)
	end
end

-- Adds the shared UIScale to a ScreenGui. Lay out its children in design
-- pixels (offset) or in scale relative to the design-size root returned here.
-- Returns a full-screen "Root" frame sized in design pixels.
function Responsive.attach(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	-- Anchored top-left so scaling grows it towards the bottom-right and it
	-- always lands exactly over the viewport.
	root.AnchorPoint = Vector2.zero
	root.Position = UDim2.new()
	root.Parent = gui

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = currentScale
	uiScale.Parent = root
	table.insert(scales, uiScale)

	-- The root always covers the whole screen in design pixels, so children
	-- can anchor to its edges with scale positions and still be sized in
	-- design pixels.
	local function resize()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else DESKTOP_REFERENCE
		root.Size = UDim2.fromOffset(viewport.X / currentScale, viewport.Y / currentScale)
	end
	resize()
	Responsive.onChanged(resize)
	return root
end

function Responsive.getScale(): number
	return currentScale
end

function Responsive.onChanged(fn: (number) -> ())
	table.insert(listeners, fn)
end

local function watchCamera(camera: Camera?)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end

watchCamera(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera(Workspace.CurrentCamera)
	apply()
end)
UserInputService.LastInputTypeChanged:Connect(apply)
currentScale = compute()

return Responsive
