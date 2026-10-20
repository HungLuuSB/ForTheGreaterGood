--!strict
-- Balance report (report only; it never changes stats).
--   lune run balance [seeds] [filter]   (filter: only Order units whose id contains it)
--
-- Every Order combat unit against every Chaos combat unit that one of them
-- can damage, with equal value on both sides (value = supply + power / 10,
-- about BUDGET per side), from two starts:
--   close  the two groups 120 studs apart: inside most weapons' range
--   long   600 studs apart: both attack-move at each other, so range and
--          speed matter
-- A battle ends when a side is gone or after MAX_TICKS. Score: the value
-- trade, enemy value destroyed / own value lost, where damage counts pro
-- rata (a unit at half health has lost half its value). > 1 favours Order.
-- Writes the matrix and per-unit summaries to docs/BALANCE.md.
-- Workers, commanders, unarmed support units and structures are left out.
-- Aircraft fight without rearm pads (they run dry).

local fs = require("@lune/fs")
local process = require("@lune/process")

local Packer = require("../src/shared/Net/Packer")
local Schema = require("../src/shared/Net/Schema")
local Defs = require("../src/shared/Defs/Defs")
local Categories = require("../src/shared/Defs/Categories")
local Sim = require("../src/server/Sim/Sim")
local Spawn = require("../src/server/Sim/Spawn")

local SEEDS = tonumber(process.args[1]) or 1
local FILTER = process.args[2]
local BUDGET = 3000
local MAX_TICKS = 1800 -- 2 minutes
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType

local defs = Defs.load()

local function value(d: Defs.UnitDef): number
	return d.cost.supply + d.cost.power / 10
end

local BIT = Categories.Bit
local function isCombat(d: Defs.UnitDef): boolean
	return d.domain ~= "structure"
		and #d.weapons > 0
		and bit32.band(d.categoryMask, BIT.WORKER + BIT.COMMANDER) == 0
end

-- Can a weapon of `a` damage `b` at all (category and armor)?
local function canDamage(a: Defs.UnitDef, b: Defs.UnitDef): boolean
	for _, slot in a.weapons do
		local wd = defs.weaponByIndex[slot.weaponIndex]
		if bit32.band(wd.targetMask, b.categoryMask) ~= 0 and (wd.damage[b.armorClass] or 0) > 0 then
			return true
		end
	end
	return false
end

local order, chaos = {}, {}
for id, d in defs.units do
	if isCombat(d) and (FILTER == nil or d.faction ~= "order" or string.find(id, FILTER, 1, true)) then
		table.insert(if d.faction == "order" then order else chaos, id)
	end
end
table.sort(order)
table.sort(chaos)

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

-- Where each side stands (x of its group centre) for a pair on `mapId`.
local SHORE = -512 -- sea:256: land west of x = -512
local function layout(a: Defs.UnitDef, b: Defs.UnitDef, gap: number): (string, number, number)
	local naval = a.domain == "naval" or b.domain == "naval"
	if not naval then
		return "flat:128", -gap / 2, gap / 2
	end
	if a.domain == "naval" and b.domain == "naval" then
		return "sea:256", -gap / 2, gap / 2
	end
	-- a ship against a land / air unit: the land side on the beach, the ship offshore
	if a.domain == "naval" then
		return "sea:256", SHORE + 60 + gap, SHORE - 40
	end
	return "sea:256", SHORE - 40, SHORE + 60 + gap
end

local function spawnGroup(sim: Sim.Sim, d: Defs.UnitDef, owner: number, cx: number, facing: number): ({ number }, number)
	local count = math.clamp(math.floor(BUDGET / value(d) + 0.5), 1, 20)
	local spacing = 8 * d.footprint + 6
	local ids = {}
	for i = 0, count - 1 do
		local row, col = i // 5, i % 5
		local x = cx + (if facing > 0 then -1 else 1) * row * spacing
		table.insert(ids, Spawn.unit(sim, d.id, owner, x, (col - 2) * spacing, facing))
	end
	return ids, count * value(d)
end

type Outcome = { trade: number, lostA: number, lostB: number, winner: string, ticks: number }

local function battle(aId: string, bId: string, kind: string, seed: number): Outcome
	local a, b = defs.units[aId], defs.units[bId]
	local gap = if kind == "close" then 120 else 600
	local mapId, xa, xb = layout(a, b, gap)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = mapId })
	local w = sim.world
	local idsA = spawnGroup(sim, a, 1, xa, math.pi / 2)
	local idsB = spawnGroup(sim, b, 2, xb, -math.pi / 2)
	local function lost(ids: { number }, d: Defs.UnitDef): number
		local v = 0
		for _, id in ids do
			local hp = if w.slot[id] then w.health[id] else 0
			v += value(d) * (1 - math.clamp(hp / d.health, 0, 1))
		end
		return v
	end
	local function alive(ids: { number }): { number }
		local out = {}
		for _, id in ids do
			if w.slot[id] then
				table.insert(out, id)
			end
		end
		return out
	end
	local g = (sim.map :: any).grid
	while sim.tick < MAX_TICKS do
		local la, lb = alive(idsA), alive(idsB)
		if #la == 0 or #lb == 0 then
			break
		end
		if sim.tick % 30 == 0 then
			for side = 1, 2 do
				local mine, theirs = if side == 1 then la else lb, if side == 1 then lb else la
				local cx, cz = 0, 0
				for _, id in theirs do
					cx += w.posX[id] / #theirs
					cz += w.posZ[id] / #theirs
				end
				local cell, ox, oz = g:encode(cx, cz)
				submit(sim, side, { cmdType = CT.FIGHT, flags = 0, unitIds = mine, cell = cell, offX = ox, offZ = oz })
			end
		end
		Sim.step(sim)
	end
	local lostA, lostB = lost(idsA, a), lost(idsB, b)
	local la, lb = #alive(idsA), #alive(idsB)
	local winner = if la > 0 and lb == 0 then "O" elseif lb > 0 and la == 0 then "C" else "-"
	return { trade = if lostA > 0 then lostB / lostA else math.huge, lostA = lostA, lostB = lostB, winner = winner, ticks = sim.tick }
