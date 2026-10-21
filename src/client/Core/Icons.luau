--!strict
-- Strategic zoom icons (guide 15.4): what each known unit looks like as an
-- icon. Pure Luau (C-7); Render/IconLayer draws them. Tactical units use
-- their def; strategic records carry an icon number (net.md section 3),
-- which since S-58 is the unit's def index. The pictures are the user's
-- icon set (C-74, BAR style: frame = unit type, dots = tech level, symbol =
-- weapon or role) on one sprite sheet, UI/IconAtlas: a unit shows its type's
-- tile in team color, a ghost the same tile at 45% opacity, a radar or sonar
-- contact the dashed frame with no symbol (its type's frame when the type is
-- known, else by what it is: aircraft, submarine, else a vehicle).

local NetIcons = require("@shared/Net/Icons")
local Schema = require("@shared/Net/Schema")
local IconAtlas = require("../UI/IconAtlas")
local World = require("./World")

local Icons = {}

export type Kind = "unit" | "ghost" | "contact"

export type Style = {
	kind: Kind,
	tile: string, -- IconAtlas tile key
	size: number, -- width in pixels (height from the tile's aspect)
	team: number,
	alpha: number, -- 1 = opaque
	selected: boolean,
}

export type Table = {
	names: { string }, -- the icon family names (sorted)
	byDef: { [number]: number }, -- def index → icon number (the def index, S-58)
	sample: { [number]: any }, -- icon number → its def
	codes: { [number]: string }, -- def index → its unique two-letter code (C-67)
}

-- Icon width in pixels for a T1 unit at strategic zoom; tiers scale it
-- (IconAtlas: ×1.15 T2, ×1.3 T3, ×1.35 the Command Vehicle).
Icons.BASE = 22
Icons.GHOST_ALPHA = 1 - IconAtlas.GHOST_TRANSPARENCY
-- a radar contact this high (studs) is drawn in the aircraft frame
Icons.AIR_ALT = 8

-- Two-letter codes from the unit names, unique over every unit def (in def
-- order): the initials of a two-word name, else its first letter with a
-- later one, else a digit (C-67).
function Icons.codes(defs: any): { [number]: string }
	local out, used = {}, {}
	for index, def in defs.unitByIndex do
		local words = {}
		for w in string.gmatch(def.name or def.id, "%a+") do
			table.insert(words, w)
		end
		local first = string.upper(string.sub(words[1] or "X", 1, 1))
		local cands = {}
		if #words >= 2 then
			table.insert(cands, first .. string.upper(string.sub(words[2], 1, 1)))
			table.insert(cands, first .. string.upper(string.sub(words[#words], 1, 1)))
		end
		local rest = string.lower(table.concat(words, ""))
		for k = 2, #rest do
			table.insert(cands, first .. string.sub(rest, k, k))
		end
		for d = 1, 9 do
			table.insert(cands, first .. d)
		end
		for _, c in cands do
			if not used[c] then
				used[c] = true
				out[index] = c
				break
			end
		end
	end
	return out
end

-- The wire numbering, from Shared/Net/Icons (S-10), plus a sample def per
-- icon number.
function Icons.table(defs: any): Table
	local byDef = NetIcons.byDef(defs)
	local sample = {}
	for index, def in defs.unitByIndex do
		local n = byDef[index]
		sample[n] = sample[n] or def
	end
	return { names = NetIcons.names(defs), byDef = byDef, sample = sample, codes = Icons.codes(defs) }
end

-- A unit type's icon in `team` color, `base` pixels wide before its tier
-- scale (the build grid and unit panel use this too).
function Icons.ofDef(def: any, team: number, base: number?): Style
	local e = IconAtlas.byDef[def.id]
	return { kind = "unit", tile = e.tile, size = math.floor((base or Icons.BASE) * e.scale + 0.5), team = team, alpha = 1, selected = false }
end

-- How `u` looks as an icon.
function Icons.style(t: Table, world: World.World, u: World.Unit, selected: boolean): Style
	local def = World.def(world, u)
	local flags = u.flags or 0
	if def == nil and u.icon and u.icon > 0 then
		def = t.sample[u.icon]
	end
	local entry = if def then IconAtlas.byDef[def.id] else nil
	if bit32.band(flags, Schema.StrategicFlag.GHOST) ~= 0 and entry then
		local s = Icons.ofDef(def, u.team)
		s.kind, s.alpha = "ghost", Icons.GHOST_ALPHA
		return s
	end
	local tracked = bit32.band(flags, Schema.StrategicFlag.TRACKED) ~= 0
	local sonar = bit32.band(flags, Schema.StrategicFlag.SONAR_ONLY) ~= 0
	local radar = bit32.band(flags, Schema.StrategicFlag.RADAR_ONLY) ~= 0
	if entry == nil or sonar or (radar and not tracked) then
		-- a contact: only the frame shows what it is
		local frame = if entry then entry.frame elseif sonar then "sub" elseif (u.alt or 0) > Icons.AIR_ALT then "air" else "vehicle"
		return { kind = "contact", tile = IconAtlas.contacts[frame], size = Icons.BASE, team = u.team, alpha = 1, selected = false }
	end
	local s = Icons.ofDef(def, u.team)
	s.selected = selected
	return s
end

export type Draw = { id: number, x: number, y: number, style: Style }

-- Every known unit on screen as an icon; `project` as in Selection. Selected
-- units come last so they're drawn on top.
function Icons.draws(t: Table, world: World.World, project: (number, number, number) -> (number, number, boolean), width: number, height: number, selected: { [number]: boolean }): { Draw }
	local out, top = {}, {}
	for id, u in world.units do
		local x, z = u.rx or u.x, u.rz or u.z
		-- ry is where the model is drawn (altitude included); else ground + altitude
		local y = u.ry or (World.groundY(world, x, z) + u.alt)
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
