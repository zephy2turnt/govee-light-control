-- Ui: the small design system every screen uses.
--
--   Ui.make(class, props, children)    instance builder
--   Ui.text(props)                     styled TextLabel
--   Ui.button(props)                   button with hover/press/release
--   Ui.panel(props)                    CanvasGroup window that pops open
--   Ui.open(panel) / Ui.close(panel)   animated show/hide
--   Ui.slider(props)                   draggable slider
--   Ui.screen(name, order)             ScreenGui + scaled design-pixel root
--
-- Everything is laid out in design pixels for 1280x720 and scaled to the
-- real screen with a UIScale (touch screens use a smaller reference so
-- buttons stay finger-sized).
--
-- Location: StarterPlayerScripts > Client > Ui (ModuleScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Audio)

local Ui = {}

Ui.Color = {
	Bg = Color3.fromRGB(12, 14, 20),
	Panel = Color3.fromRGB(22, 25, 35),
	Raised = Color3.fromRGB(34, 38, 52),
	Line = Color3.fromRGB(52, 58, 78),
	Text = Color3.fromRGB(240, 244, 255),
	Muted = Color3.fromRGB(140, 150, 175),
	Accent = Color3.fromRGB(0, 220, 255),
	Good = Color3.fromRGB(80, 255, 140),
	Bad = Color3.fromRGB(255, 80, 90),
	Gold = Color3.fromRGB(255, 205, 60),
}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
Ui.Font = {
	Body = Font.new(FAMILY, Enum.FontWeight.Medium),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Heavy = Font.new(FAMILY, Enum.FontWeight.Heavy),
}

Ui.Tween = {
	Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad),
	Press = TweenInfo.new(0.06, Enum.EasingStyle.Quad),
	Release = TweenInfo.new(0.3, Enum.EasingStyle.Back),
	Open = TweenInfo.new(0.35, Enum.EasingStyle.Back),
	Close = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
	Fade = TweenInfo.new(0.25, Enum.EasingStyle.Quint),
}

function Ui.tween(inst: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local t = TweenService:Create(inst, info, goals)
	t:Play()
	return t
end

function Ui.make(className: string, props: { [string]: any }?, children: { any }?): any
	local inst = Instance.new(className)
	local parent = nil
	for k, v in (props or {}) :: { [string]: any } do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local make = Ui.make

function Ui.corner(radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.stroke(color: Color3?, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color or Ui.Color.Line,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("AnimScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	return make("UIScale", { Name = "AnimScale", Parent = gui })
end

function Ui.pop(gui: GuiObject, amount: number?)
	local s = Ui.scaleOf(gui)
	s.Scale = 1 + (amount or 0.15)
	Ui.tween(s, Ui.Tween.Release, { Scale = 1 })
end

function Ui.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Text ---------------------------------------------------------------------------

function Ui.text(p: { [string]: any }): TextLabel
	local label = make("TextLabel", {
		Name = p.Name or "Text",
		BackgroundTransparency = 1,
		Size = p.Size or UDim2.new(1, 0, 0, (p.TextSize or 18) + 6),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		Text = p.Text or "",
		TextSize = p.TextSize or 18,
		FontFace = p.FontFace or Ui.Font.Bold,
		TextColor3 = p.TextColor3 or Ui.Color.Text,
		TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = p.TextYAlignment or Enum.TextYAlignment.Center,
		TextWrapped = p.TextWrapped == true,
		RichText = p.RichText == true,
		LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1,
	})
	label.Parent = p.Parent
	return label
end

-- Button ---------------------------------------------------------------------------

export type Button = {
	Instance: TextButton,
	Label: TextLabel,
	setText: (self: Button, text: string) -> (),
	setColor: (self: Button, color: Color3) -> (),
}

-- Hover grows to 1.05x and brightens, press shrinks to 0.95x and darkens,
-- release springs back with a Back ease. Click sound on activate.
function Ui.button(p: { [string]: any }): Button
	local color: Color3 = p.Color or Ui.Color.Accent
	local hovered, pressed = false, false
	local b = make("TextButton", {
		Name = p.Name or "Button",
		Size = p.Size,
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = p.LayoutOrder or 0,
		ZIndex = p.ZIndex or 1,
	}, {
		Ui.corner(p.Radius or 10),
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		}),
	})
	local scale = Ui.scaleOf(b)
	local label = Ui.text({
		Name = "Label",
		Text = p.Text or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = p.TextSize or 20,
		FontFace = Ui.Font.Heavy,
		TextColor3 = p.TextColor3 or Ui.Color.Bg,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = (p.ZIndex or 1) + 1,
		Parent = b,
	})

	local function refresh(info: TweenInfo)
		local target = if pressed then 0.95 elseif hovered then 1.05 else 1
		local c = if pressed then color:Lerp(Color3.new(0, 0, 0), 0.15) elseif hovered then color:Lerp(Color3.new(1, 1, 1), 0.15) else color
		Ui.tween(scale, info, { Scale = target })
		Ui.tween(b, info, { BackgroundColor3 = c })
	end
	b.MouseEnter:Connect(function()
		if Ui.isTouch() then
			return
		end
		hovered = true
		Audio.play("Hover")
		refresh(Ui.Tween.Hover)
	end)
	b.MouseLeave:Connect(function()
		hovered, pressed = false, false
		refresh(Ui.Tween.Hover)
	end)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = true
			refresh(Ui.Tween.Press)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = false
			refresh(Ui.Tween.Release)
		end
	end)
	b.Activated:Connect(function()
		Audio.play("Click")
		if p.OnClick then
			task.spawn(p.OnClick)
		end
	end)
	b.Parent = p.Parent

	local button = { Instance = b, Label = label }
	function button.setText(_self: any, text: string)
		label.Text = text
	end
	function button.setColor(_self: any, c: Color3)
		color = c
		refresh(Ui.Tween.Hover)
	end
	return (button :: any) :: Button
end

-- Panels -----------------------------------------------------------------------------

-- A CanvasGroup window (so it can fade as one piece) with a rounded body.
-- Returns (group, body). Put content in `body`.
function Ui.panel(p: { [string]: any }): (CanvasGroup, Frame)
	local group = make("CanvasGroup", {
		Name = p.Name or "Panel",
		Size = p.Size,
		Position = p.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = p.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = p.ZIndex or 1,
		Parent = p.Parent,
	})
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Ui.Color.Panel,
		BackgroundTransparency = p.Transparency or 0.04,
		Parent = group,
	}, { Ui.corner(16), Ui.stroke(Ui.Color.Line, 2) })
	return group, body
