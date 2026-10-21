--!strict
-- Range rings for selected units, BAR style (C-19): weapon, anti-air,
-- sight, radar, tracking and jammer ranges. Circles of the same kind merge
-- into one outline: only the arc segments not inside another circle of
-- that kind are kept. Pure Luau (C-7); Render/RangeOverlay draws the
-- polylines on the terrain.

local World = require("./World")

local Ranges = {}

Ranges.KINDS = table.freeze({ "weapon", "aa", "sight", "radar", "track", "jammer" })
Ranges.STEP = 6 -- studs between polyline points, at most
Ranges.MIN_POINTS_PER_CIRCLE = 24
Ranges.MAX_POINTS_PER_CIRCLE = 96
Ranges.LIFT = 0.35 -- studs above the ground
Ranges.NEAR = 24 -- studs: neighbours this close are checked first (union)

local TAU = 2 * math.pi
local EPS = 1e-6

-- owner: the unit the circle is centered on (the rings follow it between rebuilds, C-29); nil for the build ghost
export type Circle = { x: number, z: number, r: number, kind: string, owner: number? }
export type Arc = { x: number, z: number, r: number, a0: number, a1: number, kind: string, owner: number? } -- a0 < a1, radians
export type Polyline = { kind: string, owner: number?, points: { Vector3 | { number } } }

-- A point on a circle at angle `a`: (x + r cos a, z + r sin a).
function Ranges.at(arc: Arc, a: number): (number, number)
	return arc.x + arc.r * math.cos(a), arc.z + arc.r * math.sin(a)
end

-- Scratch arrays reused by every call (no allocation per interval).
local los: { number } = {}
local his: { number } = {}
local starts: { number } = {}
local ends: { number } = {}

-- The parts of [0, 2π) not covered by the first `n` intervals
-- (los[k], his[k]): any angles, each span shorter than 2π. Sweeps the sorted
-- starts and the sorted ends with a coverage depth, so plain number arrays
-- sort with the built-in comparator.
local function uncovered(n: number): { { number } }
	table.clear(starts)
	table.clear(ends)
	for k = 1, n do
		local a0 = los[k] % TAU
		local a1 = a0 + (his[k] - los[k])
		if a1 > TAU then
			table.insert(starts, a0)
			table.insert(ends, TAU)
			table.insert(starts, 0)
			table.insert(ends, a1 - TAU)
		else
			table.insert(starts, a0)
			table.insert(ends, a1)
		end
	end
	table.sort(starts)
	table.sort(ends)
	local out = {}
	local cursor, depth = 0, 0
	local i, j, m = 1, 1, #starts
	while j <= m do
		if i <= m and starts[i] <= ends[j] then
			if depth == 0 and starts[i] > cursor + EPS then
				table.insert(out, { cursor, starts[i] })
			end
			depth += 1
			i += 1
		else
			depth -= 1
			if depth == 0 then
				cursor = math.max(cursor, ends[j])
			end
			j += 1
		end
	end
	if cursor < TAU - EPS then
		table.insert(out, { cursor, TAU })
	end
	-- an arc that crosses angle 0 is one arc, not two
	if #out >= 2 and out[1][1] < EPS and out[#out][2] > TAU - EPS then
		local last = table.remove(out) :: { number }
		out[1] = { last[1] - TAU, out[1][2] }
	end
	return out
end

