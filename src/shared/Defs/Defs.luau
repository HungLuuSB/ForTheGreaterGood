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
	movement: { maxSpeed: number, accel: number, brake: number, turnRate: number }?,
	footprint: number,
	sensors: { sight: number, radar: number, sonar: number, radarSignature: number },
	weapons: { WeaponSlot },
	maxRange: number, -- derived: longest weapon range, 0 if unarmed
	countermeasures: any?,
	buildPower: number?,
	buildOptions: { string }?,
	buildRange: number?,
	model: string,
	pieces: { string },
	script: string?,
	icon: string,
	wreck: string?,
}

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
	guidance: ("IR" | "RADAR" | "COMMAND")?,
	turnRate: number?,
	lockRange: number?,
	terminalRange: number?,
	canTargetRadar: boolean?,
	fx: { [string]: string }?,
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
	fields = { charges = { kind = "integer", min = 0 }, chance = FRACTION },
}

local UNIT_SPEC: Spec = {
	kind = "record",
	fields = {
		id = STRING,
		name = STRING,
		description = STRING,
		faction = { kind = "string", enum = set({ "order", "chaos", "neutral" }) },
		tier = { kind = "integer", min = 0, max = 2 },
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
			fields = { maxSpeed = POSITIVE, accel = POSITIVE, brake = POSITIVE, turnRate = POSITIVE },
		},
		footprint = { kind = "integer", min = 1, max = 8 },
		sensors = {
			kind = "record",
			fields = { sight = NON_NEGATIVE, radar = NON_NEGATIVE, sonar = NON_NEGATIVE, radarSignature = FRACTION },
		},
		weapons = {
			kind = "list",
			maxItems = Defs.MAX_WEAPONS,
			item = {
				kind = "record",
				fields = { def = STRING, turretPiece = opt(STRING), pitchPiece = opt(STRING), muzzle = opt(STRING) },
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
		buildOptions = { kind = "list", optional = true, item = STRING, minItems = 1 },
		buildRange = opt(POSITIVE),
		model = STRING,
		pieces = { kind = "list", item = STRING, minItems = 1 },
		script = opt(STRING),
		icon = STRING,
		wreck = opt(STRING),
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
			},
		},
		guidance = { kind = "string", optional = true, enum = set({ "IR", "RADAR", "COMMAND" }) },
		turnRate = opt(POSITIVE),
		lockRange = opt(POSITIVE),
		terminalRange = opt(POSITIVE),
		canTargetRadar = { kind = "boolean", optional = true },
		fx = {
			kind = "record",
			optional = true,
			fields = { muzzle = opt(STRING), trail = opt(STRING), impact = opt(STRING), sound = opt(STRING) },
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
		if wtype == "BALLISTIC" and w.gravity == nil then
			report("gravity: required for BALLISTIC weapons")
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
		local turret = w.turret
		if
			type(turret) == "table"
			and type(turret.minPitch) == "number"
			and type(turret.maxPitch) == "number"
			and turret.minPitch > turret.maxPitch
		then
			report(`turret: minPitch {turret.minPitch} is above maxPitch {turret.maxPitch}`)
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
			for i, slot in u.weapons do
				if type(slot) == "table" and type(slot.def) == "string" and weapons[slot.def] == nil then
					report(`weapons[{i}].def: unknown weapon {describe(slot.def)}`)
				end
			end
		end

		local isBuilder = u.buildOptions ~= nil
		if isBuilder and u.buildPower == nil then
			report("buildPower: builders (units with buildOptions) need buildPower > 0")
		elseif not isBuilder and u.buildPower ~= nil then
			report("buildPower: only builders (units with buildOptions) have buildPower")
		end
		if not isBuilder and u.buildRange ~= nil then
			report("buildRange: only builders (units with buildOptions) have buildRange")
		end
		if type(u.buildOptions) == "table" then
			for i, option in u.buildOptions do
				if type(option) == "string" and units[option] == nil then
					report(`buildOptions[{i}]: unknown unit {describe(option)}`)
				end
			end
		end
		if type(u.wreck) == "string" and units[u.wreck] == nil then
			report(`wreck: unknown def {describe(u.wreck)}`)
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
