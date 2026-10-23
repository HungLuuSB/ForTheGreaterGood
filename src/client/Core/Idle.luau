--!strict
-- Idle builders and factories (C-158, the user's queue item 4; BAR's idle
-- indicators): the top strip's counts, the I key's cycle and the marks over
-- idle builders. Pure Luau (C-7).
--
-- The server says which of the player's builders and factories are idle,
-- on camera or not (IDLE events, protocol 31, S-136, request 62:
-- `world.idle`): a builder with no order and no build / assist / repair /
-- reclaim work, a factory with an empty queue.

local World = require("./World")

local Idle = {}

export type State = {
	builders: { number }, -- idle builders, sorted by id
	factories: { number },
	last: { builder: number, factory: number }, -- the last id the cycle picked
}

function Idle.new(): State
	return { builders = {}, factories = {}, last = { builder = 0, factory = 0 } }
end

function Idle.isBuilder(def: any): boolean
	return def ~= nil and def.domain ~= "structure" and def.buildOptions ~= nil and #def.buildOptions > 0
end

function Idle.isFactory(def: any): boolean
	return def ~= nil and def.domain == "structure" and def.buildOptions ~= nil and #def.buildOptions > 0
end

-- Recounts from the server's idle list (own units the client still knows).
function Idle.update(st: State, world: World.World)
	table.clear(st.builders)
	table.clear(st.factories)
	local me = world.me and world.me.team
	for id in world.idle do
		local u = world.units[id]
		local def = u and u.team == me and World.def(world, u)
		if def and Idle.isFactory(def) then
			table.insert(st.factories, id)
		elseif def and Idle.isBuilder(def) then
			table.insert(st.builders, id)
		end
	end
	table.sort(st.builders)
	table.sort(st.factories)
end

-- The next idle builder (or factory) after the last one picked, wrapping;
-- nil when there's none.
function Idle.next(st: State, kind: "builder" | "factory"): number?
	local list = if kind == "builder" then st.builders else st.factories
	if #list == 0 then
		return nil
	end
	local last = st.last[kind]
	for _, id in list do
		if id > last then
			st.last[kind] = id
			return id
		end
	end
	st.last[kind] = list[1]
	return list[1]
end

return Idle
