-- Sounds: every audio asset the game uses. All are official Roblox-owned or
-- Roblox licensed-library (ProSoundEffects / APM) assets, so they are
-- public and work in any experience.
--
-- Location: ReplicatedStorage > Shared > Sounds (ModuleScript)

export type SoundInfo = { id: number, volume: number }

local Sounds: { [string]: SoundInfo } = {
	Hit = { id = 15675055424, volume = 0.55 }, -- Roblox_UI_Cute_Pop
	Shot = { id = 15675032796, volume = 0.35 }, -- Roblox_UI_Small_Click
	Miss = { id = 15675032796, volume = 0.25 }, -- same click, pitched down in code
	Tick = { id = 17208408337, volume = 0.5 }, -- Roblox GUI - Tab
	Go = { id = 15675043410, volume = 0.6 }, -- Roblox_UI_Tonal_Stinger
	Finish = { id = 9116395089, volume = 0.6 }, -- Magic Glows Chiming Hits 4
	Best = { id = 1837829481, volume = 0.6 }, -- HIT-Metallic Ring Hit 10
	Hover = { id = 10066931761, volume = 0.3 }, -- RBLX UI Hover 01
	Click = { id = 15675059323, volume = 0.5 }, -- Roblox_UI_Bright_Click
	Open = { id = 15675024286, volume = 0.4 }, -- Roblox_UI_Whoosh_01
	Close = { id = 15675028888, volume = 0.35 }, -- Roblox_UI_Whoosh_02
}

return Sounds
