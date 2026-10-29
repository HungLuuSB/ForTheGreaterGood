--!strict
local Categories = require("@shared/Defs/Categories")
local Defs = require("@shared/Defs/Defs")
local Log = require("@shared/Util/Log")
local Registry = require("@shared/Defs/Registry")
local RunAll = require("./RunAll")

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

-- A fresh, valid, mutable copy of the registered defs.
local function raw(): Defs.RawDefs
	return deepCopy(Registry)
end

-- Builds `defs` and returns the error message (fails the test if it builds).
local function buildError(t: RunAll.Context, defs: Defs.RawDefs): string
	local ok, err = pcall(Defs.build, defs)
	t.expect(not ok, "broken defs built without error")
	return tostring(err)
end

local function expectProblem(t: RunAll.Context, defs: Defs.RawDefs, needle: string)
	local message = buildError(t, defs)
	t.expect(string.find(message, needle, 1, true) ~= nil, `expected "{needle}" in:\n{message}`)
end

local function withCapturedLog(fn: () -> ()): { string }
	local lines = {}
	Log.setSink(function(_level, line)
		table.insert(lines, line)
	end)
	local ok, err = pcall(fn)
	Log.setSink(nil)
	if not ok then
		error(err, 0)
	end
	return lines
end

return function(t: RunAll.Context)
	t.test("registered defs load", function()
		local set = Defs.load()
		t.expect(set.units.ord_lancer ~= nil, "ord_lancer missing")
		t.expect(set.units.chs_ravager ~= nil, "chs_ravager missing")
		t.expect(set.weapons.ord_light_cannon ~= nil, "ord_light_cannon missing")
		t.expect(Defs.load() == set, "load() should build once and cache")
	end)

	t.test("numeric indices are 1-based and sorted by id", function()
		local set = Defs.load()
		-- Expected order: the registry's file names, sorted independently here.
		for kind, byIndex in { units = set.unitByIndex, weapons = set.weaponByIndex } do
			local ids = {}
			for id in (Registry :: any)[kind] do
				table.insert(ids, id)
			end
			table.sort(ids)
			t.equal(#byIndex, #ids, `{kind}: one index per def`)
			for i, id in ids do
				local def = (set :: any)[kind][id]
				t.equal(def.index, i, `{kind}: {id} index`)
				t.equal(byIndex[i], def, `{kind}: byIndex[{i}]`)
			end
		end
		t.expect(set.units.chs_ravager.index < set.units.ord_lancer.index, "chs_ before ord_")
		t.equal(set.weaponByIndex[1].index, 1, "weapons are 1-based")
		t.equal(set.unitByIndex[1].index, 1, "units are 1-based")
	end)

	t.test("derived values are computed", function()
		local set = Defs.load()
		local lancer = set.units.ord_lancer
		t.equal(lancer.categoryMask, Categories.Bit.GROUND + Categories.Bit.ARMORED)
		t.equal(lancer.weapons[1].weaponIndex, set.weapons.ord_lancer_cannon.index)
		t.equal(lancer.maxRange, 95) -- ord_lancer_cannon's range: 190 halved (S-22, S-62, S-157, S-179)
		t.equal(set.units.chs_ravager.maxRange, 78)
		local cannon = set.weapons.ord_lancer_cannon
		t.equal(cannon.targetMask, Categories.mask({ "GROUND", "NAVAL", "STRUCTURE" }))
		t.deepEqual(cannon.priorityMasks, { Categories.Bit.ARMORED, Categories.Bit.GROUND, Categories.Bit.STRUCTURE })
	end)

	t.test("templates fill in shared fields", function()
		local lancer = Defs.load().units.ord_lancer
		t.equal(lancer.moveClass, "TRACKED")
		t.equal(lancer.armorClass, "ARMORED")
		t.deepEqual(lancer.pieces, { "base", "turret", "barrel", "muzzle" })
		-- the unit sets only sight; the template supplies the rest
		t.deepEqual(lancer.sensors, { sight = (Registry.units.ord_lancer :: any).sensors.sight, radar = 0, sonar = 0, radarSignature = 1 }, "sensors merge key by key")
	end)

	t.test("extend deep-merges records, replaces lists, keeps inputs intact", function()
		local base = { a = 1, rec = { x = 1, y = 2 }, list = { "p", "q" } }
		local out = Defs.extend(base, { rec = { y = 3 }, list = { "r" }, b = 2 })
		t.deepEqual(out, { a = 1, b = 2, rec = { x = 1, y = 3 }, list = { "r" } })
		t.deepEqual(base, { a = 1, rec = { x = 1, y = 2 }, list = { "p", "q" } }, "base unchanged")
		out.rec.x = 99
		t.equal(base.rec.x, 1, "result does not share tables with base")
	end)

	t.test("built defs are frozen", function()
		local lancer = Defs.load().units.ord_lancer
		t.throws(function()
			(lancer :: any).health = 1
		end)
		t.throws(function()
			(lancer.movement :: any).maxSpeed = 1
		end)
	end)

	t.test("hash is stable and changes when a stat changes", function()
		local a = Defs.build(raw())
		local b = Defs.build(raw())
		t.equal(a.hash, b.hash)
		t.equal(a.hash, Defs.load().hash)
		t.expect(a.hash >= 0 and a.hash < 2 ^ 32 and a.hash == math.floor(a.hash), "hash must be a u32")

		local changed = raw()
		changed.weapons.ord_light_cannon.reload = 1.7
		t.notEqual(Defs.build(changed).hash, a.hash)
		local renamed = raw()
		renamed.units.ord_lancer.name = "Lancer II"
		t.notEqual(Defs.build(renamed).hash, a.hash)
	end)

	t.test("missing damage entries count as 0 and are logged", function()
		local defs = raw()
		defs.weapons.ord_light_cannon.damage.SUB = nil
		local built
		local lines = withCapturedLog(function()
			built = Defs.build(defs)
		end)
		t.equal(built.weapons.ord_light_cannon.damage.SUB, 0)
		t.deepEqual(lines, { "[WARN][Defs] weapon ord_light_cannon: damage.SUB missing, counts as 0" })
	end)

	t.test("broken defs fail with clear messages", function()
		local cases: { { any } } = {
			{ 'unit ord_lancer: id: "ord_lance" does not match its file name "ord_lancer"', function(d)
				d.units.ord_lancer.id = "ord_lance"
			end },
			{ "must be lowercase snake_case", function(d)
				d.units.Ord_Tank = d.units.ord_lancer
				d.units.Ord_Tank.id = "Ord_Tank"
			end },
			{ "must start with ord_, chs_ or neu_", function(d)
				d.units.tank = d.units.ord_lancer
				d.units.tank.id = "tank"
			end },
			{ "unit ord_lancer: health: missing required field", function(d)
				d.units.ord_lancer.health = nil
			end },
			{ 'unit ord_lancer: health: expected a number, got "lots"', function(d)
				d.units.ord_lancer.health = "lots"
			end },
			{ "unit ord_lancer: movement.maxSpeed: expected a number > 0, got -5", function(d)
				d.units.ord_lancer.movement.maxSpeed = -5
			end },
			{ "unit ord_lancer: movement.maxspeed: unknown field", function(d)
				d.units.ord_lancer.movement.maxspeed = 40 -- typo
			end },
			{ "unit ord_lancer: tier: expected an integer, got 1.5", function(d)
				d.units.ord_lancer.tier = 1.5
			end },
			{ 'unit ord_lancer: categories[2]: "ARMOURED" is not one of', function(d)
				d.units.ord_lancer.categories[2] = "ARMOURED"
			end },
			{ 'unit ord_lancer: weapons[1].def: unknown weapon "ord_rail"', function(d)
				d.units.ord_lancer.weapons[1].def = "ord_rail"
			end },
			{ 'unit ord_lancer: weapons[1].turretPiece: piece "bay" is not in pieces', function(d)
				d.units.ord_lancer.weapons[1].turretPiece = "bay" -- the client rig needs it (S-3)
			end },
			{ "weapon chs_goliath_cannon: turret: restPitch -70 is outside minPitch..maxPitch (-65..20)", function(d)
				d.weapons.chs_goliath_cannon.turret.restPitch = -70 -- the arms can't rest below their limit (S-20)
			end },
			{ "weapon ord_rockets: turret: restYaw 90 is outside its 120° arc", function(d)
				d.weapons.ord_rockets.turret.restYaw = 90
			end },
			{ 'unit ord_absolution: weapons[1].turretPiece: weapon "ord_bomb" has no turret to turn it', function(d)
				d.units.ord_absolution.weapons[1].turretPiece = "bay" -- bombs fall from a fixed bay (S-11)
			end },
			{ 'unit ord_lancer: moveClass: unknown move class "TRACKS"', function(d)
				d.units.ord_lancer.moveClass = "TRACKS"
			end },
			{ 'unit ord_lancer: armorClass: "HEAVY" is not one of', function(d)
				d.units.ord_lancer.armorClass = "HEAVY"
			end },
			{ 'unit ord_lancer: faction: "chaos" does not match the id prefix (expected "order")', function(d)
				d.units.ord_lancer.faction = "chaos"
			end },
			{ "unit ord_lancer: weapons: at most 8 entries allowed, has 9", function(d)
				local slots = {}
				for i = 1, 9 do
					slots[i] = { def = "ord_light_cannon" }
				end
				d.units.ord_lancer.weapons = slots
			end },
			{ "unit ord_lancer: buildPower: builders (units with buildOptions) need buildPower > 0", function(d)
				d.units.ord_lancer.buildOptions = { "chs_ravager" }
			end },
			{ "unit ord_lancer: buildPower: only builders (units with buildOptions) have buildPower", function(d)
				d.units.ord_lancer.buildPower = 10
			end },
			{ 'unit ord_lancer: buildOptions[1]: unknown unit "ord_factory"', function(d)
				d.units.ord_lancer.buildOptions = { "ord_factory" }
				d.units.ord_lancer.buildPower = 10
			end },
			{ 'unit ord_lancer: wreck: unknown def "neu_wreck_small"', function(d)
				d.units.ord_lancer.wreck = "neu_wreck_small"
			end },
			{ "unit ord_lancer: script: expected a string, got", function(d)
				d.units.ord_lancer.script = function() end
			end },
			{ "unit ord_lancer: movement: structures don't move; remove it", function(d)
				d.units.ord_lancer.domain = "structure"
				d.units.ord_lancer.moveClass = nil
			end },
			{ "unit ord_lancer: extractor: only structures can be extractors", function(d)
				d.units.ord_lancer.extractor = { rate = 1 }
			end },
			{ "unit ord_lancer: placement: only structures have a placement class", function(d)
				d.units.ord_lancer.placement = "land"
			end },
			{ "unit ord_mason: buildRange: mobile builders need buildRange", function(d)
				d.units.ord_mason.buildRange = nil
			end },
			{ 'unit ord_vehplant: buildOptions[2]: unknown unit "ord_no_such_unit"', function(d)
				d.units.ord_vehplant.buildOptions[2] = "ord_no_such_unit"
			end },
			{ "unit ord_solar: production.power: expected a number >= 0, got -5", function(d)
				d.units.ord_solar.production.power = -5
			end },
			{ "weapon ord_light_cannon: damage.HEAVY: unknown field", function(d)
				d.weapons.ord_light_cannon.damage.HEAVY = 10
			end },
			{ "weapon ord_light_cannon: damage.LIGHT: expected a number >= 0, got -1", function(d)
				d.weapons.ord_light_cannon.damage.LIGHT = -1
			end },
			{ "weapon ord_light_cannon: gravity: required for BALLISTIC weapons", function(d)
				d.weapons.ord_light_cannon.gravity = nil
			end },
			{ "weapon ord_light_cannon: guidance: required for HOMING weapons", function(d)
				d.weapons.ord_light_cannon.type = "HOMING"
				d.weapons.ord_light_cannon.turnRate = 90
			end },
			{ "weapon ord_light_cannon: guidance: only HOMING and TORPEDO weapons are guided, not BALLISTIC", function(d)
				d.weapons.ord_light_cannon.guidance = "IR"
			end },
			{ "weapon ord_light_cannon: turret: minPitch 30 is above maxPitch 20", function(d)
				d.weapons.ord_light_cannon.turret.minPitch = 30
			end },
			{ 'weapon ord_light_cannon: type: "LASER" is not one of', function(d)
				d.weapons.ord_light_cannon.type = "LASER"
			end },
			{ "weapon ord_light_cannon: targets: needs at least 1 entry, has 0", function(d)
				d.weapons.ord_light_cannon.targets = {}
			end },
		}
		for _, case in cases do
			local defs = raw()
			case[2](defs)
			expectProblem(t, defs, case[1])
		end
	end)

	t.test("all problems are reported at once", function()
		local defs = raw()
		defs.units.ord_lancer.health = -1
		defs.units.chs_ravager.icon = nil
		defs.weapons.chs_light_cannon.range = 0
		local message = buildError(t, defs)
		t.expect(string.find(message, "Defs: 3 problem(s):", 1, true) ~= nil, message)
		t.expect(string.find(message, "unit chs_ravager: icon: missing required field", 1, true) ~= nil, message)
		t.expect(string.find(message, "unit ord_lancer: health", 1, true) ~= nil, message)
		t.expect(string.find(message, "weapon chs_light_cannon: range", 1, true) ~= nil, message)
	end)

	t.test("validate returns an empty list for the registered defs", function()
		t.deepEqual(Defs.validate(raw()), {})
	end)
end
