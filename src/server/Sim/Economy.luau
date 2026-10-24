--!strict
-- Team economy (guide 8): one account per ally team with supply and power.
--
-- Streaming model: nothing is paid upfront. Construction spends every tick
-- at a rate scaled by the team's stall ratio; the Economy system settles
-- every STEP_TICKS ticks (3 Hz):
--   stored := clamp(stored + income × window − spent + reclaimed, 0, storage)
--   ratio  := min(1, (stored + income × window) / (demand × window))   (1 if no demand)
-- Two passes (guide 8.4): the ratios for both resources are computed first;
-- each consumer then advances at the smallest ratio among the resources it
-- uses (Economy.effective), so it also uses proportionally less of the other
-- one, and only what was actually spent is charged.
-- Spending is also capped by the window's allowance (Economy.allowance), so
-- stored never goes below zero even when demand rises mid-window.
--
-- Income is recomputed at each step from the producer list (structures that
-- are complete, plus mobile units with `production`, like the Command
-- Vehicle): exact, no drift, O(producers) at 3 Hz.

local Defs = require("@shared/Defs/Defs")
local Hash = require("@shared/Util/Hash")
local Layers = require("@shared/Grid/Layers")
local PlacementRules = require("@shared/Grid/PlacementRules")
local World = require("./World")

local Economy = {}

local TOGGLED_ON = World.State.TOGGLED_ON

Economy.STEP_TICKS = 5
Economy.WINDOW = Economy.STEP_TICKS / 15 -- seconds settled per step
Economy.START_STORED = 1000 -- guide 16.3
Economy.BASE_STORAGE = 1000

export type Resource = {
	stored: number,
	storage: number,
	income: number, -- per second
	demand: number, -- per second, latest from Construction
	ratio: number, -- 0..1 for the current window
	spent: number, -- spent so far this window
	reclaimed: number, -- reclaimed so far this window
	wasted: number, -- total overflow lost to full storage
	priorityDemand: number?, -- per second, of `demand`: missile refills, served first (S-66)
	priorityRatio: number?, -- 0..1: their progress ratio this window (S-66)
	lowDemand: number?, -- per second, of `demand`: low-priority consumers, served last (S-156)
	lowRatio: number?, -- 0..1: their progress ratio this window (S-156)
	gathered: number, -- total credited: income and reclaim per window, before the storage cap (Stats, S-63)
	drawn: number, -- total spent, less any shortfall a window forgave (Stats, S-63)
	bonusIncome: number?, -- per second, from the INCOME cheat (S-102)
	bonusStorage: number?, -- storage the RES cheat added (S-102)
}

export type Account = { supply: Resource, power: Resource }

export type Economy = {
	accounts: { [number]: Account },
	teams: { number }, -- ascending
	allyOf: { [number]: number }, -- team → ally team (overflow is shared within it)
	producers: { number }, -- unit IDs with production / extractor / storage / wind / converter
	producerSlot: { [number]: number },
	seed: number, -- match seed: the wind sequence
	wind: number, -- current wind, 0..1 of a turbine's max (guide 8.5)
}

Economy.WIND_PERIOD = 450 -- ticks between wind changes (30 s)
Economy.CONVERTER_RESERVE = 0.5 -- converters only burn power above this share of storage

local function newResource(): Resource
	return {
		stored = Economy.START_STORED,
		storage = Economy.BASE_STORAGE,
		income = 0,
		demand = 0,
		ratio = 1,
		spent = 0,
		reclaimed = 0,
		wasted = 0,
		gathered = 0,
		drawn = 0,
		priorityDemand = 0,
		priorityRatio = 1,
		lowDemand = 0,
		lowRatio = 1,
	}
end

