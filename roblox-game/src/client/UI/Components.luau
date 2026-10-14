-- Components: the building blocks every screen is made from.
--
--   Components.make(class, props, children)  generic instance builder
--   Components.Text(props)                   styled TextLabel
--   Components.Button(props)                 3D button with hover/press/release
--   Components.Panel(props)                  modal window (CanvasGroup) with header
--   Components.Slider(props)                 draggable 0..1 slider
--   Components.Segmented(props)              pill selector (e.g. Low/Medium/High)
--
-- Location: StarterPlayerScripts > Client > UI > Components (ModuleScript)

local UserInputService = game:GetService("UserInputService")

local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Theme"))
local Motion = require(script.Parent.Motion)
local Sound = require(script.Parent.Sound)
local Responsive = require(script.Parent.Responsive)

local Components = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Generic builder: sets props (Parent last, so the instance is fully built
-- before it appears) and parents any children.
function Components.make(className: string, props: { [string]: any }?, children: { any }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in (props or {}) :: { [string]: any } do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
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
local make = Components.make

function Components.corner(radius: UDim?): UICorner
	return make("UICorner", { CornerRadius = radius or Theme.Radius.Medium })
end

function Components.stroke(thickness: number?, color: Color3?, contextual: boolean?): UIStroke
	return make("UIStroke", {
		Thickness = thickness or Theme.Stroke.Thickness,
		Color = color or Theme.Stroke.Color,
		ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- Vertical light-to-dark gradient; multiplies the background colour so any
-- base colour gets the same glossy, rounded look.
function Components.gloss(strength: number?): UIGradient
	local dark = 1 - (strength or 0.25)
	return make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(WHITE, Color3.new(dark, dark, dark)),
	})
end

function Components.padding(all: number): UIPadding
	local u = UDim.new(0, all)
	return make("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

-- Text -------------------------------------------------------------------------

export type TextProps = {
	text: string,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	font: Font?,
	color: Color3?,
	align: Enum.TextXAlignment?,
	outline: number?, -- outline thickness, 0 for none
	parent: Instance?,
	layoutOrder: number?,
	name: string?,
}

function Components.Text(p: TextProps): TextLabel
	local label = make("TextLabel", {
		Name = p.name or "Text",
		Size = p.size or UDim2.new(1, 0, 0, (p.textSize or Theme.TextSize.Body) + 8),
		Position = p.position or UDim2.new(),
		AnchorPoint = p.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		Text = p.text,
		FontFace = p.font or Theme.Font.Bold,
		TextSize = p.textSize or Theme.TextSize.Body,
		TextColor3 = p.color or Theme.Color.Text,
		TextXAlignment = p.align or Enum.TextXAlignment.Center,
		TextWrapped = true,
		LayoutOrder = p.layoutOrder or 0,
	})
	local outline = p.outline or 2
	if outline > 0 then
		Components.stroke(outline, Theme.Color.Outline, true).Parent = label
	end
	label.Parent = p.parent
	return label
end

-- Button -----------------------------------------------------------------------

local VARIANT_COLORS = {
	Primary = Theme.Color.Primary,
	Secondary = Theme.Color.Secondary,
	Accent = Theme.Color.Accent,
	Neutral = Theme.Color.Neutral,
	Danger = Theme.Color.Error,
}

export type ButtonProps = {
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	variant: string?, -- Primary | Secondary | Accent | Neutral | Danger
	textSize: number?,
	sound: string?, -- Theme.Sound key played on click (default "Click")
	onClick: (() -> ())?,
	parent: Instance?,
	layoutOrder: number?,
	name: string?,
}

export type Button = {
	Root: Frame,
	Face: TextButton,
	Label: TextLabel,
	setText: (self: Button, text: string) -> (),
	setEnabled: (self: Button, enabled: boolean) -> (),
	setVariant: (self: Button, variant: string) -> (),
}

local DEPTH = 6 -- height of the 3D bottom edge in design pixels

-- A chunky 3D button: a darker "base" sits under the coloured face. Pressing
-- pushes the face down onto the base. Hover grows it to 1.05x, press shrinks
-- to 0.95x, release springs back with a Back ease.
function Components.Button(p: ButtonProps): Button
	local baseColor = VARIANT_COLORS[p.variant or "Primary"] or Theme.Color.Primary
	local enabled = true
	local hovered = false
	local pressed = false

	local root = make("Frame", {
		Name = p.name or "Button",
		Size = p.size,
		Position = p.position or UDim2.new(),
		AnchorPoint = p.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		LayoutOrder = p.layoutOrder or 0,
	})
	local scale = Motion.scaleOf(root)

	local base = make("Frame", {
		Name = "Base",
		Size = UDim2.new(1, 0, 1, -DEPTH),
		Position = UDim2.fromOffset(0, DEPTH),
		BackgroundColor3 = baseColor:Lerp(BLACK, 0.45),
		Parent = root,
	}, { Components.corner(Theme.Radius.Medium), Components.stroke() })

	local face = make("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -DEPTH),
		Position = UDim2.new(),
		BackgroundColor3 = baseColor,
		AutoButtonColor = false,
		Text = "",
		Parent = root,
	}, { Components.corner(Theme.Radius.Medium), Components.stroke(), Components.gloss(0.28) })

	-- Soft highlight across the top half sells the "rounded plastic" look.
	make("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -12, 0.42, 0),
		Position = UDim2.fromOffset(6, 4),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.78,
		Parent = face,
	}, { Components.corner(Theme.Radius.Small) })

	local label = Components.Text({
		name = "Label",
		text = p.text,
		size = UDim2.fromScale(1, 1),
		textSize = p.textSize or Theme.TextSize.Button,
		font = Theme.Font.Heavy,
		outline = 2.5,
		parent = face,
	})

	local function faceColor(): Color3
		if not enabled then
			return Theme.Color.Neutral:Lerp(BLACK, 0.2)
		elseif pressed then
			return baseColor:Lerp(BLACK, 0.12)
		elseif hovered then
			return baseColor:Lerp(WHITE, 0.14)
		end
		return baseColor
	end

	local function refresh(info: TweenInfo)
		local targetScale = 1
		if enabled and pressed then
			targetScale = Theme.Scale.Press
		elseif enabled and hovered then
			targetScale = Theme.Scale.Hover
		end
		Motion.tween(scale, info, { Scale = targetScale })
		Motion.tween(face, info, {
			BackgroundColor3 = faceColor(),
			Position = UDim2.fromOffset(0, if pressed and enabled then DEPTH - 1 else 0),
		})
		base.BackgroundColor3 = (if enabled then baseColor else Theme.Color.Neutral):Lerp(BLACK, 0.45)
		label.TextTransparency = if enabled then 0 else 0.35
	end

	face.MouseEnter:Connect(function()
		if Responsive.isTouch() then
			return
		end
		hovered = true
		if enabled then
			Sound.play("Hover")
		end
		refresh(Theme.Tween.Hover)
	end)
	face.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		refresh(Theme.Tween.Hover)
	end)
	face.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			pressed = true
			refresh(Theme.Tween.Press)
		end
	end)
	face.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			pressed = false
			if t == Enum.UserInputType.Touch then
				hovered = false
			end
			refresh(Theme.Tween.Release)
		end
	end)
	face.Activated:Connect(function()
		if not enabled then
			Sound.play("Error")
			return
		end
		Sound.play(p.sound or "Click")
		if p.onClick then
			task.spawn(p.onClick)
		end
	end)

	local button = {
		Root = root,
		Face = face,
		Label = label,
	}
	function button.setText(_self: any, text: string)
		label.Text = text
	end
	function button.setEnabled(_self: any, value: boolean)
		enabled = value
		refresh(Theme.Tween.Hover)
	end
	function button.setVariant(_self: any, variant: string)
		baseColor = VARIANT_COLORS[variant] or baseColor
		refresh(Theme.Tween.Hover)
	end

	root.Parent = p.parent
	return (button :: any) :: Button
