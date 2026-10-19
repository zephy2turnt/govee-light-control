-- SettingsPanel: three columns.
--
--   GENERAL          sensitivity, field of view, volume
--   CROSSHAIR SHAPE  horizontal / vertical / dot / outline toggles, then
--                    length, thickness, gap, rotation and dot size
--   CROSSHAIR COLOR  live preview, quick colours, R/G/B sliders
--
-- Every change applies instantly (including to the live preview); settings
-- are saved to your profile when the panel closes.
--
-- Location: StarterPlayerScripts > Client > SettingsPanel (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modes"))
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local Settings = require(script.Parent.Settings)
local Crosshair = require(script.Parent.Crosshair)

local make = Ui.make
local C = Ui.Color
local LIMITS = Modes.SettingLimits

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

export type SettingsPanel = typeof(setmetatable({} :: {
	overlay: TextButton,
	panel: CanvasGroup,
	sliders: { [string]: Ui.Slider },
	toggles: { [string]: Ui.Button },
	swatches: { TextButton },
	preview: Crosshair.Crosshair,
	onClosed: (() -> ())?,
}, SettingsPanel))

local function column(parent: Instance, title: string, x: UDim, width: UDim, scrolling: boolean?): Frame
	local holder = make("Frame", {
		Position = UDim2.new(x, UDim.new(0, 76)),
		Size = UDim2.new(width, UDim.new(1, -92)),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Ui.text({ Text = title, TextSize = 15, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 20), Parent = holder })
	local list = make(if scrolling then "ScrollingFrame" else "Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = holder,
	}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	if scrolling then
		local sf = list :: ScrollingFrame
		sf.ScrollBarThickness = 5
		sf.ScrollBarImageColor3 = C.Muted
		sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sf.CanvasSize = UDim2.new()
		make("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = sf })
	end
	return list
end

function SettingsPanel.new(parent: Frame): SettingsPanel
	local self = setmetatable({}, SettingsPanel) :: any
	self.sliders = {}
	self.toggles = {}
	self.swatches = {}

	self.overlay = make("TextButton", {
		Name = "SettingsOverlay",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	self.overlay.Activated:Connect(function()
		self:close()
	end)

	local panel, body = Ui.panel({ Name = "Settings", Size = UDim2.fromOffset(920, 520), ZIndex = 21, Parent = parent })
	self.panel = panel
	Ui.text({ Text = "SETTINGS", TextSize = 32, FontFace = Ui.Font.Heavy, Position = UDim2.fromOffset(28, 18), Size = UDim2.fromOffset(300, 40), Parent = body })
	Ui.button({
		Text = "DONE",
		TextSize = 20,
		Size = UDim2.fromOffset(110, 44),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 18),
		OnClick = function()
			self:close()
		end,
		Parent = body,
	})

	local general = column(body, "GENERAL", UDim.new(0, 28), UDim.new(0, 250))
	local shape = column(body, "CROSSHAIR SHAPE", UDim.new(0, 306), UDim.new(0, 300), true)
	local colour = column(body, "CROSSHAIR COLOR", UDim.new(0, 634), UDim.new(0, 258))

	local function slider(key: string, label: string, list: Instance, order: number, step: number, format: (number) -> string)
		self.sliders[key] = Ui.slider({
			Label = label,
			Min = LIMITS[key][1],
			Max = LIMITS[key][2],
			Value = Settings.get(key),
			Step = step,
			Format = format,
			LayoutOrder = order,
			OnChanged = function(v)
				Settings.set(key, v)
			end,
			Parent = list,
		})
	end
	local function px(v: number): string
		return string.format("%dpx", v)
	end

	-- General ----------------------------------------------------------------
	slider("sensitivity", "Sensitivity", general, 1, 0.005, function(v)
		return string.format("%.3f°/px", v)
	end)
	slider("fov", "Field of view", general, 2, 1, function(v)
		return string.format("%d°", v)
	end)
	slider("volume", "Volume", general, 3, 0.01, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end)
	Ui.text({
		Text = "At 0.15°/px, moving your mouse 2400 pixels turns you a full 360°.",
		TextSize = 14,
		TextColor3 = C.Muted,
		FontFace = Ui.Font.Body,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 4,
		Parent = general,
	})

	-- Shape ------------------------------------------------------------------
	local toggleGrid = make("Frame", {
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = shape,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 42),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, entry in { { "chHorizontal", "HORIZONTAL" }, { "chVertical", "VERTICAL" }, { "chDot", "DOT" }, { "chOutline", "OUTLINE" } } do
		local key = entry[1]
		self.toggles[key] = Ui.button({
			Text = entry[2],
			TextSize = 15,
			Color = C.Raised,
			TextColor3 = C.Text,
			LayoutOrder = i,
			OnClick = function()
				Settings.set(key, not Settings.get(key))
			end,
			Parent = toggleGrid,
		})
	end
	slider("chLength", "Line length", shape, 1, 1, px)
	slider("chThickness", "Line thickness", shape, 2, 1, px)
	slider("chGap", "Gap from centre", shape, 3, 1, px)
	slider("chRotation", "Rotation", shape, 4, 1, function(v)
		return string.format("%d°", v)
	end)
	slider("chDotSize", "Dot size", shape, 5, 1, px)

	-- Colour -----------------------------------------------------------------
	local previewBox = make("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = Color3.fromRGB(32, 36, 50),
		LayoutOrder = 0,
		Parent = colour,
	}, { Ui.corner(12), Ui.stroke(C.Line, 1.5) })
	self.preview = Crosshair.new(previewBox)

	local swatchRow = make("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = colour,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
	for i, preset in Modes.CrosshairPresets do
		local swatch = make("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = preset,
			LayoutOrder = i,
			Parent = swatchRow,
		}, { Ui.corner(17), Ui.stroke(C.Bg, 3) })
		swatch.Activated:Connect(function()
			Audio.play("Click")
			Ui.pop(swatch, 0.2)
			Settings.set("chR", math.floor(preset.R * 255 + 0.5))
			Settings.set("chG", math.floor(preset.G * 255 + 0.5))
			Settings.set("chB", math.floor(preset.B * 255 + 0.5))
		end)
		self.swatches[i] = swatch
	end
	local function channel(v: number): string
		return tostring(math.floor(v))
	end
	slider("chR", "Red", colour, 2, 1, channel)
	slider("chG", "Green", colour, 3, 1, channel)
	slider("chB", "Blue", colour, 4, 1, channel)

	Settings.onChanged(function()
		self:render()
	end)
	self:render()
	return self
end

-- Syncs every control with the current settings.
function SettingsPanel.render(self: SettingsPanel)
	local all = Settings.all()
	for key, s in self.sliders do
		s:set(all[key])
	end
	for key, button in self.toggles do
		local on = all[key] == true
		button:setColor(if on then C.Accent else C.Raised)
		button.Label.TextColor3 = if on then C.Bg else C.Muted
	end
	local current = Color3.fromRGB(all.chR, all.chG, all.chB)
	for i, swatch in self.swatches do
		local preset = Modes.CrosshairPresets[i]
		local same = math.abs(preset.R - current.R) + math.abs(preset.G - current.G) + math.abs(preset.B - current.B) < 0.01
		local stroke = swatch:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if same then C.Text else C.Bg
	end
	self.preview:apply(all)
end

function SettingsPanel.isOpen(self: SettingsPanel): boolean
	return self.panel.Visible
end

function SettingsPanel.open(self: SettingsPanel, onClosed: (() -> ())?)
	self.onClosed = onClosed
	self:render()
	Audio.play("Open")
	self.overlay.Visible = true
	Ui.tween(self.overlay, Ui.Tween.Fade, { BackgroundTransparency = 0.5 })
	Ui.open(self.panel)
end

function SettingsPanel.close(self: SettingsPanel)
	if not self.panel.Visible then
		return
	end
	Settings.commit()
	Audio.play("Close")
	Ui.tween(self.overlay, Ui.Tween.Close, { BackgroundTransparency = 1 })
	Ui.close(self.panel)
	self.overlay.Visible = false
	if self.onClosed then
		self.onClosed()
	end
end

return SettingsPanel
