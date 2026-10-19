-- Round: runs one training round for one mode.
--
--   local round = Round.new(mode, eyeCFrame, hooks)
--   round:begin()     start the clock and spawn targets
--   round:fire()      a shot from the centre of the screen
--   round:cancel()    stop without results
--
-- hooks (all optional):
--   onHit(combo, reactionMs)   onMiss()   onEnd(stats)
--
-- Targets are client-only Parts in a local folder, so each player sees only
-- their own. Hit detection is a raycast from the camera through the centre
-- of the screen.
--
-- Location: StarterPlayerScripts > Client > Round (ModuleScript)

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modes"))
local Audio = require(script.Parent.Audio)

local Round = {}
Round.__index = Round

type Target = { part: Part, spawnedAt: number, cell: number? }

export type Hooks = {
	onHit: ((combo: number, reactionMs: number) -> ())?,
	onMiss: (() -> ())?,
	onEnd: ((stats: Modes.Stats) -> ())?,
}

export type Round = typeof(setmetatable({} :: {
	mode: Modes.Mode,
	plane: CFrame,
	hooks: Hooks,
	folder: Folder,
	targets: { [Part]: Target },
	running: boolean,
	startTime: number,
	stats: Modes.Stats,
	combo: number,
	reactionSum: number,
	rng: Random,
	lastCell: number?,
	lastPos: Vector2?,
	connection: RBXScriptConnection?,
	-- tracking
	trackX: number,
	trackVelocity: number,
	nextTurn: number,
	onTarget: boolean,
}, Round))

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

function Round.new(mode: Modes.Mode, eyeCFrame: CFrame, hooks: Hooks): Round
	local self = setmetatable({}, Round) :: any
	self.mode = mode
	-- Target plane straight ahead, facing the player.
	self.plane = eyeCFrame * CFrame.new(0, 0, -Modes.TargetDistance)
	self.hooks = hooks
	self.folder = Instance.new("Folder")
	self.folder.Name = "LocalTargets"
	self.folder.Parent = Workspace
	self.targets = {}
	self.running = false
	self.startTime = 0
	self.stats = { hits = 0, shots = 0, trackTime = 0, bestCombo = 0, avgReaction = 0 }
	self.combo = 0
	self.reactionSum = 0
	self.rng = Random.new()
	self.trackX = 0
	self.trackVelocity = mode.speed or 0
	self.nextTurn = 0
	self.onTarget = false
	rayParams.FilterDescendantsInstances = { self.folder }
	return self
end

-- Targets ------------------------------------------------------------------------

-- Keeps a target's whole sphere on the wall, whatever the mode's area says.
local function onWall(pos: Vector2, radius: number): Vector2
	local halfW = Modes.WallSize.X / 2 - radius - 0.5
	local halfH = Modes.WallSize.Y / 2 - radius - 0.5
	return Vector2.new(math.clamp(pos.X, -halfW, halfW), math.clamp(pos.Y, -halfH, halfH))
end

local function makeTarget(self: Round, localPos: Vector2): Part
	local r = self.mode.radius
	localPos = onWall(localPos, r)
	local part = Instance.new("Part")
	part.Name = "Target"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 0.05
	part.Color = self.mode.color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.CFrame = self.plane * CFrame.new(localPos.X, localPos.Y, 0)
	local light = Instance.new("PointLight")
	light.Color = self.mode.color
	light.Range = r * 6
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = part
	part.Parent = self.folder
	-- Quick grow-in so new targets catch the eye.
	TweenService:Create(part, TweenInfo.new(0.09, Enum.EasingStyle.Back), { Size = Vector3.one * r * 2 }):Play()
	return part
end

local function gridCellPosition(self: Round, cell: number): Vector2
	local n = self.mode.grid :: number
	local col = (cell - 1) % n
	local row = (cell - 1) // n
	local area = self.mode.area
	return Vector2.new(-area.X / 2 + col * area.X / (n - 1), -area.Y / 2 + row * area.Y / (n - 1))
end