end

local function fmt(x: number): string
	if x == math.huge then
		return "∞"
	elseif x >= 10 then
		return string.format("%.0f", x)
	end
	return string.format("%.2f", x)
end

local t0 = os.clock()
local results: { [string]: { [string]: { [string]: Outcome } } } = {}
local battles = 0
for _, aId in order do
	results[aId] = {}
	for _, bId in chaos do
		local a, b = defs.units[aId], defs.units[bId]
		if not (canDamage(a, b) or canDamage(b, a)) then
			continue
		end
		results[aId][bId] = {}
		for _, kind in { "close", "long" } do
			local sumA, sumB, wins, ticks = 0, 0, "", 0
			for seed = 1, SEEDS do
				local o = battle(aId, bId, kind, seed)
				sumA += o.lostA
				sumB += o.lostB
				wins ..= o.winner
				ticks += o.ticks
				battles += 1
			end
			results[aId][bId][kind] = {
				trade = if sumA > 0 then sumB / sumA else math.huge,
				lostA = sumA / SEEDS,
				lostB = sumB / SEEDS,
				winner = wins,
				ticks = ticks // SEEDS,
			}
		end
	end
	print(string.format("%-18s done (%.0f s)", aId, os.clock() - t0))
end

-- report
local lines = {}
local function out(s: string)
	table.insert(lines, s)
end
local function shortName(id: string): string
	return defs.units[id].name
end
out("# Balance report")
out("")
out("Generated by `lune run balance` (report only; stats are not changed). Placeholder stats from DECISIONS D88.")
out("")
out(string.format("- Equal value per side: about %d (value = supply + power / 10), at most 20 units.", BUDGET))
out(string.format("- Two starts: **close** (120 studs apart) and **long** (600 studs apart, both attack-move). %d seed(s) each; at most %d ticks (%d s).", SEEDS, MAX_TICKS, MAX_TICKS // 15))
out("- Cell: Order's value trade, close / long = Chaos value destroyed ÷ Order value lost (damage counted pro rata). Above 1 favours Order, ∞ means Order lost nothing. Letters: winner per seed (O, C, or - when time ran out with both sides alive).")
out("- Blank: neither unit can damage the other.")
out("- Aircraft have no rearm pads in these fights and run dry.")
out(string.format("- %d battles, %.0f s on the dev PC.", battles, os.clock() - t0))
out("")
local header = "| Order \\ Chaos |"
local sep = "|---|"
for _, bId in chaos do
	header ..= ` {shortName(bId)} |`
	sep ..= "---|"
end
out(header)
out(sep)
for _, aId in order do
	local row = `| **{shortName(aId)}** |`
	for _, bId in chaos do
		local r = results[aId][bId]
		if r then
			row ..= ` {fmt(r.close.trade)} {r.close.winner} / {fmt(r.long.trade)} {r.long.winner} |`
		else
			row ..= " |"
		end
	end
	out(row)
end
out("")
out("## Per-unit summary")
out("")
out("Geometric mean of the value trade over every matchup the unit takes part in (both starts), and wins / matchups (all seeds). For Chaos units the trade is inverted, so above 1 is good for the unit in both columns.")
out("")
out("| Unit | Faction | Value | Mean trade | Wins / fights |")
out("|---|---|---|---|---|")
local function summary(id: string, isOrder: boolean)
	local logSum, n, wins, fights = 0, 0, 0, 0
	local others = if isOrder then chaos else order
	for _, other in others do
		local r = if isOrder then results[id][other] else results[other][id]
		if r then
			for _, kind in { "close", "long" } do
				local o = r[kind]
				local trade = if isOrder then o.trade else (if o.lostB > 0 then o.lostA / o.lostB else math.huge)
				trade = math.clamp(trade, 0.01, 100)
				logSum += math.log(trade)
				n += 1
				for i = 1, #o.winner do
					fights += 1
					if string.sub(o.winner, i, i) == (if isOrder then "O" else "C") then
						wins += 1
					end
				end
			end
		end
	end
	local d = defs.units[id]
	out(string.format("| %s (`%s`) | %s | %.0f | %s | %d / %d |", d.name, id, d.faction, value(d), if n > 0 then fmt(math.exp(logSum / n)) else "-", wins, fights))
end
for _, id in order do
	summary(id, true)
end
for _, id in chaos do
	summary(id, false)
end
out("")
if FILTER == nil then
	fs.writeFile("docs/BALANCE.md", table.concat(lines, "\n") .. "\n")
	print("wrote docs/BALANCE.md")
else
	print(table.concat(lines, "\n"))
end
