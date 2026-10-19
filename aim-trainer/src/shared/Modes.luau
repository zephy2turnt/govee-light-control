-- Modes: every training mode, its tuning, and how it is scored.
--
-- Shared by the client (to run the round) and the server (to validate a
-- submitted result before it touches a personal best or the leaderboard).
--
-- Location: ReplicatedStorage > Shared > Modes (ModuleScript)

local Modes = {}

export type Mode = {
	id: string,
	name: string,
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
Modes.Countdown = 3

Modes.order = { "Gridshot", "Flick", "Microshot", "Tracking" }

Modes.list = {
	Gridshot = {
		id = "Gridshot",
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
		id = "Flick",
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
		id = "Microshot",
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
		id = "Tracking",
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
} :: { [string]: Mode }

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
