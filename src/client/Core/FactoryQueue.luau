--!strict
-- Factory queues as the client knows them (C-68): the server doesn't send
-- them yet (net.md: order queues aren't replicated; request 36), so this is
-- what the client queued, PLACEHOLDER until it does. An item leaves the
-- queue when a new own unit of its type shows up near its factory (back to
-- the end when the factory repeats), or when it is cancelled. Pure Luau.

local World = require("./World")

local FactoryQueue = {}

FactoryQueue.REACH = 80 -- studs: a new unit this close to a factory came out of it

export type Queue = {
	byFactory: { [number]: { number } }, -- factory ID → queued def indices, in order
	known: { [number]: boolean }, -- own unit IDs already accounted for
}

function FactoryQueue.new(): Queue
	return { byFactory = {}, known = {} }
end

function FactoryQueue.add(q: Queue, factory: number, defIndex: number, count: number)
	local list = q.byFactory[factory] or {}
	q.byFactory[factory] = list
	for _ = 1, count do
		table.insert(list, defIndex)
	end
end

-- Drops item `index` (1-based) of a factory's queue; 0 drops them all (CANCEL's `value`).
function FactoryQueue.remove(q: Queue, factory: number, index: number)
	local list = q.byFactory[factory]
	if list == nil then
		return
	end
	if index == 0 then
		table.clear(list)
	elseif list[index] then
		table.remove(list, index)
	end
end

-- Follows the world: produced units leave their factory's queue.
function FactoryQueue.step(q: Queue, world: World.World)
	local me = world.me.team
	for factory, list in q.byFactory do
		local f = world.units[factory]
		if f == nil then
			q.byFactory[factory] = nil
		end
	end
	for id in q.known do
		if world.units[id] == nil then
			q.known[id] = nil
		end
	end
	for id, u in world.units do
		if u.team ~= me or q.known[id] then
			continue
		end
		q.known[id] = true
		if u.defIndex == nil then
			continue
		end
		for factory, list in q.byFactory do
			local f = world.units[factory]
			if f and list[1] == u.defIndex and (f.x - u.x) ^ 2 + (f.z - u.z) ^ 2 <= FactoryQueue.REACH ^ 2 then
				local done = table.remove(list, 1) :: number
				if bit32.band(f.state or 0, 16) ~= 0 then -- Schema.UnitState.REPEAT
					table.insert(list, done)
				end
				break
			end
		end
	end
end

return FactoryQueue
