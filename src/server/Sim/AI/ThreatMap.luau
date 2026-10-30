--!strict
-- The skirmish AI's threat map (S-222, after BAR's CircuitAI): a coarse
-- grid of what its team knows about enemy firepower. Built from the team's
-- sensors only (D101, D107), like everything the AI reads:
--   surface  each known armed enemy (not aircraft) adds its value to every
--            cell its surface weapons reach (range + PAD): what would fire
--            on a ground unit or a building standing there;
--   army     each identified armed enemy ground unit or ship adds its value
--            to the cell it stands in: where the enemy army is.
-- A unit's value is supply + power / 10 (S-92). An unidentified contact
-- (D107) counts as UNKNOWN_VALUE with UNKNOWN_RANGE. Remembered structures
-- (ghosts) count where they were seen.

local Categories = require("@shared/Defs/Categories")
local Defs = require("@shared/Defs/Defs")
local Passability = require("@shared/Grid/Passability")
local Sensors = require("../Sensors")
local Types = require("../Types")
local World = require("../World")

local ThreatMap = {}

ThreatMap.CELL = 64 -- studs
ThreatMap.PAD = 32 -- studs beyond a weapon's range that still count as in reach
ThreatMap.UNKNOWN_VALUE = 300 -- an unidentified contact: about a T1 tank (Skirmish.UNIT_VALUE)
ThreatMap.UNKNOWN_RANGE = 150
ThreatMap.GROUP_CELLS = 2 -- a group: the army cells within this many cells (5 × 5, 320 studs)

local BIT = Categories.Bit
local SURFACE = bit32.bor(BIT.GROUND, BIT.NAVAL, BIT.STRUCTURE)

export type Map = {
	cols: number,
	rows: number,
	originX: number,
	originZ: number,
	surface: { number },
	army: { number },
	armyCells: { number }, -- cells with army value, in the order first stamped
	tick: number,
}

-- A def's value: supply + power / 10 (S-92).
function ThreatMap.value(d: Defs.UnitDef): number
	return d.cost.supply + d.cost.power / 10
end

