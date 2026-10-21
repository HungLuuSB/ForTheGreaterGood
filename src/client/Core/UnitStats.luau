--!strict
-- A unit's stats for the unit panel (C-76, BAR style): computed from the
-- shared defs plus what the client knows of the unit live. Pure Luau (C-7).
--
-- What a player may know (guide 9: fog is the server's; the client shows no
-- more than it was sent):
--   own      own team's units: everything, with the owner-only fields
--            (queue, fire / move state, ammo; S-61)
--   full     an enemy in sight (tactical, or a strategic record that isn't a
--            contact) or tracked by fire-control radar (TRACKED): its type's
--            stats and its health
--   type     a ghost (a structure seen earlier): its type's stats only
--   contact  a radar or sonar contact that isn't tracked: its domain only
--            (even when the icon number would name the type)

local ArmorClasses = require("@shared/Defs/ArmorClasses")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local UnitStats = {}

export type Access = "own" | "full" | "type" | "contact"

export type Weapon = {
	name: string,
	class: string, -- the armor class DPS is shown against
	dps: number,
	damage: number, -- per shot against `class`
	shots: number, -- per reload (salvo × projectiles)
	range: number,
	reload: number,
	spread: number, -- degrees, ± on yaw and pitch (Combat)
	guidance: string?, -- missiles
	lockRange: number?,
	stock: number?, -- missiles in stock (own units)
	stockCap: number?,
	refill: number?, -- seconds per missile
}

