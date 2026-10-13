-- Grow a Brainrot: client UI. Everything is built in code so the project
-- needs no Studio-authored assets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuySeed = remotes:WaitForChild("BuySeed") :: RemoteEvent
local SelectSeed = remotes:WaitForChild("SelectSeed") :: RemoteEvent
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent
local OpenShop = remotes:WaitForChild("OpenShop") :: RemoteEvent
local Knockback = remotes:WaitForChild("Knockback") :: RemoteEvent

local FONT = Enum.Font.FredokaOne

-- UI helpers ------------------------------------------------------------------

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = Color3.fromRGB(30, 30, 40)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.3
	b.AutoButtonColor = true
	corner(b)
	stroke(b)
	b.Parent = parent
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Cash ------------------------------------------------------------------------

local cashFrame = Instance.new("Frame")
cashFrame.AnchorPoint = Vector2.new(0.5, 0)
cashFrame.Position = UDim2.new(0.5, 0, 0, 8)
cashFrame.Size = UDim2.fromOffset(260, 64)
cashFrame.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
corner(cashFrame, 14)
stroke(cashFrame, 3)
cashFrame.Parent = gui

local cashLabel = label(cashFrame, "$0", UDim2.new(1, -16, 0.62, 0))
cashLabel.Position = UDim2.fromOffset(8, 2)
local incomeLabel = label(cashFrame, "+$0/s", UDim2.new(1, -16, 0.34, 0), Color3.fromRGB(210, 255, 210))
incomeLabel.Position = UDim2.new(0, 8, 0.62, -2)

local function refreshCash()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: NumberValue?
	cashLabel.Text = "$" .. Config.formatNumber(if cash then cash.Value else 0)
	incomeLabel.Text = "+$" .. Config.formatNumber(player:GetAttribute("Income") or 0) .. "/s"
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash") :: NumberValue
	cash.Changed:Connect(refreshCash)
	refreshCash()
end)
player:GetAttributeChangedSignal("Income"):Connect(refreshCash)

-- Notifications ---------------------------------------------------------------------

local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 120)
toastHolder.Size = UDim2.fromOffset(520, 300)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local toastCount = 0
local function toast(text: string, color: Color3)
	toastCount += 1
	local l = label(toastHolder, text, UDim2.new(1, 0, 0, 34), color)
	l.LayoutOrder = toastCount
	l.TextStrokeTransparency = 0
	local existing = toastHolder:GetChildren()
	if #existing > 7 then
		for _, child in existing do
			if child:IsA("TextLabel") and child ~= l then
				child:Destroy()
				break
			end
		end
	end
	task.delay(3.5, function()
		if l.Parent then
			local tween = TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			l:Destroy()
		end
	end)
end

Notify.OnClientEvent:Connect(function(text: string, color: Color3)
	toast(text, color)
end)

-- Seed hotbar -----------------------------------------------------------------------

local hotbar = Instance.new("Frame")
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -90) -- leave room for the Roblox backpack bar
hotbar.Size = UDim2.fromOffset(600, 64)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui
local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.Padding = UDim.new(0, 8)
hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Parent = hotbar

local function refreshHotbar()
	for _, child in hotbar:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local seeds = player:FindFirstChild("Seeds")
	if not seeds then
		return
	end
	local selected = player:GetAttribute("SelectedSeed")
	for order, id in Config.sortedSeedIds() do
		local value = seeds:FindFirstChild(id) :: IntValue?
		if value and value.Value > 0 then
			local seed = Config.Seeds[id]
			local b = button(hotbar, string.format("%s\nx%d", seed.name, value.Value), UDim2.fromOffset(110, 60), seed.color)
			b.LayoutOrder = order
			local s = b:FindFirstChildOfClass("UIStroke") :: UIStroke
			if id == selected then
				s.Color = Color3.fromRGB(255, 255, 120)
				s.Thickness = 4
			end
			b.Activated:Connect(function()
				SelectSeed:FireServer(id)
			end)
		end
	end
end

task.spawn(function()
	local seeds = player:WaitForChild("Seeds")
	local function hook(v: Instance)
		if v:IsA("IntValue") then
			v.Changed:Connect(refreshHotbar)
		end
	end
	for _, v in seeds:GetChildren() do
		hook(v)
	end
	seeds.ChildAdded:Connect(function(v)
		hook(v)
		refreshHotbar()
	end)
	refreshHotbar()
end)
player:GetAttributeChangedSignal("SelectedSeed"):Connect(refreshHotbar)

-- Shop ------------------------------------------------------------------------------

local shopFrame = Instance.new("Frame")
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.Position = UDim2.fromScale(0.5, 0.5)
shopFrame.Size = UDim2.fromOffset(460, 420)
shopFrame.BackgroundColor3 = Color3.fromRGB(45, 40, 60)
shopFrame.Visible = false
corner(shopFrame, 16)
stroke(shopFrame, 3)
shopFrame.Parent = gui

local shopTitle = label(shopFrame, "SEED SHOP", UDim2.new(1, -80, 0, 44), Color3.fromRGB(255, 230, 120))
shopTitle.Position = UDim2.fromOffset(16, 8)
shopTitle.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = button(shopFrame, "X", UDim2.fromOffset(40, 40), Color3.fromRGB(220, 60, 60))
closeButton.Position = UDim2.new(1, -52, 0, 10)
closeButton.Activated:Connect(function()
	shopFrame.Visible = false
end)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 60)
list.Size = UDim2.new(1, -24, 1, -72)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = shopFrame
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local function bestRarity(seedId: string): string
	local best, bestOrder = "Common", 0
	for _, entry in Config.Seeds[seedId].pool do
		local rarity = Config.Creatures[entry.id].rarity
		local order = Config.Rarities[rarity].order
		if order > bestOrder then
			best, bestOrder = rarity, order
		end
	end
	return best
