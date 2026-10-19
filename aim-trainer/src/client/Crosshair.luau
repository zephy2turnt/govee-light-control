-- Crosshair: a fully customisable reticle, CS/Valorant style.
--
--   Crosshair.new(parent)
--   crosshair:apply(settings)   redraw from the player's settings:
--       chR/chG/chB      colour
--       chLength         length of each line
--       chThickness      line thickness
--       chGap            space from the centre to each line
--       chHorizontal     show left/right lines
--       chVertical       show top/bottom lines
--       chDot, chDotSize centre dot
--       chRotation       rotate the lines (45 = an x)
--       chOutline        thin black outline
--   crosshair:hit()             hit marker + small pop
--   crosshair:miss()            brief red flash
--
-- Location: StarterPlayerScripts > Client > Crosshair (ModuleScript)

local Ui = require(script.Parent.Ui)

local Crosshair = {}
Crosshair.__index = Crosshair

export type Crosshair = typeof(setmetatable({} :: {
	root: Frame,
	lines: Frame,
	parts: { Frame },
	marker: { Frame },
	color: Color3,
}, Crosshair))

local function bar(parent: Instance, size: Vector2, offset: Vector2, color: Color3, outline: boolean): Frame
	local f = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Parent = parent,
	})
	if outline then
		Ui.make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.2, Parent = f })
	end
	return f
end

function Crosshair.new(parent: Instance): Crosshair
	local self = setmetatable({}, Crosshair) :: any
	self.root = Ui.make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	-- Lines and dot live in their own frame so rotation turns only them.
	self.lines = Ui.make("Frame", {
		Name = "Lines",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.root,
	})
	self.parts = {}
	self.color = Color3.new(1, 1, 1)

	-- Hit marker: four short diagonal marks, hidden until a hit.
	self.marker = {}
	for k = 0, 3 do
		local angle = 45 + k * 90
		local rad = math.rad(angle)
		local mark = bar(self.root, Vector2.new(3, 9), Vector2.new(math.sin(rad) * 16, -math.cos(rad) * 16), Color3.new(1, 1, 1), true)
		mark.Rotation = angle
		mark.BackgroundTransparency = 1
		local s = mark:FindFirstChildOfClass("UIStroke") :: UIStroke
		s.Transparency = 1
		table.insert(self.marker, mark)
	end
	return self
end

function Crosshair.apply(self: Crosshair, settings: { [string]: any })
	for _, p in self.parts do
		p:Destroy()
	end
	self.parts = {}

	local color = Color3.fromRGB(settings.chR, settings.chG, settings.chB)
	self.color = color
	local len = settings.chLength
	local thick = settings.chThickness
	local gap = settings.chGap
	local outline = settings.chOutline == true
	self.lines.Rotation = settings.chRotation

	local function add(size: Vector2, offset: Vector2)
		table.insert(self.parts, bar(self.lines, size, offset, color, outline))
	end
	local reach = gap + len / 2
	if settings.chVertical then
		add(Vector2.new(thick, len), Vector2.new(0, -reach))
		add(Vector2.new(thick, len), Vector2.new(0, reach))
	end
	if settings.chHorizontal then
		add(Vector2.new(len, thick), Vector2.new(-reach, 0))
		add(Vector2.new(len, thick), Vector2.new(reach, 0))
	end
	if settings.chDot then
		local d = settings.chDotSize
		add(Vector2.new(d, d), Vector2.zero)
		Ui.corner(99).Parent = self.parts[#self.parts]
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
