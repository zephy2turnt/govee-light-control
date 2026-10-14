-- Sounds: every audio asset the game uses. All are free Creator Store
-- assets from Roblox's licensed partner libraries (ProSoundEffects, APM,
-- DistroKid), so they are public and safe to use in any experience.
--
-- Location: ReplicatedStorage > Shared > Sounds (ModuleScript)

export type SoundInfo = { id: number, volume: number, looped: boolean? }

local Sounds: { [string]: SoundInfo } = {
	-- Grapple
	Fire = { id = 9126229255, volume = 0.55 }, -- Whoosh By Fast Airy Swooshing
	Attach = { id = 9118717475, volume = 0.6 }, -- Rope Impacts 4
	Clank = { id = 9116673678, volume = 0.35 }, -- Metal Impact Heavy Clunking
	Release = { id = 9120972321, volume = 0.45 }, -- Wood Whoosh Quick Swings 4
	Snap = { id = 9118718610, volume = 0.5 }, -- Rope Slide 4
	Empty = { id = 17208353912, volume = 0.4 }, -- Roblox GUI - Negative

	-- Movement
	Wind = { id = 9125742262, volume = 0, looped = true }, -- Plasma Trails Airy Whooshing (loop)
	Land = { id = 9113480915, volume = 0.6 }, -- Body Fall Thud 2

	-- Anchors
	Crack = { id = 9118689425, volume = 0.7 }, -- Rocks Knock Against Each Other 3
	Shatter = { id = 9125869504, volume = 0.9 }, -- Rock Cracks Impact Debris

	-- Fog and danger
	Heartbeat = { id = 9043365727, volume = 0, looped = true }, -- HEARTBEAT 01 96BPM
	Drone = { id = 9043359885, volume = 0.35, looped = true }, -- DARK DRONE 13
	Drums = { id = 138261575271157, volume = 0, looped = true }, -- March of Fire (drums)
	Consumed = { id = 9120769331, volume = 0.8 }, -- Wind Whoosh Sonic Boom Impact

	-- Round flow
	Tick = { id = 17208408337, volume = 0.5 }, -- Roblox GUI - Tab
	Go = { id = 15675043410, volume = 0.7 }, -- Roblox_UI_Tonal_Stinger
	Escape = { id = 1837829481, volume = 0.6 }, -- HIT-Metallic Ring Hit 10
	Chime = { id = 9116395089, volume = 0.6 }, -- Magic Glows Chiming Hits 4
}

return Sounds
