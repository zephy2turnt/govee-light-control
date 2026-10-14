-- Procedural models for brainrot creatures and growing plants.

local CollectionService = game:GetService("CollectionService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Visuals = {}

local RAINBOW_TAG = "RainbowPart"

local function newPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = model
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function infoBillboard(adornee: BasePart, height: number): (TextLabel, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 90
	gui.Parent = adornee

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui

	local function line(name: string, h: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.new(1, 0, h, 0)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		return label
	end
	return line("Top", 0.28), line("Main", 0.4), line("Bottom", 0.32)
end

-- Builds a creature. The returned model's PrimaryPart ("Body") is unanchored;
-- anchor it (or weld it to something) after positioning with PivotTo.
function Visuals.creature(creatureId: string, mutationId: string?): Model
	local def = Config.Creatures[creatureId]
	local rarity = Config.Rarities[def.rarity]
	local s = def.size
	local model = Instance.new("Model")
	model.Name = def.name

	local bodyColor, headColor = def.bodyColor, def.headColor
	if mutationId == "Golden" then
		bodyColor = Color3.fromRGB(255, 200, 40)
		headColor = Color3.fromRGB(255, 225, 110)
	end

	local body = newPart(model, "Body", Enum.PartType.Block, Vector3.new(2.4, 2, 1.8) * s, bodyColor)
	model.PrimaryPart = body
	body.CFrame = CFrame.new(0, 2 * s, 0)

	local head = newPart(model, "Head", Enum.PartType.Ball, Vector3.one * 2.2 * s, headColor)
	head.CFrame = body.CFrame * CFrame.new(0, 1.9 * s, 0)
	weld(body, head)

	for _, x in { -0.45, 0.45 } do
		local eyeWhite = newPart(model, "EyeWhite", Enum.PartType.Ball, Vector3.one * 0.7 * s, Color3.new(1, 1, 1))
		eyeWhite.CFrame = head.CFrame * CFrame.new(x * s, 0.25 * s, -0.85 * s)
		weld(body, eyeWhite)
		local pupil = newPart(model, "Pupil", Enum.PartType.Ball, Vector3.one * 0.35 * s, Color3.new(0, 0, 0))
		pupil.CFrame = eyeWhite.CFrame * CFrame.new(0, 0, -0.25 * s)
		weld(body, pupil)
	end

	for _, x in { -0.6, 0.6 } do
		local leg = newPart(model, "Leg", Enum.PartType.Block, Vector3.new(0.6, 1, 0.6) * s, bodyColor:Lerp(Color3.new(0, 0, 0), 0.3))
		leg.CFrame = body.CFrame * CFrame.new(x * s, -1.5 * s, 0)
		weld(body, leg)
	end

	-- Fancier brainrots get a party hat in their rarity colour.
	if rarity.order >= 3 then
		local hat = newPart(model, "Hat", Enum.PartType.Block, Vector3.new(1, 1.4, 1) * s, rarity.color)
		hat.Material = Enum.Material.Neon
		hat.CFrame = head.CFrame * CFrame.new(0, 1.3 * s, 0) * CFrame.Angles(0, math.rad(45), 0)
		weld(body, hat)
	end

	if mutationId == "Golden" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 80)
		sparkles.Parent = body
		body.Material = Enum.Material.Foil
		head.Material = Enum.Material.Foil
	elseif mutationId == "Rainbow" then
		body.Material = Enum.Material.Neon
		CollectionService:AddTag(body, RAINBOW_TAG)
		CollectionService:AddTag(head, RAINBOW_TAG)
		local fire = Instance.new("Sparkles")
		fire.Parent = head
	end

	local top, main, bottom = infoBillboard(head, 2.2 * s)
	local mutation = Config.getMutation(mutationId)
	top.Text = if mutation then mutation.name:upper() else ""
	top.TextColor3 = if mutationId == "Golden" then Color3.fromRGB(255, 210, 60) else Color3.fromRGB(255, 120, 255)
	main.Text = def.name
	bottom.Text = string.format("%s · $%s/s", def.rarity, Config.formatNumber(Config.creatureIncome(creatureId, mutationId)))
	bottom.TextColor3 = rarity.color
	if def.rarity == "Secret" then
		bottom.TextStrokeColor3 = Color3.new(1, 1, 1)
		bottom.TextColor3 = Color3.new(0, 0, 0)
	end

	return model
end

-- Distance from a creature's pivot down to its feet.
function Visuals.footOffset(creatureId: string): number
	return 2 * Config.Creatures[creatureId].size
end

-- Cycles the hue of every rainbow part. Call from a loop.
function Visuals.stepRainbow(t: number)
	local color = Color3.fromHSV((t * 0.25) % 1, 0.9, 1)
	for _, p in CollectionService:GetTagged(RAINBOW_TAG) do
		(p :: BasePart).Color = color
	end
end

-- Builds (or rebuilds) a plant on top of a soil tile. progress is 0..1.
function Visuals.plant(tile: BasePart, seedId: string, progress: number, existing: Model?): Model
	local seed = Config.Seeds[seedId]
	local model = existing
	local stem: Part, bulb: Part, label: TextLabel
	if model then
		stem = model:FindFirstChild("Stem") :: Part
		bulb = model:FindFirstChild("Bulb") :: Part
		label = (bulb:FindFirstChild("Info") :: BillboardGui):FindFirstChild("Main") :: TextLabel
	else
		model = Instance.new("Model")
		model.Name = "Plant"
		stem = newPart(model, "Stem", Enum.PartType.Cylinder, Vector3.one, Color3.fromRGB(60, 170, 60))
		bulb = newPart(model, "Bulb", Enum.PartType.Ball, Vector3.one, seed.color)
		stem.Anchored = true
		bulb.Anchored = true
		local _, main, _ = infoBillboard(bulb, 2.5)
		label = main
		model.Parent = tile
	end
	assert(model)

	local p = math.clamp(progress, 0, 1)
	local height = 0.6 + 4 * p
	local top = tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0)
	stem.Size = Vector3.new(height, 0.5 + 0.3 * p, 0.5 + 0.3 * p)
	stem.CFrame = top * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	local bulbSize = 0.8 + 2.4 * p
	bulb.Size = Vector3.one * bulbSize
	bulb.CFrame = top * CFrame.new(0, height + bulbSize / 2 - 0.2, 0)

	if p >= 1 then
		label.Text = "READY!"
		label.TextColor3 = Color3.fromRGB(120, 255, 120)
		bulb.Material = Enum.Material.Neon
		if not bulb:FindFirstChildOfClass("Sparkles") then
			Instance.new("Sparkles").Parent = bulb
		end
	else
		label.Text = string.format("%s %d%%", seed.name, math.floor(p * 100))
		label.TextColor3 = Color3.new(1, 1, 1)
	end
	return model
end

return Visuals
