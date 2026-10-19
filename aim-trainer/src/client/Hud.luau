-- Hud: everything on screen during a round.
--
--   * timer (top centre), live score (left) and accuracy (right)
--   * crosshair with hit marker, combo counter under it
--   * 3-2-1-GO countdown
--   * touch: big FIRE button and an X to quit
--
-- Location: StarterPlayerScripts > Client > Hud (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modes"))
local Ui = require(script.Parent.Ui)
local Crosshair = require(script.Parent.Crosshair)
local Menu = require(script.Parent.Menu)

local make = Ui.make
local C = Ui.Color

local Hud = {}
Hud.__index = Hud

export type Callbacks = { onFire: () -> (), onQuit: () -> () }

export type Hud = typeof(setmetatable({} :: {
	root: CanvasGroup,
	crosshair: Crosshair.Crosshair,
	timer: TextLabel,
	score: TextLabel,
	accuracy: TextLabel,
	accuracyLabel: TextLabel,
	combo: TextLabel,
	center: TextLabel,
	fire: TextButton,
	quit: Ui.Button,
	mode: Modes.Mode?,
}, Hud))

local function statBlock(parent: Instance, title: string, anchorX: number, position: UDim2): (TextLabel, TextLabel)
	local align = if anchorX == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
	local caption = Ui.text({
		Text = title,
		TextSize = 15,
		TextColor3 = C.Muted,
		TextXAlignment = align,
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = position,
		Size = UDim2.fromOffset(200, 20),
		Parent = parent,
	})
	local value = Ui.text({
		Text = "0",
		TextSize = 34,
		FontFace = Ui.Font.Heavy,
		TextXAlignment = align,
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = position + UDim2.fromOffset(0, 18),
		Size = UDim2.fromOffset(200, 38),
		Parent = parent,
	})
	return value, caption
end

function Hud.new(parent: Frame, callbacks: Callbacks): Hud
	local self = setmetatable({}, Hud) :: any
	self.root = make("CanvasGroup", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	self.crosshair = Crosshair.new(self.root)

	local bar = make("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(560, 74),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.3,
		Parent = self.root,
	}, { Ui.corner(14) })
	self.timer = Ui.text({
		Text = "0:00",
		TextSize = 44,
		FontFace = Ui.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(160, 50),
		Parent = bar,
	})
	self.score = statBlock(bar, "SCORE", 0, UDim2.fromOffset(20, 8))
	self.accuracy, self.accuracyLabel = statBlock(bar, "ACCURACY", 1, UDim2.new(1, -20, 0, 8))

	self.combo = Ui.text({
		Text = "",
		TextSize = 22,
		FontFace = Ui.Font.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 34),
		Size = UDim2.fromOffset(200, 28),
		Parent = self.root,
	})

	self.center = Ui.text({
		Text = "",
		TextSize = 120,
		FontFace = Ui.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(500, 140),
		Parent = self.root,
	})

	-- Touch controls.
	self.fire = make("TextButton", {
		Name = "Fire",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -60),
		Size = UDim2.fromOffset(140, 140),
		BackgroundColor3 = C.Accent,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = self.root,
	}, { Ui.corner(70), Ui.stroke(C.Text, 3) })
	Ui.text({
		Text = "FIRE",
		TextSize = 30,
		FontFace = Ui.Font.Heavy,
		TextColor3 = C.Bg,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = self.fire,
	})
	self.fire.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Ui.pop(self.fire, -0.08)
			callbacks.onFire()
		end
	end)
	self.quit = Ui.button({
		Text = "X",
		Color = C.Bad,
		TextColor3 = C.Text,
		TextSize = 24,
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(24, 56),
		OnClick = callbacks.onQuit,
		Parent = self.root,
	})
	return self
end

function Hud.show(self: Hud, mode: Modes.Mode)
	self.mode = mode
	local touch = Ui.isTouch()
	self.fire.Visible = touch and mode.kind ~= "track"
	self.quit.Instance.Visible = touch
	self.accuracyLabel.Text = if mode.kind == "track" then "ON TARGET" else "ACCURACY"
	self.score.Text = "0"
	self.accuracy.Text = "-"
	self.combo.Text = ""
	self.center.Text = ""
	self.timer.Text = string.format("%d:%02d", mode.duration // 60, mode.duration % 60)
	self.timer.TextColor3 = C.Text
	self.crosshair:setVisible(true)
	self.root.GroupTransparency = 1
	self.root.Visible = true
	Ui.tween(self.root, Ui.Tween.Fade, { GroupTransparency = 0 })
end

function Hud.hide(self: Hud)
	local t = Ui.tween(self.root, Ui.Tween.Fade, { GroupTransparency = 1 })
	t.Completed:Wait()
	self.root.Visible = false
end

-- Big centred text: countdown numbers, "GO!", "TIME!".
function Hud.flash(self: Hud, text: string, color: Color3?)
	self.center.Text = text
	self.center.TextColor3 = color or C.Text
	self.center.TextTransparency = 0
	Ui.pop(self.center, 0.4)
	Ui.tween(self.center, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { TextTransparency = 1 })
end

function Hud.update(self: Hud, remaining: number, stats: Modes.Stats)
	local mode = self.mode
	if not mode then
		return
	end
	local secs = math.ceil(remaining)
	self.timer.Text = string.format("%d:%02d", secs // 60, secs % 60)
	self.timer.TextColor3 = if remaining <= 5 then C.Bad else C.Text
	self.score.Text = Menu.formatScore(Modes.score(mode, stats))
	if mode.kind == "track" then
		local elapsed = mode.duration - remaining
		local pct = if elapsed > 0 then stats.trackTime / elapsed else 0
		self.accuracy.Text = string.format("%d%%", math.floor(pct * 100 + 0.5))
	elseif stats.shots > 0 then
		self.accuracy.Text = string.format("%d%%", math.floor(stats.hits / stats.shots * 100 + 0.5))
	end
end

function Hud.onHit(self: Hud, combo: number)
	self.crosshair:hit()
	if combo >= 5 then
		self.combo.Text = "x" .. combo
		self.combo.TextTransparency = 0
		Ui.pop(self.combo, 0.2)
	end
end

function Hud.onMiss(self: Hud)
	self.crosshair:miss()
	if self.combo.Text ~= "" then
		Ui.tween(self.combo, TweenInfo.new(0.3), { TextTransparency = 1 })
	end
end

return Hud
