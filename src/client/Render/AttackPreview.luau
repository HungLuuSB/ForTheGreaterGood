--!strict
-- Draws attack mode's preview (C-58, Core/AttackPreview): while the A key's
-- attack mode is on with a silo selected, the arc its nuke would fly to the
-- point under the cursor, the blast ring there, and a label with the flight
-- time and the stock (an order on an empty silo waits and fires when the
-- next nuke is built, S-48). Always-on-top line adornments on the Terrain
-- (default ZIndex, culling off), like the launch warning. Looks are
-- placeholders.

local Players = game:GetService("Players")

local AttackPreview = require("../Core/AttackPreview")
local World = require("../Core/World")

local Render = {}

local ARC = Color3.fromRGB(255, 170, 60)
local BLAST = Color3.fromRGB(255, 60, 40)
local OUT_OF_RANGE = Color3.fromRGB(150, 150, 150)
local BOLT = Color3.fromRGB(255, 170, 60) -- the D-Gun's ring colour (RangeOverlay)
local DOOMED = Color3.fromRGB(255, 60, 40)
local BOLT_STEP = 4 -- studs per drawn segment along the ground
local RING_SEGMENTS = 48

export type State = {
	folder: Folder,
	lines: { LineHandleAdornment },
	used: number,
	label: TextLabel,
}

