--!strict
-- Missile stockpiles (S-47, client request 25; guide 4.3, 8). A weapon with a
-- `stockpile` fires only while its slot has a missile in stock
-- (World.wStock), and the unit builds one missile at a time per slot while
-- below capacity, paying the weapon's stockpile cost over its buildTime like
-- construction (slower while the team stalls). Unfinished frames build
-- nothing. Scenario and test spawns (Spawn.unit) start full; finished frames
-- and units out of a factory start empty.

local Economy = require("./Economy")
local Types = require("./Types")
local World = require("./World")

local Stockpile = {}

Stockpile.DT = 1 / 15

-- Per DefSet: unit def index → its stockpile slots, or false.
type Slot = { slot: number, buildTime: number, supply: number, power: number }
local cache: { [any]: { [number]: { Slot } | false } } = setmetatable({}, { __mode = "k" }) :: any

local function slotsOf(sim: Types.Sim, defIndex: number): { Slot } | false
	local byDef = cache[sim.defs]
	if byDef == nil then
		byDef = {}
		cache[sim.defs] = byDef
	end
	local slots = byDef[defIndex]
	if slots == nil then
		local list: { Slot } = {}
		local d = sim.defs.unitByIndex[defIndex]
		for i, s in d.weapons do
			local sp = sim.defs.weapons[s.def].stockpile
			if s.stockCapacity and sp then
				table.insert(list, { slot = i, buildTime = sp.buildTime, supply = sp.cost.supply or 0, power = sp.cost.power or 0 })
			end
		end
		slots = if #list > 0 then list else false
		byDef[defIndex] = slots
	end
	return slots :: { Slot } | false
end

-- Starting stock per weapon slot of unit def `defIndex` (World.spawn's
-- weaponStock): full or empty; nil when it has no stockpile.
function Stockpile.initial(sim: Types.Sim, defIndex: number, full: boolean): { [number]: number }?
	if not slotsOf(sim, defIndex) then
		return nil
	end
	local out = {}
	for i, s in sim.defs.unitByIndex[defIndex].weapons do
		if s.stockCapacity then
			out[i] = if full then s.stockCapacity else 0
		end
	end
	return out
end

-- Empties a unit's stockpiles (a unit rolling out of a factory).
function Stockpile.empty(sim: Types.Sim, id: number)
	local w = sim.world
	for slot = 1, w.weaponCount[id] do
		local key = World.slotKey(id, slot)
		if w.wStock[key] ~= nil then
			w.wStock[key] = 0
			w.wStockProgress[key] = 0
		end
	end
end

-- May weapon slot `key` fire? Always for weapons without a stockpile.
function Stockpile.ready(w: World.World, key: number): boolean
	local stock = w.wStock[key]
	return stock == nil or stock >= 1
end

-- Spends a missile on a shot of slot `key` (no-op without a stockpile).
function Stockpile.take(w: World.World, key: number)
	local stock = w.wStock[key]
	if stock ~= nil then
		w.wStock[key] = stock - 1
	end
end

-- The capacity of unit `id`'s weapon slot (nil without a stockpile).
function Stockpile.capacity(sim: Types.Sim, id: number, slot: number): number?
	local s = sim.defs.unitByIndex[sim.world.defIndex[id]].weapons[slot]
	return s and s.stockCapacity
end

-- Construction-step economy consumer (Build.step): every finished unit
-- below capacity builds its next missile.
function Stockpile.step(sim: Types.Sim, demandS: { [number]: number }, demandP: { [number]: number })
	local w = sim.world
	local eco = sim.eco
	for _, id in w.ids do
		local slots = slotsOf(sim, w.defIndex[id])
		if not slots or w.buildProgress[id] < 1 then
			continue
		end
		local weapons = sim.defs.unitByIndex[w.defIndex[id]].weapons
		for _, s in slots do
			local key = World.slotKey(id, s.slot)
			local stock = w.wStock[key]
			if stock == nil or stock >= (weapons[s.slot].stockCapacity :: number) then
				continue
			end
			local cs, cp = s.supply, s.power
			local rate = 1 / s.buildTime -- missiles per second at full economy
			local team = w.team[id]
			local acc = eco.accounts[team]
			demandS[team] += cs * rate
			demandP[team] += cp * rate
			local step = rate * Stockpile.DT * Economy.effective(acc, cs, cp)
			if cs > 0 then
				step = math.min(step, Economy.allowance(acc.supply) / cs)
			end
			if cp > 0 then
				step = math.min(step, Economy.allowance(acc.power) / cp)
			end
			if step <= 0 then
				continue
			end
			step = math.min(step, 1 - w.wStockProgress[key])
			acc.supply.spent += cs * step
			acc.power.spent += cp * step
			local p = w.wStockProgress[key] + step
			if p >= 1 - 1e-9 then
				w.wStock[key] = stock + 1
				p = 0
			end
			w.wStockProgress[key] = p
		end
	end
end

return Stockpile
