-- Grow a Brainrot: server entry point.
-- Plant seeds -> they grow into brainrots -> brainrots earn cash on your base.
-- Other players can steal them unless you lock your base or bonk them first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapBuilder = require(script.MapBuilder)
local Visuals = require(script.Visuals)
local DataService = require(script.DataService)

type Plot = MapBuilder.Plot
type Data = DataService.Data

type Carry = { creatureId: string, mutation: string?, fromUserId: number, model: Model }
type State = {
	player: Player,
	data: Data,
	canSave: boolean,
	plot: Plot,
	plantModels: { [number]: Model },
	creatureModels: { [number]: Model },
	carrying: Carry?,
	selectedSeed: string?,
	lockedUntil: number,
	lockReadyAt: number,
	lastBonk: number,
	stunnedUntil: number,
	cashValue: NumberValue,
	seedsFolder: Folder,
}

local GREEN = Color3.fromRGB(110, 255, 120)
local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 215, 80)

local rng = Random.new()

-- Remotes ------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local BuySeed = remote("BuySeed") -- client -> server (seedId)
local SelectSeed = remote("SelectSeed") -- client -> server (seedId)
local Notify = remote("Notify") -- server -> client (text, color)
local OpenShop = remote("OpenShop") -- server -> client
local Knockback = remote("Knockback") -- server -> client (velocity)
remotes.Parent = ReplicatedStorage

-- World --------------------------------------------------------------------

local plots, shopPrompt = MapBuilder.build()
local plotOwners: { [number]: Player } = {}
local states: { [Player]: State } = {}
local weatherActive = false

local weatherTint = Instance.new("ColorCorrectionEffect")
weatherTint.Name = "GoldenRain"
weatherTint.TintColor = Color3.fromRGB(255, 235, 170)
weatherTint.Saturation = 0.2
weatherTint.Enabled = false
weatherTint.Parent = Lighting

for _, plot in plots do
	for _, pp in plot.tilePrompts do
		CollectionService:AddTag(pp, "OwnerPrompt")
	end
	for _, pp in plot.sellPrompts do
		CollectionService:AddTag(pp, "OwnerPrompt")
	end
	CollectionService:AddTag(plot.lockPrompt, "OwnerPrompt")
	for _, pp in plot.stealPrompts do
		CollectionService:AddTag(pp, "ThiefPrompt")
	end
end

-- Helpers ------------------------------------------------------------------

local function notify(player: Player, text: string, color: Color3?)
	Notify:FireClient(player, text, color or Color3.new(1, 1, 1))
end

local function notifyAll(text: string, color: Color3?)
	Notify:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Prompts already enforce distance, this just stops spoofed triggers.
local function isNear(player: Player, part: BasePart, range: number): boolean
	local hrp = rootPart(player)
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= range
end

local function ownerState(player: Player, plot: Plot): State?
	local state = states[player]
	if state and state.plot == plot then
		return state
	end
	return nil
end

-- The "Active" attribute is the source of truth for clients, which hide
-- prompts that aren't for them and re-show them from this value.
local function setActive(prompt: ProximityPrompt, active: boolean)
	prompt:SetAttribute("Active", active)
	prompt.Enabled = active
end

local function setCash(state: State, amount: number)
	state.data.cash = amount
	state.cashValue.Value = math.floor(amount)
end

local function syncSeeds(state: State)
	local seeds = state.data.seeds
	for _, id in Config.sortedSeedIds() do
		local value = state.seedsFolder:FindFirstChild(id) :: IntValue?
		if not value then
			local v = Instance.new("IntValue")
			v.Name = id
			v.Parent = state.seedsFolder
			value = v
		end
		(value :: IntValue).Value = seeds[id] or 0
	end
	if state.selectedSeed and not seeds[state.selectedSeed] then
		state.selectedSeed = nil
	end
	if not state.selectedSeed then
		for _, id in Config.sortedSeedIds() do
			if seeds[id] then
				state.selectedSeed = id
				break
			end
		end
	end
	state.player:SetAttribute("SelectedSeed", state.selectedSeed)
end