-- Wind for a tick: a stateless hash of (seed, tick // WIND_PERIOD) mapped to
-- 0..1, so it never touches sim.rng and replays exactly.
function Economy.windAt(seed: number, tick: number): number
	local h = Hash.u32(Hash.u32(Hash.OFFSET_BASIS, seed), tick // Economy.WIND_PERIOD)
	return (h % 10001) / 10000
end

function Economy.new(teams: { number }, allyOf: { [number]: number }?, seed: number?): Economy
	local accounts = {}
	local sorted = table.clone(teams)
	table.sort(sorted)
	local unique = {}
	for _, t in sorted do
		if accounts[t] == nil then
			accounts[t] = { supply = newResource(), power = newResource() }
			table.insert(unique, t)
		end
	end
	local allies: { [number]: number } = {}
	for _, t in unique do
		allies[t] = if allyOf then allyOf[t] or t else t
	end
	return {
		accounts = accounts,
		teams = unique,
		allyOf = allies,
		producers = {},
		producerSlot = {},
		seed = seed or 0,
		wind = Economy.windAt(seed or 0, 0),
	}
end

-- Does this def produce, extract or store anything?
function Economy.isProducerDef(def: Defs.UnitDef): boolean
	return def.production ~= nil or def.extractor ~= nil or def.storage ~= nil or def.wind ~= nil or def.converter ~= nil
end

function Economy.addProducer(eco: Economy, id: number)
	if eco.producerSlot[id] == nil then
		table.insert(eco.producers, id)
		eco.producerSlot[id] = #eco.producers
	end
end

function Economy.removeProducer(eco: Economy, id: number)
	local s = eco.producerSlot[id]
	if s == nil then
		return
	end
	local list = eco.producers
	local last = list[#list]
	list[s] = last
	eco.producerSlot[last] = s
	list[#list] = nil
	eco.producerSlot[id] = nil
end

-- Settles the stored amount for a window; returns the overflow above
-- storage (not yet counted as wasted: allies may take it).
local function settleStored(r: Resource, window: number): number
	local stored = r.stored + r.income * window - r.spent + r.reclaimed
	r.gathered += r.income * window + r.reclaimed
	r.drawn += r.spent
	r.spent = 0
	r.reclaimed = 0
	local overflow = 0
	if stored > r.storage then
		overflow = stored - r.storage
		stored = r.storage
	elseif stored < 0 then
		r.drawn += stored -- never paid
		stored = 0 -- income dropped mid-window (a producer died): forgive the remainder
	end
	r.stored = stored
	return overflow
end

-- Missile refills come first in a stall (S-66, the user): up to
-- REFILL_PRIORITY of the window's income goes to them before construction
-- gets its share; whatever they want beyond that shares the rest like any
-- consumer. At 0 every consumer shares alike, as before.
-- Low-priority consumers (the LOW_PRIORITY state bit, S-156) come last:
-- they share what the high ones (every other consumer) leave over.
Economy.REFILL_PRIORITY = 0.25

local function settleRatio(r: Resource, window: number)
	local available = r.stored + r.income * window
	local wanted = r.demand * window
	local pWanted = (r.priorityDemand or 0) * window
	local lowWanted = (r.lowDemand or 0) * window
	local granted = math.max(0, math.min(pWanted, available, Economy.REFILL_PRIORITY * r.income * window))
	local restWanted = wanted - granted
	if lowWanted > 0 then
		restWanted -= lowWanted
	end
	r.ratio = if restWanted > 1e-12 then math.clamp((available - granted) / restWanted, 0, 1) else 1
	r.priorityRatio = if pWanted > 0 then math.min(1, (granted + (pWanted - granted) * r.ratio) / pWanted) else 1
	if lowWanted > 0 then
		local left = available - granted - math.max(restWanted, 0) * r.ratio
		r.lowRatio = math.clamp(left / lowWanted, 0, 1)
	else
		r.lowRatio = 1
	end
end

-- Settles one resource for a window, overflow wasted. Pure; exposed for tests.
function Economy.settle(r: Resource, window: number)
	r.wasted += settleStored(r, window)
	settleRatio(r, window)
end

-- Gives `team`'s overflow to its allies with room (guide 8.4 "overflow
-- sharing", 16.1): split evenly among the allies that still have room,
-- repeated until it is placed or nobody has room; the rest is wasted.
local RESOURCES: { "supply" | "power" } = { "supply", "power" }
local overflowScratch: { [number]: number } = {}
local function shareOverflow(eco: Economy, kind: "supply" | "power", team: number, amount: number)
	local ally = eco.allyOf[team]
	local left = amount
	while left > 1e-9 do
		local open = 0
		for _, t in eco.teams do
			local r = eco.accounts[t][kind]
			if t ~= team and eco.allyOf[t] == ally and r.stored < r.storage then
				open += 1
			end
		end
		if open == 0 then
			break
		end
		local share = left / open
		for _, t in eco.teams do
			local r = eco.accounts[t][kind]
			if t ~= team and eco.allyOf[t] == ally and r.stored < r.storage then
				local give = math.min(share, r.storage - r.stored)
				r.stored += give
				left -= give
			end
		end
	end
	eco.accounts[team][kind].wasted += math.max(left, 0)
end

-- Effective progress ratio for a consumer of cost (supply, power): the
-- smallest ratio among the resources it actually uses (guide 8.4). `low`:
-- a low-priority consumer (S-156), at the ratios left after the high ones.
function Economy.effective(acc: Account, costSupply: number, costPower: number, low: boolean?): number
	local e = 1
	if costSupply > 0 then
		e = math.min(e, if low then acc.supply.lowRatio or acc.supply.ratio else acc.supply.ratio)
	end
	if costPower > 0 then
		e = math.min(e, if low then acc.power.lowRatio or acc.power.ratio else acc.power.ratio)
	end
	return e
end

-- The same for missile refills, which come first in a stall (S-66).
function Economy.priorityEffective(acc: Account, costSupply: number, costPower: number): number
	local e = 1
	if costSupply > 0 then
		e = math.min(e, acc.supply.priorityRatio or acc.supply.ratio)
	end
	if costPower > 0 then
		e = math.min(e, acc.power.priorityRatio or acc.power.ratio)
	end
	return e
end

-- Is this unit a low-priority consumer (PRIORITY 0, S-156)?
function Economy.isLow(w: World.World, id: number): boolean
	return bit32.band(w.state[id], World.State.LOW_PRIORITY) ~= 0
end

-- What may still be spent from this resource in the current window.
function Economy.allowance(r: Resource): number
	return math.max(0, r.stored + r.income * Economy.WINDOW - r.spent)
end

-- Recomputes income and storage from the producers, then settles every
-- team. `world` positions locate extractors on the deposit layer.
function Economy.step(eco: Economy, w: World.World, defs: Defs.DefSet, layers: Layers.Layers?, tick: number?)
	eco.wind = Economy.windAt(eco.seed, tick or 0)
	for _, team in eco.teams do
		local acc = eco.accounts[team]
		acc.supply.income, acc.power.income = acc.supply.bonusIncome or 0, acc.power.bonusIncome or 0
		acc.supply.storage = Economy.BASE_STORAGE + (acc.supply.bonusStorage or 0)
		acc.power.storage = Economy.BASE_STORAGE + (acc.power.bonusStorage or 0)
	end
	for _, id in eco.producers do
		local acc = eco.accounts[w.team[id]]
		if acc == nil then
			continue
		end
		local def = defs.unitByIndex[w.defIndex[id]]
		local p = def.production
		if p then
			acc.supply.income += p.supply or 0
			acc.power.income += p.power or 0
		end
		local ex = def.extractor
		if ex and layers then
			-- every deposit cell under the footprint (S-104)
			acc.supply.income += ex.rate * PlacementRules.supplyUnder(layers, def.footprint, w.posX[id], w.posZ[id])
		end
		local s = def.storage
		if s then
			acc.supply.storage += s.supply or 0
			acc.power.storage += s.power or 0
		end
		if def.wind then
			acc.power.income += def.wind.max * eco.wind
		end
	end
	-- converters (switched on): burn power above the reserve, add supply
	-- (guide 8.4 order: production, converters, consumers, overflow)
	for _, id in eco.producers do
		local conv = defs.unitByIndex[w.defIndex[id]].converter
		if conv == nil or bit32.band(w.state[id], TOGGLED_ON) == 0 then
			continue
		end
		local acc = eco.accounts[w.team[id]]
		if acc == nil then
			continue
		end
		local p = acc.power
		local spare = p.stored + p.income * Economy.WINDOW - p.spent - p.storage * Economy.CONVERTER_RESERVE
		local burn = math.clamp(spare, 0, conv.power * Economy.WINDOW)
		if burn > 0 then
			p.spent += burn
			acc.supply.reclaimed += burn * conv.supply / conv.power
		end
	end
	-- production and spending, then overflow sharing, then ratios (guide 8.4)
	for _, kind in RESOURCES do
		for _, team in eco.teams do
			overflowScratch[team] = settleStored(eco.accounts[team][kind], Economy.WINDOW)
		end
		for _, team in eco.teams do
			local over = overflowScratch[team]
			if over > 0 then
				shareOverflow(eco, kind, team, over)
			end
		end
		for _, team in eco.teams do
			settleRatio(eco.accounts[team][kind], Economy.WINDOW)
		end
	end
end

function Economy.hash(eco: Economy, h: number): number
	for _, team in eco.teams do
		local acc = eco.accounts[team]
		for _, r in { acc.supply, acc.power } do
			h = Hash.number(h, r.stored)
			h = Hash.number(h, r.storage)
			h = Hash.number(h, r.income)
			h = Hash.number(h, r.demand)
			h = Hash.number(h, r.ratio)
			h = Hash.number(h, r.spent)
			h = Hash.number(h, r.reclaimed)
			if (r.lowDemand or 0) > 0 then
				h = Hash.number(Hash.number(h, r.lowDemand :: number), r.lowRatio or 1) -- (S-156)
			end
			if r.bonusIncome or r.bonusStorage then
				h = Hash.number(Hash.number(h, r.bonusIncome or 0), r.bonusStorage or 0) -- (S-102)
			end
		end
	end
	h = Hash.number(h, eco.wind)
	local sorted = table.clone(eco.producers)
	table.sort(sorted)
	h = Hash.u32(h, #sorted)
	for _, id in sorted do
		h = Hash.u32(h, id)
	end
	return h
end

return Economy
