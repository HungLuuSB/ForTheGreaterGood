--!strict
-- Transports as drawn (C-273, the user: "The transport must descend from
-- the air, grab the unit model under its belly and rise up again, same
-- for dropping them"). While it carries a unit, that unit's model hangs
-- under its belly. Picking up or setting down (Core/TransportLift), the
-- drawn transport comes down until the hanging model would stand on the
-- ground, sliding over the unit it picks up, then rises again. The server's
-- transport only hovers; this is the look (guide 14: visual only).

local TransportLift = require("../Core/TransportLift")
local World = require("../Core/World")
local ModelPool = require("./ModelPool")
local Models = require("./Models")

local Transports = {}

Transports.GAP = 0.4 -- studs between the belly and the top of the unit it carries

type Measure = { top: number, bottom: number } -- a model's top and bottom over its reference point (studs)
type Slung = { model: Model, root: BasePart, rootOffset: CFrame, def: any, team: number }

export type State = {
	lift: TransportLift.State,
	slung: { [number]: Slung }, -- by transport
	measures: { [Model]: Measure }, -- by template
}

function Transports.new(): State
	return { lift = TransportLift.new(), slung = {}, measures = {} }
end

-- How far a def's model reaches above and below its reference point (the
-- spot UnitRenderer places: the ground under a unit, the belly height of
-- an aircraft's flight), from its template.
local function measure(s: State, def: any): Measure
	local template = Models.template(def)
	local m = s.measures[template]
	if m then
		return m
	end
	local root = template.PrimaryPart
	local offset = (template:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
	local ref = if root then (root.CFrame * offset:Inverse()).Position.Y else 0
	local box, size = template:GetBoundingBox()
	m = { top = box.Position.Y + size.Y / 2 - ref, bottom = box.Position.Y - size.Y / 2 - ref }
	s.measures[template] = m
	return m
end

-- The def of the unit transport `u` carries now (the first on board), or nil.
local function carried(world: World.World, u: World.Unit): any?
	local index = u.cargoDefs and u.cargoDefs[1]
	return if index and index ~= 0 then world.defs.unitByIndex[index] else nil
end

-- The def a lift is about: the unit picked up (still on the ground), or the one on board.
local function liftDef(s: State, world: World.World, u: World.Unit): any?
	local l = s.lift.lifts[u.id]
	if l and l.kind == "pickup" then
		local target = world.units[l.unitId]
		if target then
			return World.def(world, target)
		end
	end
	return carried(world, u)
end

-- UnitRenderer.adjust: a transport lifting comes down by its share of the
-- way to where its hanging unit stands on the ground, sliding over the
-- unit it picks up.
function Transports.adjust(s: State, world: World.World): (u: World.Unit, def: any, t: number, x: number, y: number, z: number) -> (number, number, number)
	return function(u: World.Unit, def: any, t: number, x: number, y: number, z: number): (number, number, number)
		if def.transport == nil then
			return x, y, z
		end
		local share, ox, oz = TransportLift.of(s.lift, u.id, t)
		if share == nil or share <= 0 then
			return x, y, z
		end
		local cdef = liftDef(s, world, u)
		local top = if cdef then measure(s, cdef).top else 3
		local gx, gz = ox or x, oz or z
		local low = World.groundY(world, gx, gz) - measure(s, def).bottom + Transports.GAP + top
		local dy = math.max(0, y - low)
		if ox and oz then
			x, z = x + (ox - x) * share, z + (oz - z) * share
		end
		return x, y - dy * share, z
	end
end

local function release(sl: Slung)
	for _, d in sl.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = true -- (ModelPool's default: clicks pick unit models)
		end
	end
	ModelPool.release(sl.model)
end

-- Each frame after UnitRenderer.step (`t`: the render tick): steps the
-- lifts from own transports' orders (`byUnit`: Waypoints' lists) and hangs
-- each carried unit's model under its transport as drawn.
function Transports.step(s: State, world: World.World, byUnit: { [number]: { any } }, t: number)
	TransportLift.step(s.lift, world, byUnit, t)
	for id, sl in s.slung do
		local u = world.units[id]
		local cdef = u and u.rx and carried(world, u)
		if u == nil or cdef ~= sl.def or u.team ~= sl.team then
			release(sl)
			s.slung[id] = nil
		end
	end
	for id, u in world.units do
		local def = World.def(world, u)
		if def == nil or def.transport == nil or u.rx == nil then
			continue
		end
		local cdef = carried(world, u)
		if cdef == nil then
			continue
		end
		local sl = s.slung[id]
		if sl == nil then
			local model = ModelPool.acquire(cdef, u.team)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanQuery = false -- a click goes to the transport
				end
			end
			sl = {
				model = model,
				root = model.PrimaryPart :: BasePart,
				rootOffset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity,
				def = cdef,
				team = u.team,
			}
			s.slung[id] = sl
		end
		local belly = (u.ry :: number) + measure(s, def).bottom - Transports.GAP
		local y = belly - measure(s, cdef).top
		local heading = u.rheading or u.heading
		sl.root.CFrame = CFrame.new(u.rx :: number, y, u.rz :: number) * CFrame.Angles(0, heading + math.pi, 0) * sl.rootOffset
	end
end

-- Lets every hanging model go (match restart).
function Transports.clear(s: State)
	for _, sl in s.slung do
		release(sl)
	end
	table.clear(s.slung)
	table.clear(s.lift.lifts)
end

return Transports
