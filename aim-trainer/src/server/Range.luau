-- Range: builds the shooting range from code.
--
-- One private booth per player, side by side. Each booth is a dark tunnel
-- with neon trim, a platform to stand on, and a target wall
-- Modes.TargetDistance studs ahead. Targets themselves are created on each
-- player's own client, so nobody sees anyone else's targets.
--
-- Each booth Model carries an "EyeCFrame" attribute: where the player's
-- camera sits, looking straight at the wall.
--
-- Location: ServerScriptService > Server > Range (ModuleScript)

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Modes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modes"))

local Range = {}

Range.BoothCount = 8
local SPACING = 90
local WALL_W, WALL_H = 64, 36
local EYE_HEIGHT = 5
local DARK = Color3.fromRGB(16, 18, 26)
local PANEL = Color3.fromRGB(24, 27, 38)
local NEON = Color3.fromRGB(0, 200, 255)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(40, 44, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 44, 58)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 24
	bloom.Threshold = 0.95
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast = 0.1
	grade.Saturation = 0.05
	grade.Parent = Lighting
end

local function buildBooth(index: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Booth" .. index
	local origin = CFrame.new((index - 1) * SPACING, 0, 0)
	local d = Modes.TargetDistance
	local wallZ = -(d + 1)

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- Floor of the whole tunnel, and the platform the player stands on.
	part({ Name = "Floor", Size = Vector3.new(WALL_W + 4, 1, d + 16), CFrame = at(0, -0.5, wallZ / 2 + 6), Color = DARK, Parent = model })
	part({
		Name = "Platform",
		Size = Vector3.new(10, 0.4, 10),
		CFrame = at(0, 0.2, 0),
		Color = PANEL,
		Material = Enum.Material.Metal,
		Parent = model,
	})

	-- Target wall with a faint grid so distances read clearly.
	local wallCF = at(0, EYE_HEIGHT, wallZ)
	part({ Name = "TargetWall", Size = Vector3.new(WALL_W, WALL_H, 1), CFrame = wallCF, Color = PANEL, Parent = model })
	for x = -WALL_W / 2 + 4, WALL_W / 2 - 4, 4 do
		part({
			Name = "GridV",
			Size = Vector3.new(0.06, WALL_H, 0.05),
			CFrame = wallCF * CFrame.new(x, 0, 0.53),
			Color = Color3.fromRGB(40, 46, 64),
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
	end
	for y = -WALL_H / 2 + 4, WALL_H / 2 - 4, 4 do
		part({
			Name = "GridH",
			Size = Vector3.new(WALL_W, 0.06, 0.05),
			CFrame = wallCF * CFrame.new(0, y, 0.53),
			Color = Color3.fromRGB(40, 46, 64),
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
	end

	-- Side walls and ceiling make each booth its own tunnel.
	local length = d + 16
	for _, side in { -1, 1 } do
		part({
			Name = "SideWall",
			Size = Vector3.new(1, WALL_H + 6, length),
			CFrame = at(side * (WALL_W / 2 + 1.5), EYE_HEIGHT, wallZ / 2 + 6),
			Color = DARK,
			Parent = model,
		})
		-- Neon trim along the bottom and top edges.
		for _, y in { 0.05, WALL_H + 2 } do
			part({
				Name = "Trim",
				Size = Vector3.new(0.3, 0.3, length),
				CFrame = at(side * (WALL_W / 2 + 0.9), y, wallZ / 2 + 6),
				Color = NEON,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = model,
			})
		end
	end
	part({
		Name = "Ceiling",
		Size = Vector3.new(WALL_W + 4, 1, length),
		CFrame = at(0, EYE_HEIGHT + WALL_H / 2 + 3, wallZ / 2 + 6),
		Color = DARK,
		Parent = model,
	})
	part({
		Name = "BackWall",
		Size = Vector3.new(WALL_W + 4, WALL_H + 6, 1),
		CFrame = at(0, EYE_HEIGHT, 14),
		Color = DARK,
		Parent = model,
	})

	-- Soft light washing over the target wall.
	local lamp = part({
		Name = "WallLight",
		Size = Vector3.new(1, 1, 1),
		CFrame = at(0, EYE_HEIGHT + 8, wallZ + 18),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 110
	light.Range = 40
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(190, 220, 255)
	light.Parent = lamp
	lamp.CFrame = CFrame.lookAt(lamp.Position, wallCF.Position)

	-- Number above the wall so players can tell booths apart.
	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Back
	sign.CanvasSize = Vector2.new(400, 100)
	sign.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BOOTH " .. index
	label.TextColor3 = NEON
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	label.Parent = sign
	local signPart = part({
		Name = "Sign",
		Size = Vector3.new(12, 3, 0.2),
		CFrame = at(0, EYE_HEIGHT + WALL_H / 2 - 1, wallZ + 0.6),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	sign.Parent = signPart

	model:SetAttribute("EyeCFrame", at(0, EYE_HEIGHT, 0))
	model:SetAttribute("StandCFrame", at(0, 3.2, 0))
	model.Parent = parent
	return model
end

function Range.build(): { Model }
	setupLighting()
	local folder = Instance.new("Folder")
	folder.Name = "Range"
	folder.Parent = Workspace
	local booths = {}
	for i = 1, Range.BoothCount do
		booths[i] = buildBooth(i, folder)
	end
	return booths
end

return Range
