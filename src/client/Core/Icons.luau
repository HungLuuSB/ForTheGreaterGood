--!strict
-- Strategic zoom icons (guide 15.4): what each known unit looks like as an
-- icon. Pure Luau (C-7); Render/IconLayer draws them. Tactical units use
-- their def; strategic records only carry an icon number (net.md section 3),
-- mapped back to the icon name and to a representative def for its family.

local NetIcons = require("@shared/Net/Icons")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Icons = {}

-- "sonar": a sonar contact (a submarine, or a ship heard but not seen), a hollow ring (C-31)
export type Shape = "square" | "circle" | "diamond" | "triangle" | "frame" | "blip" | "ghost" | "sonar"

export type Style = {
	shape: Shape,
	size: number, -- pixels
	team: number,
	alpha: number, -- 1 = opaque
	selected: boolean,
}

export type Table = {
	names: { string }, -- icon number → name (sorted distinct names, like NetOut.iconIndex)
	byDef: { [number]: number }, -- def index → icon number
	sample: { [number]: any }, -- icon number → a def using it (family, size)
}

-- The wire numbering, from Shared/Net/Icons (S-10), plus a sample def per
-- icon number for its family and size.
function Icons.table(defs: any): Table
	local byDef = NetIcons.byDef(defs)
	local sample = {}
	for index, def in defs.unitByIndex do
		local n = byDef[index]
		sample[n] = sample[n] or def
	end
	return { names = NetIcons.names(defs), byDef = byDef, sample = sample }
end

local function shapeOf(def: any): Shape
	if def.domain == "structure" then
		return "frame"
	elseif def.domain == "air" then
		return "triangle"
	elseif def.domain == "naval" then
		return "diamond"
	elseif def.buildOptions ~= nil then
		return "circle" -- builders: workers and Command Vehicles
	end
	return "square"
end

local function sizeOf(def: any): number
	local base = 9 + 3 * (def.tier or 1) + 2 * ((def.footprint or 1) - 1)
	if def.icon == "commander" then
		base += 6
	end
	return math.min(base, 26)
end

-- How `u` looks as an icon.
function Icons.style(t: Table, world: World.World, u: World.Unit, selected: boolean): Style
	local def = World.def(world, u)
	local flags = u.flags or 0
	if def == nil and u.icon and u.icon > 0 then
		def = t.sample[u.icon]
	end
	if bit32.band(flags, Schema.StrategicFlag.GHOST) ~= 0 then
		return { shape = "ghost", size = if def then sizeOf(def) else 12, team = u.team, alpha = 0.55, selected = false }
	end
	if bit32.band(flags, Schema.StrategicFlag.SONAR_ONLY) ~= 0 then
		return { shape = "sonar", size = if def then sizeOf(def) + 2 else 10, team = u.team, alpha = 0.8, selected = false }
	end
	if def == nil then
		-- an unidentified radar contact: only its team is known
		return { shape = "blip", size = 7, team = u.team, alpha = 0.6, selected = false }
	end
	local tracked = bit32.band(flags, Schema.StrategicFlag.TRACKED) ~= 0
	local radar = bit32.band(flags, Schema.StrategicFlag.RADAR_ONLY + Schema.StrategicFlag.SONAR_ONLY) ~= 0
	return {
		shape = shapeOf(def),
		size = sizeOf(def),
		team = u.team,
		alpha = if radar and not tracked then 0.6 else 1,
		selected = selected,
	}
end

export type Draw = { id: number, x: number, y: number, style: Style }

-- Every known unit on screen as an icon; `project` as in Selection. Selected
-- units come last so they're drawn on top.
function Icons.draws(t: Table, world: World.World, project: (number, number, number) -> (number, number, boolean), width: number, height: number, selected: { [number]: boolean }): { Draw }
	local out, top = {}, {}
	for id, u in world.units do
		local x, z = u.rx or u.x, u.rz or u.z
		local y = (u.ry or World.groundY(world, x, z)) + u.alt
		local sx, sy, front = project(x, y, z)
		if front and sx >= -20 and sy >= -20 and sx <= width + 20 and sy <= height + 20 then
			local isSel = selected[id] == true
			table.insert(if isSel then top else out, { id = id, x = sx, y = sy, style = Icons.style(t, world, u, isSel) })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	table.move(top, 1, #top, #out + 1, out)
	return out
end

-- Strategic zoom on and off by camera distance, with hysteresis.
Icons.ENTER_DISTANCE = 480
Icons.LEAVE_DISTANCE = 420

function Icons.strategic(was: boolean, distance: number): boolean
	if was then
		return distance > Icons.LEAVE_DISTANCE
	end
	return distance > Icons.ENTER_DISTANCE
end

return Icons
