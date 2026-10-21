--!strict
-- Deployable units (S-64; Order's Warden, docs/design/factions.md section 4).
-- A unit whose def has `deploy = { time, armor }` unpacks into a fortified
-- emplacement whenever it stands still: no move order (or an attack-move
-- holding to engage, Orders), at speed 0. Unpacking and packing each take
-- `time` seconds; progress runs 0 (packed) .. 1 (deployed).
--   * packed (0): moves, but its weapons don't fire;
--   * deploying or packing (between): neither moves nor fires;
--   * deployed (1): fires, can't move or be pushed, and takes damage / armor.
-- A move order on a deployed unit packs it first, then it drives off.
-- State bits: DEPLOYED at 1, DEPLOYING in between (Schema.UnitState).
-- Run at the start of Movement, every tick; units listed in
-- World.deployIds in the order they entered (deterministic).

local Lifecycle = require("./Lifecycle")
local Types = require("./Types")
local World = require("./World")

local Deploy = {}

local DT = 1 / 15
local DEPLOYED, DEPLOYING = World.State.DEPLOYED, World.State.DEPLOYING
local band, bor, bnot = bit32.band, bit32.bor, bit32.bnot

local function defOf(sim: Types.Sim, id: number): any
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

-- Lifecycle hooks.
function Deploy.added(sim: Types.Sim, id: number)
	if defOf(sim, id).deploy then
		local w = sim.world
		w.deploy[id] = 0
		table.insert(w.deployIds, id)
	end
end

function Deploy.removed(sim: Types.Sim, id: number)
	local w = sim.world
	if w.deploy[id] ~= nil then
		w.deploy[id] = nil
		local i = table.find(w.deployIds, id)
		if i then
			table.remove(w.deployIds, i)
		end
	end
end

function Deploy.step(sim: Types.Sim)
	local w = sim.world
	local hold = sim.orders.hold
	for _, id in w.deployIds do
		local d = defOf(sim, id).deploy
		local p = w.deploy[id]
		local want = w.speed[id] <= 0 and (w.orderId[id] == 0 or hold[id] == true)
		local rate = DT / d.time
		local np = if want then math.min(1, p + rate) else math.max(0, p - rate)
		if np ~= p then
			w.deploy[id] = np
			local state = band(w.state[id], bnot(DEPLOYED + DEPLOYING))
			if np >= 1 then
				state = bor(state, DEPLOYED)
			elseif np > 0 then
				state = bor(state, DEPLOYING)
			end
			if state ~= w.state[id] then
				World.setState(w, id, state)
			end
		end
	end
end

-- Neither moves nor gets pushed: deploying, deployed or packing.
function Deploy.anchored(w: World.World, id: number): boolean
	local p = w.deploy[id]
	return p ~= nil and p > 0
end

-- May fire: not a deployer, or fully deployed.
function Deploy.canFire(w: World.World, id: number): boolean
	local p = w.deploy[id]
	return p == nil or p >= 1
end

-- Damage taken is divided by this (the def's armor while deployed, else 1).
function Deploy.armor(sim: Types.Sim, id: number): number
	local p = sim.world.deploy[id]
	if p == nil or p < 1 then
		return 1
	end
	return defOf(sim, id).deploy.armor
end

table.insert(Lifecycle.addedHooks, Deploy.added)
table.insert(Lifecycle.removalHooks, Deploy.removed)

return Deploy
