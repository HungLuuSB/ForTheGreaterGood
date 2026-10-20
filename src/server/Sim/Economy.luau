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
local World = require("./World")

local Economy = {}

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
}

export type Account = { supply: Resource, power: Resource }

export type Economy = {
	accounts: { [number]: Account },
	teams: { number }, -- ascending
	producers: { number }, -- unit IDs with production / extractor / storage
	producerSlot: { [number]: number },
}

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
	}
end

function Economy.new(teams: { number }): Economy
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
	return { accounts = accounts, teams = unique, producers = {}, producerSlot = {} }
end

-- Does this def produce, extract or store anything?
function Economy.isProducerDef(def: Defs.UnitDef): boolean
	return def.production ~= nil or def.extractor ~= nil or def.storage ~= nil
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

-- Settles one resource for a window. Pure; exposed for tests.
function Economy.settle(r: Resource, window: number)
	local stored = r.stored + r.income * window - r.spent + r.reclaimed
	r.spent = 0
	r.reclaimed = 0
	if stored > r.storage then
		r.wasted += stored - r.storage
		stored = r.storage
	elseif stored < 0 then
		stored = 0 -- income dropped mid-window (a producer died): forgive the remainder
	end
	r.stored = stored
	local wanted = r.demand * window
	r.ratio = if wanted > 0 then math.min(1, (stored + r.income * window) / wanted) else 1
end

-- Effective progress ratio for a consumer of cost (supply, power): the
-- smallest ratio among the resources it actually uses (guide 8.4).
function Economy.effective(acc: Account, costSupply: number, costPower: number): number
	local e = 1
	if costSupply > 0 then
		e = math.min(e, acc.supply.ratio)
	end
	if costPower > 0 then
		e = math.min(e, acc.power.ratio)
	end
	return e
end

-- What may still be spent from this resource in the current window.
function Economy.allowance(r: Resource): number
	return math.max(0, r.stored + r.income * Economy.WINDOW - r.spent)
end

-- Recomputes income and storage from the producers, then settles every
-- team. `world` positions locate extractors on the deposit layer.
function Economy.step(eco: Economy, w: World.World, defs: Defs.DefSet, layers: Layers.Layers?)
	for _, team in eco.teams do
		local acc = eco.accounts[team]
		acc.supply.income, acc.power.income = 0, 0
		acc.supply.storage, acc.power.storage = Economy.BASE_STORAGE, Economy.BASE_STORAGE
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
			local g = layers.grid
			local cx, cz = g:cellAt(w.posX[id], w.posZ[id])
			if g:inBounds(cx, cz) then
				acc.supply.income += ex.rate * Layers.getSupply(layers, g:index(cx, cz))
			end
		end
		local s = def.storage
		if s then
			acc.supply.storage += s.supply or 0
			acc.power.storage += s.power or 0
		end
	end
	for _, team in eco.teams do
		local acc = eco.accounts[team]
		Economy.settle(acc.supply, Economy.WINDOW)
		Economy.settle(acc.power, Economy.WINDOW)
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
		end
	end
	local sorted = table.clone(eco.producers)
	table.sort(sorted)
	h = Hash.u32(h, #sorted)
	for _, id in sorted do
		h = Hash.u32(h, id)
	end
	return h
end

return Economy
