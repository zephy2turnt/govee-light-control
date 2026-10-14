-- All game tuning lives here so it can be tweaked without touching logic.

local Config = {}

Config.StartingCash = 100
Config.StartingSeeds = { basic = 2 }

Config.MaxPlots = 6
Config.TilesPerPlot = 6
Config.PedestalsPerPlot = 8

Config.LockDuration = 60 -- seconds a base stays locked
Config.LockCooldown = 20 -- seconds after a lock ends before it can be used again
Config.StealHoldTime = 1.5
Config.CarryWalkSpeed = 11
Config.NormalWalkSpeed = 16
Config.BonkCooldown = 0.8
Config.BonkRange = 9
Config.BonkStun = 1.2
Config.SellMultiplier = 30 -- sell price = income/sec * this

Config.AutosaveInterval = 120
Config.DataStoreName = "GrowABrainrot_v1"

-- Golden Rain: a recurring weather event that boosts mutation odds.
Config.WeatherInterval = 300
Config.WeatherDuration = 60
Config.WeatherMutationBoost = 4

-- Rarity colours live in Theme so the UI and the world always agree.
Config.Rarities = require(script.Parent.Theme).Rarity

export type CreatureDef = {
	name: string,
	rarity: string,
	income: number,
	bodyColor: Color3,
	headColor: Color3,
	size: number,
}

Config.Creatures = {
	noodle_shark = { name = "Noodle Sharkini", rarity = "Common", income = 2, bodyColor = Color3.fromRGB(120, 160, 200), headColor = Color3.fromRGB(240, 210, 120), size = 1 },
	toastolini = { name = "Toastolini", rarity = "Common", income = 3, bodyColor = Color3.fromRGB(210, 150, 80), headColor = Color3.fromRGB(250, 230, 180), size = 1 },
	gloopa = { name = "Gloopa Doopa", rarity = "Common", income = 4, bodyColor = Color3.fromRGB(90, 200, 90), headColor = Color3.fromRGB(150, 240, 150), size = 1.1 },
	bananini = { name = "Bananini Bandito", rarity = "Rare", income = 10, bodyColor = Color3.fromRGB(250, 220, 60), headColor = Color3.fromRGB(60, 40, 30), size = 1.2 },
	froggo = { name = "Cappuccino Froggo", rarity = "Rare", income = 14, bodyColor = Color3.fromRGB(110, 70, 40), headColor = Color3.fromRGB(80, 180, 80), size = 1.2 },
	pigeoni = { name = "Turbo Pigeoni", rarity = "Epic", income = 40, bodyColor = Color3.fromRGB(130, 130, 150), headColor = Color3.fromRGB(80, 200, 160), size = 1.35 },
	croco = { name = "Croco Dilemma", rarity = "Epic", income = 55, bodyColor = Color3.fromRGB(40, 120, 60), headColor = Color3.fromRGB(230, 230, 230), size = 1.4 },
	meatballo = { name = "Mamma Meatballo", rarity = "Legendary", income = 160, bodyColor = Color3.fromRGB(150, 60, 40), headColor = Color3.fromRGB(220, 40, 40), size = 1.6 },
	cactusso = { name = "Il Grande Cactusso", rarity = "Legendary", income = 220, bodyColor = Color3.fromRGB(50, 160, 70), headColor = Color3.fromRGB(255, 120, 200), size = 1.7 },
	vroomba = { name = "Vroomba Vroombini", rarity = "Mythic", income = 750, bodyColor = Color3.fromRGB(30, 30, 30), headColor = Color3.fromRGB(0, 230, 255), size = 1.9 },
	glitchio = { name = "Glitchio Supremo", rarity = "Secret", income = 3000, bodyColor = Color3.fromRGB(255, 0, 255), headColor = Color3.fromRGB(0, 255, 120), size = 2.2 },
} :: { [string]: CreatureDef }

export type SeedDef = {
	name: string,
	price: number,
	growTime: number,
	order: number,
	color: Color3,
	pool: { { id: string, weight: number } },
}

Config.Seeds = {
	basic = {
		name = "Basic Seed", price = 50, growTime = 20, order = 1, color = Color3.fromRGB(140, 100, 60),
		pool = { { id = "noodle_shark", weight = 50 }, { id = "toastolini", weight = 35 }, { id = "gloopa", weight = 14 }, { id = "bananini", weight = 1 } },
	},
	sprouty = {
		name = "Sprouty Seed", price = 400, growTime = 45, order = 2, color = Color3.fromRGB(90, 200, 90),
		pool = { { id = "gloopa", weight = 40 }, { id = "bananini", weight = 35 }, { id = "froggo", weight = 22 }, { id = "pigeoni", weight = 3 } },
	},
	spicy = {
		name = "Spicy Seed", price = 2500, growTime = 90, order = 3, color = Color3.fromRGB(230, 60, 40),
		pool = { { id = "froggo", weight = 35 }, { id = "pigeoni", weight = 35 }, { id = "croco", weight = 27 }, { id = "meatballo", weight = 3 } },
	},
	cosmic = {
		name = "Cosmic Seed", price = 15000, growTime = 180, order = 4, color = Color3.fromRGB(110, 60, 220),
		pool = { { id = "croco", weight = 40 }, { id = "meatballo", weight = 35 }, { id = "cactusso", weight = 22 }, { id = "vroomba", weight = 3 } },
	},
	glitched = {
		name = "Glitched Seed", price = 120000, growTime = 300, order = 5, color = Color3.fromRGB(0, 255, 160),
		pool = { { id = "cactusso", weight = 45 }, { id = "vroomba", weight = 45 }, { id = "glitchio", weight = 10 } },
	},
} :: { [string]: SeedDef }

-- Checked rarest first; chance is per harvest (0-1).
Config.Mutations = {
	{ id = "Rainbow", name = "Rainbow", multiplier = 10, chance = 0.01 },
	{ id = "Golden", name = "Golden", multiplier = 3, chance = 0.06 },
}

function Config.getMutation(id: string?): { id: string, name: string, multiplier: number, chance: number }?
	if not id then
		return nil
	end
	for _, m in Config.Mutations do
		if m.id == id then
			return m
		end
	end
	return nil
end

function Config.creatureIncome(creatureId: string, mutationId: string?): number
	local def = Config.Creatures[creatureId]
	if not def then
		return 0
	end
	local mutation = Config.getMutation(mutationId)
	return def.income * (if mutation then mutation.multiplier else 1)
end

function Config.sortedSeedIds(): { string }
	local ids = {}
	for id in Config.Seeds do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Seeds[a].order < Config.Seeds[b].order
	end)
	return ids
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Config.formatNumber(n: number): string
	n = math.floor(n)
	local i = 1
	local value = n
	while math.abs(value) >= 1000 and i < #SUFFIXES do
		value /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", value, SUFFIXES[i])
end

return Config
