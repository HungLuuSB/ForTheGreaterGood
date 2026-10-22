--!strict
-- Which commands a selection offers (C-109, the user: each unit gets its own
-- set): the union of every selected type's commands, in the command card's
-- order. Pure Luau (C-7).
--   every unit   stop
--   armed        fire state, attack
--   mobile       move, fight, patrol, guard; move state when armed
--   builders     repair, reclaim (and move / guard to assist when mobile)
--   factories    repeat, cancel; move, fight, patrol, guard, attack as
--                orders for the units they produce (the sim's order list
--                per factory, copied to each new unit: S-95)
--   switchable   on / off (converters; beam towers retract when off, S-96)
--   silos        stop (the launch), attack (a manual launch at a point)
-- "alert" (jump to the last alert) is always there: it's not a unit order.

local CommandSet = {}

CommandSet.ORDER = { "fire", "movestate", "repeat", "toggle", "cancel", "stop", "attack", "move", "patrol", "fight", "guard", "repair", "reclaim", "alert" }

local function isFactory(def: any): boolean
	return def.domain == "structure" and def.buildOptions ~= nil and #def.buildOptions > 0
end

-- The commands one unit type offers, as a set.
function CommandSet.forDef(def: any): { [string]: boolean }
	local set: { [string]: boolean } = { stop = true }
	local armed = def.weapons ~= nil and #def.weapons > 0
	local mobile = def.domain ~= "structure" and def.movement ~= nil and (def.movement.maxSpeed or 0) > 0
	local builder = (def.buildPower or 0) > 0
	-- a silo: every weapon a stockpiled launcher (no fire state: it only fires on a manual attack)
	local silo = armed and def.domain == "structure"
	for _, ws in def.weapons or {} do
		silo = silo and (ws :: any).stockCapacity ~= nil
	end
	if armed then
		set.attack = true
		if not silo then
			set.fire = true
		end
	end
	if mobile then
		set.move, set.fight, set.patrol, set.guard = true, true, true, true
		if armed then
			set.movestate = true
		end
	end
	if builder and not isFactory(def) then
		set.repair, set.reclaim = true, true
	end
	if isFactory(def) then
		set["repeat"], set.cancel = true, true
		set.move, set.fight, set.patrol, set.guard, set.attack = true, true, true, true, true
	end
	if def.converter ~= nil or def.toggle ~= nil or def.retract ~= nil then
		set.toggle = true
	end
	return set
end

-- The selection's commands in card order (`defs`: the selected units' defs).
function CommandSet.of(defs: { any }): { string }
	local any: { [string]: boolean } = {}
	for _, def in defs do
		for name in CommandSet.forDef(def) do
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