local function updateIncome(state: State): number
	local total = 0
	for _, c in state.data.creatures do
		total += Config.creatureIncome(c.id, c.mutation)
	end
	state.player:SetAttribute("Income", total)
	return total
end

local function applyWalkSpeed(state: State)
	local humanoid = humanoidOf(state.player)
	if not humanoid then
		return
	end
	if os.clock() < state.stunnedUntil then
		humanoid.WalkSpeed = 0
	elseif state.carrying then
		humanoid.WalkSpeed = Config.CarryWalkSpeed
	else
		humanoid.WalkSpeed = Config.NormalWalkSpeed
	end
end

-- Rendering ----------------------------------------------------------------

local function pedestalTop(plot: Plot, i: number): CFrame
	local ped = plot.pedestals[i]
	-- Pedestals are cylinders rotated upright, so their height is Size.X.
	-- Creatures face the road (plot +Z), i.e. their -Z look vector points along plot +Z.
	local pos = ped.Position + Vector3.new(0, ped.Size.X / 2, 0)
	return CFrame.new(pos) * plot.cframe.Rotation * CFrame.Angles(0, math.pi, 0)
end

local function renderCreature(state: State, i: number)
	local old = state.creatureModels[i]
	if old then
		old:Destroy()
		state.creatureModels[i] = nil
	end
	local plot = state.plot
	local sell, steal = plot.sellPrompts[i], plot.stealPrompts[i]
	local c = state.data.creatures[tostring(i)]
	if not c then
		setActive(sell, false)
		setActive(steal, false)
		return
	end
	local model = Visuals.creature(c.id, c.mutation)
	model:PivotTo(pedestalTop(plot, i) * CFrame.new(0, Visuals.footOffset(c.id), 0))
	assert(model.PrimaryPart).Anchored = true
	model.Parent = plot.model
	state.creatureModels[i] = model

	local def = Config.Creatures[c.id]
	local sellValue = Config.creatureIncome(c.id, c.mutation) * Config.SellMultiplier
	sell.ObjectText = def.name
	sell.ActionText = "Sell $" .. Config.formatNumber(sellValue)
	steal.ObjectText = def.name
	setActive(sell, true)
	setActive(steal, true)
end

local function plantProgress(plant: DataService.PlantSave): number
	return (os.time() - plant.plantedAt) / Config.Seeds[plant.seed].growTime
end

local function renderPlant(state: State, i: number)
	local prompt = state.plot.tilePrompts[i]
	local plant = state.data.plants[tostring(i)]
	local model = state.plantModels[i]
	if not plant then
		if model then
			model:Destroy()
			state.plantModels[i] = nil
		end
		prompt.ActionText = "Plant"
		prompt.ObjectText = "Empty Soil"
		setActive(prompt, true)
		return
	end
	local progress = plantProgress(plant)
	state.plantModels[i] = Visuals.plant(state.plot.tiles[i], plant.seed, progress, model)
	if progress >= 1 then
		prompt.ActionText = "Harvest"
		prompt.ObjectText = Config.Seeds[plant.seed].name
		setActive(prompt, true)
	else
		setActive(prompt, false)
	end
end

local function setPlotOwner(plot: Plot, player: Player?)
	local userId = if player then player.UserId else 0
	local prompts: { ProximityPrompt } = { plot.lockPrompt }
	for _, list in { plot.tilePrompts, plot.sellPrompts, plot.stealPrompts } do
		for _, pp in list do
			table.insert(prompts, pp)
		end
	end
	for _, pp in prompts do
		pp:SetAttribute("OwnerUserId", userId)
	end
	plot.signLabel.Text = if player then player.DisplayName .. "'s Base" else "Free Plot"
	plot.model:SetAttribute("OwnerUserId", userId)
end

-- Creatures ----------------------------------------------------------------

local function freePedestal(state: State): number?
	for i = 1, #state.plot.pedestals do
		if not state.data.creatures[tostring(i)] then
			return i
		end
	end
	return nil
end

local function giveCreature(state: State, creatureId: string, mutation: string?): number?
	local slot = freePedestal(state)
	if not slot then
		return nil
	end
	state.data.creatures[tostring(slot)] = { id = creatureId, mutation = mutation }
	renderCreature(state, slot)
	updateIncome(state)
	return slot
