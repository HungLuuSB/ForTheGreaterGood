--!strict
-- Def loader, validation and derived values (guide 4.1, 4.5).
--
--   local Defs = require("@shared/Defs/Defs")   -- or "../Defs/Defs" inside Shared
--   local set = Defs.load()                      -- the registered defs, built once
--   set.units.ord_lancer.index                   -- numeric index for packets (u16, 1-based)
--   set.unitByIndex[1], set.hash
--
-- Validation collects every problem, then fails once with all of them, so a
-- broken def is reported completely at startup instead of one error per run.
-- Built defs are deep-frozen: gameplay code can't modify them by accident.

local ArmorClasses = require("./ArmorClasses")
local Categories = require("./Categories")
local Hash = require("../Util/Hash")
local Log = require("../Util/Log")
local MoveClasses = require("./MoveClasses")
local Schema = require("../Net/Schema")
local Templates = require("./Templates")

local log = Log.new("Defs")

local Defs = {}

Defs.Templates = Templates
Defs.extend = Templates.extend

Defs.MAX_WEAPONS = Schema.MAX_WEAPONS
Defs.MAX_DEFS = 65535 -- indices travel as u16; 0 is reserved

--------------------------------------------------------------------------------
-- Types (built defs)
--------------------------------------------------------------------------------

export type WeaponSlot = {
	def: string,
	weaponIndex: number, -- derived
	turretPiece: string?,
	pitchPiece: string?,
	muzzle: string?,
	-- client only (S-157): barrels the shots alternate between, in order, and
	-- the drum piece turned a barrel's angle after each shot (Geryon)
	muzzles: { string }?,
	drumPiece: string?,
	stockpile: number?, -- capacity on this unit, overriding the weapon's stockpile.capacity (S-47)
	stockCapacity: number?, -- derived: the slot's missile capacity, nil = no stockpile (S-47)
}

export type UnitDef = {
	id: string,
	index: number, -- derived: u16 def index
	name: string,
	description: string,
	faction: "order" | "chaos" | "neutral",
	tier: number,
	domain: "ground" | "air" | "naval" | "structure",
	categories: { string },
	categoryMask: number, -- derived
	cost: { supply: number, power: number, buildTime: number },
	health: number,
	armorClass: string,
	moveClass: string?,
	movement: { maxSpeed: number, minSpeed: number?, accel: number, brake: number, turnRate: number }?,
	footprint: number,
	sensors: {
		sight: number,
		airSight: number?,
		radar: number,
		sonar: number,
		jam: number?,
		radarError: number?,
		radarSignature: number,
		track: number?, -- fire-control (tracking) radar radius (D104)
		trackError: number?, -- wobble radius of contacts this radar tracks
		trackDrain: number?, -- power per second; the radius shrinks when power stalls
		jamDrain: number?, -- jammer upkeep, power per second; the jam radius shrinks when power stalls (D108)
		radarDrain: number?, -- radar upkeep, power per second; the radar radius shrinks when power stalls (S-72)
	},
	weapons: { WeaponSlot },
	maxRange: number, -- derived: longest weapon range, 0 if unarmed
	countermeasures: Countermeasures?,
	buildPower: number?,
	canResurrect: boolean?, -- builders: RESURRECT brings a wreck's unit back (S-168)
	buildOptions: { string }?,
	upgradesFrom: { string }?, -- structures this one may be built over in place, the builder's own (S-108)
	spoof: string?, -- a def its untracked radar contacts pass for (S-109, the Wraith)
	buildRange: number?,
	production: { supply: number?, power: number? }?, -- per second while built
	extractor: { rate: number }?, -- supply per second per deposit value
	wind: { max: number }?, -- power per second at full wind (guide 8.5 Wind Turbine)
	converter: { power: number, supply: number }?, -- per second: power in, supply out (toggleable)
	pinpointer: boolean?, -- raises its ally team's radar precision (Shared/Combat/Pinpoint, S-59)
	pinpointFull: number?, -- this type's count for full precision (default Pinpoint.FULL, 6; S-62)
	deploy: { time: number, armor: number }?, -- unpacks when it stands still: seconds each way, damage divisor deployed (S-64)
	deathBlast: { damage: number, aoe: number, edge: number }?, -- explodes when killed: every unit in `aoe`, own included (S-70)
	-- shield dome generator (S-79; Shared/Combat/ShieldField, Sim/Shield):
	-- a dome of `radius` round it; `capacity` charge in shell masses;
	-- `recharge` charge per second, drawing `power` power per second while
	-- it recharges
	shield: { radius: number, capacity: number, recharge: number, power: number }?,
	-- switched off (TOGGLE), it retracts: can't fire, and damage to it is
	-- divided by `armor` (S-96, client request 43). It starts switched on.
	retract: { armor: number }?,
	retired: boolean?, -- no longer built (on no build list); kept so old replays and scenes load (S-157)
	storage: { supply: number?, power: number? }?, -- added to team storage while built
	placement: ("land" | "water" | "either")?, -- structures only
	ammo: number?, -- rounds carried (aircraft); nil = unlimited
	ammoCost: { supply: number?, power: number? }?, -- per round rearmed
	rearmTime: number?, -- seconds per round at full economy
	rearmPads: number?, -- structures: aircraft rearmed at once
	rearmSpeed: number?, -- structures / carriers with rearmPads: how much faster than rearmTime they rearm (default 1; S-166)
	model: string,
	pieces: { string },
	script: string?,
	icon: string,
	wreck: string?,
}

