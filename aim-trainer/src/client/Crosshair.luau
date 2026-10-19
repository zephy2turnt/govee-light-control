-- Crosshair: draws the reticle in the centre of the screen.
--
--   Crosshair.new(parent)           build it
--   crosshair:apply(style, color, size)
--   crosshair:hit()                 white X hit marker + little pop
--   crosshair:miss()                brief red flash
--
-- Location: StarterPlayerScripts > Client > Crosshair (ModuleScript)

local Ui = require(script.Parent.Ui)

local Crosshair = {}
Crosshair.__index = Crosshair

export type Crosshair = typeof(setmetatable({} :: {
	root: Frame,
	parts: { GuiObject },
	marker: { Frame },
	color: Color3,
}, Crosshair))

local function bar(parent: Instance, size: UDim2, position: UDim2, rotation: number?): Frame
	return Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = size,
		Position = position,
		Rotation = rotation or 0,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		Ui.make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }),
	})
end

function Crosshair.new(parent: Instance): Crosshair
	local self = setmetatable({}, Crosshair) :: any
	self.root = Ui.make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	self.parts = {}
	self.color = Color3.new(1, 1, 1)

	-- Hit marker: four short diagonal ticks, hidden until a hit.
	self.marker = {}
	for k = 0, 3 do
		local angle = 45 + k * 90
		local rad = math.rad(angle)
		local mark = bar(
			self.root,
			UDim2.fromOffset(3, 9),
			UDim2.new(0.5, math.sin(rad) * 14, 0.5, -math.cos(rad) * 14),
			angle
		)
		mark.BackgroundTransparency = 1
		local s = mark:FindFirstChildOfClass("UIStroke") :: UIStroke
		s.Transparency = 1
		table.insert(self.marker, mark)
	end
	return self
end

function Crosshair.apply(self: Crosshair, style: string, color: Color3, size: number)
	for _, p in self.parts do
		p:Destroy()
	end
	self.parts = {}
	self.color = color
	local s = size
	local root = self.root
	local function add(g: GuiObject)
		g.BackgroundColor3 = color
		table.insert(self.parts, g)
	end

	if style == "Dot" then
		local dot = bar(root, UDim2.fromOffset(5 * s, 5 * s), UDim2.fromScale(0.5, 0.5))
		Ui.corner(99).Parent = dot
		add(dot)
	elseif style == "Circle" then
		local ring = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18 * s, 18 * s),
			BackgroundTransparency = 1,
			Parent = root,
		}, { Ui.corner(99), Ui.make("UIStroke", { Thickness = 2, Color = color }) })
		table.insert(self.parts, ring)
		local dot = bar(root, UDim2.fromOffset(3 * s, 3 * s), UDim2.fromScale(0.5, 0.5))
		Ui.corner(99).Parent = dot
		add(dot)
	else -- Cross
		local gap, len, thick = 4 * s, 7 * s, 2 * math.max(1, s * 0.9)
		add(bar(root, UDim2.fromOffset(thick, len), UDim2.new(0.5, 0, 0.5, -(gap + len / 2))))
		add(bar(root, UDim2.fromOffset(thick, len), UDim2.new(0.5, 0, 0.5, gap + len / 2)))
		add(bar(root, UDim2.fromOffset(len, thick), UDim2.new(0.5, -(gap + len / 2), 0.5, 0)))
		add(bar(root, UDim2.fromOffset(len, thick), UDim2.new(0.5, gap + len / 2, 0.5, 0)))
	end
end

local function flashMarker(self: Crosshair, color: Color3)
	for _, mark in self.marker do
		mark.BackgroundColor3 = color
		mark.BackgroundTransparency = 0
		local s = mark:FindFirstChildOfClass("UIStroke") :: UIStroke
		s.Transparency = 0.4
		Ui.tween(mark, TweenInfo.new(0.22), { BackgroundTransparency = 1 })
		Ui.tween(s, TweenInfo.new(0.22), { Transparency = 1 })
	end
end

function Crosshair.hit(self: Crosshair)
	flashMarker(self, Color3.new(1, 1, 1))
	Ui.pop(self.root, 0.12)
end

function Crosshair.miss(self: Crosshair)
	for _, p in self.parts do
		p.BackgroundColor3 = Ui.Color.Bad
		Ui.tween(p, TweenInfo.new(0.2), { BackgroundColor3 = self.color })
	end
end

function Crosshair.setVisible(self: Crosshair, visible: boolean)
	self.root.Visible = visible
end

return Crosshair