local function spawnOne(self: Round)
	local mode = self.mode
	if mode.kind == "grid" then
		local n = mode.grid :: number
		local taken: { [number]: boolean } = {}
		for _, t in self.targets do
			if t.cell then
				taken[t.cell] = true
			end
		end
		local free = {}
		for cell = 1, n * n do
			if not taken[cell] and cell ~= self.lastCell then
				table.insert(free, cell)
			end
		end
		local cell = free[self.rng:NextInteger(1, #free)]
		local part = makeTarget(self, gridCellPosition(self, cell))
		self.targets[part] = { part = part, spawnedAt = os.clock(), cell = cell }
	else
		-- Random anywhere in the area, but not right on top of the last one.
		local area = mode.area
		local pos: Vector2
		local tries = 0
		repeat
			pos = Vector2.new(self.rng:NextNumber(-area.X / 2, area.X / 2), self.rng:NextNumber(-area.Y / 2, area.Y / 2))
			tries += 1
		until not self.lastPos or (pos - self.lastPos).Magnitude > mode.radius * 4 or tries > 10
		local part = makeTarget(self, pos)
		self.targets[part] = { part = part, spawnedAt = os.clock() }
	end
end

-- Pop effect: the target swells and fades while a burst of sparks flies out.
local function popTarget(self: Round, part: Part)
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Transparency = 1
	burst.Size = Vector3.one * 0.1
	burst.CFrame = part.CFrame
	burst.Parent = self.folder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(self.mode.color, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Lifetime = NumberRange.new(0.25, 0.45)
	sparks.Speed = NumberRange.new(12, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 6
	sparks.Rate = 0
	sparks.Parent = burst
	sparks:Emit(16)
	task.delay(0.6, function()
		burst:Destroy()
	end)

	part.CanQuery = false
	local grow = TweenService:Create(part, TweenInfo.new(0.1), { Size = part.Size * 1.5, Transparency = 1 })
	grow:Play()
	grow.Completed:Once(function()
		part:Destroy()
	end)
end

-- Tracking ----------------------------------------------------------------------

local function stepTracking(self: Round, dt: number)
	local mode = self.mode
	local now = os.clock()
	local half = mode.area.X / 2
	if now >= self.nextTurn or math.abs(self.trackX) > half then
		-- Unpredictable strafes: random direction change and speed.
		local dir = if math.abs(self.trackX) > half then -math.sign(self.trackX) else (if self.rng:NextNumber() < 0.5 then -1 else 1)
		self.trackVelocity = dir * (mode.speed :: number) * self.rng:NextNumber(0.7, 1.3)
		self.nextTurn = now + self.rng:NextNumber(0.35, 1.3)
	end
	self.trackX = math.clamp(self.trackX + self.trackVelocity * dt, -half - 0.5, half + 0.5)
	local y = math.sin(now * 1.7) * mode.area.Y * 0.3
	local pos = onWall(Vector2.new(self.trackX, y), mode.radius)
	for part in self.targets do
		part.CFrame = self.plane * CFrame.new(pos.X, pos.Y, 0)
	end

	local camera = Workspace.CurrentCamera
	local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 400, rayParams)
	local on = hit ~= nil and self.targets[hit.Instance :: Part] ~= nil
	if on then
		self.stats.trackTime += dt
	end
	if on ~= self.onTarget then
		self.onTarget = on
		for part in self.targets do
			part.Color = if on then Color3.new(1, 1, 1) else mode.color
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function Round.begin(self: Round)
	self.running = true
	self.startTime = os.clock()
	local count = if self.mode.kind == "track" then 1 else self.mode.targets
	for _ = 1, count do
		spawnOne(self)
	end
	self.connection = RunService.RenderStepped:Connect(function(dt)
		if not self.running then
			return
		end
		if self.mode.kind == "track" then
			stepTracking(self, dt)
		end
		if self:remaining() <= 0 then
			self:finish()
		end
	end)
end

function Round.remaining(self: Round): number
	if not self.running then
		return self.mode.duration
	end
	return math.max(0, self.mode.duration - (os.clock() - self.startTime))
end

function Round.isOnTarget(self: Round): boolean
	return self.onTarget
end

function Round.fire(self: Round)
	if not self.running or self.mode.kind == "track" then
		return
	end
	self.stats.shots += 1
	Audio.play("Shot")
	local camera = Workspace.CurrentCamera
	local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 400, rayParams)
	local target = hit and self.targets[hit.Instance :: Part]
	if not target then
		self.combo = 0
		Audio.play("Miss", 0.7)
		if self.hooks.onMiss then
			self.hooks.onMiss()
		end
		return
	end

	local reaction = (os.clock() - target.spawnedAt) * 1000
	self.targets[target.part] = nil
	self.stats.hits += 1
	self.reactionSum += reaction
	self.combo += 1
	self.stats.bestCombo = math.max(self.stats.bestCombo, self.combo)
	self.lastCell = target.cell
	local localPos = self.plane:PointToObjectSpace(target.part.Position)
	self.lastPos = Vector2.new(localPos.X, localPos.Y)
	-- The pop climbs in pitch as the combo builds.
	Audio.play("Hit", 1 + math.min(self.combo, 25) * 0.025, false)
	popTarget(self, target.part)
	spawnOne(self)
	if self.hooks.onHit then
		self.hooks.onHit(self.combo, reaction)
	end
end

local function cleanup(self: Round)
	self.running = false
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	task.delay(0.7, function()
		self.folder:Destroy()
	end)
	for part in self.targets do
		part:Destroy()
	end
	self.targets = {}
end

function Round.finish(self: Round)
	if not self.running then
		return
	end
	cleanup(self)
	self.stats.avgReaction = if self.stats.hits > 0 then self.reactionSum / self.stats.hits else 0
	if self.hooks.onEnd then
		task.spawn(self.hooks.onEnd, self.stats)
	end
end

function Round.cancel(self: Round)
	if self.running then
		cleanup(self)
	end
end

function Round.liveStats(self: Round): Modes.Stats
	return self.stats
end

return Round