end

-- Panel ------------------------------------------------------------------------

export type PanelProps = {
	title: string,
	size: Vector2, -- design pixels
	parent: Instance,
	onClose: (() -> ())?,
	accent: Color3?,
}

export type Panel = {
	Root: CanvasGroup,
	Content: Frame,
}

-- A modal window: CanvasGroup (so Motion can fade it as one piece) holding a
-- rounded body, a coloured header strip with the title, and a close button.
-- Content goes in `Content`, which is padded and sits under the header.
function Components.Panel(p: PanelProps): Panel
	local headerHeight = 70
	local accent = p.accent or Theme.Color.Secondary

	local group = make("CanvasGroup", {
		Name = p.title .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(p.size.X, p.size.Y),
		BackgroundTransparency = 1,
		Visible = false,
		GroupTransparency = 1,
	}, {
		make("UIAspectRatioConstraint", { AspectRatio = p.size.X / p.size.Y }),
		make("UISizeConstraint", { MaxSize = Vector2.new(p.size.X, p.size.Y) }),
	})

	-- Inset by the stroke width so the outline isn't clipped by the group.
	local inset = Theme.Stroke.Thickness + 1
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		Position = UDim2.fromOffset(inset, inset),
		BackgroundColor3 = Theme.Color.Surface,
		Parent = group,
	}, { Components.corner(Theme.Radius.Large), Components.stroke(), Components.gloss(0.12) })

	local header = make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = accent,
		Parent = body,
	}, { Components.corner(Theme.Radius.Large), Components.gloss(0.3) })
	-- Square off the header's bottom corners where it meets the body.
	make("Frame", {
		Name = "HeaderFill",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = accent:Lerp(BLACK, 0.2),
		BorderSizePixel = 0,
		Parent = header,
	})
	make("Frame", {
		Name = "HeaderLine",
		Size = UDim2.new(1, 0, 0, Theme.Stroke.Thickness),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Color.Outline,
		BorderSizePixel = 0,
		Parent = header,
	})

	Components.Text({
		name = "Title",
		text = p.title,
		size = UDim2.new(1, -140, 1, 0),
		position = UDim2.fromOffset(28, 0),
		textSize = Theme.TextSize.Title,
		font = Theme.Font.Display,
		align = Enum.TextXAlignment.Left,
		outline = 3,
		parent = header,
	})

	Components.Button({
		name = "Close",
		text = "X",
		variant = "Danger",
		size = UDim2.fromOffset(58, 58),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, -2),
		textSize = 30,
		sound = "Back",
		onClick = p.onClose,
		parent = header,
	})

	local content = make("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 1, -headerHeight - Theme.Stroke.Thickness),
		Position = UDim2.fromOffset(0, headerHeight + Theme.Stroke.Thickness),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Components.padding(Theme.Spacing.L) })

	group.Parent = p.parent
	return { Root = group, Content = content }
