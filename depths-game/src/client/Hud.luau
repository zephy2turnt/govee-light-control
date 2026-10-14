-- Hud: in-game interface.
--
--   * Status pill (top): countdown, climb timer, fog grace, escaped/consumed
--   * "CLIMB!" slam when a round starts
--   * Depth meter (left): your height vs the fog vs the exit, plus other
--     climbers as small dots
--   * Hook charges (bottom centre)
--   * Toast notifications (top right)
--   * Touch only: big HOOK button and a centre crosshair
--
-- Laid out in design pixels for 1280x720 and scaled with a UIScale.
--
-- Location: StarterPlayerScripts > Client > Hud (ModuleScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Fog = require(Shared.Fog)
local Audio = require(script.Parent.Audio)
local Grapple = require(script.Parent.Grapple)

local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Hud = {}

local player = Players.LocalPlayer

local FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local FONT_HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local SOUL = Color3.fromRGB(110, 255, 170)
local GOLD = Color3.fromRGB(255, 215, 90)
local RED = Color3.fromRGB(255, 95, 95)
local PANEL = Color3.fromRGB(14, 20, 18)
local OUTLINE = Color3.fromRGB(4, 8, 6)

local function make(className: string, props: { [string]: any }, children: { any }?): any
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function corner(radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function stroke(thickness: number?, color: Color3?): UIStroke
	return make("UIStroke", { Thickness = thickness or 2, Color = color or OUTLINE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.FontFace = props.FontFace or FONT_BOLD
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local label = make("TextLabel", props)
	make("UIStroke", { Thickness = 2, Color = OUTLINE, Parent = label })
	return label
end

local function formatTime(seconds: number): string
	return string.format("%d:%04.1f", seconds // 60, seconds % 60)
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Hud.init()
	local gui = make("ScreenGui", {
		Name = "Hud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Root frame in design pixels, scaled to fit the screen.
	local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
	local uiScale = make("UIScale", { Parent = root })
	local function resize()
		local view = Workspace.CurrentCamera.ViewportSize
		local reference = if isTouch() then Vector2.new(960, 540) else Vector2.new(1280, 720)
		local s = math.clamp(math.min(view.X / reference.X, view.Y / reference.Y), 0.5, 1.6)
		uiScale.Scale = s
		root.Size = UDim2.fromOffset(view.X / s, view.Y / s)
	end
	resize()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)

	-- Status pill ----------------------------------------------------------------
	local pill = make("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(380, 70),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Parent = root,
	}, { corner(18), stroke(3) })
	local pillScale = make("UIScale", { Parent = pill })
	local title = text({
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 4),
		TextSize = 34,
		FontFace = FONT_HEAVY,
		Text = "",
		Parent = pill,
	})
	local subtitle = text({
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 42),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(170, 200, 185),
		Text = "",
		Parent = pill,
	})

	-- Big centre slam text.
	local slam = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(700, 140),
		TextSize = 120,
		FontFace = FONT_HEAVY,
		TextColor3 = SOUL,
		TextTransparency = 1,
		Text = "CLIMB!",
		Parent = root,
	})
	local slamStroke = slam:FindFirstChildOfClass("UIStroke") :: UIStroke
	slamStroke.Thickness = 5
	slamStroke.Transparency = 1
	local slamScale = make("UIScale", { Parent = slam })
	local function doSlam(message: string, color: Color3)
		slam.Text = message
		slam.TextColor3 = color
		slam.TextTransparency = 0
		slamStroke.Transparency = 0
		slamScale.Scale = 2.2
		TweenService:Create(slamScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(1.1, function()
			TweenService:Create(slam, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(slamStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end)
	end

	-- Depth meter ------------------------------------------------------------------
	local meterHeight = 340
	local meter = make("Frame", {
		Name = "DepthMeter",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 34, 0.5, 10),
		Size = UDim2.fromOffset(22, meterHeight),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Parent = root,
	}, { corner(11), stroke(3) })
	local fogFill = make("Frame", {
		Name = "Fog",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = SOUL,
		Parent = meter,
	}, {
		corner(11),
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(180, 255, 210), Color3.fromRGB(20, 120, 70)),
		}),
	})
	text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(60, 20),
		TextSize = 16,
		TextColor3 = GOLD,
		FontFace = FONT_HEAVY,
		Text = "EXIT",
		Parent = meter,
	})
	local you = make("Frame", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = meter,
	}, { corner(9), stroke(3) })
	text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(50, 20),
		TextSize = 16,
		FontFace = FONT_HEAVY,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "YOU",
		Parent = you,
	})
	local otherDots: { [Player]: Frame } = {}

	-- Hook charges ----------------------------------------------------------------
	local chargesFrame = make("Frame", {
		Name = "Charges",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(Config.Grapple.Charges * 40, 34),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	local pips: { Frame } = {}
	for i = 1, Config.Grapple.Charges do
		local pip = make("Frame", {
			Name = "Charge" .. i,
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = SOUL,
			LayoutOrder = i,
			Parent = chargesFrame,
		}, { corner(14), stroke(3) })
		make("UIScale", { Parent = pip })
		pips[i] = pip
	end
	local function renderCharges(n: number, animate: boolean)
		for i, pip in pips do
			local on = i <= n
			local scale = pip:FindFirstChildOfClass("UIScale") :: UIScale
			TweenService:Create(pip, TweenInfo.new(0.2), {
				BackgroundColor3 = if on then SOUL else Color3.fromRGB(40, 50, 46),
			}):Play()
			if animate and on then
				scale.Scale = 1.35
				TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end
	end
	local lastCharges = Grapple.getCharges()
	renderCharges(lastCharges, false)
	Grapple.onChargesChanged(function(n)
		renderCharges(n, n > lastCharges)
		lastCharges = n
	end)
	Grapple.onOutOfCharges(function()
		-- Shake the pips: "you're empty".
		local origin = chargesFrame.Position
		for _, dx in { -8, 8, -6, 6, -3, 0 } do
			chargesFrame.Position = origin + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		chargesFrame.Position = origin
	end)

	-- Toasts ------------------------------------------------------------------------
	local toasts = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 70),
		Size = UDim2.fromOffset(420, 300),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local toastCount = 0
	NotifyRemote.OnClientEvent:Connect(function(message: string, color: Color3)
		toastCount += 1
		local toast = make("CanvasGroup", {
			Size = UDim2.fromOffset(420, 44),
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.15,
			GroupTransparency = 1,
			LayoutOrder = toastCount,
			Parent = toasts,
		}, { corner(12) })
		make("Frame", {
			Size = UDim2.new(0, 6, 1, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = toast,
		})
		text({
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(16, 0),
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Text = message,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = toast,
		})
		local slide = make("UIScale", { Scale = 0.85, Parent = toast })
		TweenService:Create(toast, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
		TweenService:Create(slide, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(4.5, function()
			local fade = TweenService:Create(toast, TweenInfo.new(0.35), { GroupTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			toast:Destroy()
		end)
	end)

	-- Touch controls -----------------------------------------------------------------
	local hookButton = make("TextButton", {
		Name = "HookButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -150),
		Size = UDim2.fromOffset(130, 130),
		BackgroundColor3 = Color3.fromRGB(30, 140, 90),
		BackgroundTransparency = 0.1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		Parent = root,
	}, { corner(65), stroke(4, Color3.fromRGB(180, 255, 210)) })
	text({ Size = UDim2.fromScale(1, 1), TextSize = 34, FontFace = FONT_HEAVY, Text = "HOOK", Parent = hookButton })
	local hookScale = make("UIScale", { Parent = hookButton })
	hookButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(hookScale, TweenInfo.new(0.08), { Scale = 0.9 }):Play()
			Grapple.press()
		end
	end)
	hookButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(hookScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			Grapple.release()
		end
	end)

	local crosshair = make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	}, { corner(7), stroke(2, Color3.fromRGB(220, 255, 235)) })

	local function refreshInputMode()
		local last = UserInputService:GetLastInputType()
		local touch = last == Enum.UserInputType.Touch or (isTouch() and not last.Name:find("Gamepad"))
		hookButton.Visible = touch
		crosshair.Visible = touch or last.Name:find("Gamepad") ~= nil
		resize()
	end
	refreshInputMode()
	UserInputService.LastInputTypeChanged:Connect(refreshInputMode)

	-- Per-frame updates ------------------------------------------------------------------
	local lastCountdown = -1
	local lastState = nil
	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local state = Workspace:GetAttribute("RoundState")
		local elapsed = Fog.elapsed(now)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local alive = humanoid ~= nil and humanoid.Health > 0
		local escapeTime = player:GetAttribute("EscapeTime")

		if state ~= lastState then
			if state == Fog.Climbing and lastState == Fog.Intermission then
				doSlam("CLIMB!", SOUL)
				Audio.play("Go")
				pillScale.Scale = 1.15
				TweenService:Create(pillScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			lastState = state
		end

		if state == Fog.Intermission then
			local remaining = math.max(0, math.ceil((Workspace:GetAttribute("StateDuration") or 0) - elapsed))
			title.Text = string.format("CLIMB IN %d", remaining)
			title.TextColor3 = Color3.new(1, 1, 1)
			subtitle.Text = "Get ready. The fog is coming."
			if remaining ~= lastCountdown then
				lastCountdown = remaining
				if remaining > 0 and remaining <= 3 then
					Audio.play("Tick", 1 + (3 - remaining) * 0.12)
					pillScale.Scale = 1.12
					TweenService:Create(pillScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end
			end
		elseif state == Fog.Climbing then
			if escapeTime then
				title.Text = "ESCAPED  " .. formatTime(escapeTime)
				title.TextColor3 = GOLD
				subtitle.Text = "Watch the others make it... or not."
			elseif not alive then
				title.Text = "CONSUMED"
				title.TextColor3 = RED
				subtitle.Text = "You'll rise again next climb."
			else
				title.Text = formatTime(elapsed)
				title.TextColor3 = Color3.new(1, 1, 1)
				local grace = Config.Fog.Grace - elapsed
				subtitle.Text = if grace > 0 then string.format("FOG RISES IN %d", math.ceil(grace)) else "THE FOG RISES"
			end
		else
			title.Text = "THE FOG RECEDES"
			title.TextColor3 = SOUL
			subtitle.Text = "Next climb soon"
		end

		-- Depth meter.
		local minY, maxY = Config.Fog.MinY, Config.Tower.Height
		local function fraction(y: number): number
			return math.clamp((y - minY) / (maxY - minY), 0, 1)
		end
		fogFill.Size = UDim2.fromScale(1, fraction(Fog.height(now)))
		local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		you.Visible = myRoot ~= nil and alive
		if myRoot then
			you.Position = UDim2.fromScale(0.5, 1 - fraction(myRoot.Position.Y))
		end
		for _, other in Players:GetPlayers() do
			if other == player then
				continue
			end
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local dot = otherDots[other]
			if otherRoot and not dot then
				dot = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(9, 9),
					BackgroundColor3 = Color3.fromRGB(200, 220, 210),
					ZIndex = 2,
					Parent = meter,
				}, { corner(5) })
				otherDots[other] = dot
			end
			if dot then
				dot.Visible = otherRoot ~= nil
				if otherRoot then
					dot.Position = UDim2.fromScale(0.5, 1 - fraction(otherRoot.Position.Y))
				end
			end
		end
		for other, dot in otherDots do
			if not other.Parent then
				dot:Destroy()
				otherDots[other] = nil
			end
		end
	end)
end

return Hud
