-- Graphics: applies the Low / Medium / High quality setting on this client.
--
-- Changes here are local to the player's machine. Post-processing effects
-- that exist now or are added later (Bloom, SunRays, DepthOfField) are
-- switched on or off by class, and other systems can call
-- Graphics.particleMultiplier() to scale their particle emission.
--
-- Location: StarterPlayerScripts > Client > Systems > Graphics (ModuleScript)

local Lighting = game:GetService("Lighting")

local Graphics = {}

type Profile = {
	shadows: boolean,
	bloom: boolean,
	sunRays: boolean,
	depthOfField: boolean,
	particles: number,
}

local PROFILES: { [string]: Profile } = {
	Low = { shadows = false, bloom = false, sunRays = false, depthOfField = false, particles = 0.35 },
	Medium = { shadows = true, bloom = true, sunRays = false, depthOfField = false, particles = 0.7 },
	High = { shadows = true, bloom = true, sunRays = true, depthOfField = true, particles = 1 },
}

local current = "High"
local listeners: { (string) -> () } = {}

local function applyToEffect(effect: Instance, profile: Profile)
	-- The menu blur is a UI effect, not a graphics option.
	if effect.Name == "MenuBlur" then
		return
	end
	if effect:IsA("BloomEffect") then
		effect.Enabled = profile.bloom
	elseif effect:IsA("SunRaysEffect") then
		effect.Enabled = profile.sunRays
	elseif effect:IsA("DepthOfFieldEffect") then
		effect.Enabled = profile.depthOfField
	end
end

function Graphics.apply(quality: string)
	local profile = PROFILES[quality]
	if not profile then
		return
	end
	current = quality
	Lighting.GlobalShadows = profile.shadows
	for _, child in Lighting:GetChildren() do
		applyToEffect(child, profile)
	end
	for _, fn in listeners do
		task.spawn(fn, quality)
	end
end

function Graphics.current(): string
	return current
end

function Graphics.particleMultiplier(): number
	return PROFILES[current].particles
end

function Graphics.onChanged(fn: (string) -> ())
	table.insert(listeners, fn)
end

-- Effects added later (e.g. by the server's lighting setup) follow the
-- current setting automatically.
Lighting.ChildAdded:Connect(function(child)
	applyToEffect(child, PROFILES[current])
end)

return Graphics