export type Sheet = {
	access: Access,
	name: string,
	domain: string,
	health: number?, -- current
	maxHealth: number?,
	build: number?, -- 0..1 while unfinished
	weapons: { Weapon },
	speed: number?,
	sight: number?,
	airSight: number?,
	radar: number?,
	sonar: number?,
	jam: number?,
	track: number?,
	costSupply: number?,
	costPower: number?,
	buildTime: number?,
	buildPower: number?,
	buildOptions: number?,
	income: { supply: number, power: number }?, -- per second
	upkeep: number?, -- power per second (tracking, jamming, radar)
	converter: { power: number, supply: number }?,
	extractRate: number?, -- × the deposit's value
	windMax: number?,
	storage: { supply: number, power: number }?,
	fireState: number?,
	moveState: number?,
	ammo: number?,
	maxAmmo: number?,
	countermeasures: { string }, -- "Flares 4/6", "Chaff 1/2" (own units: the server's charges left, S-63), "Chaff max 2" for others, "DIRCM"
}

local CLASS_SET = ArmorClasses.set

-- The armor class a weapon is meant for: the first armor class in its
-- target priority, else the class it does the most damage to.
function UnitStats.mainClass(w: any): string
	for _, p in w.priority or {} do
		if CLASS_SET[p] and (w.damage or {})[p] and w.damage[p] > 0 then
			return p
		end
	end
	local best, bestDamage = "LIGHT", -1
	for _, c in ArmorClasses.list do
		local d = (w.damage or {})[c] or 0
		if d > bestDamage then
			best, bestDamage = c, d
		end
	end
	return best
end

-- Shots per reload: salvo count × projectiles per shot.
function UnitStats.shots(w: any): number
	local salvo = w.salvo
	local count = if type(salvo) == "table" then salvo.count or 1 elseif type(salvo) == "number" then salvo else 1
	return count * (w.projectiles or 1)
end

-- Damage per second against `class` (default: its main class): damage per
-- shot × shots per reload ÷ reload.
function UnitStats.dps(w: any, class: string?): (number, string)
	local c = class or UnitStats.mainClass(w)
	local damage = (w.damage or {})[c] or 0
	return damage * UnitStats.shots(w) / math.max(w.reload or 1, 0.05), c
end

-- One weapon slot's stats; `u` (own) adds its stockpile count.
function UnitStats.weapon(defs: any, slot: number, ws: any, u: World.Unit?): Weapon?
	local w = defs.weaponByIndex[ws.weaponIndex]
	if w == nil then
		return nil
	end
	local dps, class = UnitStats.dps(w)
	local homing = w.type == "HOMING"
	return {
		name = w.id,
		class = class,
		dps = dps,
		damage = (w.damage or {})[class] or 0,
		shots = UnitStats.shots(w),
		range = w.range or 0,
		reload = w.reload or 0,
		spread = w.accuracy or 0,
		guidance = if homing then w.guidance else nil,
		lockRange = if homing then w.lockRange else nil,
		stock = if ws.stockCapacity and u and u.stock then u.stock[slot] or 0 else nil,
		stockCap = ws.stockCapacity,
		refill = if w.stockpile then w.stockpile.buildTime else nil,
	}
end

-- What the player may know of `u`.
function UnitStats.access(world: World.World, u: World.Unit): Access
	if u.team == world.me.team then
		return "own"
	end
	local flags = if u.tier == "strategic" then u.flags or 0 else 0
	local SF = Schema.StrategicFlag
	if bit32.band(flags, SF.GHOST) ~= 0 then
		return "type"
	end
	if bit32.band(flags, SF.TRACKED) ~= 0 then
		return "full"
	end
	if bit32.band(flags, SF.RADAR_ONLY + SF.SONAR_ONLY) ~= 0 then
		return "contact"
	end
	return "full"
end

local function contactDomain(u: World.Unit, def: any): string
	if bit32.band(u.flags or 0, Schema.StrategicFlag.SONAR_ONLY) ~= 0 then
		return "naval"
	end
	if def then
		return def.domain or "ground"
	end
	return if (u.alt or 0) > 8 then "air" else "ground"
end

local function positive(n: number?): number?
	return if n and n > 0 then n else nil
end

-- The stat sheet of `u` as the player may know it.
function UnitStats.of(world: World.World, u: World.Unit): Sheet
	local access = UnitStats.access(world, u)
	local def = World.def(world, u)
	if def == nil and u.icon and u.icon > 0 then
		def = world.defs.unitByIndex[u.icon]
	end
	local sheet: Sheet = { access = access, name = "Unknown contact", domain = contactDomain(u, def), weapons = {}, countermeasures = {} }
	if access == "contact" or def == nil then
		sheet.access = "contact"
		return sheet
	end
	sheet.name = def.name
	sheet.domain = def.domain or "ground"
	sheet.maxHealth = def.health
	if access ~= "type" then
		local h = World.shownHealth(world, u) or u.health
		sheet.health = if h then h * (def.health or 0) else nil
		sheet.build = if u.build and u.build < 1 then u.build else nil
	end
	for slot, ws in def.weapons or {} do
		local w = UnitStats.weapon(world.defs, slot, ws, if access == "own" then u else nil)
		if w then
			table.insert(sheet.weapons, w)
		end
	end
	local s = def.sensors or {}
	sheet.speed = positive(def.movement and def.movement.maxSpeed)
	sheet.sight, sheet.airSight = positive(s.sight), positive(s.airSight)
	sheet.radar, sheet.sonar, sheet.jam, sheet.track = positive(s.radar), positive(s.sonar), positive(s.jam), positive(s.track)
	local cost = def.cost or {}
	sheet.costSupply, sheet.costPower, sheet.buildTime = cost.supply, cost.power, cost.buildTime
	sheet.buildPower = positive(def.buildPower)
	sheet.buildOptions = if def.buildOptions and #def.buildOptions > 0 then #def.buildOptions else nil
	local p = def.production
	if p and ((p.supply or 0) > 0 or (p.power or 0) > 0) then
		sheet.income = { supply = p.supply or 0, power = p.power or 0 }
	end
	local upkeep = (s.trackDrain or 0) + (s.jamDrain or 0) + (s.radarDrain or 0) -- radars drain power since S-72
	sheet.upkeep = positive(upkeep)
	if def.converter then
		sheet.converter = { power = def.converter.power or 0, supply = def.converter.supply or 0 }
	end
	sheet.extractRate = def.extractor and def.extractor.rate
	sheet.windMax = def.wind and def.wind.max
	if def.storage then
		sheet.storage = { supply = def.storage.supply or 0, power = def.storage.power or 0 }
	end
	if access == "own" then
		sheet.fireState, sheet.moveState = u.fireState, u.moveState
		sheet.ammo, sheet.maxAmmo = u.ammo, u.maxAmmo or def.ammo
	end
	local cm = def.countermeasures or {}
	local live = access == "own"
	if cm.flares then
		local max = cm.flares.charges or 0
		table.insert(sheet.countermeasures, if live and u.flares then `Flares {u.flares}/{max}` else `Flares max {max}`)
	end
	if cm.chaff then
		local max = cm.chaff.charges or 0
		table.insert(sheet.countermeasures, if live and u.chaff then `Chaff {u.chaff}/{max}` else `Chaff max {max}`)
	end
	if cm.dircm then
		table.insert(sheet.countermeasures, "DIRCM")
	end
	return sheet
end

local FIRE = { [0] = "Hold fire", [1] = "Return fire", [2] = "Fire at will" }
local MOVE = { [0] = "Hold position", [1] = "Maneuver", [2] = "Roam" }
local CLASS_NAME = { LIGHT = "light", ARMORED = "armored", STRUCTURE = "structures", AIR = "air", SHIP = "ships", SUB = "subs" }

local function n(x: number): string
	if x >= 100 or x == math.floor(x) then
		return tostring(math.floor(x + 0.5))
	end
	return string.format("%.1f", x)
end

local function join(parts: { string }): string
	return table.concat(parts, " · ")
end

-- The sheet as compact panel lines (combat, mobility and sensors, economy,
-- state), readable at a glance; health and build progress are drawn apart.
function UnitStats.lines(sheet: Sheet): { string }
	local out = {}
	if sheet.access == "contact" then
		table.insert(out, `Radar contact: {sheet.domain}`)
		return out
	end
	for _, w in sheet.weapons do
		local shot = if w.shots > 1 then `{n(w.damage)}×{w.shots}` else n(w.damage)
		table.insert(out, join({ `DPS {n(w.dps)} vs {CLASS_NAME[w.class] or w.class}`, `Range {n(w.range)}`, `Reload {n(w.reload)}s`, `±{n(w.spread)}°`, `{shot}/shot` }))
		local extra = {}
		if w.guidance then
			table.insert(extra, `{w.guidance} guided`)
		end
		if w.lockRange then
			table.insert(extra, `Lock {n(w.lockRange)}`)
		end
		if w.stockCap then
			local count = if w.stock then `{w.stock}/{w.stockCap}` else `max {w.stockCap}`
			table.insert(extra, `Stock {count}` .. (if w.refill then `, {n(w.refill)}s each` else ""))
		end
		if #extra > 0 then
			table.insert(out, "  " .. join(extra))
		end
	end
	local see = {}
	if sheet.speed then
		table.insert(see, `Speed {n(sheet.speed)}`)
	end
	for _, pair in { { "LoS", sheet.sight }, { "AirLoS", sheet.airSight }, { "Radar", sheet.radar }, { "Sonar", sheet.sonar }, { "Jam", sheet.jam }, { "Track", sheet.track } } :: { { any } } do
		if pair[2] then
			table.insert(see, `{pair[1]} {n(pair[2])}`)
		end
	end
	if #see > 0 then
		table.insert(out, join(see))
	end
	local eco = {}
	if sheet.costSupply or sheet.costPower then
		table.insert(eco, `Cost {n(sheet.costSupply or 0)} / {n(sheet.costPower or 0)}`)
	end
	if sheet.buildPower then
		table.insert(eco, `Buildpower {n(sheet.buildPower)}`)
	end
	if sheet.buildOptions then
		table.insert(eco, `{sheet.buildOptions} options`)
	end
	if #eco > 0 then
		table.insert(out, join(eco))
	end
	local flow = {}
	if sheet.income then
		if sheet.income.supply > 0 then
			table.insert(flow, `+{n(sheet.income.supply)} supply/s`)
		end
		if sheet.income.power > 0 then
			table.insert(flow, `+{n(sheet.income.power)} power/s`)
		end
	end
	if sheet.windMax then
		table.insert(flow, `wind up to +{n(sheet.windMax)} power/s`)
	end
	if sheet.extractRate then
		table.insert(flow, `extracts {n(sheet.extractRate)}× deposit`)
	end
	if sheet.converter then
		table.insert(flow, `{n(sheet.converter.power)} power → {n(sheet.converter.supply)} supply/s`)
	end
	if sheet.upkeep then
		table.insert(flow, `−{n(sheet.upkeep)} power/s`)
	end
	if sheet.storage then
		table.insert(flow, `stores {n(sheet.storage.supply)} / {n(sheet.storage.power)}`)
	end
	if #flow > 0 then
		table.insert(out, join(flow))
	end
	local state = {}
	if sheet.fireState then
		table.insert(state, FIRE[sheet.fireState] or "?")
	end
	if sheet.moveState then
		table.insert(state, MOVE[sheet.moveState] or "?")
	end
	if sheet.ammo then
		table.insert(state, `Ammo {sheet.ammo}/{sheet.maxAmmo or sheet.ammo}`)
	end
	for _, c in sheet.countermeasures do
		table.insert(state, c)
	end
	if #state > 0 then
		table.insert(out, join(state))
	end
	return out
end

return UnitStats
