--!strict
-- Shield domes and faction balance (S-90, the user's queue task 2).
-- Report only; it never changes stats.
--   lune run shield_trial [seeds] [orderRadius] [chaosRadius] ...
-- Each faction holds a base under its own dome (Scenes.shieldSiege) against
-- the other faction's equal-value raid, at each radius pair given (default
-- 120/80, the defs, and 64/48), and without a shield (its value spent on
-- army instead). Per case, over every seed: the defender's trade (raid
-- value destroyed / defender value lost; above 1 favours the defender),
-- how often the base fell, and when.

local process = require("@lune/process")

local Defs = require("../src/shared/Defs/Defs")
local Registry = require("../src/shared/Defs/Registry")
local Sim = require("../src/server/Sim/Sim")
local Scenes = require("../src/server/Tests/Support/Scenes")

local SEEDS = tonumber(process.args[1]) or 3
local PAIRS: { { number } } = {}
local i = 2
while process.args[i] and process.args[i + 1] do
	table.insert(PAIRS, { tonumber(process.args[i]) :: number, tonumber(process.args[i + 1]) :: number })
	i += 2
end
if #PAIRS == 0 then
	PAIRS = { { 120, 80 }, { 64, 48 } }
end

-- The def set with the two generators' dome radii set.
local function defsWith(orderR: number, chaosR: number): Defs.DefSet
	local units = table.clone(Registry.units)
	for id, r in { ord_phalanx = orderR, chs_carapace = chaosR } do
		local u = table.clone(units[id])
		u.shield = table.clone(u.shield)
		u.shield.radius = r
		units[id] = u
	end
	return Defs.build({ units = units, weapons = Registry.weapons } :: any)
end

-- One siege: (defender value lost, raid value lost, base fell at tick or nil, shells turned).
local function play(scene: Scenes.Scene, defender: string): (number, number, number?, number)
	local sim = scene.sim
	local w = sim.world
	local defs = sim.defs
	local sides = scene.sides :: { { number } }
	local defOf: { [number]: Defs.UnitDef } = {}
	for s = 1, 2 do
		for _, id in sides[s] do
			defOf[id] = defs.unitByIndex[w.defIndex[id]]
		end
	end
	local base = scene.base :: { number }
	local fell, turned = nil, 0
	while sim.tick < scene.maxTicks and not scene.done(sim) do
		scene.drive(sim)
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "SHIELD_HIT" then
				turned += 1
			end
		end
	end
	local alive = 0
	for _, id in base do
		if w.slot[id] then
			alive += 1
		end
	end
	if alive == 0 then
		fell = sim.tick
	end
	local function lost(ids: { number }): number
		local v = 0
		for _, id in ids do
			local d = defOf[id]
			local hp = if w.slot[id] then w.health[id] else 0
			v += Scenes.value(d) * (1 - math.clamp(hp / d.health, 0, 1))
		end
		return v
	end
	local dIdx = if defender == "order" then 1 else 2
	return lost(sides[dIdx]), lost(sides[3 - dIdx]), fell, turned
end

local function row(label: string, defender: string, shielded: boolean, defs: Defs.DefSet): string
	local dl, rl, falls, fallTicks, turned = 0, 0, 0, 0, 0
	for seed = 1, SEEDS do
		local a, b, fell, n = play(Scenes.shieldSiege(defender, shielded, seed, defs), defender)
		dl += a
		rl += b
		turned += n
		if fell then
			falls += 1
			fallTicks += fell
		end
	end
	local trade = if dl > 0 then rl / dl else math.huge
	local when = if falls > 0 then string.format("%.0f s", fallTicks / falls / 15) else "—"
	return string.format("| %s | %s | %.2f | %d / %d | %s | %.0f | %.0f | %.0f |", label, defender, trade, falls, SEEDS, when, dl / SEEDS, rl / SEEDS, turned / SEEDS)
end

print("| Domes (Order / Chaos) | Defender | Defender's trade | Base fell | Fell after | Defender lost | Raid lost | Shield hits |")
print("|---|---|---|---|---|---|---|---|")
local plain = Defs.load()
for _, defender in { "order", "chaos" } do
	print(row("no shield", defender, false, plain))
	for _, pair in PAIRS do
		print(row(`{pair[1]} / {pair[2]}`, defender, true, defsWith(pair[1], pair[2])))
	end
end
