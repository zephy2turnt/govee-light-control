-- Builds the whole map from code: ground, seed shop, and the player plots.
-- Each plot is described in "plot space": local +Z faces the middle road,
-- the garden sits at the front and the base (where brainrots live) at the back.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local MapBuilder = {}

export type Plot = {
	index: number,
	cframe: CFrame,
	model: Model,
	tiles: { BasePart },
	tilePrompts: { ProximityPrompt },
	pedestals: { BasePart },
	sellPrompts: { ProximityPrompt },
	stealPrompts: { ProximityPrompt },
	lockButton: BasePart,
	lockPrompt: ProximityPrompt,
	barrier: BasePart,
	signLabel: TextLabel,
	lockLabel: TextLabel,
}

local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(140, 230, 120),
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(255, 160, 220),
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function billboard(parent: Instance, size: UDim2, offset: Vector3, maxDistance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 150
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return label
end

local function prompt(parent: Instance, actionText: string, objectText: string, holdTime: number?, key: Enum.KeyCode?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = objectText
	pp.HoldDuration = holdTime or 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = key or Enum.KeyCode.E
	pp:SetAttribute("Active", true)
	pp.Parent = parent
	return pp
end

local function buildEnvironment()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	part({
		Name = "Ground", Size = Vector3.new(700, 2, 700), Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(95, 170, 70), Material = Enum.Material.Grass, Parent = map,
	})
	part({
		Name = "Road", Size = Vector3.new(560, 0.2, 60), Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(200, 180, 140), Material = Enum.Material.Sand, Parent = map,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 18)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = map

	-- Seed shop stall in the middle of the road.
	local shop = Instance.new("Model")
	shop.Name = "SeedShop"
	shop.Parent = map
	local counter = part({
		Name = "Counter", Size = Vector3.new(18, 4, 6), Position = Vector3.new(0, 2, -6),
		Color = Color3.fromRGB(150, 95, 50), Material = Enum.Material.Wood, Parent = shop,
	})
	for _, x in { -8, 8 } do
		part({
			Name = "Post", Size = Vector3.new(1, 12, 1), Position = Vector3.new(x, 6, -8),
			Color = Color3.fromRGB(120, 75, 40), Material = Enum.Material.Wood, Parent = shop,
		})
	end
	local roof = part({
		Name = "Roof", Size = Vector3.new(22, 1, 10), Position = Vector3.new(0, 12.5, -7),
		Color = Color3.fromRGB(230, 70, 70), Material = Enum.Material.Fabric, Parent = shop,
	})
	local title = billboard(roof, UDim2.fromOffset(300, 70), Vector3.new(0, 3, 0), 250)
	title.Text = "SEED SHOP"
	title.TextColor3 = Color3.fromRGB(255, 240, 120)
	local shopPrompt = prompt(counter, "Open Shop", "Seed Shop")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.MaxActivationDistance = 14
	return map, shopPrompt
end

local function buildPlot(index: number, cframe: CFrame, parent: Instance): Plot
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = parent

	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	part({
		Name = "Floor", Size = Vector3.new(100, 1, 80), CFrame = at(0, 0.5, 0),
		Color = Color3.fromRGB(110, 185, 85), Material = Enum.Material.Grass, Parent = model,
	})

	-- Garden: 3x2 soil tiles at the front of the plot.
	local tiles, tilePrompts = {}, {}
	local tileIndex = 0
	for _, z in { 30, 14 } do
		for _, x in { -24, 0, 24 } do
			tileIndex += 1
			local tile = part({
				Name = "Tile" .. tileIndex, Size = Vector3.new(12, 0.6, 12), CFrame = at(x, 1.2, z),
				Color = Color3.fromRGB(100, 65, 40), Material = Enum.Material.Ground, Parent = model,
			})
			local pp = prompt(tile, "Plant", "Empty Soil")
			pp.Name = "TilePrompt"
			tiles[tileIndex] = tile
			tilePrompts[tileIndex] = pp
		end
	end

	-- Base: raised platform with pedestals, walls on three sides.
	part({
		Name = "BaseFloor", Size = Vector3.new(92, 1, 38), CFrame = at(0, 1.5, -20),
		Color = color, Material = Enum.Material.SmoothPlastic, Parent = model,
	})
	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.35)
	part({ Name = "BackWall", Size = Vector3.new(92, 8, 2), CFrame = at(0, 5, -40), Color = wallColor, Parent = model })
	part({ Name = "LeftWall", Size = Vector3.new(2, 8, 38), CFrame = at(-47, 5, -20), Color = wallColor, Parent = model })
	part({ Name = "RightWall", Size = Vector3.new(2, 8, 38), CFrame = at(47, 5, -20), Color = wallColor, Parent = model })

	local pedestals, sellPrompts, stealPrompts = {}, {}, {}
	local pedIndex = 0
	for _, z in { -12, -28 } do
		for _, x in { -33, -11, 11, 33 } do
			pedIndex += 1
			local ped = part({
				Name = "Pedestal" .. pedIndex, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 7, 7),
				CFrame = at(x, 2.75, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(235, 235, 245), Material = Enum.Material.Marble, Parent = model,
			})
			local sell = prompt(ped, "Sell", "", 0.5, Enum.KeyCode.F)
			sell.Name = "SellPrompt"
			sell.Enabled = false
			sell:SetAttribute("Active", false)
			local steal = prompt(ped, "Steal", "", Config.StealHoldTime, Enum.KeyCode.E)
			steal.Name = "StealPrompt"
			steal.Enabled = false
			steal:SetAttribute("Active", false)
			pedestals[pedIndex] = ped
			sellPrompts[pedIndex] = sell
			stealPrompts[pedIndex] = steal
		end
	end

	local lockButton = part({
		Name = "LockButton", Size = Vector3.new(5, 1, 5), CFrame = at(40, 1.5, 4),
		Color = Color3.fromRGB(230, 40, 40), Material = Enum.Material.Neon, Parent = model,
	})
	local lockPrompt = prompt(lockButton, "Lock Base", "Security", 0.3)
	lockPrompt.Name = "LockPrompt"
	local lockLabel = billboard(lockButton, UDim2.fromOffset(160, 40), Vector3.new(0, 3, 0), 80)
	lockLabel.Text = "LOCK READY"

	local barrier = part({
		Name = "Barrier", Size = Vector3.new(92, 14, 38), CFrame = at(0, 9, -20),
		Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.ForceField,
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = model,
	})

	local signPart = part({
		Name = "Sign", Size = Vector3.new(1, 1, 1), CFrame = at(0, 14, -38),
		Transparency = 1, CanCollide = false, CanQuery = false, Parent = model,
	})
	local signLabel = billboard(signPart, UDim2.fromOffset(420, 70), Vector3.zero, 300)
	signLabel.Text = "Free Plot"

	return {
		index = index,
		cframe = cframe,
		model = model,
		tiles = tiles,
		tilePrompts = tilePrompts,
		pedestals = pedestals,
		sellPrompts = sellPrompts,
		stealPrompts = stealPrompts,
		lockButton = lockButton,
		lockPrompt = lockPrompt,
		barrier = barrier,
		signLabel = signLabel,
		lockLabel = lockLabel,
	}
end

function MapBuilder.build(): ({ Plot }, ProximityPrompt)
	local map, shopPrompt = buildEnvironment()
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = map

	local plots = {}
	local positions = {}
	for _, x in { -110, 0, 110 } do
		table.insert(positions, Vector3.new(x, 0, -75))
		table.insert(positions, Vector3.new(x, 0, 75))
	end
	for i = 1, math.min(Config.MaxPlots, #positions) do
		local pos = positions[i]
		-- Rotate so the plot's local +Z faces the road at z = 0.
		local cf = CFrame.new(pos) * (if pos.Z > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		plots[i] = buildPlot(i, cf, plotsFolder)
	end
	return plots, shopPrompt
end

-- Is a world position standing inside this plot's base area?
function MapBuilder.isInBase(plot: Plot, position: Vector3): boolean
	local localPos = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= 47 and localPos.Z <= -1 and localPos.Z >= -40 and localPos.Y < 20
end

function MapBuilder.spawnCFrame(plot: Plot): CFrame
	-- Stand between garden and base, facing the road.
	return plot.cframe * CFrame.new(0, 5, 4)
end

return MapBuilder
