--!strict
-- Health and build-progress bars (guide 15.7, C-24): which units get bars
-- and what they show. Only selected units, damaged units and frames under
-- construction (own, or enemies in sight) get bars; a healthy, finished,
-- unselected unit gets none, so big armies stay clean. A frame shows two
-- bars (health over build progress); a finished unit one, and a factory
-- that is producing a second (amber) bar with the item's progress, always
-- shown for own and allied factories (C-168). The sim grows a
-- frame's health with its progress and damage never lowers progress
-- (Sim/Build), so the client only displays both numbers. Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local World = require("./World")

local Bars = {}

Bars.FULL = 0.999 -- at or above: counts as full (health is a u8 on the wire)

-- `stock` / `stockMax`: an own unit's missiles in stock and its capacity
-- (S-47, C-56); a unit that isn't full shows its bar, so a refilling SAM site
-- stays visible.
-- A wreck's bar (protocol 35, S-168; C-216) has `wreck` set and `id` its
-- wreck ID: `supplyShare` (supply / fullSupply, only below full) and `rez`
-- (resurrect progress, only above 0); `health` repeats the first row's share.
export type Bar = { id: number, health: number, build: number?, production: number?, reload: number?, own: boolean, selected: boolean, stock: number?, stockMax: number?, stockProgress: number?, wreck: boolean?, supplyShare: number?, rez: number? }

-- A factory's item progress 0..1 while it produces, else nil: as drawn
-- (eased) when the renderer has it, else the server's.
function Bars.production(u: World.Unit): number?
	local q = u.queue
	local producing = (q ~= nil and #q > 0) or (u.producing ~= nil and u.producing > 0)
	if not producing then
		return nil
	end
	return u.productionShown or (if q and #q > 0 then u.queueProgress else u.producingProgress) or 0
end

-- Bars for the tactical units (the only ones whose health is known).
function Bars.list(world: World.World, selected: { [number]: boolean }): { Bar }
	local out = {}
	for id, u in world.units do
		local shown = World.shownHealth(world, u)
		if u.tier ~= "tactical" or shown == nil then
			continue
		end
		local health = shown :: number
		local building = u.build ~= nil and (u.build :: number) < 1
		local isSel = selected[id] == true
		local stock, stockMax = World.stockOf(world, u)
		local refilling = stock ~= nil and (stock :: number) < (stockMax :: number)
		local production = if building then nil else Bars.production(u)
		-- own and allied long-reload weapons recharging (C-170)
		local friendly = u.team == world.me.team or World.relation(world, u) == "ally"
		local reload = if friendly then World.reloadOf(world, u, world.shownTick or world.latestTick) else nil
		if isSel or building or health < Bars.FULL or refilling or production ~= nil or reload ~= nil then
			table.insert(out, {
				id = id,
				health = health,
				build = if building then u.build else nil,
				production = production,
				reload = reload,
				own = u.team == world.me.team,
				selected = isSel,
				stock = stock,
				stockMax = stockMax,
				stockProgress = if refilling then World.stockProgressOf(world, u, world.shownTick or 0) else nil,
			})
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

local CORNERS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

-- Bars for known wrecks that are partly reclaimed or being resurrected
-- (C-216), in wreck ID order.
function Bars.wreckList(world: World.World): { Bar }
	local out = {}
	for id, w in world.wrecks do
		local share = if w.fullSupply > 0 then math.clamp(w.supply / w.fullSupply, 0, 1) else 1
		local partly = share < Bars.FULL
		local rezzing = w.rez > 0
		if partly or rezzing then
			table.insert(out, {
				id = id,
				health = if partly then share else w.rez,
				own = false,
				selected = false,
				wreck = true,
				supplyShare = if partly then share else nil,
				rez = if rezzing then w.rez else nil,
			})
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

Bars.MIN_WIDTH = 18 -- pixels: a bar stays readable when zoomed out
Bars.MAX_WIDTH = 90

export type Draw = { bar: Bar, x: number, y: number, width: number } -- y: the bars' top edge

Bars.GAP = 4 -- pixels between the unit's footprint and its bars

-- Where the bars go on screen: under the unit (the user, C-208): centred on
-- it, their top GAP pixels below the lowest on-screen corner of its
-- footprint at its base (where the model is drawn, altitude included), as
-- wide as the footprint looks along the camera's right vector (rightX,
-- rightZ), clamped to MIN_WIDTH..MAX_WIDTH. Off-screen bars are left out.
function Bars.draws(world: World.World, bars: { Bar }, project: (number, number, number) -> (number, number, boolean), width: number, height: number, rightX: number, rightZ: number): { Draw }
	local out = {}
	for _, b in bars do
		local def, x, z, y
		if b.wreck then
			local w = world.wrecks[b.id]
			def = world.defs.unitByIndex[w.defIndex]
			x, z = w.x, w.z
			y = World.groundY(world, x, z)
		else
			local u = world.units[b.id]
			def = World.def(world, u)
			x, z = u.rx or u.x, u.rz or u.z
			-- ry is where the model is drawn (altitude included); else ground + altitude
			y = u.ry or (World.groundY(world, x, z) + u.alt)
		end
		local size = (if def then def.footprint else 1) * Grid.CELL_SIZE
		local sx, _, front = project(x, y, z)
		local half = size / 2
		local low = -math.huge
		for _, c in CORNERS do
			local _, cy, cf = project(x + c[1] * half, y, z + c[2] * half)
			front = front and cf
			low = math.max(low, cy)
		end
		local sy = low + Bars.GAP
		if not front or sx < -60 or sy < -20 or sx > width + 60 or sy > height + 20 then
			continue
		end
		local ax = project(x - rightX * half, y, z - rightZ * half)
		local bx = project(x + rightX * half, y, z + rightZ * half)
		local w = math.clamp(math.abs(bx - ax), Bars.MIN_WIDTH, Bars.MAX_WIDTH)
		table.insert(out, { bar = b, x = sx, y = sy, width = w })
	end
	return out
end

-- Health bar color: green when full, yellow at half, red when low.
function Bars.healthColor(h: number): (number, number, number)
	h = math.clamp(h, 0, 1)
	if h >= 0.5 then
		local k = (h - 0.5) / 0.5
		return math.floor(235 - 145 * k), 220, math.floor(60 + 20 * k) -- yellow → green
	end
	local k = h / 0.5
	return 230, math.floor(60 + 160 * k), 50 -- red → yellow
end

return Bars
