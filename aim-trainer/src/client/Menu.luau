-- Menu: pick a mode and a difficulty, see your best and the global top 10,
-- press PLAY.
--
-- Location: StarterPlayerScripts > Client > Menu (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modes"))
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)

local GetLeaderboard = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GetLeaderboard") :: RemoteFunction

local make = Ui.make
local C = Ui.Color

local Menu = {}
Menu.__index = Menu

export type Callbacks = { onPlay: (modeId: string) -> (), onSettings: () -> () }

export type Menu = typeof(setmetatable({} :: {
	root: CanvasGroup,
	cards: { [string]: { frame: TextButton, best: TextLabel, stroke: UIStroke } },
	selected: string, -- mode (without difficulty), e.g. "Flick"
	difficulty: string, -- "Easy" | "Medium" | "Hard"
	difficultyButtons: { [string]: Ui.Button },
	bests: { [string]: any },
	detailName: TextLabel,
	detailInfo: TextLabel,
	detailDesc: TextLabel,
	detailBest: TextLabel,
	play: Ui.Button,
	board: Frame,
	boardTitle: TextLabel,
	boardStatus: TextLabel,
	boardRequest: number,
}, Menu))

local function formatScore(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
Menu.formatScore = formatScore

local function infoLine(mode: Modes.Mode): string
	if mode.kind == "track" then
		return string.format("%ds  •  keep on target", mode.duration)
	end
	return string.format("%ds  •  %d target%s", mode.duration, mode.targets, if mode.targets == 1 then "" else "s")
end

function Menu.new(parent: Frame, callbacks: Callbacks): Menu
	local self = setmetatable({}, Menu) :: any
	self.cards = {}
	self.selected = Modes.order[1]
	self.difficulty = "Medium"
	self.difficultyButtons = {}
	self.bests = {}
	self.boardRequest = 0

	self.root = make("CanvasGroup", {
		Name = "Menu",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	-- Darken the left side so text reads over the 3D range.
	make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = self.root,
	}, {
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.6, 0.2),
				NumberSequenceKeypoint.new(1, 0.6),
			}),
		}),
	})

	Ui.text({
		Text = "AIM RANGE",
		TextSize = 56,
		FontFace = Ui.Font.Heavy,
		TextColor3 = C.Text,
		Position = UDim2.fromOffset(48, 40),
		Size = UDim2.fromOffset(500, 60),
		Parent = self.root,
	})
	Ui.text({
		Text = "Pick a drill. Beat your best.",
		TextSize = 20,
		TextColor3 = C.Muted,
		FontFace = Ui.Font.Body,
		Position = UDim2.fromOffset(50, 98),
		Size = UDim2.fromOffset(500, 26),
		Parent = self.root,
	})
	Ui.button({
		Text = "SETTINGS",
		Color = C.Raised,
		TextColor3 = C.Text,
		Size = UDim2.fromOffset(150, 48),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 46),
		OnClick = callbacks.onSettings,
		Parent = self.root,
	})

	-- Mode cards -------------------------------------------------------------
	local grid = make("Frame", {
		Name = "Cards",
		Position = UDim2.fromOffset(48, 150),
		Size = UDim2.fromOffset(560, 440),
		BackgroundTransparency = 1,
		Parent = self.root,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(272, 212),
			CellPadding = UDim2.fromOffset(16, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, id in Modes.order do
		local mode = Modes.list[id]
		local stroke = Ui.stroke(C.Line, 2)
		local card = make("TextButton", {
			Name = id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.Panel,
			LayoutOrder = i,
			Parent = grid,
		}, { Ui.corner(14), stroke })
		make("Frame", {
			Size = UDim2.new(1, -28, 0, 5),
			Position = UDim2.fromOffset(14, 14),
			BackgroundColor3 = mode.color,
			BorderSizePixel = 0,
			Parent = card,
		}, { Ui.corner(3) })
		Ui.text({ Text = mode.name, TextSize = 30, FontFace = Ui.Font.Heavy, Position = UDim2.fromOffset(18, 30), Size = UDim2.new(1, -36, 0, 36), Parent = card })
		Ui.text({ Text = mode.tagline:upper(), TextSize = 15, TextColor3 = mode.color, Position = UDim2.fromOffset(18, 66), Size = UDim2.new(1, -36, 0, 20), Parent = card })
		Ui.text({
			Text = mode.description,
			TextSize = 16,
			TextColor3 = C.Muted,
			FontFace = Ui.Font.Body,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(18, 94),
			Size = UDim2.new(1, -36, 0, 60),
			Parent = card,
		})
		local best = Ui.text({ Text = "", TextSize = 17, Position = UDim2.new(0, 18, 1, -40), Size = UDim2.new(1, -36, 0, 24), Parent = card })
		self.cards[id] = { frame = card, best = best, stroke = stroke }

		local scale = Ui.scaleOf(card)
		card.MouseEnter:Connect(function()
			if not Ui.isTouch() then
				Audio.play("Hover")
				Ui.tween(scale, Ui.Tween.Hover, { Scale = 1.03 })
			end
		end)
		card.MouseLeave:Connect(function()
			Ui.tween(scale, Ui.Tween.Hover, { Scale = 1 })
		end)
		card.Activated:Connect(function()
			Audio.play("Click")
			Ui.pop(card, 0.04)
			self:select(id)
		end)
	end

	-- Detail panel -------------------------------------------------------------
	local detail = make("Frame", {
		Name = "Detail",
		Position = UDim2.fromOffset(632, 150),
		Size = UDim2.new(1, -680, 0, 480),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		Parent = self.root,
	}, { Ui.corner(16), Ui.stroke(C.Line, 2), make("UISizeConstraint", { MaxSize = Vector2.new(600, 480) }) })
	self.detailName = Ui.text({ TextSize = 40, FontFace = Ui.Font.Heavy, Position = UDim2.fromOffset(24, 18), Size = UDim2.new(1, -48, 0, 46), Parent = detail })
	self.detailInfo = Ui.text({ TextSize = 17, TextColor3 = C.Muted, Position = UDim2.fromOffset(26, 64), Size = UDim2.new(1, -48, 0, 22), Parent = detail })
	self.detailDesc = Ui.text({
		TextSize = 17,
		FontFace = Ui.Font.Body,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(26, 92),
		Size = UDim2.new(1, -52, 0, 44),
		Parent = detail,
	})

	-- Difficulty picker.
	local difficultyRow = make("Frame", {
		Position = UDim2.fromOffset(24, 140),
		Size = UDim2.fromOffset(300, 36),
		BackgroundTransparency = 1,
		Parent = detail,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, difficulty in Modes.difficulties do
		self.difficultyButtons[difficulty] = Ui.button({
			Text = difficulty:upper(),
			TextSize = 15,
			Color = C.Raised,
			TextColor3 = C.Muted,
			Size = UDim2.fromOffset(92, 36),
			LayoutOrder = i,
			OnClick = function()
				self.difficulty = difficulty
				self:select(self.selected)
			end,
			Parent = difficultyRow,
		})
	end

	self.detailBest = Ui.text({ TextSize = 18, TextColor3 = C.Gold, Position = UDim2.fromOffset(26, 186), Size = UDim2.new(1, -52, 0, 24), Parent = detail })
	self.play = Ui.button({
		Text = "PLAY",
		TextSize = 30,
		Size = UDim2.fromOffset(190, 62),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 100),
		OnClick = function()
			callbacks.onPlay(self:selectedId())
		end,
		Parent = detail,
	})

	self.boardTitle = Ui.text({ Text = "GLOBAL TOP 10", TextSize = 16, TextColor3 = C.Muted, Position = UDim2.fromOffset(26, 220), Size = UDim2.new(1, -52, 0, 20), Parent = detail })
	self.board = make("Frame", {
		Name = "Board",
		Position = UDim2.fromOffset(20, 246),
		Size = UDim2.new(1, -40, 1, -256),
		BackgroundTransparency = 1,
		Parent = detail,
	}, { make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.boardStatus = Ui.text({
		TextSize = 16,
		TextColor3 = C.Muted,
		FontFace = Ui.Font.Body,
		Position = UDim2.fromOffset(26, 250),
		Size = UDim2.new(1, -52, 0, 22),
		Parent = detail,
	})

	Ui.text({
		Text = "Tip: lower sensitivity helps precision.  Backspace (or the X button) quits a round.",
		TextSize = 16,
		TextColor3 = C.Muted,
		FontFace = Ui.Font.Body,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 50, 1, -28),
		Size = UDim2.new(1, -100, 0, 22),
		Parent = self.root,
	})

	self:select(self.selected)
	return self
end

-- The mode + difficulty that PLAY will start, e.g. "Flick_Hard".
function Menu.selectedId(self: Menu): string
	return Modes.id(self.selected, self.difficulty)
end

function Menu.setBests(self: Menu, bests: { [string]: any })
	self.bests = bests or {}
	self:select(self.selected)
end

function Menu.select(self: Menu, baseId: string)
	self.selected = baseId
	local id = self:selectedId()
	local mode = Modes.list[id]
	for cardId, card in self.cards do
		card.stroke.Color = if cardId == baseId then Modes.list[cardId].color else C.Line
		card.stroke.Thickness = if cardId == baseId then 3 else 2
		-- Cards show your best at the difficulty you have picked.
		local cardBest = self.bests[Modes.id(cardId, self.difficulty)]
		card.best.Text = if cardBest then "BEST  " .. formatScore(cardBest.score) else "No score yet"
		card.best.TextColor3 = if cardBest then C.Gold else C.Muted
	end
	for difficulty, button in self.difficultyButtons do
		local on = difficulty == self.difficulty
		button:setColor(if on then Modes.DifficultyColor[difficulty] else C.Raised)
		button.Label.TextColor3 = if on then C.Bg else C.Muted
	end
	self.detailName.Text = mode.name
	self.detailName.TextColor3 = mode.color
	self.detailInfo.Text = infoLine(mode)
	self.detailDesc.Text = mode.description
	self.boardTitle.Text = "GLOBAL TOP 10  ·  " .. self.difficulty:upper()
	local best = self.bests[id]
	self.detailBest.Text = if best then string.format("Your best: %s  (%d%%)", formatScore(best.score), math.floor(best.accuracy * 100 + 0.5)) else "Your best: -"
	self.play:setColor(mode.color)
	self:refreshBoard()
end

-- Fetches the selected mode's leaderboard (ignores stale replies if the
-- player switched modes while waiting).
function Menu.refreshBoard(self: Menu)
	self.boardRequest += 1
	local request = self.boardRequest
	local id = self:selectedId()
	for _, child in self.board:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	self.boardStatus.Text = "Loading..."
	task.spawn(function()
		local ok, entries = pcall(function()
			return GetLeaderboard:InvokeServer(id)
		end)
		if request ~= self.boardRequest then
			return
		end
		if not ok or type(entries) ~= "table" or #entries == 0 then
			self.boardStatus.Text = "No scores yet. Be the first!"
			return
		end
		self.boardStatus.Text = ""
		for _, entry in entries do
			local row = make("Frame", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				LayoutOrder = entry.rank,
				Parent = self.board,
			})
			local color = if entry.rank == 1 then C.Gold elseif entry.rank <= 3 then C.Text else C.Muted
			Ui.text({ Text = "#" .. entry.rank, TextSize = 16, TextColor3 = color, Size = UDim2.new(0, 40, 1, 0), Parent = row })
			Ui.text({ Text = entry.name, TextSize = 16, TextColor3 = color, FontFace = Ui.Font.Body, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -150, 1, 0), Parent = row })
			Ui.text({
				Text = formatScore(entry.score),
				TextSize = 16,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 110, 1, 0),
				Parent = row,
			})
		end
	end)
end

function Menu.show(self: Menu)
	Ui.open(self.root)
	self:refreshBoard()
end

function Menu.hide(self: Menu)
	Ui.close(self.root)
end

return Menu
