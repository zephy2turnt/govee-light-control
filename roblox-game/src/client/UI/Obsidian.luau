-- Obsidian: loads the Obsidian UI library for use inside this game.
--
--   local Library = require(script.Parent.Obsidian)   -- from a sibling module
--   local Window = Library:CreateWindow({
--       Title = "Admin",
--       Footer = "v1",
--       ShowCustomCursor = false, -- keep the normal Roblox cursor (defaults to true)
--   })
--
-- What this adds on top of a plain require:
--   * Icons: Obsidian normally downloads its Lucide icons with
--     loadstring/HttpGet, which don't exist in a real game. We bundle the
--     icon module and hand it over with SetIconModule instead.
--   * Styling: the library's colour scheme and font are set from Theme, so
--     Obsidian menus match the rest of the game.
--
-- Obsidian runs on the client only. Anything a menu changes that matters
-- (cash, items, teleports) must go through a RemoteEvent the server checks.
--
-- Location: StarterPlayerScripts > Client > UI > Obsidian (ModuleScript)
-- Library:  ReplicatedStorage > Packages > Obsidian / LucideIcons

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Library = require(Packages:WaitForChild("Obsidian")) :: any

Library:SetIconModule(require(Packages:WaitForChild("LucideIcons")) :: any)

local scheme = Library.Scheme
scheme.BackgroundColor = Theme.Color.Background
scheme.MainColor = Theme.Color.Surface
scheme.AccentColor = Theme.Color.Primary
scheme.OutlineColor = Theme.Color.SurfaceRaised
scheme.FontColor = Theme.Color.Text
scheme.RedColor = Theme.Color.Error
scheme.DestructiveColor = Theme.Color.Error
Library:SetFont(Theme.Font.Body)
Library.CornerRadius = 8
Library:UpdateColorsUsingRegistry()

return Library
