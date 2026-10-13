-- Loads and saves player data. If the DataStore can't be reached (e.g. Studio
-- without API access), the player still gets a fresh profile but it won't be
-- saved, so a failed load can never overwrite real progress.

local DataStoreService = game:GetService("DataStoreService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DataService = {}

export type CreatureSave = { id: string, mutation: string? }
export type PlantSave = { seed: string, plantedAt: number }
export type Data = {
	cash: number,
	seeds: { [string]: number },
	-- Keyed by tostring(index): DataStores can't store sparse number-keyed arrays.
	plants: { [string]: PlantSave },
	creatures: { [string]: CreatureSave },
}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not save:", result)
	end
end

local function defaultData(): Data
	return {
		cash = Config.StartingCash,
		seeds = table.clone(Config.StartingSeeds),
		plants = {},
		creatures = {},
	}
end

-- Drops anything that no longer exists in Config (renamed seeds, etc).
local function sanitize(raw: any): Data
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.cash) == "number" then
		data.cash = raw.cash
	end
	if type(raw.seeds) == "table" then
		data.seeds = {}
		for id, count in raw.seeds do
			if Config.Seeds[id] and type(count) == "number" and count > 0 then
				data.seeds[id] = math.floor(count)
			end
		end
	end
	if type(raw.plants) == "table" then
		for key, plant in raw.plants do
			local i = tonumber(key)
			if i and i >= 1 and i <= Config.TilesPerPlot and type(plant) == "table" and Config.Seeds[plant.seed] then
				data.plants[tostring(i)] = { seed = plant.seed, plantedAt = tonumber(plant.plantedAt) or os.time() }
			end
		end
	end
	if type(raw.creatures) == "table" then
		for key, c in raw.creatures do
			local i = tonumber(key)
			if i and i >= 1 and i <= Config.PedestalsPerPlot and type(c) == "table" and Config.Creatures[c.id] then
				data.creatures[tostring(i)] = { id = c.id, mutation = if Config.getMutation(c.mutation) then c.mutation else nil }
			end
		end
	end
	return data
end

local function key(userId: number): string
	return "p_" .. userId
end

-- Returns the data and whether it is safe to save back later.
function DataService.load(userId: number): (Data, boolean)
	if not store then
		return defaultData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(key(userId))
		end)
		if ok then
			return sanitize(result), true
		end
		warn(string.format("[DataService] load attempt %d failed for %d: %s", attempt, userId, tostring(result)))
		local message = tostring(result)
		if message:find("403") or message:find("Studio") or message:find("publish") then
			break -- API access is off; retrying won't help
		end
		task.wait(attempt)
	end
	return defaultData(), false
end

function DataService.save(userId: number, data: Data): boolean
	if not store then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync(key(userId), data, { userId })
		end)
		if ok then
			return true
		end
		warn(string.format("[DataService] save attempt %d failed for %d: %s", attempt, userId, tostring(err)))
		task.wait(attempt)
	end
	return false
end

return DataService