end

local tokens: { [GuiObject]: number } = {}

function Ui.open(gui: GuiObject)
	tokens[gui] = (tokens[gui] or 0) + 1
	local s = Ui.scaleOf(gui)
	if not gui.Visible then
		s.Scale = 0.88
		if gui:IsA("CanvasGroup") then
			gui.GroupTransparency = 1
		end
	end
	gui.Visible = true
	Ui.tween(s, Ui.Tween.Open, { Scale = 1 })
	if gui:IsA("CanvasGroup") then
		Ui.tween(gui, Ui.Tween.Fade, { GroupTransparency = 0 })
	end
end

-- Yields until hidden.
function Ui.close(gui: GuiObject)
	tokens[gui] = (tokens[gui] or 0) + 1
	local mine = tokens[gui]
	if not gui.Visible then
		return
	end
	Ui.tween(Ui.scaleOf(gui), Ui.Tween.Close, { Scale = 0.9 })
	if gui:IsA("CanvasGroup") then
		Ui.tween(gui, Ui.Tween.Close, { GroupTransparency = 1 })
	end
	task.wait(Ui.Tween.Close.Time)
	if tokens[gui] == mine then
		gui.Visible = false
	end
end

-- Slider -------------------------------------------------------------------------------

export type Slider = { Instance: Frame, set: (self: Slider, value: number) -> () }

-- value/min/max in real units; format(value) gives the label text.
function Ui.slider(p: { [string]: any }): Slider
	local min, max = p.Min :: number, p.Max :: number
	local value = math.clamp(p.Value :: number, min, max)
	local root = make("Frame", {
		Name = p.Name or "Slider",
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = p.Parent,
	})
	Ui.text({ Text = p.Label, Size = UDim2.new(0.6, 0, 0, 24), TextSize = 18, Parent = root })
	local valueLabel = Ui.text({
		Size = UDim2.new(0.4, 0, 0, 24),
		Position = UDim2.fromScale(0.6, 0),
		TextSize = 18,
		TextColor3 = Ui.Color.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = root,
	})
	local hit = make("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 26),
		Parent = root,
	})
	local track = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Ui.Color.Raised,
		Parent = hit,
	}, { Ui.corner(4) })
	local fill = make("Frame", { BackgroundColor3 = Ui.Color.Accent, Size = UDim2.fromScale(0, 1), Parent = track }, { Ui.corner(4) })
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Ui.Color.Text,
		ZIndex = 2,
		Parent = track,
	}, { Ui.corner(10) })

	local function render()
		local t = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(t, 1)
		knob.Position = UDim2.fromScale(t, 0.5)
		valueLabel.Text = if p.Format then p.Format(value) else string.format("%.2f", value)
	end
	render()

	local dragging = false
	local function setFromX(x: number)
		local t = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local raw = min + (max - min) * t
		local step = p.Step or 0
		value = if step > 0 then math.clamp(math.floor(raw / step + 0.5) * step, min, max) else raw
		render()
		if p.OnChanged then
			p.OnChanged(value)
		end
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Ui.tween(Ui.scaleOf(knob), Ui.Tween.Press, { Scale = 1.25 })
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Ui.tween(Ui.scaleOf(knob), Ui.Tween.Release, { Scale = 1 })
			Audio.play("Tick", 0.9 + (value - min) / (max - min) * 0.3)
		end
	end)

	local slider = { Instance = root }
	function slider.set(_self: any, v: number)
		value = math.clamp(v, min, max)
		render()
	end
	return (slider :: any) :: Slider
end

-- Screens -------------------------------------------------------------------------------

-- A ScreenGui with a root frame sized in design pixels and scaled to fit.
function Ui.screen(name: string, displayOrder: number): (ScreenGui, Frame)
	local gui = make("ScreenGui", {
		Name = name,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
	})
	local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
	local s = make("UIScale", { Parent = root })
	local function resize()
		local view = Workspace.CurrentCamera.ViewportSize
		local reference = if Ui.isTouch() then Vector2.new(960, 540) else Vector2.new(1280, 720)
		local k = math.clamp(math.min(view.X / reference.X, view.Y / reference.Y), 0.5, 1.6)
		s.Scale = k
		root.Size = UDim2.fromOffset(view.X / k, view.Y / k)
	end
	resize()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, root
end

return Ui
