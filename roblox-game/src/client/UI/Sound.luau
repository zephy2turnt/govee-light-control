-- Sound: plays UI sound effects and background music through two
-- SoundGroups ("Music" and "SFX") so the Settings sliders control each one.
--
-- Location: StarterPlayerScripts > Client > UI > Sound (ModuleScript)

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Theme"))

local Sound = {}

local function makeGroup(name: string): SoundGroup
	local group = SoundService:FindFirstChild(name)
	if group and group:IsA("SoundGroup") then
		return group
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	return g
end

local musicGroup = makeGroup("Music")
local sfxGroup = makeGroup("SFX")

-- One template per effect; each play clones it so rapid clicks can overlap.
local templates: { [string]: Sound } = {}
for name, info in Theme.Sound do
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. info.id
	s.Volume = info.volume
	s.SoundGroup = sfxGroup
	s.Parent = sfxGroup
	templates[name] = s
end

task.spawn(function()
	local list = {}
	for _, s in templates do
		table.insert(list, s)
	end
	ContentProvider:PreloadAsync(list)
end)

-- Plays a UI effect. A small random pitch shift stops repeated clicks from
-- sounding robotic.
function Sound.play(name: string, pitch: number?)
	local template = templates[name]
	if not template then
		warn("[Sound] unknown sound:", name)
		return
	end
	local s = template:Clone()
	s.PlaybackSpeed = (pitch or 1) * (0.96 + math.random() * 0.08)
	s.Parent = sfxGroup
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local currentTrack: Sound? = nil
local currentName: string? = nil

-- Crossfades to a named track from Theme.Music (or silence with nil).
function Sound.playMusic(name: string?, fadeTime: number?)
	if name == currentName then
		return
	end
	local fade = TweenInfo.new(fadeTime or 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local old = currentTrack
	if old then
		local t = TweenService:Create(old, fade, { Volume = 0 })
		t:Play()
		t.Completed:Once(function()
			old:Destroy()
		end)
	end
	currentTrack, currentName = nil, name
	if not name then
		return
	end
	local info = Theme.Music[name]
	if not info then
		warn("[Sound] unknown music track:", name)
		return
	end
	local track = Instance.new("Sound")
	track.Name = "Music_" .. name
	track.SoundId = "rbxassetid://" .. info.id
	track.Looped = true
	track.Volume = 0
	track.SoundGroup = musicGroup
	track.Parent = musicGroup
	track:Play()
	TweenService:Create(track, fade, { Volume = info.volume }):Play()
	currentTrack = track
end

-- 0..1 volume per channel, called by the Settings screen.
function Sound.setVolumes(music: number, sfx: number)
	musicGroup.Volume = math.clamp(music, 0, 1)
	sfxGroup.Volume = math.clamp(sfx, 0, 1)
end

return Sound