function Render.new(): State
	local gui = Instance.new("ScreenGui")
	gui.Name = "AttackPreview"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- positioned in viewport coordinates
	gui.DisplayOrder = 6
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Size = UDim2.fromOffset(320, 20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 15
	label.TextColor3 = ARC
	label.TextStrokeTransparency = 0.4
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Visible = false
	label.Parent = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local folder = Instance.new("Folder")
	folder.Name = "AttackPreview"
	folder.Parent = workspace
	return { folder = folder, lines = {}, used = 0, label = label }
end

local function line(s: State, a: Vector3, b: Vector3, color: Color3, thickness: number, transparency: number)
	s.used += 1
	local l = s.lines[s.used]
	if l == nil then
		local inst = Instance.new("LineHandleAdornment")
		inst.Adornee = workspace.Terrain
		inst.AlwaysOnTop = true
		inst.AdornCullingMode = Enum.AdornCullingMode.Never
		inst.Parent = s.folder
		s.lines[s.used] = inst
		l = inst
	end
	l.CFrame = CFrame.lookAt(a, b)
	l.Length = math.max((b - a).Magnitude, 0.01)
	l.Color3 = color
	l.Thickness = thickness
	l.Transparency = transparency
	l.Visible = true
end

local function ring(s: State, world: World.World, x: number, z: number, r: number, color: Color3)
	local prev: Vector3? = nil
	for i = 0, RING_SEGMENTS do
		local a = i / RING_SEGMENTS * 2 * math.pi
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		local p = Vector3.new(px, World.groundY(world, px, pz) + 1, pz)
		if prev then
			line(s, prev, p, color, 3, 0.25)
		end
		prev = p
	end
end

-- A path on the ground from (x0, z0) to (x1, z1), offset `side` studs to its
-- left, following the terrain; every other segment when `dashed`.
local function groundPath(s: State, world: World.World, x0: number, z0: number, x1: number, z1: number, side: number, color: Color3, thickness: number, dashed: boolean)
	local dx, dz = x1 - x0, z1 - z0
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-3 then
		return
	end
	local nx, nz = -dz / len * side, dx / len * side
	local n = math.max(1, math.ceil(len / BOLT_STEP))
	local prev: Vector3? = nil
	for i = 0, n do
		local px, pz = x0 + dx * i / n + nx, z0 + dz * i / n + nz
		local p = Vector3.new(px, World.groundY(world, px, pz) + 1, pz)
		if prev and (not dashed or i % 2 == 0) then
			line(s, prev, p, color, thickness, 0.15)
		end
		prev = p
	end
end

-- D-Gun mode's preview (C-264): each Commander's bolt as a band its width
-- (the hitbox) over its whole range from the Commander, and a red ring on
-- every unit in its way.
local function bolts(s: State, world: World.World, selection: { number }, aim: Vector3, targetId: number?)
	for _, b in AttackPreview.bolts(world, selection, aim.X, aim.Z, targetId) do
		groundPath(s, world, b.x0, b.z0, b.x1, b.z1, b.reach, BOLT, 3, false)
		groundPath(s, world, b.x0, b.z0, b.x1, b.z1, -b.reach, BOLT, 3, false)
		groundPath(s, world, b.x0, b.z0, b.x1, b.z1, 0, BOLT, 2, true)
		local dx, dz = b.x1 - b.x0, b.z1 - b.z0
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len * b.reach, dx / len * b.reach
		groundPath(s, world, b.x0 + nx, b.z0 + nz, b.x0 - nx, b.z0 - nz, 0, BOLT, 3, false) -- the ends
		groundPath(s, world, b.x1 + nx, b.z1 + nz, b.x1 - nx, b.z1 - nz, 0, BOLT, 3, false)
		for _, id in b.hits do
			local o = world.units[id]
			local def = World.def(world, o)
			ring(s, world, o.x, o.z, (if def then def.footprint else 1) * 4, DOOMED)
		end
	end
end

-- `aim`: the ground point under the cursor while attack mode is on, else nil;
-- `boltAim`: the same while D-Gun mode is on, and `boltUnit` the unit under it.
function Render.step(s: State, world: World.World, selection: { number }, aim: Vector3?, cam: Camera, boltAim: Vector3?, boltUnit: number?)
	s.used = 0
	if boltAim then
		bolts(s, world, selection, boltAim, boltUnit)
	end
	local arcs = if aim then AttackPreview.arcs(world, selection, aim.X, aim.Z) else {}
	for _, arc in arcs do
		local color = if arc.inRange then ARC else OUT_OF_RANGE
		local prev: Vector3? = nil
		for i, p in arc.points do
			local v = Vector3.new(p[1], p[2], p[3])
			-- dashed: every other segment
			if prev and i % 2 == 0 then
				line(s, prev, v, color, 3, 0.15)
			end
			prev = v
		end
	end
	-- bombers' carpets: a blast ring on every bomb's spot, joined along the run
	if aim then
		for _, c in AttackPreview.carpets(world, selection, aim.X, aim.Z) do
			local prev: Vector3? = nil
			for _, p in c.points do
				ring(s, world, p[1], p[2], c.weapon.aoe or 0, BLAST)
				local v = Vector3.new(p[1], World.groundY(world, p[1], p[2]) + 1, p[2])
				if prev then
					line(s, prev, v, BLAST, 2, 0.35)
				end
				prev = v
			end
		end
	end
	local first = arcs[1]
	if first then
		ring(s, world, first.x, first.z, first.weapon.aoe or 0, if first.inRange then BLAST else OUT_OF_RANGE)
		local stock = 0
		for _, arc in arcs do
			stock += arc.stock or 0
		end
		local text = if not first.inRange
			then "out of range"
			elseif stock > 0 then string.format("impact in %.1f s  -  %d in stock", first.seconds, stock)
			else string.format("impact in %.1f s  -  empty: fires when built", first.seconds)
		local v = cam:WorldToViewportPoint(Vector3.new(first.x, World.groundY(world, first.x, first.z), first.z))
		s.label.Position = UDim2.fromOffset(v.X + 16, v.Y - 8)
		s.label.Text = text
		s.label.TextColor3 = if first.inRange then ARC else OUT_OF_RANGE
		s.label.Visible = true
	elseif s.label.Visible then
		s.label.Visible = false
	end
	for i = s.used + 1, #s.lines do
		if s.lines[i].Visible then
			s.lines[i].Visible = false
		end
	end
end

return Render
