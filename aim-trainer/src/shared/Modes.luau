-- Modes: every training mode, its tuning, and how it is scored.
--
-- Shared by the client (to run the round) and the server (to validate a
-- submitted result before it touches a personal best or the leaderboard).
--
-- Location: ReplicatedStorage > Shared > Modes (ModuleScript)

local Modes = {}

export type Mode = {
	id: string, -- unique per mode and difficulty, e.g. "Flick_Hard"
	base: string, -- the mode without difficulty, e.g. "Flick"
	difficulty: string, -- "Easy" | "Medium" | "Hard"
	name: string,
	fullName: string, -- e.g. "FLICK  ·  HARD"
	tagline: string,
	description: string,
	kind: "grid" | "random" | "track",
	duration: number, -- seconds of play (after the countdown)
	radius: number, -- target radius in studs
	targets: number, -- targets on screen at once (click modes)
	area: Vector2, -- width/height of the target area in studs
	grid: number?, -- grid modes: cells per side
	speed: number?, -- tracking: strafe speed in studs/s
	maxHitsPerSecond: number, -- anything faster is rejected by the server
	color: Color3,
}

-- Targets sit on a plane this far in front of the player's eyes.
Modes.TargetDistance = 50
-- Size of the target wall in studs. It is centred on the player's eyes, and
-- no target is ever placed past its edges.
Modes.WallSize = Vector2.new(64, 36)
Modes.Countdown = 3

-- The four modes, in menu order (each comes in three difficulties).
Modes.order = { "Gridshot", "Flick", "Microshot", "Tracking" }

local base = {
	Gridshot = {
		name = "GRIDSHOT",
		tagline = "Speed",
		description = "Three targets on a grid. Clear them as fast as you can.",
		kind = "grid",
		duration = 60,
		radius = 1.5,
		targets = 3,
		grid = 5,
		area = Vector2.new(24, 24),
		maxHitsPerSecond = 9,
		color = Color3.fromRGB(0, 220, 255),
	},
	Flick = {
		name = "FLICK",
		tagline = "Reaction",
		description = "One target anywhere on the wall. Snap to it.",
		kind = "random",
		duration = 60,
		radius = 1.3,
		targets = 1,
		area = Vector2.new(46, 22),
		maxHitsPerSecond = 6,
		color = Color3.fromRGB(255, 170, 40),
	},
	Microshot = {
		name = "MICROSHOT",
		tagline = "Precision",
		description = "Tiny targets close together. Small, careful adjustments.",
		kind = "random",
		duration = 60,
		radius = 0.55,
		targets = 1,
		area = Vector2.new(14, 8),
		maxHitsPerSecond = 6,
		color = Color3.fromRGB(190, 110, 255),
	},
	Tracking = {
		name = "TRACKING",
		tagline = "Smoothness",
		description = "Keep your crosshair on a strafing target. No clicking.",
		kind = "track",
		duration = 45,
		radius = 1.4,
		targets = 1,
		area = Vector2.new(36, 10),
		speed = 15,
		maxHitsPerSecond = 0,
		color = Color3.fromRGB(80, 255, 140),
	},
}

-- Easy / Medium / Hard. Each difficulty only changes the numbers listed;
-- everything else comes from the mode above (Medium is the mode as written).
Modes.difficulties = { "Easy", "Medium", "Hard" }
Modes.DifficultyColor = {
	Easy = Color3.fromRGB(80, 230, 120),
	Medium = Color3.fromRGB(255, 200, 40),
	Hard = Color3.fromRGB(255, 70, 70),
}

local tuning: { [string]: { [string]: { [string]: any } } } = {
	Gridshot = {
		Easy = { radius = 1.9, grid = 4, area = Vector2.new(18, 18), maxHitsPerSecond = 10 },
		Medium = {},
		Hard = { radius = 1.1, grid = 6, area = Vector2.new(30, 26) },
	},
	Flick = {
		Easy = { radius = 1.8, area = Vector2.new(32, 16) },
		Medium = {},
		Hard = { radius = 0.9, area = Vector2.new(56, 28) },
	},
	Microshot = {
		Easy = { radius = 0.8, area = Vector2.new(12, 7) },
		Medium = {},
		Hard = { radius = 0.4, area = Vector2.new(18, 10) },
	},
	Tracking = {
		Easy = { radius = 1.9, speed = 10, area = Vector2.new(30, 8) },
		Medium = {},
		Hard = { radius = 1.0, speed = 21, area = Vector2.new(44, 14) },
	},
}