end

for order, id in Config.sortedSeedIds() do
	local seed = Config.Seeds[id]
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 70)
	row.BackgroundColor3 = Color3.fromRGB(65, 60, 85)
	corner(row)
	row.Parent = list

	local swatch = Instance.new("Frame")
	swatch.Position = UDim2.fromOffset(10, 13)
	swatch.Size = UDim2.fromOffset(44, 44)
	swatch.BackgroundColor3 = seed.color
	corner(swatch, 22)
	swatch.Parent = row

	local name = label(row, seed.name, UDim2.new(1, -200, 0, 30), Color3.new(1, 1, 1))
	name.Position = UDim2.fromOffset(64, 6)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local top = bestRarity(id)
	local info = label(row, string.format("Grows in %ds · up to %s", seed.growTime, top), UDim2.new(1, -200, 0, 24), Config.Rarities[top].color)
	info.Position = UDim2.fromOffset(64, 38)
	info.TextXAlignment = Enum.TextXAlignment.Left

	local buy = button(row, "$" .. Config.formatNumber(seed.price), UDim2.fromOffset(110, 50), Color3.fromRGB(40, 170, 70))
	buy.Position = UDim2.new(1, -120, 0, 10)
	buy.Activated:Connect(function()
		BuySeed:FireServer(id)
	end)
end

local shopToggle = button(gui, "SHOP", UDim2.fromOffset(110, 50), Color3.fromRGB(230, 110, 40))
shopToggle.AnchorPoint = Vector2.new(0, 0.5)
shopToggle.Position = UDim2.new(0, 12, 0.5, 0)
shopToggle.Activated:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
end)

OpenShop.OnClientEvent:Connect(function()
	shopFrame.Visible = true
end)

-- Help ------------------------------------------------------------------------------

local helpFrame = Instance.new("Frame")
helpFrame.AnchorPoint = Vector2.new(0, 0.5)
helpFrame.Position = UDim2.new(0, 12, 0.5, 40)
helpFrame.Size = UDim2.fromOffset(230, 150)
helpFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
helpFrame.BackgroundTransparency = 0.35
corner(helpFrame)
helpFrame.Parent = gui
local help = label(helpFrame, table.concat({
	"1. Buy seeds (SHOP)",
	"2. Plant them in your soil",
	"3. Harvest brainrots = $/sec",
	"4. Steal from others (hold E)",
	"5. Lock your base + bonk thieves!",
}, "\n"), UDim2.new(1, -16, 1, -12))
help.Position = UDim2.fromOffset(8, 6)
help.TextXAlignment = Enum.TextXAlignment.Left
help.TextScaled = false
help.TextSize = 16

-- Weather banner ------------------------------------------------------------------------

local weatherLabel = label(gui, "", UDim2.fromOffset(420, 36), Color3.fromRGB(255, 215, 80))
weatherLabel.AnchorPoint = Vector2.new(0.5, 0)
weatherLabel.Position = UDim2.new(0.5, 0, 0, 78)
weatherLabel.TextStrokeTransparency = 0

-- Carrying banner
local carryLabel = label(gui, "", UDim2.fromOffset(460, 36), Color3.fromRGB(255, 120, 120))
carryLabel.AnchorPoint = Vector2.new(0.5, 1)
carryLabel.Position = UDim2.new(0.5, 0, 1, -160)
carryLabel.TextStrokeTransparency = 0

-- Knockback (applied on the client because it owns its character physics) -------

Knockback.OnClientEvent:Connect(function(velocity: Vector3)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if hrp and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		hrp.AssemblyLinearVelocity = velocity
	end
end)

-- Prompt filtering + timers ---------------------------------------------------------------
-- Owners see Plant/Harvest/Sell/Lock on their own plot; everyone else sees Steal.
-- The server still validates everything, this just keeps the screen tidy.

local function filterPrompts()
	local me = player.UserId
	local function apply(pp: ProximityPrompt, forMe: boolean)
		local want = forMe and pp:GetAttribute("Active") == true
		if pp.Enabled ~= want then
			pp.Enabled = want
		end
	end
	for _, pp in CollectionService:GetTagged("OwnerPrompt") do
		apply(pp :: ProximityPrompt, pp:GetAttribute("OwnerUserId") == me)
	end
	for _, pp in CollectionService:GetTagged("ThiefPrompt") do
		local owner = pp:GetAttribute("OwnerUserId")
		apply(pp :: ProximityPrompt, owner ~= me and owner ~= 0)
	end
end

while true do
	filterPrompts()

	local endsAt = Workspace:GetAttribute("WeatherEndsAt")
	if endsAt then
		local left = math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))
		weatherLabel.Text = string.format("GOLDEN RAIN · %ds · %dx mutations", left, Config.WeatherMutationBoost)
	else
		weatherLabel.Text = ""
	end

	carryLabel.Text = if player:GetAttribute("Carrying") then "CARRYING A BRAINROT! Get back to your base!" else ""

	task.wait(0.2)
end