export type Charges = { charges: number, chance: number, refillSupply: number } -- refillSupply: per charge restocked
export type Dircm = { chance: number, cooldown: number, powerDrain: number }
export type Countermeasures = { flares: Charges?, chaff: Charges?, dircm: Dircm? } -- guide 11.6

export type WeaponDef = {
	id: string,
	index: number, -- derived
	type: "HITSCAN" | "BALLISTIC" | "HOMING" | "BEAM" | "TORPEDO" | "BOMB",
	range: number,
	reload: number,
	salvo: { count: number, delay: number }?,
	projectileSpeed: number?,
	gravity: number?,
	accuracy: number?,
	damage: { [string]: number }, -- every armor class present after build
	aoe: number?,
	edgeEffectiveness: number?,
	targets: { string },
	targetMask: number, -- derived
	priority: { string }?,
	priorityMasks: { number }, -- derived, same order as priority
	turret: any?,
	guidance: ("IR" | "RADAR" | "COMMAND" | "ACOUSTIC")?,
	turnRate: number?,
	lockRange: number?,
	terminalRange: number?,
	seekerAngle: number?, -- degrees off the nose the seeker sees; default by guidance (EW.SEEKER_ANGLE, S-27)
	climbHeight: number?, -- vertical launch: studs above the ground it climbs straight before pitching over (S-44)
	-- missiles kept in stock (S-47): a shot needs one; the unit builds one
	-- at a time (buildTime seconds, cost each) while below capacity. A unit's
	-- slot may set its own capacity (WeaponSlot.stockpile).
	stockpile: { capacity: number, buildTime: number, cost: { supply: number?, power: number? } }?,
	-- strategic missiles (S-48): `strategic` = interceptable by `intercepts`
	-- weapons, its blast hurts every side, it passes over units in flight
	-- and every player is warned of its launch; `manualFire` = never picks a
	-- target, fires one shot per attack-ground order; `apex` (BALLISTIC) =
	-- lofted (Shared/Combat/Lofted, S-51): straight up at projectileSpeed to
	-- climbHeight, a pitch-over at turnRate, then the arc that peaks `apex`
	-- studs above the ordered spot and lands on it
	strategic: boolean?,
	manualFire: boolean?,
	apex: number?,
	-- HOMING: also targets enemy strategic missiles the team detects, before
	-- anything else; a proximity burst destroys one with `chance` (S-48).
	-- `tactical`: enemy missiles and rockets (HOMING weapons and `rocket`
	-- ones; not strategic missiles or interceptors) within range that the
	-- team detects, instead (point defence, S-149)
	intercepts: { chance: number, tactical: boolean? }?,
	rocket: boolean?, -- BALLISTIC: an unguided rocket, which point defence intercepts (S-149)
	highArc: boolean?, -- BALLISTIC: lobbed on the high arc, not the low one (S-157: Gauntlet, Talos)
	interceptOnly: boolean?, -- with intercepts: never fires at units (anti-nukes, S-111)
	stationary: boolean?, -- fires only while its unit stands still (S-111)
	launch: ("turret" | "vertical")?, -- HOMING: "vertical" leaves straight up, no turret aim (S-42); default "turret"
	burnThrough: number?, -- RADAR: fraction of lockRange inside which jamming fails
	canTargetRadar: boolean?,
	beamDuration: number?, -- BEAM: seconds the beam lingers; its damage is dealt over that time (S-113)
	pierce: boolean?, -- with beamDuration: the beam's line hurts every enemy it crosses, hit or miss (S-115)
	shieldMass: number?, -- weight against shield fields (1 = a typical shell); default from damage (ShieldField.mass, S-79)
	shotCost: { supply: number?, power: number? }?, -- drawn from the team's stores per shot; no shot without it (S-96)
	-- HITSCAN (S-157, the Beamer): each hit deals `from` .. `to` (the damage
	-- table is the full `to`), rising over `seconds` on one target; leaving a
	-- target pauses the weapon cooldown[1] .. cooldown[2] seconds, by the
	-- intensity it had reached
	ramp: { from: number, to: number, seconds: number, cooldown: { number } }?,
	fx: { [string]: any }?, -- muzzle / trail / impact / sound names; tracer "laser" with color { r, g, b } (S-157; client only)
}

