-- Grapple: the "zip and fling" grappling hook.
--
-- Flow:
--   1. Aim assist picks the best anchor near your cursor (or screen centre
--      on touch/gamepad) and highlights it.
--   2. Hold Grapple: the rope shoots out. When it lands, you're yanked
--      toward the anchor, accelerating the whole way.
--   3. Let go any time: you keep all that speed and fly. Carried momentum
--      fades slowly in the air, so chaining hooks keeps you fast.
--   4. You get Config.Grapple.Charges hooks; touching the ground refills them.
--
-- Physics run here on the client (the player owns their character's
-- physics), so it responds instantly. The server is told which anchor you
-- are on, so everyone sees your rope and gargoyles crumble for everyone.
--
-- Controls: hold Left Mouse / R2 / Q, or the HOOK button on touch screens.
--
-- Location: StarterPlayerScripts > Client > Grapple (ModuleScript)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Audio = require(script.Parent.Audio)
local CameraFX = require(script.Parent.CameraFX)

local GrappleRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Grapple") :: RemoteEvent

local Grapple = {}

local TAG = "GrappleAnchor"
local cfg = Config.Grapple
local player = Players.LocalPlayer
local ROPE_COLOR = Color3.fromRGB(120, 255, 180)

type Hook = {
	anchor: BasePart,
	phase: "shooting" | "pulling",
	shootTime: number,
	shootDuration: number,
	lastDistance: number,
	stuck: number,
	tip: Attachment,
	tipBall: Part,
	beam: Beam,
}

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local hand: Attachment? = nil

local charges = cfg.Charges
local target: BasePart? = nil
local hook: Hook? = nil
local carry: Vector3? = nil -- horizontal momentum kept after a release

local chargeListeners: { (number) -> () } = {}
local emptyListeners: { () -> () } = {}

-- Client-only effects live under the camera so they never replicate.
local localFolder = Instance.new("Folder")
local function ensureLocalFolder()
	localFolder.Name = "GrappleFX"
	localFolder.Parent = Workspace.CurrentCamera
end
ensureLocalFolder()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ensureLocalFolder)

-- Aim-assist visuals ----------------------------------------------------------------

local highlight = Instance.new("Highlight")
highlight.FillColor = ROPE_COLOR
highlight.FillTransparency = 0.55
highlight.OutlineColor = Color3.new(1, 1, 1)
highlight.OutlineTransparency = 0.1
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = localFolder

local reticle = Instance.new("BillboardGui")
reticle.Name = "GrappleReticle"
reticle.Size = UDim2.fromOffset(64, 64)
reticle.AlwaysOnTop = true
reticle.LightInfluence = 0
reticle.Enabled = false
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromScale(0.8, 0.8)
ring.BackgroundTransparency = 1
ring.Parent = reticle
local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(0.5, 0)
ringCorner.Parent = ring
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 3
ringStroke.Color = ROPE_COLOR
ringStroke.Parent = ring
for k = 0, 3 do
	-- Four ticks around the ring, like a scope.
	local notch = Instance.new("Frame")
	notch.AnchorPoint = Vector2.new(0.5, 0.5)
	notch.Size = UDim2.fromOffset(4, 12)
	notch.BackgroundColor3 = ROPE_COLOR
	notch.BorderSizePixel = 0
	notch.Rotation = k * 90
	local a = k * math.pi / 2
	notch.Position = UDim2.fromScale(0.5 + math.sin(a) * 0.5, 0.5 - math.cos(a) * 0.5)
	notch.Parent = ring
end
reticle.Parent = player:WaitForChild("PlayerGui")

local function setTarget(newTarget: BasePart?)
	if newTarget == target then
		return
	end
	target = newTarget
	highlight.Adornee = newTarget and newTarget.Parent
	highlight.Enabled = newTarget ~= nil
	reticle.Adornee = newTarget
	reticle.Enabled = newTarget ~= nil
	if newTarget then
		ring.Size = UDim2.fromScale(1.3, 1.3)
		TweenService:Create(ring, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.8, 0.8) }):Play()
	end
end