end

-- Slider -----------------------------------------------------------------------

export type SliderProps = {
	label: string,
	value: number, -- 0..1
	onChanged: ((number) -> ())?, -- while dragging
	onReleased: ((number) -> ())?, -- once, when the drag ends
	parent: Instance,
	layoutOrder: number?,
}

export type Slider = { Root: Frame, set: (self: Slider, value: number) -> () }

function Components.Slider(p: SliderProps): Slider
	local value = math.clamp(p.value, 0, 1)
	local root = make("Frame", {
		Name = p.label .. "Slider",
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundTransparency = 1,
		LayoutOrder = p.layoutOrder or 0,
	})
	Components.Text({
		text = p.label,
		size = UDim2.new(0.7, 0, 0, 30),
		align = Enum.TextXAlignment.Left,
		textSize = Theme.TextSize.Body + 2,
		parent = root,
	})
	local valueLabel = Components.Text({
		text = "",
		size = UDim2.new(0.3, 0, 0, 30),
		position = UDim2.fromScale(0.7, 0),
		align = Enum.TextXAlignment.Right,
		textSize = Theme.TextSize.Body + 2,
		color = Theme.Color.Accent,
		font = Theme.Font.Heavy,
		parent = root,
	})

	-- The track is the touch target, so it's taller than it looks.
	local hit = make("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 34),
		Parent = root,
	})
	local track = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = Theme.Color.SurfaceSunken,
		Parent = hit,
	}, { Components.corner(Theme.Radius.Pill), Components.stroke(Theme.Stroke.ThicknessThin) })
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(value, 1),
		BackgroundColor3 = Theme.Color.Primary,
		Parent = track,
	}, { Components.corner(Theme.Radius.Pill), Components.gloss(0.3) })
	local knob = make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Parent = track,
	}, { Components.corner(Theme.Radius.Pill), Components.stroke(), Components.gloss(0.2) })
	local knobScale = Motion.scaleOf(knob)

	local fast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function render(info: TweenInfo)
		valueLabel.Text = string.format("%d%%", math.floor(value * 100 + 0.5))
		Motion.tween(fill, info, { Size = UDim2.fromScale(value, 1) })
		Motion.tween(knob, info, { Position = UDim2.fromScale(value, 0.5) })
	end
	render(fast)

	local dragging = false
	local function setFromX(x: number)
		local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		value = math.clamp(rel, 0, 1)
		render(fast)
		if p.onChanged then
			p.onChanged(value)
		end
	end

	hit.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			Motion.tween(knobScale, Theme.Tween.Press, { Scale = 1.2 })
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
			Motion.tween(knobScale, Theme.Tween.Release, { Scale = 1 })
			Sound.play("Tick", 0.9 + value * 0.3)
			if p.onReleased then
				p.onReleased(value)
			end
		end
	end)

	root.Parent = p.parent
	local slider = { Root = root }
	function slider.set(_self: any, v: number)
		value = math.clamp(v, 0, 1)
		render(Theme.Tween.Value)
	end
	return (slider :: any) :: Slider
