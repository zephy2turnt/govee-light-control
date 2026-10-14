-- Config: every gameplay number in one place, so the feel can be tuned
-- without touching logic. Distances are in studs, times in seconds.
--
-- Location: ReplicatedStorage > Shared > Config (ModuleScript)

local Config = {}

-- The climb ------------------------------------------------------------------

Config.Tower = {
	Height = 330, -- floor (y = 0) to the escape gate
	Radius = 100, -- inner radius of the chasm
}

-- Grapple ---------------------------------------------------------------------
-- The grapple is a "zip and fling": the rope yanks you toward the anchor,
-- accelerating the whole way. Let go early and you keep all that speed.

Config.Grapple = {
	Range = 140, -- max distance to an anchor
	AimCone = 20, -- degrees around the cursor that aim assist searches (mouse)
	TouchAimCone = 32, -- wider for touch/gamepad, which aim with the screen centre
	Charges = 3, -- hooks you can fire before you must touch the ground
	ShootSpeed = 650, -- how fast the rope flies out to the anchor

	PullAccel = 270, -- acceleration toward the anchor while reeling in
	GravityAssist = 0.85, -- fraction of gravity cancelled while pulling
	SideDamping = 2.2, -- how quickly sideways drift is bled off while pulling
	MaxSpeed = 175, -- hard speed cap while pulling
	StartKick = 45, -- instant speed toward the anchor when the hook lands

	ArriveDistance = 7, -- auto-release this close to the anchor
	ArrivePop = 34, -- upward pop on arrival, to clear the ledge
	ReleaseBoost = 12, -- extra speed along your direction when you let go
	ReleaseLift = 16, -- extra upward speed when you let go

	AirSteer = 55, -- sideways control while flying
	AirDrag = 0.35, -- how fast carried momentum fades in the air (per second)
	StuckTime = 0.45, -- release if you stop getting closer for this long
}

-- Anchors ---------------------------------------------------------------------

Config.Anchor = {
	CrumbleTime = 1.5, -- gargoyles hold for this long after being hooked
	RespawnTime = 12, -- broken gargoyles rebuild after this long
}

-- Rising fog ------------------------------------------------------------------
-- height(t) = MinY + Rate * t + 0.5 * Accel * t^2, after a grace period.
-- With these numbers the fog reaches the top in about 2.5 minutes.

Config.Fog = {
	MinY = -12,
	Grace = 8, -- seconds before the fog starts rising
	Rate = 1.2, -- starting rise speed
	Accel = 0.012, -- rise speed gained per second
	DrainTime = 4, -- fog sinks back down between climbs
	Intermission = 6, -- countdown before each climb
	DangerRange = 45, -- danger effects start within this distance above the fog
}

-- Speed effects -------------------------------------------------------------------

Config.SpeedFX = {
	BaseFOV = 70,
	MaxFOV = 94,
	Start = 45, -- speed at which wind lines and FOV kick begin
	Full = 150, -- speed at which they are at full strength
}

return Config
