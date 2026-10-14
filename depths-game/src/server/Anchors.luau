-- Anchors: the things you can grapple to.
--
--   Anchors.ring(cf, parent)      iron bracket with a soul-fire orb (solid)
--   Anchors.post(cf, parent)      stone post topped with an orb (solid)
--   Anchors.gargoyle(cf, parent)  gargoyle holding an orb; crumbles 1.5s
--                                 after being hooked, rebuilds later
--
-- Every grapple target is a glowing orb Part tagged "GrappleAnchor". The
-- server is the only one that decides when a gargoyle breaks, so it breaks
-- at the same moment for everyone.
--
-- Location: ServerScriptService > Server > Anchors (ModuleScript)

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)

local Anchors = {}

Anchors.TAG = "GrappleAnchor"
Anchors.SOUL_GREEN = Color3.fromRGB(70, 255, 150)

-- Set by the server: called when a gargoyle's orb shatters, so anyone
-- hooked to it can be released.
Anchors.onBroken = nil :: ((orb: BasePart) -> ())?

local STONE = Color3.fromRGB(68, 70, 76)
local IRON = Color3.fromRGB(40, 40, 46)
local rng = Random.new()

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function wedge(props: { [string]: any }): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function playAt(position: Vector3, soundName: string)
	local info = Sounds[soundName]
	local holder = part({
		Name = "SoundHolder",
		Size = Vector3.one,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Position = position,
		Parent = Workspace,
	})
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. info.id
	s.Volume = info.volume
	s.RollOffMaxDistance = 220
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 6)
end

