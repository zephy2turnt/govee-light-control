-- Ropes: draws other players' grapple ropes.
--
-- The server sets Character.GrappleTarget (an ObjectValue) to the anchor
-- each player is hooked to. Your own rope is drawn instantly by Grapple;
-- this draws everyone else's from that replicated value.
--
-- Location: StarterPlayerScripts > Client > Ropes (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ropes = {}

local ROPE_COLOR = Color3.fromRGB(120, 255, 180)

type Rope = { beam: Beam, anchorAttachment: Attachment, target: BasePart }

local ropes: { [Player]: Rope } = {}

local function removeRope(player: Player)
	local rope = ropes[player]
	if rope then
		rope.beam:Destroy()
		rope.anchorAttachment:Destroy()
		ropes[player] = nil
	end
end

local function update(player: Player)
	local character = player.Character
	local value = character and character:FindFirstChild("GrappleTarget") :: ObjectValue?
	local target = value and value.Value
	if not (target and target:IsA("BasePart") and target.Parent) then
		removeRope(player)
		return
	end
	local existing = ropes[player]
	if existing and existing.target == target then
		return
	end
	removeRope(player)

	local handPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local hand = handPart and handPart:FindFirstChild("RightGripAttachment") :: Attachment?
	if not hand then
		return
	end
	local anchorAttachment = Instance.new("Attachment")
	anchorAttachment.Name = "RopeEnd"
	anchorAttachment.Parent = target

	local beam = Instance.new("Beam")
	beam.Attachment0 = hand
	beam.Attachment1 = anchorAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(210, 255, 230), ROPE_COLOR)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 0.2
	beam.Width1 = 0.12
	beam.FaceCamera = true
	beam.Parent = target
	ropes[player] = { beam = beam, anchorAttachment = anchorAttachment, target = target :: BasePart }
end

function Ropes.init()
	local me = Players.LocalPlayer
	Players.PlayerRemoving:Connect(removeRope)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.05 then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			if player ~= me then
				update(player)
			end
		end
	end)
end

return Ropes