export type DefSet = {
	units: { [string]: UnitDef },
	weapons: { [string]: WeaponDef },
	unitByIndex: { UnitDef }, -- sorted by id
	weaponByIndex: { WeaponDef }, -- sorted by id
	hash: number, -- u32; compared between server and client on join
}

export type RawDefs = {
	units: { [string]: any },
	weapons: { [string]: any },
}

--------------------------------------------------------------------------------
-- Shape specs
--------------------------------------------------------------------------------

type Spec = {
	kind: "string" | "number" | "integer" | "boolean" | "record" | "list",
	optional: boolean?,
	min: number?, -- inclusive
	above: number?, -- exclusive lower bound
	max: number?,
	enum: { [string]: boolean }?,
	fields: { [string]: Spec }?,
	item: Spec?,
	minItems: number?,
	maxItems: number?,
}

local function set(list: { string }): { [string]: boolean }
	local out = {}
	for _, v in list do
		out[v] = true
	end
	return out
end

local function opt(spec: Spec): Spec
	local copy = table.clone(spec)
	copy.optional = true
	return copy
end

local STRING: Spec = { kind = "string" }
local POSITIVE: Spec = { kind = "number", above = 0 }
local NON_NEGATIVE: Spec = { kind = "number", min = 0 }
local FRACTION: Spec = { kind = "number", min = 0, max = 1 }

local categoryNames = {}
for name in Categories.Bit do
	table.insert(categoryNames, name)
end
local CATEGORY: Spec = { kind = "string", enum = set(categoryNames) }
local ARMOR_CLASS: Spec = { kind = "string", enum = ArmorClasses.set }

local damageFields: { [string]: Spec } = {}
for _, class in ArmorClasses.list do
	damageFields[class] = opt(NON_NEGATIVE)
end

local CHARGES: Spec = {
	kind = "record",
	fields = { charges = { kind = "integer", min = 0 }, chance = FRACTION, refillSupply = NON_NEGATIVE },
}