end

local function creatureLabel(creatureId: string, mutation: string?): string
	local def = Config.Creatures[creatureId]
	return if mutation then mutation .. " " .. def.name else def.name
end

local function rollCreature(seedId: string): string
	local pool = Config.Seeds[seedId].pool
	local total = 0
	for _, entry in pool do
		total += entry.weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in pool do
		roll -= entry.weight
		if roll <= 0 then
			return entry.id
		end
	end
	return pool[#pool].id
end

local function rollMutation(): string?
	local boost = if weatherActive then Config.WeatherMutationBoost else 1
	for _, m in Config.Mutations do
		if rng:NextNumber() < m.chance * boost then
			return m.id
		end
	end
	return nil
end

-- Carrying (stealing) --------------------------------------------------------

local function attachCarry(state: State, creatureId: string, mutation: string?, fromUserId: number): boolean
	local character = state.player.Character
	local hrp = rootPart(state.player)
	if not (character and hrp and humanoidOf(state.player)) then
		return false
	end
	local scale = 0.6
	local model = Visuals.creature(creatureId, mutation)
	model:ScaleTo(scale)
	model:PivotTo(hrp.CFrame * CFrame.new(0, 3 + Visuals.footOffset(creatureId) * scale, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Name = "CarriedBrainrot"
	model.Parent = character
	state.carrying = { creatureId = creatureId, mutation = mutation, fromUserId = fromUserId, model = model }
	state.player:SetAttribute("Carrying", true)
	applyWalkSpeed(state)
	return true
end

local function clearCarry(state: State): Carry?
	local carry = state.carrying
	if not carry then
		return nil
	end
	state.carrying = nil
	carry.model:Destroy()
	state.player:SetAttribute("Carrying", false)
	applyWalkSpeed(state)
	return carry
end

-- Sends a carried brainrot home to whoever it was stolen from.
local function returnCarry(state: State, message: string?)
	local carry = clearCarry(state)
	if not carry then
		return
	end
	if message then
		notify(state.player, message, RED)
	end
	local owner = Players:GetPlayerByUserId(carry.fromUserId)
	local ownerS = owner and states[owner]
	if owner and ownerS and giveCreature(ownerS, carry.creatureId, carry.mutation) then
		notify(owner, creatureLabel(carry.creatureId, carry.mutation) .. " came back to your base!", GREEN)
	end
end

local function stun(state: State)
	state.stunnedUntil = os.clock() + Config.BonkStun
	applyWalkSpeed(state)
	task.delay(Config.BonkStun + 0.05, applyWalkSpeed, state)
end

-- Prompt handlers --------------------------------------------------------------

local function onTile(player: Player, plot: Plot, i: number)
	local state = ownerState(player, plot)
	if not state or not isNear(player, plot.tiles[i], 20) then
		return
	end
	local data = state.data
	local key = tostring(i)
	local plant = data.plants[key]

	if plant then
		if plantProgress(plant) < 1 then
			return
		end
		if not freePedestal(state) then
			notify(player, "Your base is full! Sell a brainrot first.", RED)
			return
		end
		local creatureId = rollCreature(plant.seed)
		local mutation = rollMutation()
		data.plants[key] = nil
		renderPlant(state, i)
		giveCreature(state, creatureId, mutation)

		local def = Config.Creatures[creatureId]
		local rarity = Config.Rarities[def.rarity]
		local label = creatureLabel(creatureId, mutation)
		notify(player, string.format("You grew %s (%s)!", label, def.rarity), rarity.color)
		if rarity.order >= 4 or mutation == "Rainbow" then
			notifyAll(string.format("%s grew a %s %s!", player.DisplayName, def.rarity, label), rarity.color)
		end
		return
	end

	local seedId = state.selectedSeed
	if not seedId or not data.seeds[seedId] then
		notify(player, "No seeds! Buy some at the Seed Shop.", RED)
		return
	end
	data.seeds[seedId] -= 1
	if data.seeds[seedId] <= 0 then
		data.seeds[seedId] = nil
	end
	data.plants[key] = { seed = seedId, plantedAt = os.time() }
	syncSeeds(state)
	renderPlant(state, i)
end

local function onSell(player: Player, plot: Plot, i: number)
	local state = ownerState(player, plot)
	if not state or not isNear(player, plot.pedestals[i], 20) then
		return
	end
	local key = tostring(i)
	local c = state.data.creatures[key]
	if not c then
		return
	end
	local value = Config.creatureIncome(c.id, c.mutation) * Config.SellMultiplier
	state.data.creatures[key] = nil
	renderCreature(state, i)
	updateIncome(state)
	setCash(state, state.data.cash + value)
	notify(player, string.format("Sold %s for $%s", creatureLabel(c.id, c.mutation), Config.formatNumber(value)), GOLD)
end

local function onSteal(thief: Player, plot: Plot, i: number)
	local victim = plotOwners[plot.index]
	local victimState = victim and states[victim]
	local thiefState = states[thief]
	if not (victim and victimState and thiefState) or victim == thief then
		return
	end
	if not isNear(thief, plot.pedestals[i], 20) then
		return
	end
	if thiefState.carrying then
		notify(thief, "You're already carrying one!", RED)
		return
	end
	if os.clock() < victimState.lockedUntil then
		notify(thief, "That base is locked!", RED)
		return
	end
	if not freePedestal(thiefState) then
		notify(thief, "Your base is full, no room for stolen goods!", RED)
		return
	end
	local key = tostring(i)
	local c = victimState.data.creatures[key]
	if not c then
		return
	end

	victimState.data.creatures[key] = nil
	renderCreature(victimState, i)
	updateIncome(victimState)
	if not attachCarry(thiefState, c.id, c.mutation, victim.UserId) then
		giveCreature(victimState, c.id, c.mutation)
		return
	end
	local label = creatureLabel(c.id, c.mutation)
	notify(thief, "Got " .. label .. "! Run it back to your base!", GOLD)
	notify(victim, thief.DisplayName .. " is stealing your " .. label .. "! Bonk them!", RED)
end

local function onLock(player: Player, plot: Plot)
	local state = ownerState(player, plot)
	if not state then
		return
	end
	local now = os.clock()
	if now < state.lockedUntil then
		return
	end
	if now < state.lockReadyAt then
		notify(player, string.format("Lock recharging (%ds)", math.ceil(state.lockReadyAt - now)), RED)
		return
	end
	state.lockedUntil = now + Config.LockDuration
	state.lockReadyAt = state.lockedUntil + Config.LockCooldown
	plot.barrier.Transparency = 0.5
	notify(player, string.format("Base locked for %ds!", Config.LockDuration), GREEN)
end

for _, plot in plots do
	for i, pp in plot.tilePrompts do
		pp.Triggered:Connect(function(player)
			onTile(player, plot, i)
		end)
	end
	for i, pp in plot.sellPrompts do
		pp.Triggered:Connect(function(player)
			onSell(player, plot, i)
		end)
	end
	for i, pp in plot.stealPrompts do
		pp.Triggered:Connect(function(player)
			onSteal(player, plot, i)
		end)
	end
	plot.lockPrompt.Triggered:Connect(function(player)
		onLock(player, plot)
	end)
end

shopPrompt.Triggered:Connect(function(player)
	OpenShop:FireClient(player)
end)

-- Bonk bat -------------------------------------------------------------------

local function onBonk(player: Player, tool: Tool)
	local state = states[player]
	local hrp = rootPart(player)
	if not state or not hrp or not humanoidOf(player) then
		return
	end
	local now = os.clock()
	if now - state.lastBonk < Config.BonkCooldown then
		return
	end
	state.lastBonk = now

	-- The default Animate script plays a swing when it sees this value.
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool

	local target: Player?, targetRoot: BasePart?, bestDist = nil, nil, math.huge
	for other in states do
		local otherRoot = rootPart(other)
		if other ~= player and otherRoot and humanoidOf(other) then
			local offset = otherRoot.Position - hrp.Position
			local dist = offset.Magnitude
			local inFront = dist < 0.01 or hrp.CFrame.LookVector:Dot(offset.Unit) > -0.2
			if dist <= Config.BonkRange and inFront and dist < bestDist then
				target, targetRoot, bestDist = other, otherRoot, dist
			end
		end
	end
	if not (target and targetRoot) then
		return
	end
	local targetState = states[target]

	local flat = (targetRoot.Position - hrp.Position) * Vector3.new(1, 0, 1)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else hrp.CFrame.LookVector
	Knockback:FireClient(target, dir * 70 + Vector3.new(0, 35, 0))
	stun(targetState)

	if targetState.carrying then
		returnCarry(targetState, player.DisplayName .. " bonked you and you dropped it!")
		notify(player, "BONK! You stopped " .. target.DisplayName .. "!", GREEN)
	end
end

local function giveBat(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Bonk Bat") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Bat"
	tool.ToolTip = "Bonk thieves to get your brainrots back"
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, 0, -1.6)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 0.7, 4.5)
	handle.Color = Color3.fromRGB(160, 110, 60)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.one * 1.3
	tip.Color = handle.Color
	tip.Material = Enum.Material.Wood
	tip.CanCollide = false
	tip.Massless = true
	tip.CFrame = handle.CFrame * CFrame.new(0, 0, -2.2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = tip
	tip.Parent = tool

	tool.Activated:Connect(function()
		onBonk(player, tool)
	end)
	tool.Parent = backpack
end

-- Players ---------------------------------------------------------------------

local function onCharacterAdded(player: Player, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	-- Data may still be loading when the first character spawns.
	local waited = 0
	while not states[player] and player.Parent and waited < 20 do
		waited += task.wait(0.2)
	end
	local state = states[player]
	if not (state and hrp and humanoid) or player.Character ~= character then
		return
	end
	task.wait() -- let the default spawn positioning finish first
	character:PivotTo(MapBuilder.spawnCFrame(state.plot))
	applyWalkSpeed(state)
	giveBat(player)
	humanoid.Died:Connect(function()
		returnCarry(state, "You died and dropped it!")
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	local plotIndex: number? = nil
	for i in plots do
		if not plotOwners[i] then
			plotIndex = i
			break
		end
	end
	if not plotIndex then
		player:Kick("This server is full, try another one!")
		return
	end
	plotOwners[plotIndex] = player -- reserve before the DataStore yield

	local data, canSave = DataService.load(player.UserId)
	if not player.Parent then
		plotOwners[plotIndex] = nil
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("NumberValue")
	cashValue.Name = "Cash"
	cashValue.Parent = leaderstats
	leaderstats.Parent = player

	local seedsFolder = Instance.new("Folder")
	seedsFolder.Name = "Seeds"
	seedsFolder.Parent = player

	local plot = plots[plotIndex]
	local state: State = {
		player = player,
		data = data,
		canSave = canSave,
		plot = plot,
		plantModels = {},
		creatureModels = {},
		carrying = nil,
		selectedSeed = nil,
		lockedUntil = 0,
		lockReadyAt = 0,
		lastBonk = 0,
		stunnedUntil = 0,
		cashValue = cashValue,
		seedsFolder = seedsFolder,
	}
	states[player] = state

	setPlotOwner(plot, player)
	setCash(state, data.cash)
	syncSeeds(state)
	for i in plot.tiles do
		renderPlant(state, i)
	end
	for i in plot.pedestals do
		renderCreature(state, i)
	end
	updateIncome(state)

	if not canSave then
		notify(player, "Saving is off (DataStore unavailable). Progress won't be kept.", RED)
	end
	notify(player, "Welcome! Buy seeds at the shop, plant them, and grow brainrots!", GOLD)
end

local pendingSaves = 0

local function saveState(state: State)
	if not state.canSave then
		return
	end
	pendingSaves += 1
	DataService.save(state.player.UserId, state.data)
	pendingSaves -= 1
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if not state then
		for i, owner in plotOwners do
			if owner == player then
				plotOwners[i] = nil
			end
		end
		return
	end
	-- A thief who leaves mid-heist gives the brainrot back.
	returnCarry(state, nil)
	states[player] = nil

	local plot = state.plot
	for _, model in state.plantModels do
		model:Destroy()
	end
	for _, model in state.creatureModels do
		model:Destroy()
	end
	for i in plot.tiles do
		plot.tilePrompts[i].ActionText = "Plant"
		plot.tilePrompts[i].ObjectText = "Empty Soil"
		setActive(plot.tilePrompts[i], true)
	end
	for i in plot.pedestals do
		setActive(plot.sellPrompts[i], false)
		setActive(plot.stealPrompts[i], false)
	end
	plot.barrier.Transparency = 1
	plot.lockLabel.Text = "LOCK READY"
	setPlotOwner(plot, nil)
	plotOwners[plot.index] = nil

	saveState(state)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

game:BindToClose(function()
	for _, state in states do
		task.spawn(saveState, state)
	end
	local deadline = os.clock() + 25
	task.wait(0.1)
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end)

-- Shop remotes ------------------------------------------------------------------

BuySeed.OnServerEvent:Connect(function(player, seedId)
	local state = states[player]
	if not state or type(seedId) ~= "string" then
		return
	end
	local seed = Config.Seeds[seedId]
	if not seed then
		return
	end
	if state.data.cash < seed.price then
		notify(player, "Not enough cash!", RED)
		return
	end
	setCash(state, state.data.cash - seed.price)
	state.data.seeds[seedId] = (state.data.seeds[seedId] or 0) + 1
	syncSeeds(state)
	notify(player, "Bought a " .. seed.name .. "!", GREEN)
end)

SelectSeed.OnServerEvent:Connect(function(player, seedId)
	local state = states[player]
	if not state or type(seedId) ~= "string" or not state.data.seeds[seedId] then
		return
	end
	state.selectedSeed = seedId
	syncSeeds(state)
end)

-- Loops -------------------------------------------------------------------------

-- Income, plant growth and lock timers, once per second.
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, state in states do
			local income = updateIncome(state)
			if income > 0 then
				setCash(state, state.data.cash + income)
			end
			for i in state.plot.tiles do
				if state.data.plants[tostring(i)] then
					renderPlant(state, i)
				end
			end
			local plot = state.plot
			if now < state.lockedUntil then
				plot.lockLabel.Text = string.format("LOCKED %ds", math.ceil(state.lockedUntil - now))
				plot.barrier.Transparency = 0.5
			elseif now < state.lockReadyAt then
				plot.lockLabel.Text = string.format("RECHARGE %ds", math.ceil(state.lockReadyAt - now))
				plot.barrier.Transparency = 1
			else
				plot.lockLabel.Text = "LOCK READY"
				plot.barrier.Transparency = 1
			end
		end
	end
end)

-- Deliver stolen brainrots when the thief reaches their own base.
local deliverAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	deliverAccumulator += dt
	if deliverAccumulator < 0.15 then
		return
	end
	deliverAccumulator = 0
	for player, state in states do
		local carry = state.carrying
		local hrp = rootPart(player)
		if carry and hrp and MapBuilder.isInBase(state.plot, hrp.Position) then
			clearCarry(state)
			local label = creatureLabel(carry.creatureId, carry.mutation)
			if giveCreature(state, carry.creatureId, carry.mutation) then
				notify(player, "Stole " .. label .. "!", GREEN)
				local victim = Players:GetPlayerByUserId(carry.fromUserId)
				if victim then
					notify(victim, player.DisplayName .. " stole your " .. label .. "!", RED)
				end
			else
				state.carrying = carry -- keep it for returnCarry
				returnCarry(state, "Your base is full, so it ran home!")
			end
		end
	end
	Visuals.stepRainbow(os.clock())
end)

-- Golden Rain weather event.
task.spawn(function()
	while true do
		task.wait(Config.WeatherInterval)
		weatherActive = true
		weatherTint.Enabled = true
		Workspace:SetAttribute("WeatherEndsAt", Workspace:GetServerTimeNow() + Config.WeatherDuration)
		notifyAll(string.format("GOLDEN RAIN! Mutations are %dx more likely!", Config.WeatherMutationBoost), GOLD)
		task.wait(Config.WeatherDuration)
		weatherActive = false
		weatherTint.Enabled = false
		Workspace:SetAttribute("WeatherEndsAt", nil)
		notifyAll("The Golden Rain has stopped.", GOLD)
	end
end)

-- Autosave.
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, state in states do
			task.spawn(saveState, state)
		end
	end
end)
