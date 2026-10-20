--!strict
-- Balance report (report only; it never changes stats).
--   lune run balance [seeds] [filter]   (filter: only Order units whose id contains it)
--
-- 1. Matrix: every Order combat unit against every Chaos combat unit that
--    one of them can damage, with equal value on both sides (value = supply
--    + power / 10, about BUDGET per side), from two starts:
--      close  the two groups 120 studs apart: inside most weapons' range
--      long   600 studs apart: both attack-move at each other
--    A battle ends when a side is gone or after MAX_TICKS. Score: the value
--    trade, enemy value destroyed / own value lost, where damage counts pro
--    rata. > 1 favours Order.
-- 2. Sieges: each combat unit's equal-value group against an enemy base of
--    passive structures (Scenes.siege): the "Structure" column.
-- 3. Coastal batteries (guide 13.5) against every enemy ship.
-- 4. Counter check: the results against the counter matrix in guide 12.4
--    (parsed from the guide), listing every attacker / target pair that
--    falls short of its dots, and why (DECISIONS D94):
--      mechanic  can't target, can't see, can't reach, out of range, ran
--                dry, or a bomber never lined up a run
--      numbers   it fought (fired, hit) but lost the trade
-- Workers, commanders, unarmed support units and structures (except
-- coastal batteries in section 3) are left out. Aircraft have no rearm pads.
-- Every fight is the same as `lune run export matchup:<a>:<b>[:close|long]`
-- or `siege:<unit>`, so it can be watched in tools/viewer/index.html.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Defs = require("../src/shared/Defs/Defs")
local Sensors = require("../src/server/Sim/Sensors")
local Sim = require("../src/server/Sim/Sim")
local Scenes = require("../src/server/Tests/Support/Scenes")

local SEEDS = tonumber(process.args[1]) or 1
local FILTER = process.args[2]
local BUDGET = Scenes.BUDGET
local MAX_TICKS = Scenes.MATCHUP_TICKS -- 2 minutes
local L = Sensors.Level

local defs = Defs.load()
local value = Scenes.value
local isCombat = Scenes.isCombat

-- Weapons of `a` that can damage `b` (category and armor).
local function damaging(a: Defs.UnitDef, b: Defs.UnitDef): { Defs.WeaponDef }
	local out = {}
	for _, slot in a.weapons do
		local wd = defs.weaponByIndex[slot.weaponIndex]
		if bit32.band(wd.targetMask, b.categoryMask) ~= 0 and (wd.damage[b.armorClass] or 0) > 0 then
			table.insert(out, wd)
		end
	end
	return out
end
local function canDamage(a: Defs.UnitDef, b: Defs.UnitDef): boolean
	return #damaging(a, b) > 0
end

local order, chaos = {}, {}
for id, d in defs.units do
	if isCombat(d) and (FILTER == nil or d.faction ~= "order" or string.find(id, FILTER, 1, true)) then
		table.insert(if d.faction == "order" then order else chaos, id)
	end
end
table.sort(order)
table.sort(chaos)

-- What one side did in a fight (summed over seeds).
type Diag = {
	lost: number, -- own value lost
	dealt: number, -- enemy value destroyed
	shots: number, -- shots fired (SPAWN_PROJ / FIRE)
	hits: number, -- shots that hit an enemy unit (impacts and hitscan hits)
	knew: boolean, -- ever knew a target its weapons accept
	minDist: number, -- closest the two groups got (studs)
	dry: boolean, -- an aircraft ran out of ammo
}
type Outcome = { trade: number, lostA: number, lostB: number, winner: string, ticks: number, diag: { Diag } }

local function newDiag(): Diag
	return { lost = 0, dealt = 0, shots = 0, hits = 0, knew = false, minDist = math.huge, dry = false }
end