local UNIT_SPEC: Spec = {
	kind = "record",
	fields = {
		id = STRING,
		name = STRING,
		description = STRING,
		faction = { kind = "string", enum = set({ "order", "chaos", "neutral" }) },
		tier = { kind = "integer", min = 0, max = 3 }, -- 3: strategic structures (S-48)
		domain = { kind = "string", enum = set({ "ground", "air", "naval", "structure" }) },
		categories = { kind = "list", item = CATEGORY, minItems = 1 },
		cost = {
			kind = "record",
			fields = { supply = NON_NEGATIVE, power = NON_NEGATIVE, buildTime = POSITIVE },
		},
		health = POSITIVE,
		armorClass = ARMOR_CLASS,
		moveClass = opt(STRING),
		movement = {
			kind = "record",
			optional = true,
			fields = {
				maxSpeed = POSITIVE,
				minSpeed = opt(POSITIVE), -- jets: can't fly slower
				accel = POSITIVE,
				brake = POSITIVE,
				turnRate = POSITIVE,
			},
		},
		footprint = { kind = "integer", min = 1, max = 8 },
		sensors = {
			kind = "record",
			fields = {
				sight = NON_NEGATIVE,
				airSight = opt(NON_NEGATIVE), -- sight against aircraft; default 1.5 × sight
				radar = NON_NEGATIVE,
				sonar = NON_NEGATIVE,
				jam = opt(NON_NEGATIVE), -- jammer radius (hides own team from enemy radar)
				radarError = opt(NON_NEGATIVE), -- wobble radius of this unit's radar contacts (studs)
				radarSignature = FRACTION,
				track = opt(NON_NEGATIVE), -- tracking radar radius (D104)
				trackError = opt(NON_NEGATIVE), -- wobble radius of tracked contacts (studs)
				trackDrain = opt(NON_NEGATIVE), -- power per second while tracking
				jamDrain = opt(NON_NEGATIVE), -- power per second while jamming (D108)
				radarDrain = opt(NON_NEGATIVE), -- radar upkeep, power per second; the radar radius shrinks when power stalls (S-72)
			},
		},
		weapons = {
			kind = "list",
			maxItems = Defs.MAX_WEAPONS,
			item = {
				kind = "record",
				fields = {
					def = STRING,
					turretPiece = opt(STRING),
					pitchPiece = opt(STRING),
					muzzle = opt(STRING),
					muzzles = { kind = "list", optional = true, item = STRING, minItems = 2, maxItems = 3 }, -- (S-157)
					drumPiece = opt(STRING),
					stockpile = { kind = "integer", optional = true, min = 1, max = 255 }, -- capacity (S-47)
				},
			},
		},
		countermeasures = {
			kind = "record",
			optional = true,
			fields = {
				flares = opt(CHARGES),
				chaff = opt(CHARGES),
				dircm = {
					kind = "record",
					optional = true,
					fields = { chance = FRACTION, cooldown = POSITIVE, powerDrain = NON_NEGATIVE },
				},
			},
		},
		buildPower = opt(POSITIVE),
		canResurrect = { kind = "boolean", optional = true },
		buildOptions = { kind = "list", optional = true, item = STRING, minItems = 1 },
		upgradesFrom = { kind = "list", optional = true, item = STRING, minItems = 1 },
		spoof = opt(STRING),
		buildRange = opt(POSITIVE),
		model = STRING,
		pieces = { kind = "list", item = STRING, minItems = 1 },
		script = opt(STRING),
		icon = STRING,
		wreck = opt(STRING),
		-- economy (guide 8)
		production = {
			kind = "record",
			optional = true,
			fields = { supply = opt(NON_NEGATIVE), power = opt(NON_NEGATIVE) },
		},
		extractor = { kind = "record", optional = true, fields = { rate = POSITIVE } },
		wind = { kind = "record", optional = true, fields = { max = POSITIVE } },
		converter = { kind = "record", optional = true, fields = { power = POSITIVE, supply = POSITIVE } },
		pinpointer = { kind = "boolean", optional = true },
		pinpointFull = { kind = "number", optional = true, min = 1 },
		deploy = { kind = "record", optional = true, fields = { time = POSITIVE, armor = { kind = "number", min = 1 } } },
		deathBlast = { kind = "record", optional = true, fields = { damage = POSITIVE, aoe = POSITIVE, edge = { kind = "number", min = 0, max = 1 } } },
		shield = { kind = "record", optional = true, fields = { radius = POSITIVE, capacity = POSITIVE, recharge = POSITIVE, power = NON_NEGATIVE } },
		retract = { kind = "record", optional = true, fields = { armor = { kind = "number", min = 1 } } },
		retired = { kind = "boolean", optional = true },
		storage = {
			kind = "record",
			optional = true,
			fields = { supply = opt(NON_NEGATIVE), power = opt(NON_NEGATIVE) },
		},
		placement = { kind = "string", optional = true, enum = set({ "land", "water", "either" }) },
		-- aircraft ammo and rearming (guide 8.6, 12.2)
		ammo = { kind = "integer", optional = true, min = 1 },
		ammoCost = {
			kind = "record",
			optional = true,
			fields = { supply = opt(NON_NEGATIVE), power = opt(NON_NEGATIVE) },
		},
		rearmTime = opt(POSITIVE), -- seconds per round at full economy
		rearmPads = { kind = "integer", optional = true, min = 1 }, -- aircraft rearmed at once
		rearmSpeed = opt(POSITIVE), -- rearm rate multiplier (S-166)
	},
}

local WEAPON_TYPES = set({ "HITSCAN", "BALLISTIC", "HOMING", "BEAM", "TORPEDO", "BOMB" })
local PROJECTILE_TYPES = set({ "BALLISTIC", "HOMING", "TORPEDO", "BOMB" })
local GUIDED_TYPES = set({ "HOMING", "TORPEDO" })

