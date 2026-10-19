-- Data: player profiles (personal bests + settings) and global leaderboards.
--
-- Profiles live in a DataStore; leaderboards in one OrderedDataStore per
-- mode. If the DataStore can't be reached (Studio without API access), the
-- game still works but nothing is saved, and a failed load never
-- overwrites real data.
--
-- Location: ServerScriptService > Server > Data (ModuleScript)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Modes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modes"))

local Data = {}

local VERSION = "v1"

export type Best = { score: number, accuracy: number, hits: number, at: number }
export type Profile = {
	bests: { [string]: Best },
	settings: { [string]: any },
}

local profileStore: DataStore? = nil
local boards: { [string]: OrderedDataStore } = {}
do
	local ok, err = pcall(function()
		profileStore = DataStoreService:GetDataStore("AimRange_Profiles_" .. VERSION)
		for _, id in Modes.order do
			boards[id] = DataStoreService:GetOrderedDataStore("AimRange_LB_" .. VERSION .. "_" .. id)
		end
	end)
	if not ok then
		warn("[Data] DataStores unavailable, nothing will save:", err)
		profileStore = nil
	end
end

-- Settings ------------------------------------------------------------------------

function Data.sanitizeSettings(raw: any): { [string]: any }
	local out = table.clone(Modes.DefaultSettings)
	if type(raw) ~= "table" then
		return out
	end
	for key, limits in Modes.SettingLimits do
		local v = raw[key]
		if type(v) == "number" and v == v then
			out[key] = math.clamp(v, limits[1], limits[2])
		end
	end
	if type(raw.crosshairStyle) == "string" and table.find(Modes.CrosshairStyles, raw.crosshairStyle) then
		out.crosshairStyle = raw.crosshairStyle
	end
	if type(raw.crosshairColor) == "number" and Modes.CrosshairColors[math.floor(raw.crosshairColor)] then
		out.crosshairColor = math.floor(raw.crosshairColor)
	end
	return out
end

local function sanitizeProfile(raw: any): Profile
	local profile: Profile = { bests = {}, settings = Data.sanitizeSettings(nil) }
	if type(raw) ~= "table" then
		return profile
	end
	if type(raw.bests) == "table" then
		for id, best in raw.bests do
			if Modes.list[id] and type(best) == "table" and type(best.score) == "number" then
				profile.bests[id] = {
					score = best.score,
					accuracy = tonumber(best.accuracy) or 0,
					hits = tonumber(best.hits) or 0,
					at = tonumber(best.at) or 0,
				}
			end
		end
	end
	profile.settings = Data.sanitizeSettings(raw.settings)
	return profile
end

-- Profiles ------------------------------------------------------------------------

local function key(userId: number): string
	return "p_" .. userId
end

-- Returns the profile and whether it is safe to save back later.
function Data.load(userId: number): (Profile, boolean)
	if not profileStore then
		return sanitizeProfile(nil), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (profileStore :: DataStore):GetAsync(key(userId))
		end)
		if ok then
			return sanitizeProfile(result), true
		end
		warn(string.format("[Data] load %d failed (attempt %d): %s", userId, attempt, tostring(result)))
		local message = tostring(result)
		if message:find("403") or message:find("Studio") or message:find("publish") then
			break
		end
		task.wait(attempt)
	end
	return sanitizeProfile(nil), false
end

function Data.save(userId: number, profile: Profile): boolean
	if not profileStore then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(profileStore :: DataStore):SetAsync(key(userId), profile, { userId })
		end)
		if ok then
			return true
		end
		warn(string.format("[Data] save %d failed (attempt %d): %s", userId, attempt, tostring(err)))
		task.wait(attempt)
	end
	return false
end

-- Leaderboards ----------------------------------------------------------------------

export type Entry = { rank: number, userId: number, name: string, score: number }

local CACHE_SECONDS = 60
local cache: { [string]: { at: number, entries: { Entry } } } = {}
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else "Player"
	return names[userId]
end

-- Records a score if it beats the player's leaderboard entry.
function Data.submitScore(modeId: string, userId: number, score: number)
	local board = boards[modeId]
	if not board then
		return
	end
	pcall(function()
		board:UpdateAsync(tostring(userId), function(old)
			if type(old) == "number" and old >= score then
				return nil -- keep the existing, higher score
			end
			return math.floor(score)
		end)
	end)
	cache[modeId] = nil
end

function Data.top(modeId: string): { Entry }
	local cached = cache[modeId]
	if cached and os.clock() - cached.at < CACHE_SECONDS then
		return cached.entries
	end
	local board = boards[modeId]
	local entries: { Entry } = {}
	if board then
		local ok, pages = pcall(function()
			return board:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			for i, row in (pages :: DataStorePages):GetCurrentPage() do
				local userId = tonumber(row.key) or 0
				table.insert(entries, { rank = i, userId = userId, name = nameOf(userId), score = row.value })
			end
		end
	end
	cache[modeId] = { at = os.clock(), entries = entries }
	return entries
end

return Data
