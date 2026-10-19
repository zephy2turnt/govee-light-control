-- Audio: plays the sounds listed in Shared.Sounds.
--
--   Audio.play(name, pitch?, volumeScale?)   one-shot (overlapping is fine)
--   Audio.loop(name)                         returns a looping Sound you
--                                            drive yourself (Volume/Pitch)
--
-- Location: StarterPlayerScripts > Client > Audio (ModuleScript)

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Sounds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sounds"))

local Audio = {}

local group = Instance.new("SoundGroup")
group.Name = "Game"
group.Parent = SoundService

local templates: { [string]: Sound } = {}
for name, info in Sounds do
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. info.id
	s.Volume = info.volume
	s.Looped = info.looped == true
	s.SoundGroup = group
	templates[name] = s
end

task.spawn(function()
	local list = {}
	for _, s in templates do
		table.insert(list, s)
	end
	ContentProvider:PreloadAsync(list)
end)

function Audio.play(name: string, pitch: number?, volumeScale: number?)
	local template = templates[name]
	if not template then
		warn("[Audio] unknown sound:", name)
		return
	end
	local s = template:Clone()
	s.PlaybackSpeed = (pitch or 1) * (0.95 + math.random() * 0.1)
	s.Volume = template.Volume * (volumeScale or 1)
	s.Parent = group
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Audio.loop(name: string): Sound
	local s = templates[name]:Clone()
	s.Looped = true
	s.Parent = group
	s:Play()
	return s
end

return Audio
