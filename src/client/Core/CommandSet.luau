--!strict
-- Which commands a selection offers (C-109, the user: each unit gets its own
-- set): the union of every selected type's commands, in the command card's
-- order. Pure Luau (C-7). Audited unit by unit in C-193 (the user: "why
-- does the generator has a Stop command"):
--   stop         only what has something to stop: mobile units, builders,
--                factories, armed units and nuke silos; a generator, an
--                extractor, storage, sonar, a pad or a wall offers nothing
--   armed        fire state, attack
--   mobile       move, fight, patrol, guard; move state when armed
--   builders     repair, reclaim (and move / guard to assist when mobile);
--                "upgrade" (Upgrade extractors, an area command) when they
--                can build an extractor that upgrades in place (C-121)
--   factories    repeat, cancel; move, fight, patrol, guard, attack as
--                orders for the units they produce (the sim's order list
--                per factory, copied to each new unit: S-95)
--   switchable   on / off (converters; beam towers retract when off, S-96;
--                shield generators, to save power: C-193)
--   silos        stop (the launch), attack (a manual launch at a point);
--                only nuke silos (strategic weapons)
--   interceptors fire state only (hold fire keeps the stock): anti-nukes and
--                point defence never take a manual target
--   transports   load (pick a unit up), unload (set the cargo down at a
--                point); S-219, C-272
--   priority     high / low resource priority (S-156, C-196) on what uses
--                resources: builders and factories, stockpiling launchers,
--                aircraft (rearm), shields, radars, jammers, DIRCM
-- "alert" (jump to the last alert) is always there: it's not a unit order.

local Upgrades = require("./Upgrades")

local CommandSet = {}

CommandSet.ORDER = { "fire", "movestate", "retreat", "repeat", "toggle", "priority", "cancel", "stop", "attack", "dgun", "move", "patrol", "fight", "guard", "repair", "reclaim", "resurrect", "load", "unload", "upgrade", "selfdestruct", "alert" }

-- Whether `def` is a nuke silo: armed with strategic weapons only (they
-- launch on a manual attack at a point, ATTACK_GROUND; never at a unit).
function CommandSet.isSilo(def: any, all: any): boolean
	if def.weapons == nil or #def.weapons == 0 then
		return false
	end
	for _, ws in def.weapons do
		local w = all and all.weaponByIndex and all.weaponByIndex[(ws :: any).weaponIndex]
		if w == nil or w.strategic ~= true or w.intercepts ~= nil then
			return false
		end
	end
	return true
end

-- Whether `def` has a D-Gun (S-194: the Commanders' manual-fire bolt).
function CommandSet.hasDgun(def: any, all: any?): boolean
	for _, ws in def.weapons or {} do
		local w = all and all.weaponByIndex and all.weaponByIndex[(ws :: any).weaponIndex]
		if w and w.fx and w.fx.trail == "dgun" then
			return true
		end
	end
	return false
end

-- Whether resource priority does something for `def` (the sim's S-156
-- consumers): build power, missile stockpiles, rearming, upkeep.
function CommandSet.consumer(def: any): boolean
	if (def.buildPower or 0) > 0 or def.domain == "air" or def.shield ~= nil then
		return true
	end
	local s = def.sensors
	if s and (s.radarDrain or s.jamDrain or s.trackDrain) then
		return true
	end
	if def.countermeasures and def.countermeasures.dircm then
		return true
	end
	for _, ws in def.weapons or {} do
		if (ws :: any).stockCapacity ~= nil then
			return true
		end
	end
	return false
end

local function isFactory(def: any): boolean
	return def.domain == "structure" and def.buildOptions ~= nil and #def.buildOptions > 0
end

-- The commands one unit type offers, as a set (`all`: the def set, for
-- the upgrade command; without it there is none).
function CommandSet.forDef(def: any, all: any?): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local armed = def.weapons ~= nil and #def.weapons > 0
	local mobile = def.domain ~= "structure" and def.movement ~= nil and (def.movement.maxSpeed or 0) > 0
	local builder = (def.buildPower or 0) > 0
	-- what its weapons are (with the def set): nuke silos launch only on a
	-- manual attack; interceptors only ever shoot missiles down
	local silo, interceptor = armed, armed
	for _, ws in def.weapons or {} do
		local w = all and all.weaponByIndex and all.weaponByIndex[(ws :: any).weaponIndex]
		if w then
			silo = silo and w.strategic == true and w.intercepts == nil
			interceptor = interceptor and w.interceptOnly == true
		else
			-- (no def set: the old rule, every weapon stockpiled on a structure)
			silo = silo and def.domain == "structure" and (ws :: any).stockCapacity ~= nil
			interceptor = false
		end
	end
	if interceptor then
		set.fire = true
	elseif armed then
		set.attack, set.stop = true, true
		if not silo then
			set.fire = true
		end
	end
	if mobile or builder then
		set.stop = true
	end
	if mobile then
		set.move, set.fight, set.patrol, set.guard = true, true, true, true
		if armed then
			set.movestate = true
		end
	end
	if builder and not isFactory(def) then
		set.repair, set.reclaim = true, true
		if def.canResurrect then
			set.resurrect = true -- T1 workers (S-168, C-216)
		end
		if all ~= nil and Upgrades.upgraderFor(all, { def }) ~= nil then
			set.upgrade = true
		end
	end
	if isFactory(def) then
		set["repeat"], set.cancel, set.stop = true, true, true
		set.move, set.fight, set.patrol, set.guard, set.attack = true, true, true, true, true
	end
	if def.converter ~= nil or def.toggle ~= nil or def.retract ~= nil or def.shield ~= nil or def.cloak ~= nil then -- (cloakers: S-228)
		set.toggle = true
	end
	if CommandSet.consumer(def) then
		set.priority = true
	end
	-- protocol 39 (S-194): every unit can self-destruct; aircraft retreat to
	-- a pad below a health share; Commanders fire their D-Gun
	set.selfdestruct = true
	if def.domain == "air" and mobile then
		set.retreat = true
	end
	if CommandSet.hasDgun(def, all) then
		set.dgun = true
	end
	if def.transport ~= nil then
		set.load, set.unload = true, true -- air transports (S-219, C-272)
	end
	return set
end

-- The selection's commands in card order (`defs`: the selected units' defs;
-- `all`: the def set).
function CommandSet.of(defs: { any }, all: any?): { string }
	local any: { [string]: boolean } = {}
	for _, def in defs do
		for name in CommandSet.forDef(def, all) do
			any[name] = true
		end
	end
	local out = {}
	if #defs == 0 then
		return out
	end
	for _, name in CommandSet.ORDER do
		if any[name] or name == "alert" then
			table.insert(out, name)
		end
	end
	return out
end

return CommandSet
