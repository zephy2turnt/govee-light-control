-- MainMenu: the title screen shown when a player joins.
--
-- Layout (design pixels, 1280x720 reference):
--   * animated logo with a moving shine and a gentle bob
--   * PLAY (disabled with "LOADING..." until the player's data has loaded)
--     and SETTINGS buttons
--   * player card with avatar headshot (top right)
--   * rotating gameplay tips (bottom) and the version (bottom left)
-- Everything slides in with a staggered entrance and slides out on Play.
--
-- Location: StarterPlayerScripts > Client > Screens > MainMenu (ModuleScript)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Motion = require(UI.Motion)

local make = Components.make
local MainMenu = {}
MainMenu.__index = MainMenu

local TIPS = {
	"Lock your base before you go stealing. Thieves love an empty house.",
	"Golden Rain makes mutations 4x more likely. Plant before it starts!",
	"Rainbow brainrots earn 10x. Guard them with your bat.",
	"Carrying a stolen brainrot slows you down. Plan your escape route.",
	"Plants keep growing while you're offline.",
	"Bonk a thief to send your brainrot straight back home.",
}

export type Callbacks = {
	onPlay: () -> (),
	onSettings: () -> (),
}

export type MainMenu = typeof(setmetatable({} :: {
	container: Frame,
	shades: { Frame },
	logo: CanvasGroup,
	actions: Frame,
	card: CanvasGroup,
	tips: CanvasGroup,
	tipLabel: TextLabel,
	footer: TextLabel,
	play: Components.Button,
	blur: BlurEffect,
	loops: { Tween },
	visible: boolean,
	ready: boolean,
}, MainMenu))

-- Builders --------------------------------------------------------------------

local function buildShades(container: Frame): { Frame }
	-- Dark gradients top and bottom keep text readable over the 3D world.
	local function shade(name: string, anchorY: number, rotation: number): Frame
		return make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0, anchorY),
			Position = UDim2.fromScale(0, anchorY),
			Size = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = Theme.Color.Background,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = container,
		}, {
			make("UIGradient", {
				Rotation = rotation,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.05),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	return { shade("TopShade", 0, 90), shade("BottomShade", 1, 270) }
end

local function buildLogo(container: Frame): (CanvasGroup, Tween)
	local logo = make("CanvasGroup", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.27),
		Size = UDim2.fromOffset(1000, 260),
		BackgroundTransparency = 1,
		Parent = container,
	})

	local titleProps = {
		size = UDim2.new(1, 0, 0, 140),
		textSize = Theme.TextSize.Hero,
		font = Theme.Font.Display,
		parent = logo,
	}

	-- Drop shadow for depth.
	Components.Text({
		name = "Shadow",
		text = Theme.GameTitle,
		size = titleProps.size,
		position = UDim2.fromOffset(0, 9),
		textSize = titleProps.textSize,
		font = titleProps.font,
		color = Theme.Color.Outline,
		outline = 0,
		parent = logo,
	}).TextTransparency = 0.35

	local title = Components.Text({
		name = "Title",
		text = Theme.GameTitle,
		size = titleProps.size,
		textSize = titleProps.textSize,
		font = titleProps.font,
		outline = 0,
		parent = logo,
	})
	make("UIStroke", {
		Thickness = 7,
		Color = Theme.Color.Outline,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = title,
	})
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
			ColorSequenceKeypoint.new(0.55, Theme.Color.Accent),
			ColorSequenceKeypoint.new(1, Theme.Color.Warning),
		}),
		Parent = title,
	})

	-- Shine: a white copy of the title masked to a thin diagonal band that
	-- sweeps across every few seconds.
	local shine = Components.Text({
		name = "Shine",
		text = Theme.GameTitle,
		size = titleProps.size,
		textSize = titleProps.textSize,
		font = titleProps.font,
		color = Color3.new(1, 1, 1),
		outline = 0,
		parent = logo,
	})
	local shineGradient = make("UIGradient", {
		Rotation = 20,
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine,
	})
	local sweep = TweenService:Create(
		shineGradient,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.2),
		{ Offset = Vector2.new(1, 0) }
	)

	-- Tagline chip under the title.
	local chip = make("Frame", {
		Name = "Tagline",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(440, 50),
		BackgroundColor3 = Theme.Color.Surface,
		Parent = logo,
	}, { Components.corner(Theme.Radius.Pill), Components.stroke(), Components.gloss(0.15) })
	Components.Text({
		text = Theme.Tagline,
		size = UDim2.fromScale(1, 1),
		textSize = Theme.TextSize.Body + 2,
		font = Theme.Font.Heavy,
		color = Theme.Color.Accent,
		outline = 0,
		parent = chip,
	})

	return logo, sweep