-- The outline of the union of same-kind circles, as arcs. O(n²) per kind,
-- with squared-distance early-outs; it runs only when the selection or the
-- units' positions change (Render/RangeOverlay).
function Ranges.union(circles: { Circle }): { Arc }
	local out: { Arc } = {}
	local byKind: { [string]: { Circle } } = {}
	for _, c in circles do
		if c.r > EPS then
			local list = byKind[c.kind]
			if list == nil then
				list = {}
				byKind[c.kind] = list
			end
			table.insert(list, c)
		end
	end
	for _, list in byKind do
		for i, c in list do
			local cx, cz, cr = c.x, c.z, c.r
			local n = 0
			local hidden = false
			-- near neighbours first: they sit all around a circle inside a
			-- group and cover most of its edge, so interior circles of a
			-- dense group are found covered after one cheap check
			local near2 = math.min(cr * 0.5, Ranges.NEAR) ^ 2
			for pass = 1, 2 do
				for j, o in list do
					if j == i then
						continue
					end
					local dx, dz = o.x - cx, o.z - cz
					local d2 = dx * dx + dz * dz
					if (pass == 1) ~= (d2 <= near2) then
						continue
					end
					local or_ = o.r
					local sum = cr + or_
					if d2 >= (sum - EPS) * (sum - EPS) then
						continue -- apart (or touching)
					end
					local diff = or_ - cr
					if diff >= -EPS and d2 <= (diff + EPS) * (diff + EPS) then
						-- c lies inside o (an identical circle hides only the later one)
						if not (math.abs(diff) <= EPS and d2 <= EPS and j > i) then
							hidden = true
							break
						end
						continue
					end
					if diff < 0 and d2 <= (-diff + EPS) * (-diff + EPS) then
						continue -- o inside c: c's edge is untouched
					end
					local d = math.sqrt(d2)
					local phi = math.atan2(dz, dx)
					local alpha = math.acos(math.clamp((cr * cr + d2 - or_ * or_) / (2 * cr * d), -1, 1))
					n += 1
					los[n], his[n] = phi - alpha, phi + alpha
				end
				if hidden or (pass == 1 and n >= 2 and #uncovered(n) == 0) then
					hidden = true
					break
				end
			end
			if not hidden then
				for _, span in uncovered(n) do
					table.insert(out, { x = cx, z = cz, r = cr, a0 = span[1], a1 = span[2], kind = c.kind, owner = c.owner })
				end
			end
		end
	end
	return out
end

local function targetsOnlyAir(weapon: any): boolean
	local targets = weapon.targets or {}
	return #targets > 0 and table.find(targets, "AIR") ~= nil and #targets == 1
end

-- Circles of one def at (x, z), owned by unit `owner` if given.
function Ranges.circlesOfDef(def: any, defs: any, x: number, z: number, out: { Circle }, owner: number?)
	for _, slot in def.weapons or {} do
		local weapon = defs.weaponByIndex[slot.weaponIndex]
		if weapon and weapon.range > 0 then
			table.insert(out, { x = x, z = z, r = weapon.range, kind = if targetsOnlyAir(weapon) then "aa" else "weapon", owner = owner })
		end
	end
	local s = def.sensors or {}
	for kind, r in { sight = s.sight, radar = s.radar, track = s.track, jammer = s.jam } :: { [string]: number? } do
		if r and r > 0 then
			table.insert(out, { x = x, z = z, r = r, kind = kind, owner = owner })
		end
	end
end

-- Circles of the given units: own team only (enemy ranges stay hidden; the
-- wire doesn't say which other teams are allied yet).
function Ranges.circles(world: World.World, ids: { number }): { Circle }
	local out: { Circle } = {}
	for _, id in ids do
		local u = world.units[id]
		local def = u and World.def(world, u)
		if u and def and u.team == world.me.team then
			Ranges.circlesOfDef(def, world.defs, u.rx or u.x, u.rz or u.z, out, id)
		end
	end
	return out
end

-- Arcs as point lists on the terrain (`groundY(x, z)`), at most STEP apart.
function Ranges.polylines(arcs: { Arc }, groundY: (number, number) -> number): { { any } }
	local out = {}
	for _, arc in arcs do
		local span = arc.a1 - arc.a0
		local perCircle = math.clamp(math.ceil(TAU * arc.r / Ranges.STEP), Ranges.MIN_POINTS_PER_CIRCLE, Ranges.MAX_POINTS_PER_CIRCLE)
		local n = math.max(1, math.ceil(perCircle * span / TAU))
		local points = {}
		for k = 0, n do
			local a = arc.a0 + span * k / n
			local x, z = Ranges.at(arc, a)
			table.insert(points, { x, groundY(x, z) + Ranges.LIFT, z })
		end
		table.insert(out, { kind = arc.kind, owner = arc.owner, points = points })
	end
	return out
end

return Ranges
