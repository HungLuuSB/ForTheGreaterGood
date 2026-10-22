--!strict
-- Stress test and bandwidth report (guide 17.5, 18.1, 7.6).
--   lune run stress [ticks] [sizes...]      e.g. lune run stress 450 200 400 600 800
--
-- Two mixed armies (tanks, artillery, radars, jammers) on a generated
-- 256×256 map attack-move into each other. Each player's camera watches the
-- middle of the battlefield (40×30 cells). Reports per-system average and
-- peak ms per tick against the guide 18.1 budgets, and bytes per second per
-- player per channel against guide 7.6. Writes debug_out/stress.txt.
-- Lune on a desktop is not a live Roblox server: repeat on a live server.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Packer = require("../src/shared/Net/Packer")
local Schema = require("../src/shared/Net/Schema")
local Sim = require("../src/server/Sim/Sim")
local Spawn = require("../src/server/Sim/Spawn")
local Nav = require("../src/server/Sim/Nav")
local Work = require("../src/server/Sim/Work")

local TICKS = tonumber(process.args[1]) or 450
local SIZES = {}
for i = 2, #process.args do
	table.insert(SIZES, tonumber(process.args[i]) :: number)
end
if #SIZES == 0 then
	SIZES = { 200, 400, 600, 800 }
end

-- guide 18.1 (ms); systems sharing a budget line are summed
local BUDGETS = {
	{ "Commands", { "Sim.Commands" }, 1 },
	{ "Economy", { "Sim.Economy" }, 1 },
	{ "Sensors", { "Sim.Sensors" }, 5 },
	{ "Targeting", { "Sim.Targeting" }, 8 },
	{ "Pathing", { "Sim.Pathing" }, 8 },
	{ "Movement", { "Sim.Movement" }, 10 },
	{ "Weapons", { "Sim.Weapons" }, 5 },
	{ "Projectiles+Damage", { "Sim.Projectiles", "Sim.Damage" }, 8 },
	{ "Construction", { "Sim.Construction" }, 2 },
	{ "NetOut", { "Sim.NetOut" }, 6 },
}
local TICK_BUDGET = 1000 / 15

local lines = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local MIX = { -- per team: fraction of the army
	{ 0.75, "ord_lancer", "chs_ravager" },
	{ 0.15, "ord_verdict", "chs_hellmouth" },
	{ 0.05, "ord_oracle", "chs_watcher" },
	{ 0.05, "ord_veil", "chs_shroud" },
}

