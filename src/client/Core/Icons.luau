--!strict
-- Strategic zoom icons (guide 15.4): what each known unit looks like as an
-- icon. Pure Luau (C-7); Render/IconLayer draws them. Tactical units use
-- their def; strategic records carry an icon number (net.md section 3),
-- which since S-58 is the unit's def index. Every unit type has its own
-- icon, BAR style (C-71, replacing C-67's letter codes): its domain's shape
-- (structure frame, air triangle, naval diamond, builder circle, else a
-- square; the commander a star) in team color, a white role mark for its
-- family (artillery ◎, radar ◉, SAM △ / ▲, factory ⌂ ...), tier pips, a
-- corner notch on Chaos types, and variant dots where two types would
-- still look alike: unique across all unit types (`Icons.glyphs`).

local NetIcons = require("@shared/Net/Icons")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Icons = {}

-- "sonar": a sonar contact (a submarine, or a ship heard but not seen), a hollow ring (C-31)
export type Shape = "square" | "circle" | "diamond" | "triangle" | "frame" | "blip" | "ghost" | "sonar" | "star"

export type Style = {
	shape: Shape,
	size: number, -- pixels
	team: number,
	alpha: number, -- 1 = opaque
	selected: boolean,
	code: string?, -- the unit type's two-letter code (C-67, UI labels); nil for an unknown blip
	glyph: Glyph?, -- the unit type's mark, tier, faction and variant (C-71); nil for an unknown blip
}

-- A unit type's icon details over its shape (C-71).
export type Glyph = { mark: string, tier: number, chaos: boolean, variant: number }

export type Table = {
	names: { string }, -- the icon family names (sorted)
	byDef: { [number]: number }, -- def index → icon number (the def index, S-58)
	sample: { [number]: any }, -- icon number → its def
	codes: { [number]: string }, -- def index → its unique two-letter code (C-67)
	glyphs: { [number]: Glyph }, -- def index → its icon details (C-71)
}

-- Role marks by icon family (glyphs Roblox's UI fonts draw as plain,
-- tintable symbols; ⚡ ☢ ⚙ ✈ ⚓ come out as color emoji and aren't used).
Icons.MARKS = table.freeze({
	commander = "", -- the star itself
	worker = "✚",
	scout = "»",
	tank = "▲",
	tank_heavy = "■",
	tank_amphib = "∞",
	artillery = "◎",
	tracking = "⦿",
	radar = "◉",
	sonar = "Ω",
	jammer = "≈",
	pinpointer = "⊕",
	sam_ir = "△",
	sam_radar = "▲",
	fighter = "",
	bomber = "■",
	bomber_heavy = "◆",
	heli = "○",
	heli_asw = "Ω",
	awacs = "◉",
	ew_aircraft = "≈",
	corvette = "",
	destroyer = "▲",
	cruiser = "■",
	carrier = "□",
	submarine = "▼",
	torpedo = "⌇",
	ew_ship = "≈",
	factory = "⌂",
	factory_air = "△",
	factory_naval = "◇",
	airpad = "○",
	extractor = "⏚",
	generator = "●",
	solar = "☼",
	wind = "♣",
	tidal = "⌇",
	fusion = "◈",
	converter = "⊗",
	storage = "□",
	battery = "■",
	turret = "✚",
	turret_heavy = "♠",
	turret_naval = "♦",
	nuke = "Ψ",
})

-- Glyphs for every unit def, unique as a whole (shape, mark, tier, faction,
-- variant): a variant counts types that would otherwise match.
function Icons.glyphs(defs: any): { [number]: Glyph }
	local out, seen = {}, {}
	for index, def in defs.unitByIndex do
		local shape = if def.icon == "commander" then "star" else Icons.shapeOf(def)
		local g = { mark = Icons.MARKS[def.icon] or "", tier = math.clamp(def.tier or 1, 0, 3), chaos = string.sub(def.id, 1, 4) == "chs_", variant = 0 }
		local key = `{shape}|{g.mark}|{g.tier}|{g.chaos}`
		local n = seen[key] or 0
		seen[key] = n + 1
		g.variant = n
		out[index] = g
	end
	return out
end

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
-- icon number for its family and size.
function Icons.table(defs: any): Table
	local byDef = NetIcons.byDef(defs)
	local sample = {}
	for index, def in defs.unitByIndex do
		local n = byDef[index]
		sample[n] = sample[n] or def
	end
	return { names = NetIcons.names(defs), byDef = byDef, sample = sample, codes = Icons.codes(defs), glyphs = Icons.glyphs(defs) }
end

function Icons.shapeOf(def: any): Shape
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
	-- room for the unit type's code (C-67)
	local base = 13 + 3 * (def.tier or 1) + 2 * ((def.footprint or 1) - 1)
	if def.icon == "commander" then
		base += 6
	end
	return math.min(base, 30)
end

-- How `u` looks as an icon.
function Icons.style(t: Table, world: World.World, u: World.Unit, selected: boolean): Style
	local def = World.def(world, u)
	local flags = u.flags or 0
	if def == nil and u.icon and u.icon > 0 then
		def = t.sample[u.icon]
	end
	local code = if def then t.codes[def.index] else nil
	local glyph = if def then t.glyphs[def.index] else nil
	if bit32.band(flags, Schema.StrategicFlag.GHOST) ~= 0 then
		return { shape = "ghost", size = if def then sizeOf(def) else 12, team = u.team, alpha = 0.55, selected = false, code = code, glyph = glyph }
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
		shape = if def.icon == "commander" then "star" else Icons.shapeOf(def),
		size = sizeOf(def),
		team = u.team,
		alpha = if radar and not tracked then 0.6 else 1,
		selected = selected,
		code = code,
		glyph = glyph,
	}
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
