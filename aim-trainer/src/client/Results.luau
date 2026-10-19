-- Results: the end-of-round screen.
--
-- Score counts up, a NEW BEST badge pops if you beat your record, and the
-- round's stats are laid out underneath. RETRY replays the same mode and difficulty.
--
-- Location: StarterPlayerScripts > Client > Results (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modes"))
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local Menu = require(script.Parent.Menu)

local make = Ui.make
local C = Ui.Color

local Results = {}
Results.__index = Results

export type Callbacks = { onRetry: () -> (), onMenu: () -> () }

export type Results = typeof(setmetatable({} :: {
	panel: CanvasGroup,
	modeName: TextLabel,
	score: TextLabel,
	badge: TextLabel,
	sub: TextLabel,
	stats: { TextLabel },
	statNames: { TextLabel },
	retry: Ui.Button,
}, Results))

function Results.new(parent: Frame, callbacks: Callbacks): Results
	local self = setmetatable({}, Results) :: any
	local panel, body = Ui.panel({ Name = "Results", Size = UDim2.fromOffset(560, 470), Parent = parent })
	self.panel = panel

	self.modeName = Ui.text({
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = body,
	})
	self.score = Ui.text({
		Text = "0",
		TextSize = 84,
		FontFace = Ui.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 90),
		Parent = body,
	})
	self.badge = Ui.text({
		Text = "NEW BEST!",
		TextSize = 24,
		FontFace = Ui.Font.Heavy,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(300, 30),
		Parent = body,
	})
	self.sub = Ui.text({
		TextSize = 17,
		TextColor3 = C.Muted,
		FontFace = Ui.Font.Body,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 172),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = body,
	})

	-- 2x2 stat tiles.
	local grid = make("Frame", {
		Position = UDim2.fromOffset(30, 210),
		Size = UDim2.new(1, -60, 0, 160),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 74), CellPadding = UDim2.fromOffset(12, 12) }),
	})
	self.stats, self.statNames = {}, {}
	for i = 1, 4 do
		local tile = make("Frame", { BackgroundColor3 = C.Raised, LayoutOrder = i, Parent = grid }, { Ui.corner(10) })
		self.statNames[i] = Ui.text({ TextSize = 14, TextColor3 = C.Muted, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 18), Parent = tile })
		self.stats[i] = Ui.text({ TextSize = 28, FontFace = Ui.Font.Heavy, Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 34), Parent = tile })
	end

	self.retry = Ui.button({
		Text = "RETRY",
		TextSize = 24,
		Size = UDim2.new(0.5, -36, 0, 56),
		Position = UDim2.new(0, 30, 1, -78),
		OnClick = callbacks.onRetry,
		Parent = body,
	})
	Ui.button({
		Text = "MENU",
		TextSize = 24,
		Color = C.Raised,
		TextColor3 = C.Text,
		Size = UDim2.new(0.5, -36, 0, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 1, -78),
		OnClick = callbacks.onMenu,
		Parent = body,
	})
	return self
end

-- Animates the score from 0 up to `target` over about a second.
local function countUp(label: TextLabel, target: number)
	local start = os.clock()
	local duration = 1.1
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / duration)
		local eased = 1 - (1 - t) ^ 3
		label.Text = Menu.formatScore(target * eased)
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

-- result: the server's reply (may be nil or carry an error if offline).
function Results.show(self: Results, mode: Modes.Mode, stats: Modes.Stats, result: any)
	local score = Modes.score(mode, stats)
	local accuracy = Modes.accuracy(mode, stats)
	self.modeName.Text = mode.fullName
	self.modeName.TextColor3 = mode.color
	self.score.Text = "0"
	self.badge.Visible = false
	self.retry:setColor(mode.color)

	if type(result) == "table" and result.error == nil then
		if result.newBest and result.previousBest then
			self.sub.Text = "Previous best: " .. Menu.formatScore(result.previousBest)
		elseif result.newBest then
			self.sub.Text = "First score on this drill!"
		else
			self.sub.Text = "Your best: " .. Menu.formatScore(result.best)
		end
	else
		self.sub.Text = "Score not saved" .. (if type(result) == "table" and result.error then " (" .. result.error .. ")" else "")
	end

	local rows
	if mode.kind == "track" then
		rows = {
			{ "ON TARGET", string.format("%d%%", math.floor(accuracy * 100 + 0.5)) },
			{ "TIME ON TARGET", string.format("%.1fs", stats.trackTime) },
			{ "DURATION", string.format("%ds", mode.duration) },
			{ "SCORE", Menu.formatScore(score) },
		}
	else
		rows = {
			{ "HITS", tostring(stats.hits) },
			{ "ACCURACY", string.format("%d%%", math.floor(accuracy * 100 + 0.5)) },
			{ "AVG REACTION", if stats.hits > 0 then string.format("%dms", math.floor(stats.avgReaction + 0.5)) else "-" },
			{ "BEST COMBO", tostring(stats.bestCombo) },
		}
	end
	for i, row in rows do
		self.statNames[i].Text = row[1]
		self.stats[i].Text = row[2]
	end

	Ui.open(self.panel)
	Audio.play("Finish")
	countUp(self.score, score)
	if type(result) == "table" and result.newBest then
		task.delay(1.15, function()
			self.badge.Visible = true
			Ui.pop(self.badge, 0.6)
			Ui.pop(self.score, 0.15)
			Audio.play("Best")
		end)
	end
end

function Results.hide(self: Results)
	Ui.close(self.panel)
end

return Results
