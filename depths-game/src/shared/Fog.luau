-- Fog: the single formula for the fog's height.
--
-- The server only publishes the round state and when it started (as
-- Workspace attributes). Both sides compute the height from that, so the
-- client can animate the fog smoothly every frame and the server can kill
-- players with exactly the same numbers, without streaming positions.
--
-- Location: ReplicatedStorage > Shared > Fog (ModuleScript)

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local Fog = {}

-- Round states, published in Workspace.RoundState.
Fog.Intermission = "Intermission"
Fog.Climbing = "Climbing"
Fog.Draining = "Draining"

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- Fog height while climbing, t seconds after the climb started.
function Fog.climbHeight(t: number): number
	local f = Config.Fog
	local rising = math.max(0, t - f.Grace)
	return f.MinY + f.Rate * rising + 0.5 * f.Accel * rising * rising
end

-- Fog height right now, from the published round state.
function Fog.height(now: number?): number
	local t = (now or Workspace:GetServerTimeNow()) - (Workspace:GetAttribute("StateStart") or 0)
	local state = Workspace:GetAttribute("RoundState")
	local cap = Config.Tower.Height + 6
	if state == Fog.Climbing then
		return math.min(Fog.climbHeight(t), cap)
	elseif state == Fog.Draining then
		local from = Workspace:GetAttribute("DrainFrom") or Config.Fog.MinY
		local k = smooth(math.clamp(t / Config.Fog.DrainTime, 0, 1))
		return from + (Config.Fog.MinY - from) * k
	end
	return Config.Fog.MinY
end

-- Seconds since the current state began.
function Fog.elapsed(now: number?): number
	return (now or Workspace:GetServerTimeNow()) - (Workspace:GetAttribute("StateStart") or 0)
end

return Fog