-- The glowing orb players actually hook onto.
local function orb(cf: CFrame, size: number, parent: Instance): Part
	local o = part({
		Name = "Anchor",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = cf,
		Color = Anchors.SOUL_GREEN,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Anchors.SOUL_GREEN
	light.Range = 14
	light.Brightness = 2.2
	light.Shadows = false
	light.Parent = o
	CollectionService:AddTag(o, Anchors.TAG)
	return o
end

-- Iron bracket sticking out of a wall. `cf` is the orb's position, with its
-- LookVector pointing away from the wall (into the chasm).
function Anchors.ring(cf: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "SoulRing"
	part({
		Name = "Bracket",
		Size = Vector3.new(0.7, 0.7, 4.5),
		CFrame = cf * CFrame.new(0, 0, 2.6),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	for k = 0, 7 do
		local angle = k / 8 * math.pi * 2
		part({
			Name = "Ring",
			Size = Vector3.new(0.9, 0.45, 0.45),
			CFrame = cf * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.7, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = model,
		})
	end
	local o = orb(cf, 1.7, model)
	o:SetAttribute("Kind", "Ring")
	model.PrimaryPart = o
	model.Parent = parent
	return model
end

-- Stone post standing on a ledge. `cf` is the post's base on the ground.
function Anchors.post(cf: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "SoulPost"
	part({
		Name = "Post",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 1.6, 1.6),
		CFrame = cf * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	part({
		Name = "Cup",
		Size = Vector3.new(2.4, 0.6, 2.4),
		CFrame = cf * CFrame.new(0, 5.2, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local o = orb(cf * CFrame.new(0, 6.6, 0), 1.9, model)
	o:SetAttribute("Kind", "Post")
	model.PrimaryPart = o
	model.Parent = parent
	return model
end

-- Gargoyle perched on a ledge, clutching an orb. `cf` is its base on the
-- ground, looking outward. Breakable.
function Anchors.gargoyle(cf: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Gargoyle"
	model:SetAttribute("BuildCFrame", cf)

	local stone = { Color = STONE, Material = Enum.Material.Slate }
	local function stonePart(props: { [string]: any }): Part
		for k, v in stone do
			props[k] = props[k] or v
		end
		props.Parent = model
		return part(props)
	end

	stonePart({ Name = "Pedestal", Size = Vector3.new(3.4, 1.2, 3.4), CFrame = cf * CFrame.new(0, 0.6, 0) })
	stonePart({
		Name = "Body",
		Size = Vector3.new(2.2, 2.8, 1.9),
		CFrame = cf * CFrame.new(0, 2.6, 0.1) * CFrame.Angles(math.rad(-14), 0, 0),
	})
	stonePart({ Name = "Head", Size = Vector3.new(1.7, 1.4, 1.7), CFrame = cf * CFrame.new(0, 4.5, -0.55) })
	stonePart({ Name = "Snout", Size = Vector3.new(1.1, 0.7, 0.9), CFrame = cf * CFrame.new(0, 4.25, -1.6) })
	for _, side in { -1, 1 } do
		local hornCF = cf * CFrame.new(0.55 * side, 5.45, -0.3) * CFrame.Angles(math.rad(-25), 0, math.rad(-15 * side))
		local horn = wedge({ Name = "Horn", Size = Vector3.new(0.3, 0.9, 0.5), CFrame = hornCF, Parent = model })
		horn.Color, horn.Material = STONE, Enum.Material.Slate
		local wingCF = cf * CFrame.new(1.5 * side, 3.6, 0.7) * CFrame.Angles(math.rad(-10), math.rad(35 * side), math.rad(-25 * side))
		local wing = wedge({ Name = "Wing", Size = Vector3.new(0.35, 3.2, 2.8), CFrame = wingCF, Parent = model })
		wing.Color, wing.Material = STONE:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate
		part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.32,
			CFrame = cf * CFrame.new(0.38 * side, 4.65, -1.42),
			Color = Anchors.SOUL_GREEN,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end

	local o = orb(cf * CFrame.new(0, 2.7, -1.9), 1.6, model)
	o:SetAttribute("Kind", "Gargoyle")
	o:SetAttribute("Breakable", true)
	model.PrimaryPart = o
	model.Parent = parent
	return model
end

-- Starts the crumble countdown on a gargoyle's orb (no-op for solid anchors
-- or one that is already crumbling).
function Anchors.crumble(o: BasePart)
	if not o:GetAttribute("Breakable") or o:GetAttribute("Crumbling") or o:GetAttribute("Broken") then
		return
	end
	local model = o.Parent
	if not (model and model:IsA("Model")) then
		return
	end
	o:SetAttribute("Crumbling", true)
	local base = model:GetPivot()
	local buildCF = model:GetAttribute("BuildCFrame")
	local parent = model.Parent
	playAt(o.Position, "Crack")

	task.spawn(function()
		local start = os.clock()
		local duration = Config.Anchor.CrumbleTime
		local hot = Color3.fromRGB(255, 90, 40)
		-- Shake harder and glow redder as it's about to go.
		while os.clock() - start < duration do
			local k = (os.clock() - start) / duration
			local a = 0.02 + 0.06 * k
			model:PivotTo(base * CFrame.Angles(rng:NextNumber(-a, a), rng:NextNumber(-a, a), rng:NextNumber(-a, a)))
			o.Color = Anchors.SOUL_GREEN:Lerp(hot, k)
			task.wait(0.05)
		end

		o:SetAttribute("Broken", true)
		CollectionService:RemoveTag(o, Anchors.TAG)
		if Anchors.onBroken then
			Anchors.onBroken(o)
		end
		playAt(o.Position, "Shatter")

		-- Every piece breaks loose and tumbles down the chasm.
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = false
				piece.CanCollide = true
				piece.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(4, 16), rng:NextNumber(-14, 14))
				piece.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
			end
		end
		local light = o:FindFirstChildOfClass("PointLight")
		if light then
			light:Destroy()
		end
		Debris:AddItem(model, 5)

		if typeof(buildCF) == "CFrame" and parent then
			task.delay(Config.Anchor.RespawnTime, function()
				Anchors.gargoyle(buildCF, parent)
			end)
		end
	end)
end

return Anchors
