-- Audio: plays the sounds listed in Shared.Sounds through one SoundGroup,
-- whose volume the Settings screen controls.
--
-- Location: StarterPlayerScripts > Client > Audio (ModuleScript)

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Sounds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sounds"))

local Audio = {}

local group = Instance.new("SoundGroup")
group.Name = "AimRange"
group.Parent = SoundService

local templates: { [string]: Sound } = {}
for name, info in Sounds do
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. info.id
	s.Volume = info.volume
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

-- pitch: exact playback speed; jitter adds a little randomness (default on).
function Audio.play(name: string, pitch: number?, jitter: boolean?)
	local template = templates[name]
	if not template then
		return
	end
	local s = template:Clone()
	local variation = if jitter == false then 1 else 0.97 + math.random() * 0.06
	s.PlaybackSpeed = (pitch or 1) * variation
	s.Parent = group
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Audio.setVolume(v: number)
	group.Volume = math.clamp(v, 0, 1)
end

return Audio