local WEAPON_SPEC: Spec = {
	kind = "record",
	fields = {
		id = STRING,
		type = { kind = "string", enum = WEAPON_TYPES },
		range = POSITIVE,
		reload = POSITIVE,
		salvo = {
			kind = "record",
			optional = true,
			fields = { count = { kind = "integer", min = 1 }, delay = NON_NEGATIVE },
		},
		projectileSpeed = opt(POSITIVE),
		gravity = opt(NON_NEGATIVE),
		accuracy = opt(NON_NEGATIVE),
		damage = { kind = "record", fields = damageFields },
		aoe = opt(NON_NEGATIVE),
		edgeEffectiveness = opt(FRACTION),
		targets = { kind = "list", item = CATEGORY, minItems = 1 },
		priority = { kind = "list", optional = true, item = CATEGORY },
		turret = {
			kind = "record",
			optional = true,
			fields = {
				yawRate = POSITIVE,
				pitchRate = POSITIVE,
				tolerance = NON_NEGATIVE,
				minPitch = { kind = "number", min = -90, max = 90 },
				maxPitch = { kind = "number", min = -90, max = 90 },
				arc = { kind = "number", above = 0, max = 360 },
				-- rest pose and restore delay (guide 10.3, 14.4; Shared/Combat/Aim, S-20)
				restYaw = { kind = "number", optional = true, min = -180, max = 180 },
				restPitch = { kind = "number", optional = true, min = -90, max = 90 },
				restoreDelay = opt(NON_NEGATIVE),
			},
		},
		guidance = { kind = "string", optional = true, enum = set({ "IR", "RADAR", "COMMAND", "ACOUSTIC" }) },
		turnRate = opt(POSITIVE),
		lockRange = opt(POSITIVE),
		terminalRange = opt(POSITIVE),
		seekerAngle = { kind = "number", optional = true, min = 1, max = 180 },
		launch = { kind = "string", optional = true, enum = set({ "turret", "vertical" }) },
		climbHeight = opt(NON_NEGATIVE),
		stockpile = {
			kind = "record",
			optional = true,
			fields = {
				capacity = { kind = "integer", min = 1, max = 255 }, -- a u8 on the wire
				buildTime = POSITIVE, -- seconds per missile at full economy
				cost = { kind = "record", fields = { supply = opt(NON_NEGATIVE), power = opt(NON_NEGATIVE) } },
			},
		},
		burnThrough = opt(FRACTION),
		strategic = { kind = "boolean", optional = true },
		manualFire = { kind = "boolean", optional = true },
		apex = opt(POSITIVE),
		intercepts = { kind = "record", optional = true, fields = { chance = FRACTION, tactical = { kind = "boolean", optional = true } } },
		rocket = { kind = "boolean", optional = true },
		highArc = { kind = "boolean", optional = true },
		interceptOnly = { kind = "boolean", optional = true },
		stationary = { kind = "boolean", optional = true },
		canTargetRadar = { kind = "boolean", optional = true },
		beamDuration = opt(POSITIVE),
		pierce = { kind = "boolean", optional = true },
		shieldMass = opt(POSITIVE),
		shotCost = { kind = "record", optional = true, fields = { supply = opt(NON_NEGATIVE), power = opt(NON_NEGATIVE) } },
		ramp = {
			kind = "record",
			optional = true,
			fields = {
				from = POSITIVE,
				to = POSITIVE,
				seconds = POSITIVE,
				cooldown = { kind = "list", item = NON_NEGATIVE, minItems = 2, maxItems = 2 },
			},
		},
		fx = {
			kind = "record",
			optional = true,
			fields = {
				muzzle = opt(STRING),
				trail = opt(STRING),
				impact = opt(STRING),
				sound = opt(STRING),
				tracer = { kind = "string", optional = true, enum = set({ "laser" }) }, -- (S-157)
				color = {
					kind = "record",
					optional = true,
					fields = {
						r = { kind = "integer", min = 0, max = 255 },
						g = { kind = "integer", min = 0, max = 255 },
						b = { kind = "integer", min = 0, max = 255 },
					},
				},
			},
		},
	},
}

--------------------------------------------------------------------------------
-- Shape checking
--------------------------------------------------------------------------------

