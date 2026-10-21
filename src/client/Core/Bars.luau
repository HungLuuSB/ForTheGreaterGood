--!strict
-- Health and build-progress bars (guide 15.7, C-24): which units get bars
-- and what they show. Only selected units, damaged units and frames under
-- construction (own, or enemies in sight) get bars; a healthy, finished,
-- unselected unit gets none, so big armies stay clean. A frame shows two
-- bars (health over build progress); a finished unit one. The sim grows a
-- frame's health with its progress and damage never lowers progress
-- (Sim/Build), so the client only displays both numbers. Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local World = require("./World")

local Bars = {}

Bars.FULL = 0.999 -- at or above: counts as full (health is a u8 on the wire)

-- `stock` / `stockMax`: an own unit's missiles in stock and its capacity
-- (S-47, C-56); a unit that isn't full shows its bar, so a refilling SAM site
-- stays visible.
export type Bar = { id: number, health: number, build: number?, own: boolean, selected: boolean, stock: number?, stockMax: number?, stockProgress: number? }

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
		if isSel or building or health < Bars.FULL or refilling then
			table.insert(out, {
				id = id,
				health = health,
				build = if building then u.build else nil,
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

Bars.MIN_WIDTH = 18 -- pixels: a bar stays readable when zoomed out
Bars.MAX_WIDTH = 90

export type Draw = { bar: Bar, x: number, y: number, width: number }

-- Where the bars go on screen: centered above the unit, as wide as its
-- footprint looks along the camera's right vector (rightX, rightZ),
-- clamped to MIN_WIDTH..MAX_WIDTH. Off-screen bars are left out.
function Bars.draws(world: World.World, bars: { Bar }, project: (number, number, number) -> (number, number, boolean), width: number, height: number, rightX: number, rightZ: number): { Draw }
	local out = {}
	for _, b in bars do
		local u = world.units[b.id]
		local def = World.def(world, u)
		local size = (if def then def.footprint else 1) * Grid.CELL_SIZE
		local x, z = u.rx or u.x, u.rz or u.z
		-- ry is where the model is drawn (altitude included); else ground + altitude
		local y = (u.ry or (World.groundY(world, x, z) + u.alt)) + size * 0.6 + 3
		local sx, sy, front = project(x, y, z)
		if not front or sx < -60 or sy < -20 or sx > width + 60 or sy > height + 20 then
			continue
		end
		local half = size / 2
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