-- Runs a scene to the end, recording both sides.
local function run(scene: Scenes.Scene): ({ Diag }, number, string)
	local sim = scene.sim
	local w = sim.world
	local sides = scene.sides :: { { number } }
	local member: { [number]: number } = {}
	local defOf: { [number]: Defs.UnitDef } = {} -- kept after death
	for s = 1, 2 do
		for _, id in sides[s] do
			member[id] = s
			defOf[id] = defs.unitByIndex[w.defIndex[id]]
		end
	end
	local diag = { newDiag(), newDiag() }
	local projSide: { [number]: number } = {}
	local function accepts(id: number, target: number): boolean
		local level = Sensors.level(sim, w.ally[id], target)
		for _, wd in damaging(defOf[id], defOf[target]) do
			if level == L.VISIBLE
				or ((level == L.RADAR or level == L.GHOST) and wd.canTargetRadar)
				or (level == L.SONAR and wd.type == "TORPEDO") then
				return true
			end
		end
		return false
	end
	while sim.tick < MAX_TICKS and not scene.done(sim) do
		scene.drive(sim)
		Sim.step(sim)
		for _, e in sim.combat.events do
			if (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") and member[e.unit] then
				local side = member[e.unit]
				diag[side].shots += 1
				if e.kind == "SPAWN_PROJ" then
					projSide[e.other] = side
				elseif e.hit then
					diag[side].hits += 1
				end
			elseif e.kind == "IMPACT" then
				local side = projSide[e.other]
				if side and member[e.unit] == 3 - side then
					diag[side].hits += 1
				end
				projSide[e.other] = nil
			end
		end
		if sim.tick % 5 == 0 then
			for s = 1, 2 do
				local d = diag[s]
				for _, id in sides[s] do
					if w.slot[id] then
						if sim.air.ammo[id] == 0 then
							d.dry = true
						end
						for _, t in sides[3 - s] do
							if w.slot[t] then
								local dist = math.sqrt((w.posX[id] - w.posX[t]) ^ 2 + (w.posZ[id] - w.posZ[t]) ^ 2)
								d.minDist = math.min(d.minDist, dist)
								if not d.knew and accepts(id, t) then
									d.knew = true
								end
							end
						end
					end
				end
			end
		end
	end
	local function lost(ids: { number }): number
		local v = 0
		for _, id in ids do
			local d = defOf[id]
			local hp = if w.slot[id] then w.health[id] else 0
			v += value(d) * (1 - math.clamp(hp / d.health, 0, 1))
		end
		return v
	end
	diag[1].lost, diag[2].lost = lost(sides[1]), lost(sides[2])
	diag[1].dealt, diag[2].dealt = diag[2].lost, diag[1].lost
	local function alive(ids: { number }): number
		local n = 0
		for _, id in ids do
			if w.slot[id] then
				n += 1
			end
		end
		return n
	end
	local la, lb = alive(sides[1]), alive(sides[2])
	local winner = if la > 0 and lb == 0 then "O" elseif lb > 0 and la == 0 then "C" else "-"
	return diag, sim.tick, winner
end

local function merge(into: Diag, d: Diag)
	into.lost += d.lost
	into.dealt += d.dealt
	into.shots += d.shots
	into.hits += d.hits
	into.knew = into.knew or d.knew
	into.minDist = math.min(into.minDist, d.minDist)
	into.dry = into.dry or d.dry
end

local function fight(make: (number) -> Scenes.Scene): Outcome
	local total = { newDiag(), newDiag() }
	local wins, ticks = "", 0
	for seed = 1, SEEDS do
		local diag, t, winner = run(make(seed))
		merge(total[1], diag[1])
		merge(total[2], diag[2])
		wins ..= winner
		ticks += t
	end
	return {
		trade = if total[1].lost > 0 then total[1].dealt / total[1].lost else math.huge,
		lostA = total[1].lost / SEEDS,
		lostB = total[2].lost / SEEDS,
		winner = wins,
		ticks = ticks // SEEDS,
		diag = total,
	}
end

local function fmt(x: number): string
	if x == math.huge then
		return "∞"
	elseif x >= 10 then
		return string.format("%.0f", x)
	end
	return string.format("%.2f", x)
end

-- 1. matrix
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
			results[aId][bId][kind] = fight(function(seed)
				return Scenes.matchup(aId, bId, kind, seed)
			end)
			battles += SEEDS
		end
	end
	print(string.format("%-18s done (%.0f s)", aId, os.clock() - t0))
end

-- 2. sieges
local sieges: { [string]: Outcome } = {}
local siegeUnits = table.clone(order)
for _, id in chaos do
	table.insert(siegeUnits, id)
end
for _, id in siegeUnits do
	sieges[id] = fight(function(seed)
		return Scenes.siege(id, seed)
	end)
	battles += SEEDS
end
print(string.format("sieges done (%.0f s)", os.clock() - t0))

local function baseValue(attackerFaction: string): number
	local p = if attackerFaction == "order" then "chs_" else "ord_"
	return value(defs.units[p .. "vehplant"]) + 3 * value(defs.units[p .. "generator"]) + value(defs.units[p .. (if p == "ord_" then "watchtower" else "eye")])
end

-- 3. coastal batteries against ships (both directions)
local batteries: { [string]: { [string]: Outcome } } = {}
for _, pair in { { "ord_rampart", chaos }, { "chs_breaker", order } } do
	local battery, enemies = pair[1] :: string, pair[2] :: { string }
	batteries[battery] = {}
	for _, ship in enemies do
		if defs.units[ship].moveClass == "SHIP" then
			batteries[battery][ship] = fight(function(seed)
				if battery == "ord_rampart" then
					return Scenes.matchup(battery, ship, "long", seed)
				end
				return Scenes.matchup(ship, battery, "long", seed)
			end)
			battles += SEEDS
		end
	end
end
print(string.format("coastal batteries done (%.0f s)", os.clock() - t0))

-- 4. counter check against guide 12.4 ----------------------------------------------
-- Roles (matrix rows) by unit name, both factions.
local ROLE_UNITS: { [string]: { string } } = {
	["Tanks"] = { "lancer", "ravager", "paladin", "juggernaut", "tideguard", "mire" },
	["Artillery"] = { "verdict", "hellmouth", "judgement", "hydra" },
	["IR SAM"] = { "halo", "hornet" },
	["Radar SAM"] = { "seraph", "gorgon" },
	["Fighters"] = { "falcon", "harpy", "archon", "manticore" },
	["Bombers"] = { "absolution", "plague", "phantom", "behemoth" },
	["Attack helis"] = { "guardian", "wasp" },
	["Destroyers"] = { "crusader", "corsair" },
	["Submarines"] = { "silence", "lamprey" },
	["Coastal battery (13.5)"] = { "rampart", "breaker" },
}
local function idOf(name: string): string
	return (if defs.units["ord_" .. name] then "ord_" else "chs_") .. name
end
-- Target class (matrix column) of a defender.
local function classOf(d: Defs.UnitDef): string?
	if d.domain == "structure" then
		return "Structure"
	elseif d.moveClass == "JET" then
		return "Air (jet)"
	elseif d.moveClass == "HELI" then
		return "Air (heli)"
	elseif d.moveClass == "SUB" then
		return "Sub"
	elseif d.domain == "naval" then
		return "Ship"
	elseif d.domain == "ground" then
		return "Ground"
	end
	return nil
end

-- the matrix, read from the guide
local guide = fs.readFile("docs/For_The_Greater_Good_Design_Guide.md")
local section = string.match(guide, "### 12%.4 Counter matrix.-\n(|.-)\n\n")
assert(section, "balance: guide 12.4 table not found")
local columns: { string } = {}
local matrix: { [string]: { [string]: number } } = {} -- role → column → dots (0 = cannot target)
for line in string.gmatch(section :: string, "[^\n]+") do
	local cells = {}
	for cell in string.gmatch(line, "|([^|]*)") do
		table.insert(cells, (string.gsub(cell, "^%s*(.-)%s*$", "%1")))
	end
	if #cells > 0 and cells[#cells] == "" then
		table.remove(cells)
	end
	if string.find(cells[1] or "", "attacker") then
		for k = 2, #cells do
			columns[k - 1] = cells[k]
		end
	elseif cells[1] and not string.find(cells[1], "^%-") and #cells == #columns + 1 then
		local row = {}
		for k = 2, #cells do
			local _, dots = string.gsub(cells[k], "●", "")
			row[columns[k - 1]] = dots
		end
		matrix[cells[1]] = row
	end
end
assert(matrix["Tanks"] and matrix["Submarines"], "balance: guide 12.4 rows not parsed")
matrix["Coastal battery (13.5)"] = { Ship = 3 } -- guide 13.5: "Heavy gun against ships"
local DOTS = { [0] = "—", "●", "●●", "●●●" }

-- The attacker's side of each fight against a defender.
type Check = { trade: number, diag: Diag, start: string }
local function duel(attacker: string, defender: string): { Check }
	local out = {}
	local att = defs.units[attacker]
	local mine = if att.faction == "order" then 1 else 2
	local function add(o: Outcome, start: string)
		local d = o.diag[mine]
		table.insert(out, { trade = if d.lost > 0 then d.dealt / d.lost else math.huge, diag = d, start = start })
	end
	if att.domain == "structure" then
		local o = batteries[attacker] and batteries[attacker][defender]
		if o then
			add(o, "long")
		end
		return out
	end
	local oId = if att.faction == "order" then attacker else defender
	local cId = if att.faction == "order" then defender else attacker
	local r = results[oId] and results[oId][cId]
	if r then
		add(r.close, "close")
		add(r.long, "long")
	end
	return out
end

local function reachOf(a: Defs.UnitDef, b: Defs.UnitDef): number
	local best = 0
	for _, wd in damaging(a, b) do
		best = math.max(best, wd.range)
	end
	return best
end

local function isBomber(d: Defs.UnitDef): boolean
	for _, slot in d.weapons do
		if defs.weaponByIndex[slot.weaponIndex].type == "BOMB" then
			return true
		end
	end
	return false
end

-- Why an attacker fell short: (kind, reason).
local function diagnose(att: Defs.UnitDef, def: Defs.UnitDef?, d: Diag): (string, string)
	if def and not canDamage(att, def) then
		return "mechanic", "can't target (no weapon that damages it)"
	end
	if not d.knew then
		return "mechanic", "can't see (never detected a target its weapons accept)"
	end
	if d.shots == 0 then
		if isBomber(att) then
			return "mechanic", "never lined up a bomb run (sight 190–200 < release distance ≈ 400)"
		end
		local reach = if def then reachOf(att, def) else 0
		if d.minDist > reach + 20 then
			local landBound = att.domain == "ground" and att.moveClass ~= "AMPHIB"
			local seaBound = att.domain == "naval" or att.domain == "structure"
			if def and ((landBound and def.domain == "naval") or (seaBound and def.domain ~= "naval" and def.domain ~= "air")) then
				return "mechanic", string.format("can't reach (closest %.0f studs, range %d; can't cross the shore)", d.minDist, reach)
			end
			return "mechanic", string.format("out of range (closest %.0f studs, range %d)", d.minDist, reach)
		end
		return "mechanic", "never fired (in range and seen)"
	end
	if d.hits == 0 then
		return "mechanic", "fired but never hit (aim, tracking or the target's countermeasures)"
	end
	if d.dry then
		return "mechanic", "ran out of ammo (no rearm pads)"
	end
	if isBomber(att) then
		return "mechanic", "too few bomb runs lined up (sight 190–200 < release distance ≈ 400)"
	end
	return "numbers", "fought and lost the trade"
end

type Finding = { row: string, col: string, dots: number, attacker: string, target: string, start: string, result: string, kind: string, why: string }
local findings: { Finding } = {}
local checked, held = 0, 0

local rows = {}
for row in matrix do
	table.insert(rows, row)
end
table.sort(rows)
for _, row in rows do
	local cols = {}
	for col in matrix[row] do
		table.insert(cols, col)
	end
	table.sort(cols)
	for _, name in ROLE_UNITS[row] or {} do
		local attacker = idOf(name)
		local att = defs.units[attacker]
		if att == nil or (FILTER and att.faction == "order" and not string.find(attacker, FILTER, 1, true)) then
			continue
		end
		for _, col in cols do
			local dots = matrix[row][col]
			if col == "Structure" then
				local o = sieges[attacker]
				if o then
					checked += 1
					local before = #findings
					local d = o.diag[if att.faction == "order" then 1 else 2]
					local frac = (d.dealt / SEEDS) / baseValue(att.faction)
					local need = ({ [0] = 0, 0.02, 0.3, 0.6 })[dots]
					if (dots == 0 and frac > 0) or (dots > 0 and frac < need) then
						local kind, why = "mechanic", "damages structures though the matrix says it can't"
						if dots > 0 then
							kind, why = diagnose(att, nil, d)
							if kind == "numbers" then
								why = "fought but destroyed too little"
							end
						end
						table.insert(findings, { row = row, col = col, dots = dots, attacker = attacker, target = "enemy base", start = "siege", result = string.format("%.0f%% destroyed, %d shots", frac * 100, d.shots // SEEDS), kind = kind, why = why })
					end
					if #findings == before then
						held += 1
					end
				end
			else
				for _, defender in (if att.faction == "order" then chaos else order) do
					local def = defs.units[defender]
					if classOf(def) ~= col then
						continue
					end
					checked += 1
					local before = #findings
					if dots == 0 then
						if canDamage(att, def) then
							table.insert(findings, { row = row, col = col, dots = dots, attacker = attacker, target = defender, start = "-", result = "can damage it", kind = "mechanic", why = "targets a class the matrix says it can't" })
						else
							held += 1
						end
						continue
					end
					local checks = duel(attacker, defender)
					if #checks == 0 then
						local kind, why = diagnose(att, def, newDiag())
						table.insert(findings, { row = row, col = col, dots = dots, attacker = attacker, target = defender, start = "-", result = "no fight", kind = kind, why = why })
						continue
					end
					for _, c in checks do
						local bad = if dots == 1 then c.diag.dealt <= 0 else c.trade < ({ 0, 1, 2 })[dots]
						if bad then
							local kind, why = diagnose(att, def, c.diag)
							table.insert(findings, { row = row, col = col, dots = dots, attacker = attacker, target = defender, start = c.start, result = string.format("trade %s, %d shots, %d hits", fmt(c.trade), c.diag.shots // SEEDS, c.diag.hits // SEEDS), kind = kind, why = why })
						end
					end
					if #findings == before then
						held += 1
					end
				end
			end
		end
	end
end
print(string.format("counter check done: %d findings (%.0f s)", #findings, os.clock() - t0))

-- report -------------------------------------------------------------------------------
local lines = {}
local function out(s: string)
	table.insert(lines, s)
end
local function shortName(id: string): string
	return if defs.units[id] then defs.units[id].name else id
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
out("- Watch any fight: `lune run export matchup:<order id>:<chaos id>[:close|long]` (or `siege:<id>`), then open `tools/viewer/index.html`.")
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
out("Geometric mean of the value trade over every matchup the unit takes part in (both starts), and wins / matchups (all seeds). For Chaos units the trade is inverted, so above 1 is good for the unit in both columns. Siege: share of an enemy base (plant, 3 generators, radar tower) destroyed in 2 minutes.")
out("")
out("| Unit | Faction | Value | Mean trade | Wins / fights | Siege |")
out("|---|---|---|---|---|---|")
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
	local siege = "-"
	local o = sieges[id]
	if o then
		siege = string.format("%.0f%%", (o.diag[if isOrder then 1 else 2].dealt / SEEDS) / baseValue(d.faction) * 100)
	end
	out(string.format("| %s (`%s`) | %s | %.0f | %s | %d / %d | %s |", d.name, id, d.faction, value(d), if n > 0 then fmt(math.exp(logSum / n)) else "-", wins, fights, siege))
end
for _, id in order do
	summary(id, true)
end
for _, id in chaos do
	summary(id, false)
end
out("")
out("## Counter check (guide 12.4)")
out("")
out("Each matrix cell is checked for every unit of that role on both sides, against every enemy unit of that target class. A pair falls short when:")
out("")
out("- **—**: the attacker can damage the class anyway;")
out("- **●**: it destroys nothing;")
out("- **●●**: its value trade is below 1;")
out("- **●●●**: its value trade is below 2.")
out("")
out("Against structures (the siege), the share of the base destroyed must be above 2% for ●, 30% for ●●, and 60% for ●●●. The coastal battery row comes from guide 13.5 (\"heavy gun against ships\": ●●●).")
out("")
out("Why a pair fell short:")
out("")
out("- **mechanic**: can't target, can't see, can't reach (the shore), out of range, never hit, ran dry, or a bomber never lined up a run;")
out("- **numbers**: it saw, reached, fired and hit, but lost the trade.")
out("")
local byKind = { mechanic = 0, numbers = 0 }
for _, f in findings do
	byKind[f.kind] += 1
end
out(string.format("%d of %d attacker / target pairs hold (both starts); %d findings (one per pair and start): %d mechanic, %d numbers.", held, checked, #findings, byKind.mechanic, byKind.numbers))
out("")
out("| Matrix cell | Attacker | Target | Start | Result | Kind | Why |")
out("|---|---|---|---|---|---|---|")
table.sort(findings, function(a, b)
	if a.row ~= b.row then
		return a.row < b.row
	elseif a.col ~= b.col then
		return a.col < b.col
	elseif a.attacker ~= b.attacker then
		return a.attacker < b.attacker
	elseif a.target ~= b.target then
		return a.target < b.target
	end
	return a.start < b.start
end)
for _, f in findings do
	out(string.format("| %s → %s %s | %s | %s | %s | %s | %s | %s |", f.row, f.col, DOTS[f.dots], shortName(f.attacker), shortName(f.target), f.start, f.result, f.kind, f.why))
end
out("")
if FILTER == nil then
	fs.writeFile("docs/BALANCE.md", table.concat(lines, "\n") .. "\n")
	print("wrote docs/BALANCE.md")
else
	print(table.concat(lines, "\n"))
end
