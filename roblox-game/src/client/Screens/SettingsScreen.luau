-- SettingsScreen: modal window with music/SFX volume and graphics quality.
-- Changes apply live; they are saved to the server when the window closes.
--
-- Location: StarterPlayerScripts > Client > Screens > SettingsScreen (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Motion = require(UI.Motion)
local Sound = require(UI.Sound)
local SettingsController = require(script.Parent.Parent.Systems.SettingsController)

local SettingsScreen = {}
SettingsScreen.__index = SettingsScreen

local QUALITY_INFO = {
	Low = "Best performance. No shadows, glow or sun rays.",
	Medium = "Balanced. Shadows and glow, fewer particles.",
	High = "Best looking. All effects on.",
}

export type SettingsScreen = typeof(setmetatable({} :: {
	overlay: TextButton,
	panel: Components.Panel,
	music: Components.Slider,
	sfx: Components.Slider,
	quality: Components.Segmented,
	qualityInfo: TextLabel,
	busy: boolean,
}, SettingsScreen))

local function caption(text: string, order: number, parent: Instance)
	Components.Text({
		text = text,
		size = UDim2.new(1, 0, 0, 24),
		align = Enum.TextXAlignment.Left,
		textSize = Theme.TextSize.Caption,
		font = Theme.Font.Heavy,
		color = Theme.Color.TextMuted,
		outline = 0,
		layoutOrder = order,
		parent = parent,
	})
end

function SettingsScreen.new(parent: Frame): SettingsScreen
	local self = setmetatable({}, SettingsScreen) :: any
	self.busy = false

	-- Dimmed backdrop; clicking it closes the window like most games do.
	self.overlay = Components.make("TextButton", {
		Name = "SettingsOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	self.overlay.Activated:Connect(function()
		self:close()
	end)

	self.panel = Components.Panel({
		title = "SETTINGS",
		size = Vector2.new(600, 530),
		parent = parent,
		accent = Theme.Color.Secondary,
		onClose = function()
			self:close()
		end,
	})
	self.panel.Root.ZIndex = 6

	local list = Components.make("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.TextMuted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = self.panel.Content,
	}, {
		Components.make("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Components.make("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingLeft = UDim.new(0, 4) }),
	})

	local settings = SettingsController.get()

	caption("AUDIO", 1, list)
	self.music = Components.Slider({
		label = "Music",
		value = settings.music,
		layoutOrder = 2,
		parent = list,
		onChanged = function(v)
			SettingsController.set("music", v)
		end,
	})
	self.sfx = Components.Slider({
		label = "Sound Effects",
		value = settings.sfx,
		layoutOrder = 3,
		parent = list,
		onChanged = function(v)
			SettingsController.set("sfx", v)
		end,
	})

	caption("GRAPHICS", 4, list)
	self.qualityInfo = Components.Text({
		text = QUALITY_INFO[settings.quality],
		size = UDim2.new(1, 0, 0, 26),
		align = Enum.TextXAlignment.Left,
		textSize = Theme.TextSize.Caption,
		font = Theme.Font.Body,
		color = Theme.Color.TextMuted,
		outline = 0,
		layoutOrder = 6,
		parent = list,
	})
	self.quality = Components.Segmented({
		options = Theme.QualityLevels,
		value = settings.quality,
		layoutOrder = 5,
		parent = list,
		onChanged = function(option)
			SettingsController.set("quality", option)
			self.qualityInfo.Text = QUALITY_INFO[option]
		end,
	})

	local footer = Components.make("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 1,
		LayoutOrder = 7,
		Parent = list,
	})
	Components.Button({
		name = "Done",
		text = "DONE",
		variant = "Primary",
		size = UDim2.fromOffset(220, 72),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		onClick = function()
			self:close()
		end,
		parent = footer,
	})

	return self
end

function SettingsScreen.isOpen(self: SettingsScreen): boolean
	return Motion.isOpen(self.panel.Root)
end

function SettingsScreen.open(self: SettingsScreen)
	if self:isOpen() then
		return
	end
	-- Re-sync in case settings loaded from the server after we were built.
	local settings = SettingsController.get()
	self.music:set(settings.music)
	self.sfx:set(settings.sfx)
	self.quality:set(settings.quality)
	self.qualityInfo.Text = QUALITY_INFO[settings.quality]

	Sound.play("Open")
	self.overlay.Visible = true
	Motion.tween(self.overlay, Theme.Tween.Fade, { BackgroundTransparency = 0.45 })
	Motion.open(self.panel.Root)
end

function SettingsScreen.close(self: SettingsScreen)
	if not self:isOpen() or self.busy then
		return
	end
	self.busy = true
	SettingsController.commit()
	Sound.play("Close")
	Motion.tween(self.overlay, Theme.Tween.Close, { BackgroundTransparency = 1 })
	Motion.close(self.panel.Root)
	self.overlay.Visible = false
	self.busy = false
end

return SettingsScreen
