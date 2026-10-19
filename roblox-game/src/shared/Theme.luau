-- Theme: the single source of truth for how the game looks and sounds.
-- Every screen pulls colours, fonts, radii, tween styles and sound IDs from
-- here, so changing a value restyles the whole game consistently.
--
-- Location: ReplicatedStorage > Shared > Theme (ModuleScript)

local Theme = {}

Theme.GameTitle = "GROW A BRAINROT"
Theme.Tagline = "GROW  •  COLLECT  •  STEAL"
Theme.Version = "v0.2 Early Access"

-- Palette ---------------------------------------------------------------------
-- Dark navy surfaces make bright buttons and rarity colours pop, and keep
-- the HUD readable on top of a sunny, saturated world.
Theme.Color = {
	Background = Color3.fromRGB(16, 19, 30),
	Surface = Color3.fromRGB(28, 33, 50),
	SurfaceRaised = Color3.fromRGB(40, 47, 70),
	SurfaceSunken = Color3.fromRGB(20, 24, 37),
	Outline = Color3.fromRGB(8, 10, 17),

	Primary = Color3.fromRGB(70, 200, 95), -- leaf green: main actions (Play, Buy)
	Secondary = Color3.fromRGB(64, 150, 255), -- sky blue: navigation
	Accent = Color3.fromRGB(255, 196, 46), -- gold: currency, highlights
	Neutral = Color3.fromRGB(88, 98, 128), -- quiet buttons (Back, Cancel)

	Success = Color3.fromRGB(80, 220, 110),
	Error = Color3.fromRGB(255, 82, 82),
	Warning = Color3.fromRGB(255, 160, 40),

	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(165, 176, 205),
	TextOnLight = Color3.fromRGB(20, 24, 36),
}

-- Rarity colours, used for item cards, borders, glows and chat callouts.
-- `glow` marks rarities that get an animated shine.
Theme.Rarity = {
	Common = { color = Color3.fromRGB(170, 176, 190), order = 1, glow = false },
	Rare = { color = Color3.fromRGB(64, 150, 255), order = 2, glow = false },
	Epic = { color = Color3.fromRGB(168, 85, 247), order = 3, glow = true },
	Legendary = { color = Color3.fromRGB(255, 196, 46), order = 4, glow = true },
	Mythic = { color = Color3.fromRGB(255, 64, 88), order = 5, glow = true },
	Secret = { color = Color3.fromRGB(25, 25, 30), order = 6, glow = true },
}

-- Typography --------------------------------------------------------------------
-- One family (Builder Sans) in a few weights keeps every screen consistent.
local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
Theme.Font = {
	Body = Font.new(FAMILY, Enum.FontWeight.Medium),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Heavy = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
	Display = Font.new(FAMILY, Enum.FontWeight.Heavy),
}

-- Sizes are in "design pixels": the whole UI is laid out for a 1280x720
-- reference screen and a UIScale converts that to the real screen.
Theme.TextSize = {
	Caption = 16,
	Body = 20,
	Button = 26,
	Title = 34,
	Hero = 92,
}

-- Shape -------------------------------------------------------------------------
Theme.Radius = {
	Small = UDim.new(0, 8),
	Medium = UDim.new(0, 14),
	Large = UDim.new(0, 22),
	Pill = UDim.new(0.5, 0),
}

Theme.Stroke = {
	Thickness = 3,
	ThicknessThin = 2,
	Color = Theme.Color.Outline,
}

Theme.Spacing = {
	XS = 4,
	S = 8,
	M = 14,
	L = 22,
	XL = 36,
}

-- Minimum height of anything tappable, in design pixels. On phones the
-- UIScale keeps this at roughly 48+ real points, comfortably finger-sized.
Theme.MinTapHeight = 64

-- Motion -------------------------------------------------------------------------
Theme.Tween = {
	Hover = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Press = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Release = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Open = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
	Fade = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slide = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Value = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

Theme.Scale = {
	Hover = 1.05,
	Press = 0.95,
	OpenFrom = 0.82,
}

-- Sound ---------------------------------------------------------------------------
-- All official Roblox-owned assets, so they are public and work in any game.
Theme.Sound = {
	Hover = { id = 10066931761, volume = 0.35 }, -- RBLX UI Hover 01
	Click = { id = 15675059323, volume = 0.6 }, -- Roblox_UI_Bright_Click
	Back = { id = 17208186900, volume = 0.55 }, -- Roblox GUI - Back
	Open = { id = 15675024286, volume = 0.45 }, -- Roblox_UI_Whoosh_01
	Close = { id = 15675028888, volume = 0.4 }, -- Roblox_UI_Whoosh_02
	Tick = { id = 17208408337, volume = 0.4 }, -- Roblox GUI - Tab
	Purchase = { id = 17208380755, volume = 0.6 }, -- Roblox GUI - Purchase
	Notify = { id = 17208361335, volume = 0.5 }, -- Roblox GUI - Notification High
	Error = { id = 17208353912, volume = 0.55 }, -- Roblox GUI - Negative
	Pop = { id = 15675055424, volume = 0.5 }, -- Roblox_UI_Cute_Pop
	Stinger = { id = 15675043410, volume = 0.6 }, -- Roblox_UI_Tonal_Stinger
}

Theme.Music = {
	Menu = { id = 15675069601, volume = 0.5 }, -- Roblox_UI_Loop_Calm_Music
}

-- Player settings defaults (also used by the server to validate saves).
Theme.DefaultSettings = {
	music = 0.5,
	sfx = 0.8,
	quality = "High",
}
Theme.QualityLevels = { "Low", "Medium", "High" }

return Theme