-- Id of a mode at a difficulty: "Flick_Easy", "Flick", "Flick_Hard". Medium
-- keeps the plain name so scores saved before difficulties existed still count.
function Modes.id(baseId: string, difficulty: string): string
	return if difficulty == "Medium" then baseId else baseId .. "_" .. difficulty
end

-- Every playable mode, keyed by id (12 in all: 4 modes x 3 difficulties).
Modes.list = {} :: { [string]: Mode }
for baseId, def in base do
	for _, difficulty in Modes.difficulties do
		local mode = table.clone(def) :: any
		for key, value in tuning[baseId][difficulty] do
			mode[key] = value
		end
		mode.id = Modes.id(baseId, difficulty)
		mode.base = baseId
		mode.difficulty = difficulty
		mode.fullName = def.name .. "  ·  " .. difficulty:upper()
		Modes.list[mode.id] = mode :: Mode
	end
end

export type Stats = {
	hits: number,
	shots: number,
	trackTime: number, -- seconds on target (tracking only)
	bestCombo: number,
	avgReaction: number, -- ms between a target appearing and being hit
}

function Modes.accuracy(mode: Mode, stats: Stats): number
	if mode.kind == "track" then
		return math.clamp(stats.trackTime / mode.duration, 0, 1)
	end
	if stats.shots <= 0 then
		return 0
	end
	return math.clamp(stats.hits / stats.shots, 0, 1)
end

-- Click modes: 100 per hit, scaled by accuracy so spamming doesn't pay.
-- Tracking: percentage of time on target, out of 10,000.
function Modes.score(mode: Mode, stats: Stats): number
	local accuracy = Modes.accuracy(mode, stats)
	if mode.kind == "track" then
		return math.floor(accuracy * 10000 + 0.5)
	end
	return math.floor(stats.hits * 100 * accuracy + 0.5)
end

-- Server-side sanity check of a submitted result. Returns an error string
-- if the numbers are impossible for a human in this mode.
function Modes.validate(mode: Mode, stats: any): string?
	if type(stats) ~= "table" then
		return "bad stats"
	end
	for _, key in { "hits", "shots", "trackTime", "bestCombo", "avgReaction" } do
		local v = stats[key]
		if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then
			return "bad " .. key
		end
	end
	if mode.kind == "track" then
		if stats.trackTime > mode.duration + 0.5 then
			return "track time too long"
		end
	else
		if stats.hits > stats.shots then
			return "more hits than shots"
		end
		if stats.hits > mode.duration * mode.maxHitsPerSecond then
			return "too many hits"
		end
		if stats.bestCombo > stats.hits then
			return "combo larger than hits"
		end
		if stats.hits > 0 and stats.avgReaction < 80 then
			return "inhuman reaction time"
		end
	end
	return nil
end

-- Default per-player settings; the server validates saves against these.
-- Crosshair sizes are in design pixels (the HUD scales with the screen).
Modes.DefaultSettings = {
	sensitivity = 0.15, -- degrees per mouse pixel
	fov = 75,
	volume = 0.7,

	-- Crosshair
	chR = 0, -- colour, 0-255 per channel
	chG = 255,
	chB = 140,
	chLength = 7, -- length of each line
	chThickness = 2,
	chGap = 4, -- space between the centre and each line
	chRotation = 0, -- degrees; 45 turns a + into an x
	chDotSize = 3,
	chHorizontal = true, -- show the left/right lines
	chVertical = true, -- show the top/bottom lines
	chDot = false, -- centre dot
	chOutline = true, -- thin black outline for visibility
}

-- Number settings and their allowed ranges.
Modes.SettingLimits = {
	sensitivity = { 0.02, 0.6 },
	fov = { 60, 100 },
	volume = { 0, 1 },
	chR = { 0, 255 },
	chG = { 0, 255 },
	chB = { 0, 255 },
	chLength = { 1, 24 },
	chThickness = { 1, 8 },
	chGap = { 0, 24 },
	chRotation = { 0, 90 },
	chDotSize = { 1, 10 },
}

-- On/off settings.
Modes.SettingToggles = { "chHorizontal", "chVertical", "chDot", "chOutline" }

-- Quick-pick colours in the settings panel.
Modes.CrosshairPresets = {
	Color3.fromRGB(0, 255, 140),
	Color3.fromRGB(0, 220, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 60, 200),
	Color3.fromRGB(255, 230, 0),
	Color3.fromRGB(255, 70, 70),
}

return Modes
