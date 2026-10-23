--!strict
-- Placeholder minimap and resource bar logic (guide 15.7, 15.8). Pure Luau
-- (C-7); UI/Minimap and UI/ResourceBar draw it. Placeholder UI: it shows
-- what the client knows, the look is temporary.

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Minimap = {}

Minimap.BLOCK = 4 -- cells per terrain tile side
Minimap.REFRESH = 1 / 10 -- seconds between unit dot refreshes (guide 15.8 says the strategic rate; the user asked for faster, C-99)

-- World studs → minimap fraction (0..1), north (-Z) up.
function Minimap.toMap(grid: Grid.Grid, x: number, z: number): (number, number)
	return (x - grid.originX) / grid.sizeX, (z - grid.originZ) / grid.sizeZ
end

-- Minimap fraction → world studs (clicks).
function Minimap.toWorld(grid: Grid.Grid, u: number, v: number): (number, number)
	return grid.originX + math.clamp(u, 0, 1) * grid.sizeX, grid.originZ + math.clamp(v, 0, 1) * grid.sizeZ
end

export type Tile = { u: number, v: number, w: number, h: number, height: number, water: number, supply: number }

-- The terrain as tiles of BLOCK × BLOCK cells, merged with equal
-- neighbours along a row (average height, deepest water, any deposit).
function Minimap.terrain(layers: Layers.Layers): { Tile }
	local g = layers.grid
	local b = Minimap.BLOCK
	local rows = {}
	for bz = 0, g.cellsZ - 1, b do
		local row: { Tile } = {}
		for bx = 0, g.cellsX - 1, b do
			local sum, n, water, supply = 0, 0, 0, 0
			for cz = bz, math.min(bz + b, g.cellsZ) - 1 do
				for cx = bx, math.min(bx + b, g.cellsX) - 1 do
					local i = g:index(cx, cz)
					sum += Layers.getHeight(layers, i)
					n += 1
					water = math.max(water, Layers.getWater(layers, i))
					supply = math.max(supply, Layers.getSupply(layers, i))
				end
			end
			local height = math.floor(sum / n + 0.5)
			local w = math.min(b, g.cellsX - bx) / g.cellsX
			local last = row[#row]
			if last and last.height == height and last.water == water then
				last.w += w
			else
				table.insert(row, { u = bx / g.cellsX, v = bz / g.cellsZ, w = w, h = math.min(b, g.cellsZ - bz) / g.cellsZ, height = height, water = water, supply = supply })
			end
		end
		table.move(row, 1, #row, #rows + 1, rows)
	end
	return rows
end

export type Dot = { id: number, u: number, v: number, team: number, kind: "unit" | "structure" | "blip" | "ghost", selected: boolean, attacked: boolean } -- attacked: the server's UNDER_ATTACK flag (S-68)

Minimap.ICON_SCALE = 0.5 -- the minimap's unit icons against the strategic layer's (Icons.BASE 22: about 11 pixels; C-122)

local DRAW_ORDER = { ghost = 1, structure = 2, unit = 3, blip = 3 }

-- One dot per known unit, ghosts and structures first, selected units last
-- (drawn in this order, so the selection stays on top).
function Minimap.dots(world: World.World, selected: { [number]: boolean }): { Dot }
	local g = world.grid
	local out = {}
	for id, u in world.units do
		local x, z = u.rx or u.sx or u.x, u.rz or u.sz or u.z
		local mu, mv = Minimap.toMap(g, x, z)
		local flags = u.flags or 0
		local def = World.def(world, u)
		local kind: "unit" | "structure" | "blip" | "ghost" = "unit"
		if bit32.band(flags, Schema.StrategicFlag.GHOST) ~= 0 then
			kind = "ghost"
		elseif def == nil and (u.icon or 0) == 0 then
			kind = "blip"
		elseif def and def.domain == "structure" then
			kind = "structure"
		end
		table.insert(out, { id = id, u = mu, v = mv, team = u.team, kind = kind, selected = selected[id] == true, attacked = bit32.band(flags, Schema.StrategicFlag.UNDER_ATTACK) ~= 0 })
	end
	table.sort(out, function(a, b)
		local oa, ob = DRAW_ORDER[a.kind] + (if a.selected then 10 else 0), DRAW_ORDER[b.kind] + (if b.selected then 10 else 0)
		if oa ~= ob then
			return oa < ob
		end
		return a.id < b.id
	end)
	return out
end

-- The camera's cell rectangle as minimap fractions (u0, v0, u1, v1).
function Minimap.cameraBox(grid: Grid.Grid, rect: { number }): (number, number, number, number)
	return rect[1] / grid.cellsX, rect[2] / grid.cellsZ, (rect[3] + 1) / grid.cellsX, (rect[4] + 1) / grid.cellsZ
end

-- Resource bar text: "stored / storage  +income  -demand" with a stall flag.
export type ResLine = { text: string, fill: number, stalling: boolean }

local function short(n: number): string
	if n >= 10000 then
		return string.format("%.0fk", n / 1000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return string.format("%d", math.floor(n + 0.5))
end

function Minimap.resLine(name: string, r: any): ResLine
	if r == nil then
		return { text = `{name}: waiting for the server`, fill = 0, stalling = false }
	end
	local stalling = r.ratio < 0.999
	local text = `{name} {short(r.stored)} / {short(r.storage)}   +{string.format("%.1f", r.income)}  -{string.format("%.1f", r.demand)}`
	if stalling then
		text ..= string.format("   STALL %d%%", math.floor(r.ratio * 100 + 0.5))
	end
	return { text = text, fill = if r.storage > 0 then math.clamp(r.stored / r.storage, 0, 1) else 0, stalling = stalling }
end

return Minimap