-- The longest range among a def's weapons that pick surface targets on
-- their own (0: none; manual-fire weapons such as nukes don't count).
local surfaceRanges: { [Defs.UnitDef]: number } = setmetatable({}, { __mode = "k" }) :: any
function ThreatMap.surfaceRange(defs: Defs.DefSet, d: Defs.UnitDef): number
	local r = surfaceRanges[d]
	if r == nil then
		r = 0
		for _, slot in d.weapons do
			local wd = defs.weapons[slot.def]
			if bit32.band(wd.targetMask, SURFACE) ~= 0 and not wd.manualFire then
				r = math.max(r, wd.range)
			end
		end
		surfaceRanges[d] = r
	end
	return r :: number
end

local function stamp(m: Map, x: number, z: number, v: number, range: number)
	local CELL = ThreatMap.CELL
	local r = range + ThreatMap.PAD
	local c0 = math.max(0, math.floor((x - r - m.originX) / CELL))
	local c1 = math.min(m.cols - 1, math.floor((x + r - m.originX) / CELL))
	local r0 = math.max(0, math.floor((z - r - m.originZ) / CELL))
	local r1 = math.min(m.rows - 1, math.floor((z + r - m.originZ) / CELL))
	local r2 = r * r
	local s = m.surface
	for row = r0, r1 do
		local cz = m.originZ + (row + 0.5) * CELL
		local dz2 = (cz - z) ^ 2
		for col = c0, c1 do
			local cx = m.originX + (col + 0.5) * CELL
			if (cx - x) ^ 2 + dz2 <= r2 then
				local i = row * m.cols + col + 1
				s[i] += v
			end
		end
	end
end

local function cellIndex(m: Map, x: number, z: number): number
	local col = math.clamp(math.floor((x - m.originX) / ThreatMap.CELL), 0, m.cols - 1)
	local row = math.clamp(math.floor((z - m.originZ) / ThreatMap.CELL), 0, m.rows - 1)
	return row * m.cols + col + 1
end

-- The threat map of ally team `ally` now.
function ThreatMap.build(sim: Types.Sim, ally: number): Map
	local g = (sim.map :: Passability.PassMap).grid
	local cols = math.ceil(g.sizeX / ThreatMap.CELL)
	local rows = math.ceil(g.sizeZ / ThreatMap.CELL)
	local m: Map = {
		cols = cols,
		rows = rows,
		originX = g.originX,
		originZ = g.originZ,
		surface = table.create(cols * rows, 0),
		army = table.create(cols * rows, 0),
		armyCells = {},
		tick = sim.tick,
	}
	local w = sim.world
	local function consider(id: number, gen: number?)
		local kx, kz, level, defIndex = Sensors.knownTarget(sim, ally, id, gen)
		if kx == nil or kz == nil then
			return
		end
		local shown = Sensors.shownDef(sim, ally, id, level, defIndex :: number) -- a decoy counts as what it shows (S-109)
		local v, range, mobile
		if shown then
			local d = sim.defs.unitByIndex[shown]
			if d.domain == "air" then
				return
			end
			range = ThreatMap.surfaceRange(sim.defs, d)
			if range <= 0 then
				return
			end
			v = ThreatMap.value(d)
			mobile = d.domain ~= "structure"
		else
			if bit32.band(Sensors.knownCategories(sim, ally, id, level, defIndex :: number), Sensors.DOMAIN_MASK.air) ~= 0 then
				return
			end
			-- in the threat, not the army: a blip may be a worker or the
			-- Commander, and blips counted as tanks made one side's groups
			-- look half again as big as the other's (a side bias, S-31)
			v, range, mobile = ThreatMap.UNKNOWN_VALUE, ThreatMap.UNKNOWN_RANGE, false
		end
		stamp(m, kx, kz, v, range)
		if mobile then
			local i = cellIndex(m, kx, kz)
			if m.army[i] == 0 then
				table.insert(m.armyCells, i)
			end
			m.army[i] += v
		end
	end
	for _, id in w.ids do
		if w.ally[id] ~= ally then
			consider(id)
		end
	end
	for _, gid in sim.sensors.ghostIds[ally] or {} do
		local ghost = sim.sensors.ghosts[ally][gid]
		if not World.isRef(w, gid, ghost.gen) then
			consider(gid, ghost.gen)
		end
	end
	return m
end

-- Built once per tick per ally team: allied brains thinking in the same
-- tick share it.
local cache: { [any]: { [number]: Map } } = setmetatable({}, { __mode = "k" }) :: any
function ThreatMap.of(sim: Types.Sim, ally: number): Map
	local perSim = cache[sim]
	if perSim == nil then
		perSim = {}
		cache[sim] = perSim
	end
	local m = perSim[ally]
	if m == nil or m.tick ~= sim.tick then
		m = ThreatMap.build(sim, ally)
		perSim[ally] = m
	end
	return m
end

-- The surface threat at (x, z): the value of the known enemies that reach it.
function ThreatMap.at(m: Map, x: number, z: number): number
	return m.surface[cellIndex(m, x, z)]
end

-- The strongest known enemy group: the most army value within GROUP_CELLS
-- cells of one army cell, and that cell's centre.
function ThreatMap.strongestGroup(m: Map): (number, number, number)
	local best, bx, bz = 0, 0, 0
	local k = ThreatMap.GROUP_CELLS
	for _, i in m.armyCells do
		local col, row = (i - 1) % m.cols, (i - 1) // m.cols
		local sum = 0
		for r = math.max(0, row - k), math.min(m.rows - 1, row + k) do
			for c = math.max(0, col - k), math.min(m.cols - 1, col + k) do
				sum += m.army[r * m.cols + c + 1]
			end
		end
		if sum > best then
			best = sum
			bx = m.originX + (col + 0.5) * ThreatMap.CELL
			bz = m.originZ + (row + 0.5) * ThreatMap.CELL
		end
	end
	return best, bx, bz
end

return ThreatMap