end

-- Segmented control ---------------------------------------------------------------

export type SegmentedProps = {
	options: { string },
	value: string,
	onChanged: ((string) -> ())?,
	parent: Instance,
	layoutOrder: number?,
}

export type Segmented = { Root: Frame, set: (self: Segmented, value: string) -> () }

-- A pill with one option per segment; a highlight slides to the selection.
function Components.Segmented(p: SegmentedProps): Segmented
	local count = #p.options
	local root = make("Frame", {
		Name = "Segmented",
		Size = UDim2.new(1, 0, 0, Theme.MinTapHeight),
		BackgroundColor3 = Theme.Color.SurfaceSunken,
		LayoutOrder = p.layoutOrder or 0,
	}, { Components.corner(Theme.Radius.Pill), Components.stroke(), Components.padding(5) })

	local highlight = make("Frame", {
		Name = "Highlight",
		Size = UDim2.fromScale(1 / count, 1),
		BackgroundColor3 = Theme.Color.Secondary,
		Parent = root,
	}, { Components.corner(Theme.Radius.Pill), Components.stroke(Theme.Stroke.ThicknessThin), Components.gloss(0.28) })

	local labels: { [string]: TextLabel } = {}
	local current = p.value

	local function render(info: TweenInfo)
		local index = table.find(p.options, current) or 1
		Motion.tween(highlight, info, { Position = UDim2.fromScale((index - 1) / count, 0) })
		for option, label in labels do
			Motion.tween(label, Theme.Tween.Hover, {
				TextColor3 = if option == current then Theme.Color.Text else Theme.Color.TextMuted,
			})
		end
	end

	for i, option in p.options do
		local button = make("TextButton", {
			Name = option,
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1 / count, 1),
			Position = UDim2.fromScale((i - 1) / count, 0),
			ZIndex = 2,
			Parent = root,
		})
		labels[option] = Components.Text({
			text = option,
			size = UDim2.fromScale(1, 1),
			font = Theme.Font.Heavy,
			textSize = Theme.TextSize.Body + 2,
			color = Theme.Color.TextMuted,
			parent = button,
		})
		button.MouseEnter:Connect(function()
			if option ~= current and not Responsive.isTouch() then
				Sound.play("Hover")
				Motion.tween(labels[option], Theme.Tween.Hover, { TextColor3 = Theme.Color.Text })
			end
		end)
		button.MouseLeave:Connect(function()
			render(Theme.Tween.Hover)
		end)
		button.Activated:Connect(function()
			if option == current then
				return
			end
			current = option
			Sound.play("Tick")
			Motion.pop(highlight, 0.06)
			render(Theme.Tween.Release)
			if p.onChanged then
				p.onChanged(option)
			end
		end)
	end
	render(TweenInfo.new(0))

	root.Parent = p.parent
	local segmented = { Root = root }
	function segmented.set(_self: any, value: string)
		current = value
		render(Theme.Tween.Release)
	end
	return (segmented :: any) :: Segmented
end

return Components