end

local function buildActions(container: Frame, callbacks: Callbacks): (Frame, Components.Button, Tween)
	local actions = make("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(380, 200),
		BackgroundTransparency = 1,
		Parent = container,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, Theme.Spacing.M),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local play = Components.Button({
		name = "Play",
		text = "LOADING...",
		variant = "Primary",
		size = UDim2.fromOffset(360, 100),
		textSize = 44,
		sound = "Stinger",
		layoutOrder = 1,
		onClick = callbacks.onPlay,
		parent = actions,
	})
	play:setEnabled(false)

	-- Pulsing glow behind PLAY draws the eye to the main action.
	local glow = make("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 26, 1, 22),
		BackgroundColor3 = Theme.Color.Primary,
		BackgroundTransparency = 0.9,
		ZIndex = 0,
		Parent = play.Root,
	}, { Components.corner(Theme.Radius.Large) })
	local pulse = TweenService:Create(
		glow,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.55, Size = UDim2.new(1, 34, 1, 30) }
	)

	Components.Button({
		name = "Settings",
		text = "SETTINGS",
		variant = "Secondary",
		size = UDim2.fromOffset(300, 76),
		textSize = 30,
		sound = "Click",
		layoutOrder = 2,
		onClick = callbacks.onSettings,
		parent = actions,
	})

	return actions, play, pulse
end

local function buildPlayerCard(container: Frame): CanvasGroup
	local player = Players.LocalPlayer
	local card = make("CanvasGroup", {
		Name = "PlayerCard",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(320, 92),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.Color.Surface,
		Parent = card,
	}, { Components.corner(Theme.Radius.Large), Components.stroke(), Components.gloss(0.15) })

	local avatar = make("ImageLabel", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = Theme.Color.SurfaceRaised,
		Image = "",
		Parent = body,
	}, {
		Components.corner(Theme.Radius.Pill),
		Components.stroke(3, Theme.Color.Accent),
	})
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok then
			avatar.Image = image
		end
	end)

	Components.Text({
		name = "DisplayName",
		text = player.DisplayName,
		size = UDim2.new(1, -96, 0, 32),
		position = UDim2.fromOffset(86, 14),
		align = Enum.TextXAlignment.Left,
		textSize = 24,
		font = Theme.Font.Heavy,
		parent = body,
	}).TextTruncate = Enum.TextTruncate.AtEnd
	Components.Text({
		name = "Username",
		text = "@" .. player.Name,
		size = UDim2.new(1, -96, 0, 24),
		position = UDim2.fromOffset(86, 46),
		align = Enum.TextXAlignment.Left,
		textSize = Theme.TextSize.Caption,
		font = Theme.Font.Body,
		color = Theme.Color.TextMuted,
		outline = 0,
		parent = body,
	}).TextTruncate = Enum.TextTruncate.AtEnd
	return card
end

