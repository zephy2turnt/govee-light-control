-- Catacombs: builds "Catacombs of the Damned", the first biome, from code.
--
-- The chasm and every ledge are Terrain (Basalt / Slate / Rock), so the
-- level is organic rock rather than blocks. On top of that sit Part-built
-- details: soul-rings, gargoyles, hanging cages, soul-fire torches and the
-- escape gate.
--
-- Layout: a round chasm (radius Config.Tower.Radius) from the floor at
-- y = 0 up to the gate at Config.Tower.Height. Wall rings spiral up the
-- walls so there is always a route; ledges, spires, arches and cages give
-- alternative lines and places to land and refill your hooks.
--
-- Location: ServerScriptService > Server > Catacombs (ModuleScript)

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Anchors = require(script.Parent.Anchors)

local Catacombs = {}

local H = Config.Tower.Height
local R = Config.Tower.Radius
local SOUL = Anchors.SOUL_GREEN
local IRON = Color3.fromRGB(40, 40, 46)

-- Fixed seed: the layout stays the same between test sessions while we tune
-- the grapple. Randomised chunks come with the chunk-stacking stage.
local rng = Random.new(1337)

local terrain = Workspace.Terrain

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

local function polar(angle: number, radius: number, y: number): Vector3
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

-- CFrame at a wall point, looking toward the chasm's centre axis.
local function facingCentre(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

local ROCK = { Enum.Material.Basalt, Enum.Material.Slate, Enum.Material.Rock }
local function rockMaterial(): Enum.Material
	return ROCK[rng:NextInteger(1, #ROCK)]
end

-- The chasm --------------------------------------------------------------------

local function buildChasm()
	-- Solid shell, then carve the shaft out of it.
	terrain:FillCylinder(CFrame.new(0, (H + 10) / 2, 0), H + 40, R + 34, Enum.Material.Basalt)
	terrain:FillCylinder(CFrame.new(0, (H + 10) / 2 + 6, 0), H + 60, R, Enum.Material.Air)
	-- Floor.
	terrain:FillCylinder(CFrame.new(0, -6, 0), 12, R + 4, Enum.Material.Slate)

	-- Craggy bulges so the walls read as natural rock.
	for _ = 1, 110 do
		local a = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(-4, H + 20)
		terrain:FillBall(polar(a, R + rng:NextNumber(-1, 5), y), rng:NextNumber(6, 13), rockMaterial())
	end
	-- Rubble on the floor.
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		terrain:FillBall(polar(a, rng:NextNumber(30, R - 8), -1), rng:NextNumber(2.5, 6), rockMaterial())
	end
end

-- Anchors and props ----------------------------------------------------------------

-- Clears a little alcove in the wall first so the orb is never buried
-- inside a rock bulge.
local function wallRing(angle: number, y: number, parent: Instance)
	local position = polar(angle, R - 5, y)
	terrain:FillBall(position, 4.5, Enum.Material.Air)
	Anchors.ring(facingCentre(position), parent)
end

local function torch(angle: number, y: number, parent: Instance)
	local position = polar(angle, R - 2.5, y)
	terrain:FillBall(position, 3, Enum.Material.Air)
	local cf = facingCentre(position)
	part({
		Name = "TorchBracket",
		Size = Vector3.new(0.6, 0.6, 2.4),
		CFrame = cf * CFrame.new(0, 0, 0.9),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local cup = part({
		Name = "TorchCup",
		Size = Vector3.new(1.4, 0.8, 1.4),
		CFrame = cf * CFrame.new(0, 0.3, -0.4),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(60, 255, 140)
	fire.SecondaryColor = Color3.fromRGB(10, 90, 50)
	fire.Size = 4
	fire.Heat = 9
	fire.Parent = cup
	local light = Instance.new("PointLight")
	light.Color = SOUL
	light.Range = 22
	light.Brightness = 2.5
	light.Shadows = true
	light.Parent = cup
end

-- A rocky floating ledge with a flat top you can land on. Returns its top.
local function ledge(position: Vector3): Vector3
	local yaw = rng:NextNumber(0, math.pi * 2)
	local size = Vector3.new(rng:NextNumber(13, 18), 4, rng:NextNumber(9, 12))
	terrain:FillBlock(CFrame.new(position) * CFrame.Angles(0, yaw, 0), size, Enum.Material.Slate)
	terrain:FillBall(position - Vector3.new(0, 4, 0), rng:NextNumber(5.5, 7.5), Enum.Material.Basalt)
	terrain:FillBall(position + Vector3.new(rng:NextNumber(-3, 3), -8, rng:NextNumber(-3, 3)), rng:NextNumber(3, 4.5), rockMaterial())
	return position + Vector3.new(0, size.Y / 2, 0)
end

local function spire(angle: number, radius: number, height: number, parent: Instance)
	local base = polar(angle, radius, 0)
	local r = rng:NextNumber(4.5, 7)
	terrain:FillCylinder(CFrame.new(base + Vector3.new(0, height / 2, 0)), height, r, Enum.Material.Basalt)
	for y = 10, height - 6, 14 do
		terrain:FillBall(base + Vector3.new(rng:NextNumber(-2, 2), y, rng:NextNumber(-2, 2)), r + rng:NextNumber(0.5, 2.5), rockMaterial())
	end
	-- Jagged broken tip.
	terrain:FillBall(base + Vector3.new(0, height, 0), r * 0.8, Enum.Material.Rock)
	Anchors.post(CFrame.new(base + Vector3.new(0, height + r * 0.6, 0)), parent)
end

-- A collapsed stone arch from one wall toward another, with its middle
-- missing.
local function brokenArch(angleA: number, angleB: number, y: number)
	local a = polar(angleA, R - 2, y)
	local b = polar(angleB, R - 2, y)
	local steps = 26
	for k = 0, steps do
		local t = k / steps
		if t > 0.42 and t < 0.6 then
			continue -- the collapsed gap
		end
		local p = a:Lerp(b, t) + Vector3.new(0, math.sin(t * math.pi) * 22, 0)
		terrain:FillBall(p, 3.6, Enum.Material.Slate)
	end
end

local function cage(angle: number, radius: number, y: number, parent: Instance)
	local top = polar(angle, radius, y)
	local chainLength = 26
	part({
		Name = "Chain",
		Size = Vector3.new(0.35, chainLength, 0.35),
		Position = top + Vector3.new(0, chainLength / 2 + 4, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = parent,
	})
	local model = Instance.new("Model")
	model.Name = "Cage"
	local disc = function(dy: number)
		part({
			Name = "Disc",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 7, 7),
			CFrame = CFrame.new(top + Vector3.new(0, dy, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = IRON,
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	disc(4)
	disc(-4)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		part({
			Name = "Bar",
			Size = Vector3.new(0.3, 8, 0.3),
			Position = top + Vector3.new(math.cos(a) * 3.2, 0, math.sin(a) * 3.2),
			Color = IRON,
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	model.Parent = parent
	-- Orb hanging under the cage.
	Anchors.ring(CFrame.new(top - Vector3.new(0, 6, 0)) * CFrame.Angles(math.rad(-90), 0, 0), parent)
end

local function spawnArea(parent: Instance)
	for k = 0, 3 do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.Position = polar(k * math.pi / 2, 9, 0.2)
		spawn.Color = Color3.fromRGB(30, 34, 36)
		spawn.Material = Enum.Material.Slate
		spawn.Parent = parent
	end
	-- Glowing rune circle on the floor.
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		part({
			Name = "Rune",
			Size = Vector3.new(0.4, 0.1, 2.4),
			CFrame = CFrame.new(polar(a, 16, 0.08)) * CFrame.Angles(0, -a, 0),
			Color = SOUL,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function escapeGate(parent: Instance): BasePart
	local platformY = H - 10
	terrain:FillBlock(CFrame.new(0, platformY, 0), Vector3.new(30, 6, 30), Enum.Material.Slate)
	terrain:FillBall(Vector3.new(0, platformY - 7, 0), 13, Enum.Material.Basalt)
	terrain:FillBall(Vector3.new(0, platformY - 16, 0), 7, Enum.Material.Rock)

	-- Standing ring of light.
	local centre = Vector3.new(0, platformY + 3 + 9, 0)
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		part({
			Name = "GateRing",
			Size = Vector3.new(1, 2.6, 1),
			CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, a) * CFrame.new(0, 9, 0),
			Color = Color3.fromRGB(220, 255, 235),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = parent,
		})
	end
	local zone = part({
		Name = "EscapeZone",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 16,
		Position = centre,
		Transparency = 0.85,
		Color = Color3.fromRGB(200, 255, 220),
		Material = Enum.Material.ForceField,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 255, 220)
	light.Range = 40
	light.Brightness = 4
	light.Parent = zone
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(200, 255, 220))
	sparkle.LightEmission = 1
	sparkle.Rate = 25
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.6, 0)
	sparkle.Parent = zone

	-- Rings around the top so the last stretch has a clear route.
	for k = 0, 3 do
		Anchors.post(CFrame.new(polar(k * math.pi / 2 + math.pi / 4, 12, platformY + 3)), parent)
	end
	return zone
end

-- Where escaped players wait, floating above the tower.
local function sanctum(parent: Instance): BasePart
	local floor = part({
		Name = "Sanctum",
		Size = Vector3.new(44, 2, 44),
		Position = Vector3.new(0, H + 48, 0),
		Color = Color3.fromRGB(42, 46, 50),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	for _, offset in { Vector3.new(22, 1.2, 0), Vector3.new(-22, 1.2, 0), Vector3.new(0, 1.2, 22), Vector3.new(0, 1.2, -22) } do
		part({
			Name = "Trim",
			Size = if offset.X ~= 0 then Vector3.new(0.6, 0.4, 44) else Vector3.new(44, 0.4, 0.6),
			Position = floor.Position + offset,
			Color = SOUL,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = parent,
		})
	end
	return floor
end

-- Build ---------------------------------------------------------------------------

export type Map = {
	folder: Folder,
	escapeZone: BasePart,
	sanctum: BasePart,
}

function Catacombs.build(): Map
	local folder = Instance.new("Folder")
	folder.Name = "Catacombs"
	folder.Parent = Workspace

	buildChasm()

	-- Wall rings: a double spiral up the walls, the guaranteed route.
	local y = 22
	local angle = 0
	while y < H - 14 do
		wallRing(angle, y, folder)
		wallRing(angle + math.pi, y + 9, folder)
		y += 20
		angle += 0.55
	end

	-- Ledges spiralling up the middle, half with gargoyles (breakable),
	-- half with soul posts (solid).
	local ledgeCount = 20
	for i = 1, ledgeCount do
		local t = i / ledgeCount
		local a = i * 2.39996 -- golden angle spreads them evenly
		local pos = polar(a, rng:NextNumber(26, R - 26), 16 + t * (H - 50))
		local top = ledge(pos)
		local outward = CFrame.lookAt(top, top + (top * Vector3.new(1, 0, 1)).Unit)
		if i % 2 == 0 then
			Anchors.gargoyle(outward, folder)
		else
			Anchors.post(CFrame.new(top), folder)
		end
	end

	for k = 0, 4 do
		spire(k * 1.3 + 0.4, rng:NextNumber(40, 66), rng:NextNumber(60, 190), folder)
	end

	brokenArch(0.3, 0.3 + math.pi * 0.9, 95)
	brokenArch(2.2, 2.2 + math.pi * 0.8, 175)
	brokenArch(4.1, 4.1 + math.pi * 0.85, 250)

	cage(1.0, 55, 135, folder)
	cage(3.3, 50, 205, folder)
	cage(5.2, 58, 280, folder)

	for k = 0, 17 do
		torch(k * 0.95, 8 + k * (H / 18), folder)
	end

	spawnArea(folder)
	local escapeZone = escapeGate(folder)
	local sanctumFloor = sanctum(folder)

	return { folder = folder, escapeZone = escapeZone, sanctum = sanctumFloor }
end

return Catacombs
