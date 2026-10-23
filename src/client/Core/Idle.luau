--!strict
-- Idle builders and factories (C-158, the user's queue item 4; BAR's idle
-- indicators): the top strip's counts, the I key's cycle and the marks over
-- idle builders. Pure Luau (C-7).
--
-- The server will say which own units are idle (sim request 62). Until it
-- does, the client guesses from what it sees: a factory is idle when its
-- queue (the owner field, S-61) is empty or was never sent (the server
-- sends one only once the factory has had a queue); a builder when it has stood still
-- STILL_SECONDS with no order of ours left (Core/Waypoints) and no own frame
-- going up within its build range. Only units in the tactical tier count
-- (owner fields don't reach the rest).

local World = require("./World")

local Idle = {}

Idle.STILL_SECONDS = 3

export type State = {
	since: { [number]: number }, -- builder id → when it was first seen idle-looking
	builders: { number }, -- idle builders, sorted by id
	factories: { number },
	last: { builder: number, factory: number }, -- the last id the cycle picked
}

function Idle.new(): State
	return { since = {}, builders = {}, factories = {}, last = { builder = 0, factory = 0 } }
end

function Idle.isBuilder(def: any): boolean
	return def ~= nil and def.domain ~= "structure" and def.buildOptions ~= nil and #def.buildOptions > 0
end

function Idle.isFactory(def: any): boolean
	return def ~= nil and def.domain == "structure" and def.buildOptions ~= nil and #def.buildOptions > 0
end

-- Is `u` putting up a frame: an own unfinished structure within its build range?
local function building(world: World.World, u: World.Unit, def: any): boolean
	local range = (def.buildRange or 0) + 16
	for _, s in world.units do
		if s.team == u.team and s.build and s.build < 1 and (s.x - u.x) ^ 2 + (s.z - u.z) ^ 2 <= range * range then
			return true
		end
	end
	return false
end

-- Recounts. `hasOrders(id)`: whether the client still shows orders for it
-- (Waypoints). `now` in seconds.
function Idle.update(st: State, world: World.World, hasOrders: (number) -> boolean, now: number)
	table.clear(st.builders)
	table.clear(st.factories)
	local me = world.me and world.me.team
	for id, u in world.units do
		if u.team ~= me or u.tier ~= "tactical" or (u.build or 1) < 1 then
			st.since[id] = nil
			continue
		end
		local def = World.def(world, u)
		if Idle.isFactory(def) then
			if u.queue == nil or #u.queue == 0 then
				table.insert(st.factories, id)
			end
		elseif Idle.isBuilder(def) then
			local looks = not World.moving(world, u) and not hasOrders(id) and not building(world, u, def)
			if looks then
				local since = st.since[id]
				if since == nil then
					st.since[id] = now
				elseif now - since >= Idle.STILL_SECONDS then
					table.insert(st.builders, id)
				end
			else
				st.since[id] = nil
			end
		end
	end
	for id in st.since do
		if world.units[id] == nil then
			st.since[id] = nil
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