-- Helpers ----------------------------------------------------------------------------

local function isUsable(anchor: Instance?): boolean
	return anchor ~= nil
		and anchor.Parent ~= nil
		and anchor:IsDescendantOf(Workspace)
		and not anchor:GetAttribute("Broken")
		and CollectionService:HasTag(anchor, TAG)
end

local function grounded(): boolean
	return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function setCharges(n: number)
	if n == charges then
		return
	end
	charges = n
	for _, fn in chargeListeners do
		task.spawn(fn, n)
	end
end

local function usesCentreAim(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch or last.Name:find("Gamepad") ~= nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Picks the anchor closest to where the player is aiming, preferring small
-- angles over short distances, with a clear line of sight from the body.
local function pickTarget(): BasePart?
	local camera = Workspace.CurrentCamera
	if not (root and camera) then
		return nil
	end
	local centre = usesCentreAim()
	local aim: Ray
	if centre then
		aim = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	else
		local mouse = UserInputService:GetMouseLocation()
		aim = camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local coneRad = math.rad(if centre then cfg.TouchAimCone else cfg.AimCone)
	local cosCone = math.cos(coneRad)

	local candidates: { { anchor: BasePart, score: number } } = {}
	for _, inst in CollectionService:GetTagged(TAG) do
		local anchor = inst :: BasePart
		if not isUsable(anchor) then
			continue
		end
		local distance = (anchor.Position - root.Position).Magnitude
		if distance > cfg.Range or distance < 5 then
			continue
		end
		local cosAngle = aim.Direction:Dot((anchor.Position - aim.Origin).Unit)
		if cosAngle < cosCone then
			continue
		end
		local angle = math.acos(math.clamp(cosAngle, -1, 1)) / coneRad
		table.insert(candidates, { anchor = anchor, score = angle * 0.8 + distance / cfg.Range * 0.2 })
	end
	table.sort(candidates, function(a, b)
		return a.score < b.score
	end)

	for i = 1, math.min(#candidates, 6) do
		local anchor = candidates[i].anchor
		local exclude: { Instance } = { localFolder }
		if character then
			table.insert(exclude, character)
		end
		if anchor.Parent then
			table.insert(exclude, anchor.Parent)
		end
		rayParams.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(root.Position, anchor.Position - root.Position, rayParams)
		if not hit then
			return anchor
		end
	end
	return nil
end

-- Rope -------------------------------------------------------------------------------

local function handPosition(): Vector3
	if hand then
		return hand.WorldPosition
	end
	return if root then root.Position else Vector3.zero
end

local function buildRope(anchor: BasePart): Hook
	local tip = Instance.new("Attachment")
	tip.Name = "GrappleTip"
	tip.WorldPosition = handPosition()
	tip.Parent = Workspace.Terrain

	local tipBall = Instance.new("Part")
	tipBall.Name = "HookTip"
	tipBall.Shape = Enum.PartType.Ball
	tipBall.Size = Vector3.one * 0.6
	tipBall.Color = ROPE_COLOR
	tipBall.Material = Enum.Material.Neon
	tipBall.Anchored = true
	tipBall.CanCollide = false
	tipBall.CanQuery = false
	tipBall.CanTouch = false
	tipBall.CFrame = CFrame.new(tip.WorldPosition)
	tipBall.Parent = localFolder

	local beam = Instance.new("Beam")
	beam.Attachment0 = hand or (root and root:FindFirstChild("RootAttachment")) :: Attachment
	beam.Attachment1 = tip
	beam.Color = ColorSequence.new(Color3.fromRGB(210, 255, 230), ROPE_COLOR)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 0.2
	beam.Width1 = 0.12
	beam.FaceCamera = true
	beam.Segments = 16
	-- A little wobble while the rope is flying, straightened on impact.
	beam.CurveSize0 = math.random(-4, 4)
	beam.CurveSize1 = math.random(-3, 3)
	beam.Parent = Workspace.Terrain

	local distance = (anchor.Position - tip.WorldPosition).Magnitude
	return {
		anchor = anchor,
		phase = "shooting",
		shootTime = 0,
		shootDuration = math.max(distance / cfg.ShootSpeed, 0.06),
		lastDistance = math.huge,
		stuck = 0,
		tip = tip,
		tipBall = tipBall,
		beam = beam,
	}
end

local function destroyRope(h: Hook)
	h.beam:Destroy()
	h.tip:Destroy()
	h.tipBall:Destroy()
end

-- Hook lifecycle -------------------------------------------------------------------

local function detach(boost: boolean)
	local h = hook
	if not h then
		return
	end
	hook = nil
	local wasPulling = h.phase == "pulling"
	destroyRope(h)
	if wasPulling then
		GrappleRemote:FireServer(nil)
	end
	if wasPulling and boost and root then
		local v = root.AssemblyLinearVelocity
		if v.Magnitude > 1 then
			v += v.Unit * cfg.ReleaseBoost + Vector3.new(0, cfg.ReleaseLift, 0)
		end
		root.AssemblyLinearVelocity = v
		carry = Vector3.new(v.X, 0, v.Z)
		Audio.play("Release", 1 + math.clamp(v.Magnitude / cfg.MaxSpeed, 0, 1) * 0.3)
	end
end

local function attach(h: Hook)
	h.phase = "pulling"
	h.tip.WorldPosition = h.anchor.Position
	h.tipBall.CFrame = CFrame.new(h.anchor.Position)
	TweenService:Create(h.beam, TweenInfo.new(0.12), { CurveSize0 = 0, CurveSize1 = 0 }):Play()
	GrappleRemote:FireServer(h.anchor)

	Audio.play("Attach")
	if h.anchor:GetAttribute("Kind") ~= "Gargoyle" then
		Audio.play("Clank", 1.1)
	end
	CameraFX.punch(6)
	CameraFX.kick(0.22)

	if humanoid and root then
		if grounded() then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		-- Instant tug so the hook feels like it grabs you.
		local dir = (h.anchor.Position - root.Position).Unit
		local v = root.AssemblyLinearVelocity
		local along = v:Dot(dir)
		if along < cfg.StartKick then
			root.AssemblyLinearVelocity = v + dir * (cfg.StartKick - along)
		end
	end
	carry = nil
end

local function fire()
	if hook or not (root and humanoid and humanoid.Health > 0) then
		return
	end
	if charges <= 0 then
		Audio.play("Empty")
		for _, fn in emptyListeners do
			task.spawn(fn)
		end
		return
	end
	if not target then
		Audio.play("Empty", 1.25, 0.6)
		return
	end
	setCharges(charges - 1)
	hook = buildRope(target)
	Audio.play("Fire")
end

-- Physics ------------------------------------------------------------------------------

local function horizontal(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function stepPull(h: Hook, dt: number)
	assert(root and humanoid)
	local toAnchor = h.anchor.Position - root.Position
	local distance = toAnchor.Magnitude

	if distance < cfg.ArriveDistance then
		-- Arrived: pop up over the anchor and keep flying.
		root.AssemblyLinearVelocity += Vector3.new(0, cfg.ArrivePop, 0)
		detach(true)
		return
	end

	-- Bail out if something is blocking us (pressed into a wall).
	if distance > h.lastDistance - 0.05 then
		h.stuck += dt
		if h.stuck > cfg.StuckTime then
			detach(false)
			return
		end
	else
		h.stuck = 0
	end
	h.lastDistance = distance

	local dir = toAnchor / distance
	local v = root.AssemblyLinearVelocity
	v += dir * cfg.PullAccel * dt
	v += Vector3.new(0, Workspace.Gravity * cfg.GravityAssist * dt, 0)

	local along = v:Dot(dir)
	local side = v - dir * along
	side *= math.max(0, 1 - cfg.SideDamping * dt)

	-- A little steering perpendicular to the rope.
	local move = humanoid.MoveDirection
	local steer = (move - dir * move:Dot(dir)) * cfg.AirSteer * dt

	v = dir * along + side + steer
	if v.Magnitude > cfg.MaxSpeed then
		v = v.Unit * cfg.MaxSpeed
	end
	root.AssemblyLinearVelocity = v

	local state = humanoid:GetState()
	if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

-- Keeps horizontal speed after a release. The default Humanoid air control
-- would otherwise brake you to walking speed almost immediately.
local function stepCarry(dt: number)
	assert(root and humanoid)
	local c = carry :: Vector3
	local v = root.AssemblyLinearVelocity
	local actual = horizontal(v)

	-- Hit a wall: take whatever speed survived the collision.
	if actual.Magnitude < c.Magnitude * 0.6 then
		c = actual
	end
	c *= math.exp(-cfg.AirDrag * dt)
	local move = horizontal(humanoid.MoveDirection)
	c += move * cfg.AirSteer * 0.5 * dt

	if c.Magnitude <= humanoid.WalkSpeed then
		carry = nil
		return
	end
	carry = c
	root.AssemblyLinearVelocity = Vector3.new(c.X, v.Y, c.Z)
end

local function step(dt: number)
	if not (root and humanoid and humanoid.Health > 0) then
		if hook then
			detach(false)
		end
		carry = nil
		return
	end

	-- Escaping teleports you to the sanctum; drop any hook from below.
	if player:GetAttribute("EscapeTime") then
		if hook then
			detach(false)
		end
		carry = nil
		return
	end

	if grounded() then
		carry = nil
		if not hook and charges < cfg.Charges then
			setCharges(cfg.Charges)
		end
	end

	local h = hook
	if h then
		if not isUsable(h.anchor) then
			Audio.play("Snap")
			detach(true)
			return
		end
		if h.phase == "shooting" then
			h.shootTime += dt
			local alpha = math.min(1, h.shootTime / h.shootDuration)
			local position = handPosition():Lerp(h.anchor.Position, alpha)
			h.tip.WorldPosition = position
			h.tipBall.CFrame = CFrame.new(position)
			if alpha >= 1 then
				attach(h)
			end
		else
			h.tip.WorldPosition = h.anchor.Position
			h.tipBall.CFrame = CFrame.new(h.anchor.Position)
			stepPull(h, dt)
		end
	elseif carry then
		stepCarry(dt)
	end
end

-- Public API ------------------------------------------------------------------------------

function Grapple.press()
	fire()
end

function Grapple.release()
	if hook then
		detach(hook.phase == "pulling")
	end
end

function Grapple.getCharges(): number
	return charges
end

function Grapple.isHooked(): boolean
	return hook ~= nil and hook.phase == "pulling"
end

function Grapple.onChargesChanged(fn: (number) -> ())
	table.insert(chargeListeners, fn)
end

function Grapple.onOutOfCharges(fn: () -> ())
	table.insert(emptyListeners, fn)
end

local function bindCharacter(newCharacter: Model)
	if hook then
		detach(false)
	end
	carry = nil
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	root = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	-- R15 has a RightHand, R6 a "Right Arm"; both carry a RightGripAttachment.
	local handPart = newCharacter:WaitForChild("RightHand", 3) or newCharacter:FindFirstChild("Right Arm")
	hand = handPart and handPart:FindFirstChild("RightGripAttachment") :: Attachment?
	setCharges(cfg.Charges)
end

function Grapple.init()
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function()
		if hook then
			detach(false)
		end
		character, humanoid, root, hand = nil, nil, nil, nil
		setTarget(nil)
	end)

	ContextActionService:BindActionAtPriority("Grapple", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Grapple.press()
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			Grapple.release()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2, Enum.KeyCode.Q)

	RunService.PreSimulation:Connect(step)
	RunService.RenderStepped:Connect(function()
		if root and humanoid and humanoid.Health > 0 and not hook then
			setTarget(pickTarget())
		elseif not hook then
			setTarget(nil)
		end
		-- Red reticle when you're out of hooks.
		local colour = if charges > 0 then ROPE_COLOR else Color3.fromRGB(255, 90, 90)
		ringStroke.Color = colour
		highlight.FillColor = colour
		ring.Rotation = (os.clock() * 90) % 360
	end)
end

return Grapple
