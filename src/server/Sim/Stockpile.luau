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

-- Steps of build progress that put a STOCK record on the wire (S-49): the
-- client fills the next missile's pip from them.
Stockpile.WIRE_STEPS = 16

-- Construction-step economy consumer (Build.step): every finished unit
-- below capacity builds its next missile.
-- Refills come first in a stall, up to Economy.REFILL_PRIORITY of income
-- (S-66): their demand is also added to `priorityS` / `priorityP`, and they
-- progress at the priority ratio. Build.step runs this before construction.
-- A low-priority stockpiler (S-156) refills last instead, at the low ratios.
function Stockpile.step(sim: Types.Sim, demandS: { [number]: number }, demandP: { [number]: number }, priorityS: { [number]: number }, priorityP: { [number]: number }, lowS: { [number]: number }, lowP: { [number]: number })
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
			local step
			if bit32.band(w.state[id], World.State.LOW_PRIORITY) ~= 0 then
				lowS[team] += cs * rate
				lowP[team] += cp * rate
				step = rate * Stockpile.DT * Economy.effective(acc, cs, cp, true)
			else
				priorityS[team] += cs * rate
				priorityP[team] += cp * rate
				step = rate * Stockpile.DT * Economy.priorityEffective(acc, cs, cp)
			end
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

-- Heavy shots (S-205, the user's playtest 3 H32: "Bulwark only shoot its
-- primary turret for once and never used it again"). A weapon whose shot
-- costs CHARGE_MIN power or more (the beam towers, the Centurion's lance)
-- no longer needs the whole cost in the team's stores the moment it fires:
-- in a real match construction keeps power near zero, so after the first
-- shot it never fired again. Instead it pays the next shot while it
-- reloads, cost / reload per second, as a priority consumer like a missile
-- refill (a low-priority unit's last), and fires once both are done. The
-- D-Gun (a bolt, ordered by hand) still pays at once. Spawned charged.
Stockpile.CHARGE_MIN = 100

-- Does `weapon` charge its shots (rather than pay at once)?
function Stockpile.charges(weapon: any): boolean
	local cost = weapon.shotCost
	return cost ~= nil and (cost.power or 0) + (cost.supply or 0) >= Stockpile.CHARGE_MIN and not weapon.bolt
end

-- Per DefSet: unit def index → its charging slots, or false.
local chargeCache: { [any]: { [number]: { number } | false } } = setmetatable({}, { __mode = "k" }) :: any
local function chargingSlots(sim: Types.Sim, defIndex: number): { number } | false
	local byDef = chargeCache[sim.defs]
	if byDef == nil then
		byDef = {}
		chargeCache[sim.defs] = byDef
	end
	local slots = byDef[defIndex]
	if slots == nil then
		local list = {}
		for i, s in sim.defs.unitByIndex[defIndex].weapons do
			if Stockpile.charges(sim.defs.weaponByIndex[s.weaponIndex]) then
				table.insert(list, i)
			end
		end
		slots = if #list > 0 then list else false
		byDef[defIndex] = slots
	end
	return slots :: { number } | false
end

-- Is slot `key` charged for its next shot?
function Stockpile.charged(w: World.World, key: number): boolean
	local c = w.wCharge[key]
	return c == nil or c >= 1
end

-- A shot of slot `key` spent the charge: the next one starts.
function Stockpile.discharge(w: World.World, key: number)
	w.wCharge[key] = 0
end

-- Construction-step economy consumer (Build.step, after the refills).
function Stockpile.chargeStep(sim: Types.Sim, demandS: { [number]: number }, demandP: { [number]: number }, priorityS: { [number]: number }, priorityP: { [number]: number }, lowS: { [number]: number }, lowP: { [number]: number })
	local w = sim.world
	local eco = sim.eco
	for _, id in w.ids do
		local slots = chargingSlots(sim, w.defIndex[id])
		if not slots or w.buildProgress[id] < 1 then
			continue
		end
		local weapons = sim.defs.unitByIndex[w.defIndex[id]].weapons
		for _, slot in slots do
			local key = World.slotKey(id, slot)
			local p = w.wCharge[key]
			if p == nil then
				continue -- charged
			end
			local weapon = sim.defs.weaponByIndex[weapons[slot].weaponIndex]
			local cost = weapon.shotCost :: { supply: number?, power: number? }
			local cs, cp = cost.supply or 0, cost.power or 0
			local rate = 1 / math.max(weapon.reload, Stockpile.DT) -- shots per second at full economy
			local team = w.team[id]
			local acc = eco.accounts[team]
			demandS[team] += cs * rate
			demandP[team] += cp * rate
			local step
			if bit32.band(w.state[id], World.State.LOW_PRIORITY) ~= 0 then
				lowS[team] += cs * rate
				lowP[team] += cp * rate
				step = rate * Stockpile.DT * Economy.effective(acc, cs, cp, true)
			else
				priorityS[team] += cs * rate
				priorityP[team] += cp * rate
				step = rate * Stockpile.DT * Economy.priorityEffective(acc, cs, cp)
			end
			if cs > 0 then
				step = math.min(step, Economy.allowance(acc.supply) / cs)
			end
			if cp > 0 then
				step = math.min(step, Economy.allowance(acc.power) / cp)
			end
			if step <= 0 then
				continue
			end
			step = math.min(step, 1 - p)
			acc.supply.spent += cs * step
			acc.power.spent += cp * step
			p += step
			w.wCharge[key] = if p >= 1 - 1e-9 then nil else p
		end
	end
end

return Stockpile
