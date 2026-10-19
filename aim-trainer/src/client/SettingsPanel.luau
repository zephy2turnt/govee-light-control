-- SettingsPanel: sensitivity, FOV, crosshair (style/colour/size with a live
-- preview) and volume. Changes apply instantly; they're saved when the
-- panel closes.
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

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

export type SettingsPanel = typeof(setmetatable({} :: {
	overlay: TextButton,
	panel: CanvasGroup,
	sliders: { [string]: Ui.Slider },
	styleButtons: { [string]: Ui.Button },
	swatches: { Frame },
	preview: Crosshair.Crosshair,
	onClosed: (() -> ())?,
}, SettingsPanel))

local LIMITS = Modes.SettingLimits

function SettingsPanel.new(parent: Frame): SettingsPanel
	local self = setmetatable({}, SettingsPanel) :: any
	self.sliders = {}
	self.styleButtons = {}
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

	local panel, body = Ui.panel({ Name = "Settings", Size = UDim2.fromOffset(640, 560), ZIndex = 21, Parent = parent })
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

	-- Left column: sliders.
	local left = make("Frame", {
		Position = UDim2.fromOffset(28, 80),
		Size = UDim2.new(0.55, -40, 1, -100),
		BackgroundTransparency = 1,
		Parent = body,
	}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local function slider(key: string, label: string, order: number, step: number, format: (number) -> string)
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
			Parent = left,
		})
	end
	slider("sensitivity", "Sensitivity", 1, 0.005, function(v)
		return string.format("%.3f°/px", v)
	end)
	slider("fov", "Field of view", 2, 1, function(v)
		return string.format("%d°", v)
	end)
	slider("crosshairSize", "Crosshair size", 3, 0.05, function(v)
		return string.format("%.2fx", v)
	end)
	slider("volume", "Volume", 4, 0.01, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end)
	Ui.text({
		Text = "Tip: at 0.15°/px, sliding your mouse 2400 pixels turns you a full 360°.",
		TextSize = 14,
		TextColor3 = C.Muted,
		FontFace = Ui.Font.Body,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 5,
		Parent = left,
	})

	-- Right column: crosshair style, colour, preview.
	local right = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 80),
		Size = UDim2.new(0.45, -20, 1, -100),
		BackgroundTransparency = 1,
		Parent = body,
	})
	Ui.text({ Text = "Crosshair", TextSize = 18, Size = UDim2.new(1, 0, 0, 24), Parent = right })
	local styleRow = make("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = right,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
	for i, style in Modes.CrosshairStyles do
		self.styleButtons[style] = Ui.button({
			Text = style:upper(),
			TextSize = 16,
			Color = C.Raised,
			TextColor3 = C.Text,
			Size = UDim2.new(1 / 3, -6, 1, 0),
			LayoutOrder = i,
			OnClick = function()
				Settings.set("crosshairStyle", style)
			end,
			Parent = styleRow,
		})
	end

	local swatchRow = make("Frame", {
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = right,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
	for i, color in Modes.CrosshairColors do
		local swatch = make("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = color,
			LayoutOrder = i,
			Parent = swatchRow,
		}, { Ui.corner(18), Ui.stroke(C.Bg, 3) })
		swatch.Activated:Connect(function()
			Audio.play("Click")
			Ui.pop(swatch, 0.2)
			Settings.set("crosshairColor", i)
		end)
		self.swatches[i] = swatch
	end

	local previewBox = make("Frame", {
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundColor3 = Color3.fromRGB(24, 27, 38),
		Parent = right,
	}, { Ui.corner(12), Ui.stroke(C.Line, 1.5) })
	self.preview = Crosshair.new(previewBox)

	Settings.onChanged(function()
		self:render()
	end)
	self:render()
	return self
end

-- Syncs every control with the current settings.
function SettingsPanel.render(self: SettingsPanel)
	for key, s in self.sliders do
		s:set(Settings.get(key))
	end
	local style = Settings.get("crosshairStyle")
	for name, button in self.styleButtons do
		button:setColor(if name == style then C.Accent else C.Raised)
		button.Label.TextColor3 = if name == style then C.Bg else C.Text
	end
	for i, swatch in self.swatches do
		local stroke = swatch:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if i == Settings.get("crosshairColor") then C.Text else C.Bg
	end
	self.preview:apply(style, Settings.crosshairColor(), Settings.get("crosshairSize"))
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