local function run(total: number)
	local sim = Sim.new({ seed = total, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "gen:4:256" })
	local nav = sim.nav :: Nav.Nav
	local g = nav.grid
	local timing = Sim.enableTiming(sim)
	-- armies: blocks around x = ±600, on ground their tanks can stand on
	local armies = { {}, {} }
	for team = 1, 2 do
		local cx = if team == 1 then -600 else 600
		local placed, k = 0, 0
		local per = total // 2
		local counts = {}
		for i, m in MIX do
			counts[i] = math.floor(per * m[1] + 0.5)
		end
		local kind = 1
		while placed < per and k < per * 20 do
			local col, row = k % 25, k // 25
			local x, z = cx + (col - 12) * 14, (row - 12) * 14
			k += 1
			if Nav.fits(nav, nav.profiles[sim.defs.units.ord_lancer.index], x, z) then
				while kind < #MIX and counts[kind] <= 0 do
					kind += 1
				end
				counts[kind] -= 1
				local defId = MIX[kind][team + 1]
				table.insert(armies[team], Spawn.unit(sim, defId, team, x, z, if team == 1 then math.pi / 2 else -math.pi / 2))
				placed += 1
			end
		end
	end
	-- cameras over the middle of the map, attack-move into each other
	for pid = 1, 2 do
		submit(sim, pid, { cmdType = Schema.CmdType.CAMERA, flags = 0, unitIds = {}, minX = 108, minZ = 113, maxX = 147, maxZ = 142 })
		local ids = armies[pid]
		for i = 1, #ids, 200 do
			local chunk = table.move(ids, i, math.min(i + 199, #ids), 1, {})
			local tx = if pid == 1 then 500 else -500
			local cell, ox, oz = g:encode(tx, 0)
			submit(sim, pid, { cmdType = Schema.CmdType.FIGHT, flags = 0, unitIds = chunk, cell = cell, offX = ox, offZ = oz })
		end
	end

	local tickTimes = {}
	-- move-order path per tick: Commands (issuing) + Pathing (plans, fields)
	local orderPeak, lastOrders = 0, 0
	-- structures placed mid-battle (every 30 ticks from tick 60), timed with
	-- the tick they land in: passability, quadtree and field-cache updates
	local placements, placementPeak, placeCost = 0, 0, 0
	Work.reset() -- counts from the first tick (S-99)
	local t0 = os.clock()
	for tick = 1, TICKS do
		local s = os.clock()
		local placed = false
		if tick >= 60 and tick % 30 == 0 then
			local k = tick // 30
			local x, z = ((k * 137) % 400) - 200, ((k * 71) % 400) - 200
			local p0 = os.clock()
			Spawn.unit(sim, if k % 2 == 0 then "ord_vehplant" else "chs_generator", 1 + k % 2, x, z)
			placeCost = math.max(placeCost, (os.clock() - p0) * 1000)
			placements += 1
			placed = true
		end
		Sim.step(sim)
		local ms = (os.clock() - s) * 1000
		table.insert(tickTimes, ms)
		if placed then
			placementPeak = math.max(placementPeak, ms)
		end
		local orders = (timing.total["Sim.Commands"] or 0) + (timing.total["Sim.Pathing"] or 0)
		orderPeak = math.max(orderPeak, (orders - lastOrders) * 1000)
		lastOrders = orders
	end
	local wall = os.clock() - t0
	table.sort(tickTimes)
	local avgTick = wall * 1000 / TICKS

	out("")
	out(string.format("=== %d units (%d alive at the end), %d ticks (%.0f s game time), %d projectiles live at the end, kills %d ===",
		total, #sim.world.ids, TICKS, TICKS / 15, #sim.combat.proj, sim.combat.stats.kills))
	out(string.format("tick: avg %.2f ms, p95 %.2f ms, max %.2f ms (budget %.1f ms)",
		avgTick, tickTimes[math.floor(#tickTimes * 0.95)], tickTimes[#tickTimes], TICK_BUDGET))
	out(string.format("%-20s %9s %9s %8s  %s", "system", "avg ms", "peak ms", "budget", ""))
	local firstOver = nil
	for _, b in BUDGETS do
		local sum, peak, at = 0, 0, 0
		for _, name in b[2] do
			sum += timing.total[name]
			if timing.peak[name] > peak then
				peak, at = timing.peak[name], timing.peakTick[name] or 0
			end
		end
		local avg = sum * 1000 / timing.ticks
		local over = avg > b[3]
		if over and firstOver == nil then
			firstOver = b[1]
		end
		out(string.format("%-20s %9.3f %9.2f %8.1f  %s (tick %d)", b[1], avg, peak * 1000, b[3], if over then "OVER (average)" elseif peak * 1000 > b[3] then "peak over" else "ok", at))
	end
	out("first system over budget (average): " .. (firstOver or "none"))
	out(string.format("move orders (Commands + Pathing in one tick): worst tick %.2f ms", orderPeak))
	local wc = Work.counts
	out(string.format("work (deterministic, S-99): route %d, flow field %d, sensor lookups %d, known-target lookups %d", wc.routeWork, wc.flowWork, wc.sensorLookups, wc.knownLookups))
	out(string.format("structure placements mid-battle: %d, worst tick with a placement %.2f ms (placement itself: worst %.2f ms)", placements, placementPeak, placeCost))
	out(string.format("state hash %08x (equal before and after an optimisation = same behaviour)", Sim.hash(sim)))
	-- bandwidth per player
	local seconds = TICKS / 15
	for pid = 1, 2 do
		local pn = sim.net.players[pid]
		local tac = pn.bytes.Tactical / seconds / 1000
		local strat = pn.bytes.Strategic / seconds / 1000
		local st = pn.bytes.State / seconds / 1000
		local ev = pn.bytes.Events / seconds / 1000
		local se = st + ev
		local pr = (pn.bytes.Projectiles or 0) / seconds / 1000
		local total = tac + strat + se + pr
		out(string.format("player %d KB/s: tactical %.2f (peak target 15), strategic %.2f (10), state %.2f + events %.2f = %.2f (10), projectiles %.2f, total %.2f (35)%s",
			pid, tac, strat, st, ev, se, pr, total, if total > 35 then "  OVER" else ""))
		local kinds = {}
		for name, k in Schema.EventKind do
			local n = (pn.eventCounts or {})[k] or 0
			if n > 0 then
				table.insert(kinds, { name = name, n = n })
			end
		end
		table.sort(kinds, function(x, y)
			return x.n > y.n
		end)
		local parts = {}
		for _, k in kinds do
			table.insert(parts, string.format("%s %.1f/s (%.0f B/s)", k.name, k.n / seconds, ((pn.eventBytes or {})[Schema.EventKind[k.name]] or 0) / seconds))
		end
		if #parts > 0 then
			out(string.format("  player %d event records: %s", pid, table.concat(parts, ", ")))
		end
	end
	return firstOver
end

out(string.format("Stress test: %d ticks per size, Lune on the dev PC (not a live server)", TICKS))
for _, n in SIZES do
	run(n)
end
if not fs.isDir("debug_out") then
	fs.writeDir("debug_out")
end
fs.writeFile("debug_out/stress.txt", table.concat(lines, "\n") .. "\n")