local function buildTips(container: Frame): (CanvasGroup, TextLabel)
	local tips = make("CanvasGroup", {
		Name = "Tips",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(760, 60),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local body = make("Frame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.Color.Background,
		BackgroundTransparency = 0.25,
		Parent = tips,
	}, { Components.corner(Theme.Radius.Pill), Components.stroke(Theme.Stroke.ThicknessThin) })
	local label = Components.Text({
		name = "Tip",
		text = "",
		size = UDim2.new(1, -40, 1, 0),
		position = UDim2.fromOffset(20, 0),
		textSize = Theme.TextSize.Body,
		font = Theme.Font.Bold,
		color = Theme.Color.Text,
		outline = 0,
		parent = body,
	})
	label.RichText = true
	return tips, label
end

-- Public API -----------------------------------------------------------------------

function MainMenu.new(parent: Frame, callbacks: Callbacks): MainMenu
	local self = setmetatable({}, MainMenu) :: any
	self.visible = false
	self.ready = false

	self.container = make("Frame", {
		Name = "MainMenu",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	self.shades = buildShades(self.container)
	local sweep, pulse
	self.logo, sweep = buildLogo(self.container)
	self.actions, self.play, pulse = buildActions(self.container, callbacks)
	self.card = buildPlayerCard(self.container)
	self.tips, self.tipLabel = buildTips(self.container)
	self.footer = Components.Text({
		name = "Version",
		text = Theme.Version,
		size = UDim2.fromOffset(300, 24),
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, 24, 1, -12),
		align = Enum.TextXAlignment.Left,
		textSize = Theme.TextSize.Caption,
		color = Theme.Color.TextMuted,
		outline = 0,
		parent = self.container,
	})

	-- Gentle bob on the logo.
	self.logo.Rotation = -1.5
	local bob = TweenService:Create(
		self.logo,
		TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = 1.5 }
	)
	self.loops = { sweep, pulse, bob }

	self.blur = Lighting:FindFirstChild("MenuBlur") :: BlurEffect?
	if not self.blur then
		local blur = Instance.new("BlurEffect")
		blur.Name = "MenuBlur"
		blur.Size = 0
		blur.Parent = Lighting
		self.blur = blur
	end
	return self
end

-- Rotates through TIPS with a fade while the menu is visible.
function MainMenu._runTips(self: MainMenu)
	local index = math.random(#TIPS)
	while self.visible do
		self.tipLabel.Text = '<font color="#FFC42E">TIP</font>  ' .. TIPS[index]
		Motion.tween(self.tipLabel, Theme.Tween.Fade, { TextTransparency = 0 })
		task.wait(6)
		if not self.visible then
			break
		end
		local t = Motion.tween(self.tipLabel, Theme.Tween.Close, { TextTransparency = 1 })
		t.Completed:Wait()
		index = index % #TIPS + 1
	end
end

-- Staggered entrance. Returns immediately; animations run on their own.
function MainMenu.show(self: MainMenu)
	if self.visible then
		return
	end
	self.visible = true
	self.container.Visible = true
	for _, shade in self.shades do
		shade.BackgroundTransparency = 1
		Motion.tween(shade, Theme.Tween.Slide, { BackgroundTransparency = 0 })
	end
	Motion.tween(self.blur, Theme.Tween.Slide, { Size = 14 })

	Motion.slideIn(self.logo, Vector2.new(0, -260), 0.05)
	Motion.slideIn(self.actions, Vector2.new(0, 420), 0.22)
	Motion.slideIn(self.card, Vector2.new(380, 0), 0.32)
	Motion.slideIn(self.tips, Vector2.new(0, 120), 0.42)
	self.footer.TextTransparency = 1
	Motion.tween(self.footer, Theme.Tween.Slide, { TextTransparency = 0 })

	for _, loop in self.loops do
		loop:Play()
	end
	task.spawn(self._runTips, self)
end

-- Staggered exit. Yields until everything is off screen.
function MainMenu.hide(self: MainMenu)
	if not self.visible then
		return
	end
	self.visible = false
	for _, shade in self.shades do
		Motion.tween(shade, Theme.Tween.Fade, { BackgroundTransparency = 1 })
	end
	Motion.tween(self.blur, Theme.Tween.Fade, { Size = 0 })
	Motion.tween(self.footer, Theme.Tween.Close, { TextTransparency = 1 })

	task.spawn(Motion.slideOut, self.card, Vector2.new(380, 0))
	task.spawn(Motion.slideOut, self.tips, Vector2.new(0, 120))
	task.spawn(Motion.slideOut, self.actions, Vector2.new(0, 420), 0.04)
	Motion.slideOut(self.logo, Vector2.new(0, -260), 0.08)

	for _, loop in self.loops do
		loop:Cancel()
	end
	self.container.Visible = false
end

-- Called once the server has loaded the player's data.
function MainMenu.setReady(self: MainMenu)
	if self.ready then
		return
	end
	self.ready = true
	self.play:setText("PLAY")
	self.play:setEnabled(true)
	Motion.pop(self.play.Root, 0.15)
end

return MainMenu