local function describe(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return `{v} ({typeof(v)})`
end

local function join(path: string, key: string | number): string
	if type(key) == "number" then
		return `{path}[{key}]`
	end
	return if path == "" then key else `{path}.{key}`
end

local function sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function checkShape(v: any, spec: Spec, path: string, report: (string) -> ())
	if v == nil then
		if not spec.optional then
			report(`{path}: missing required field`)
		end
		return
	end

	local kind = spec.kind
	if kind == "string" then
		if type(v) ~= "string" then
			report(`{path}: expected a string, got {describe(v)}`)
		elseif spec.enum and not spec.enum[v] then
			local options = sortedKeys(spec.enum)
			report(`{path}: {describe(v)} is not one of {table.concat(options, ", ")}`)
		end
	elseif kind == "number" or kind == "integer" then
		local what = if kind == "integer" then "an integer" else "a number"
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
			report(`{path}: expected {what}, got {describe(v)}`)
		elseif kind == "integer" and v ~= math.floor(v) then
			report(`{path}: expected an integer, got {v}`)
		elseif spec.above ~= nil and v <= spec.above then
			report(`{path}: expected {what} > {spec.above}, got {v}`)
		elseif spec.min ~= nil and v < spec.min then
			report(`{path}: expected {what} >= {spec.min}, got {v}`)
		elseif spec.max ~= nil and v > spec.max then
			report(`{path}: expected {what} <= {spec.max}, got {v}`)
		end
	elseif kind == "boolean" then
		if type(v) ~= "boolean" then
			report(`{path}: expected a boolean, got {describe(v)}`)
		end
	elseif kind == "record" then
		if type(v) ~= "table" then
			report(`{path}: expected a table, got {describe(v)}`)
			return
		end
		local fields = spec.fields :: { [string]: Spec }
		for _, k in sortedKeys(v) do
			if type(k) ~= "string" or fields[k] == nil then
				report(`{join(path, tostring(k))}: unknown field`)
			end
		end
		for _, k in sortedKeys(fields) do
			checkShape(v[k], fields[k], join(path, k), report)
		end
	elseif kind == "list" then
		if type(v) ~= "table" then
			report(`{path}: expected a list, got {describe(v)}`)
			return
		end
		local n = #v
		for _, k in sortedKeys(v) do
			if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
				report(`{path}: expected a list, found key {describe(k)}`)
				return
			end
		end
		if spec.minItems and n < spec.minItems then
			report(`{path}: needs at least {spec.minItems} entr{if spec.minItems == 1 then "y" else "ies"}, has {n}`)
		end
		if spec.maxItems and n > spec.maxItems then
			report(`{path}: at most {spec.maxItems} entries allowed, has {n}`)
		end
		for i = 1, n do
			checkShape(v[i], spec.item :: Spec, join(path, i), report)
		end
	end
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

local PREFIX_FACTION = { ord = "order", chs = "chaos", neu = "neutral" }

local function checkId(id: any, key: string, report: (string) -> ())
	if type(id) ~= "string" then
		return -- reported by the shape check
	end
	if id ~= key then
		report(`id: {describe(id)} does not match its file name "{key}"`)
	end
	if not string.match(id, "^[a-z][a-z0-9_]*$") then
		report(`id: {describe(id)} must be lowercase snake_case`)
	elseif PREFIX_FACTION[string.sub(id, 1, 3)] == nil or string.sub(id, 4, 4) ~= "_" then
		report(`id: {describe(id)} must start with ord_, chs_ or neu_`)
	end
end

-- Returns every problem found, sorted; empty when the defs are valid.
function Defs.validate(raw: RawDefs): { string }
	local problems: { string } = {}
	local units = raw.units or {}
	local weapons = raw.weapons or {}

	for _, key in sortedKeys(weapons) do
		local w = weapons[key]
		local function report(message: string)
			table.insert(problems, `weapon {key}: {message}`)
		end
		if type(w) ~= "table" then
			report(`expected a table, got {describe(w)}`)
			continue
		end
		checkShape(w, WEAPON_SPEC, "", report)
		checkId(w.id, key, report)

		local wtype = w.type
		if PROJECTILE_TYPES[wtype] and wtype ~= "BOMB" and w.projectileSpeed == nil then
			report(`projectileSpeed: required for {wtype} weapons`)
		end
		if (wtype == "BALLISTIC" or wtype == "BOMB") and w.gravity == nil then
			report(`gravity: required for {wtype} weapons`)
		end
		if GUIDED_TYPES[wtype] then
			if w.guidance == nil then
				report(`guidance: required for {wtype} weapons`)
			end
			if w.turnRate == nil then
				report(`turnRate: required for {wtype} weapons`)
			end
		elseif w.guidance ~= nil then
			report(`guidance: only HOMING and TORPEDO weapons are guided, not {tostring(wtype)}`)
		end
		if w.apex ~= nil and wtype ~= "BALLISTIC" then
			report(`apex: only BALLISTIC weapons are lofted, not {tostring(wtype)}`)
		end
		if w.highArc and (wtype ~= "BALLISTIC" or w.apex ~= nil) then
			report("highArc: only unlofted BALLISTIC weapons take the high arc")
		end
		local ramp = w.ramp
		if type(ramp) == "table" then
			if wtype ~= "HITSCAN" then
				report(`ramp: only HITSCAN weapons ramp, not {tostring(wtype)}`)
			end
			if (w.aoe or 0) > 0 then
				report("ramp: a ramping weapon hits its target only (aoe 0)")
			end
			if type(ramp.from) == "number" and type(ramp.to) == "number" and ramp.from > ramp.to then
				report("ramp: from must not exceed to")
			end
			local cd = ramp.cooldown
			if type(cd) == "table" and type(cd[1]) == "number" and type(cd[2]) == "number" and cd[1] > cd[2] then
				report("ramp.cooldown: { shortest, longest }")
			end
		end
		if w.apex ~= nil and w.turnRate == nil then
			report(`turnRate: required for lofted (apex) weapons: the pitch-over`)
		end
		if w.intercepts ~= nil and (wtype ~= "HOMING" or w.launch ~= "vertical") then
			report(`intercepts: only vertical-launch HOMING weapons intercept (they need no aim)`)
		end
		if w.beamDuration ~= nil and wtype ~= "BEAM" then
			report(`beamDuration: only BEAM weapons linger`)
		end
		if w.pierce and w.beamDuration == nil then
			report(`pierce: only lingering beams (beamDuration) pierce`)
		end
		if w.interceptOnly and w.intercepts == nil then
			report(`interceptOnly: needs intercepts`)
		end
		local turret = w.turret
		if
			type(turret) == "table"
			and type(turret.minPitch) == "number"
			and type(turret.maxPitch) == "number"
			and turret.minPitch > turret.maxPitch
		then
			report(`turret: minPitch {turret.minPitch} is above maxPitch {turret.maxPitch}`)
		end
		if type(turret) == "table" and type(turret.restPitch) == "number" and type(turret.minPitch) == "number" and type(turret.maxPitch) == "number" then
			if turret.restPitch < turret.minPitch or turret.restPitch > turret.maxPitch then
				report(`turret: restPitch {turret.restPitch} is outside minPitch..maxPitch ({turret.minPitch}..{turret.maxPitch})`)
			end
		end
		if type(turret) == "table" and type(turret.restYaw) == "number" and type(turret.arc) == "number" and math.abs(turret.restYaw) > turret.arc / 2 then
			report(`turret: restYaw {turret.restYaw} is outside its {turret.arc}° arc`)
		end
	end

	for _, key in sortedKeys(units) do
		local u = units[key]
		local function report(message: string)
			table.insert(problems, `unit {key}: {message}`)
		end
		if type(u) ~= "table" then
			report(`expected a table, got {describe(u)}`)
			continue
		end
		checkShape(u, UNIT_SPEC, "", report)
		checkId(u.id, key, report)

		if type(u.id) == "string" and type(u.faction) == "string" then
			local expected = PREFIX_FACTION[string.sub(u.id, 1, 3)]
			if expected and expected ~= u.faction then
				report(`faction: "{u.faction}" does not match the id prefix (expected "{expected}")`)
			end
		end

		if u.ammo ~= nil and u.rearmTime == nil then
			report("rearmTime: units with ammo need rearmTime")
		end
		if u.rearmPads ~= nil and u.domain ~= "structure" and u.domain ~= "naval" then
			report("rearmPads: only structures and ships (carriers) have rearm pads")
		end
		if u.rearmSpeed ~= nil and u.rearmPads == nil then
			report("rearmSpeed: only units with rearmPads")
		end
		if type(u.movement) == "table" and u.movement.minSpeed ~= nil and u.movement.minSpeed > u.movement.maxSpeed then
			report("movement.minSpeed: above maxSpeed")
		end
		if (u.wind ~= nil or u.converter ~= nil) and u.domain ~= "structure" then
			report("wind / converter: only structures")
		end
		if u.extractor ~= nil and u.domain ~= "structure" then
			report("extractor: only structures can be extractors")
		end
		if u.placement ~= nil and u.domain ~= "structure" then
			report("placement: only structures have a placement class")
		end
		if u.buildOptions ~= nil and u.domain ~= "structure" and u.buildRange == nil then
			report("buildRange: mobile builders need buildRange")
		end
		if u.domain == "structure" then
			if u.moveClass ~= nil then
				report("moveClass: structures don't move; remove it")
			end
			if u.movement ~= nil then
				report("movement: structures don't move; remove it")
			end
		else
			if u.moveClass == nil then
				report("moveClass: required for mobile units")
			elseif type(u.moveClass) == "string" and MoveClasses[u.moveClass] == nil then
				report(`moveClass: unknown move class {describe(u.moveClass)}`)
			end
			if u.movement == nil then
				report("movement: required for mobile units")
			end
		end

		if type(u.weapons) == "table" then
			-- the client rig animates these pieces (guide 14.2, docs/contracts/rig.md)
			local pieces: { [string]: boolean } = {}
			if type(u.pieces) == "table" then
				for _, piece in u.pieces do
					pieces[piece] = true
				end
			end
			for i, slot in u.weapons do
				if type(slot) == "table" and type(slot.def) == "string" and weapons[slot.def] == nil then
					report(`weapons[{i}].def: unknown weapon {describe(slot.def)}`)
				end
				if
					type(slot) == "table"
					and slot.stockpile ~= nil
					and type(slot.def) == "string"
					and type(weapons[slot.def]) == "table"
					and weapons[slot.def].stockpile == nil
				then
					report(`weapons[{i}].stockpile: weapon {describe(slot.def)} has no stockpile`)
				end
				if type(slot) == "table" then
					for _, key in { "turretPiece", "pitchPiece", "muzzle", "drumPiece" } do
						local piece = slot[key]
						if type(piece) == "string" and not pieces[piece] then
							report(`weapons[{i}].{key}: piece {describe(piece)} is not in pieces`)
						end
					end
					if type(slot.muzzles) == "table" then
						for j, piece in slot.muzzles do
							if type(piece) == "string" and not pieces[piece] then
								report(`weapons[{i}].muzzles[{j}]: piece {describe(piece)} is not in pieces`)
							end
						end
					end
					if slot.drumPiece ~= nil and slot.muzzles == nil then
						report(`weapons[{i}].drumPiece: a drum turns between muzzles; it needs muzzles`)
					end
					-- only a turret turns pieces: a weapon without one (bombs fall
					-- from a fixed bay, D91) has a muzzle but no turret or pitch piece
					local wdef = if type(slot.def) == "string" then weapons[slot.def] else nil
					if type(wdef) == "table" and wdef.turret == nil then
						for _, key in { "turretPiece", "pitchPiece" } do
							if slot[key] ~= nil then
								report(`weapons[{i}].{key}: weapon {describe(slot.def)} has no turret to turn it`)
							end
						end
					end
				end
			end
		end

		local isBuilder = u.buildOptions ~= nil
		if isBuilder and u.buildPower == nil then
			report("buildPower: builders (units with buildOptions) need buildPower > 0")
		elseif not isBuilder and u.buildPower ~= nil then
			report("buildPower: only builders (units with buildOptions) have buildPower")
		end
		if u.canResurrect and u.buildPower == nil then
			report("canResurrect: only builders with buildPower")
		end
		if not isBuilder and u.buildRange ~= nil then
			report("buildRange: only builders (units with buildOptions) have buildRange")
		end
		if type(u.buildOptions) == "table" then
			for i, option in u.buildOptions do
				if type(option) == "string" and units[option] == nil then
					report(`buildOptions[{i}]: unknown unit {describe(option)}`)
				elseif type(option) == "string" and type(units[option]) == "table" and units[option].retired then
					report(`buildOptions[{i}]: {option} is retired (S-157)`)
				end
			end
		end
		if type(u.wreck) == "string" and units[u.wreck] == nil then
			report(`wreck: unknown def {describe(u.wreck)}`)
		end
		if type(u.spoof) == "string" and units[u.spoof] == nil then
			report(`spoof: unknown unit {describe(u.spoof)}`)
		end
		if type(u.upgradesFrom) == "table" then
			if u.domain ~= "structure" then
				report("upgradesFrom: only structures upgrade in place")
			end
			for i, from in u.upgradesFrom do
				local fd = if type(from) == "string" then units[from] else nil
				if fd == nil then
					report(`upgradesFrom[{i}]: unknown unit {describe(from)}`)
				elseif fd.domain ~= "structure" then
					report(`upgradesFrom[{i}]: {from} isn't a structure`)
				end
			end
		end
	end

	local unitCount, weaponCount = #sortedKeys(units), #sortedKeys(weapons)
	if unitCount > Defs.MAX_DEFS then
		table.insert(problems, `too many unit defs: {unitCount} (max {Defs.MAX_DEFS})`)
	end
	if weaponCount > Defs.MAX_DEFS then
		table.insert(problems, `too many weapon defs: {weaponCount} (max {Defs.MAX_DEFS})`)
	end
	return problems
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function deepFreeze(t: { [any]: any }): { [any]: any }
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			deepFreeze(v)
		end
	end
	return table.freeze(t)
end

-- Validates and compiles raw defs (tables keyed by file name). Errors with
-- every problem listed if anything is invalid. Inputs are not modified.
function Defs.build(raw: RawDefs): DefSet
	local problems = Defs.validate(raw)
	if #problems > 0 then
		error(`Defs: {#problems} problem(s):\n  {table.concat(problems, "\n  ")}`, 2)
	end

	local weaponIds = sortedKeys(raw.weapons)
	local unitIds = sortedKeys(raw.units)

	local weapons: { [string]: any } = {}
	local weaponByIndex = {}
	for index, id in weaponIds do
		local w = deepCopy(raw.weapons[id])
		w.index = index
		for _, class in ArmorClasses.list do
			if w.damage[class] == nil then
				log:warn("weapon %s: damage.%s missing, counts as 0", id, class)
				w.damage[class] = 0
			end
		end
		w.targetMask = Categories.mask(w.targets)
		w.priorityMasks = {}
		for i, name in w.priority or {} do
			w.priorityMasks[i] = Categories.Bit[name]
		end
		weapons[id] = w
		weaponByIndex[index] = w
	end

	local units: { [string]: any } = {}
	local unitByIndex = {}
	for index, id in unitIds do
		local u = deepCopy(raw.units[id])
		u.index = index
		u.categoryMask = Categories.mask(u.categories)
		local maxRange = 0
		for _, slot in u.weapons do
			local w = weapons[slot.def]
			slot.weaponIndex = w.index
			if w.stockpile then
				slot.stockCapacity = slot.stockpile or w.stockpile.capacity
			end
			maxRange = math.max(maxRange, w.range)
		end
		u.maxRange = maxRange
		units[id] = u
		unitByIndex[index] = u
	end

	local hash = Hash.value({ units = unitByIndex, weapons = weaponByIndex })

	return deepFreeze({
		units = units,
		weapons = weapons,
		unitByIndex = unitByIndex,
		weaponByIndex = weaponByIndex,
		hash = hash,
	}) :: any
end

local loaded: DefSet? = nil

-- The registered defs (Defs/Registry), built on first call.
function Defs.load(): DefSet
	if loaded == nil then
		loaded = Defs.build(require("./Registry") :: any)
	end
	return loaded :: DefSet
end

return Defs
