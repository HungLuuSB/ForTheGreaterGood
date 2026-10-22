--!strict
-- Headless profile of the Studio `normandy` battle (MatchConfig, S-53/S-54;
-- overnight task 3): the profile's spawns and stores exactly as the Roblox
-- entry builds them, then (the profile itself gives no orders) both armies
-- and air forces attack-move at each other from tick 30, with both
-- players' cameras over the battlefield. Reports per-system average and
-- peak ms against the guide 18.1 budgets, and the worst ticks.
--   lune run profile_normandy [ticks]      (default 3600 = 4 minutes)

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Packer = require("../src/shared/Net/Packer")
local Schema = require("../src/shared/Net/Schema")
local Sim = require("../src/server/Sim/Sim")
local Spawn = require("../src/server/Sim/Spawn")
local Work = require("../src/server/Sim/Work")

local TICKS = tonumber(process.args[1]) or 3600

-- the profiles table, from the Roblox config file itself (plain data)
local source = fs.readFile("src/roblox/MatchConfig.luau")
source = string.gsub(source, "return table%.freeze%(PROFILES%[ACTIVE%]%)", "return PROFILES")
local profiles = luau.load(source, { debugName = "MatchConfig" })() :: any
local cfg = profiles.normandy

local BUDGETS = { -- guide 18.1 (ms); systems sharing a line are summed
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

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local sim = Sim.new({ seed = cfg.seed, players = cfg.players, mapId = cfg.mapId, scenario = cfg.scenario })
local w = sim.world
for _, s in cfg.spawns do
	local cols = s.cols or s.count or 1
	for i = 0, (s.count or 1) - 1 do
		local col, row = i % cols, i // cols
		local x = s.x + col * (s.dx or 0) + row * (s.rowDx or 0)
		local z = s.z + col * (s.dz or 0) + row * (s.rowDz or 0)
		Spawn.unit(sim, s.def, s.player, x, z, s.heading or 0)
	end
end
for _ = 1, 5 do
	Sim.step(sim)
end
for _, acc in sim.eco.accounts do
	acc.supply.stored = math.min(cfg.startResources.supply, acc.supply.storage)
	acc.power.stored = math.min(cfg.startResources.power, acc.power.storage)
end
local g = (sim.map :: any).grid
for pid = 1, 2 do
	-- the camera over the middle of the bocage
	submit(sim, pid, { cmdType = Schema.CmdType.CAMERA, flags = 0, unitIds = {}, minX = 88, minZ = 88, maxX = 168, maxZ = 148 })
end
print(string.format("normandy: %d units", #w.ids))

local timing = Sim.enableTiming(sim)
local last: { [string]: number } = {}
local sysPeak: { [string]: number } = {}
local sysPeakTick: { [string]: number } = {}
local sysTotal: { [string]: number } = {}
local tickTimes: { { number } } = {}
Work.reset() -- counts from the first tick (S-99)
for tick = 1, TICKS do
	if tick == 30 then
		-- attack-move: every armed mobile unit at the other side's staging field
		for pid = 1, 2 do
			local ids = {}
			for _, id in w.ids do
				local d = sim.defs.unitByIndex[w.defIndex[id]]
				if w.owner[id] == pid and d.domain ~= "structure" and #d.weapons > 0 then
					table.insert(ids, id)
				end
			end
			local tx = if pid == 1 then 500 else -500
			local cell, ox, oz = g:encode(tx, 0)
			for i = 1, #ids, 200 do
				submit(sim, pid, { cmdType = Schema.CmdType.FIGHT, flags = 0, unitIds = table.move(ids, i, math.min(i + 199, #ids), 1, {}), cell = cell, offX = ox, offZ = oz })
			end
		end
	end
	local kb0 = collectgarbage("count")
	local t0 = os.clock()
	Sim.step(sim)
	local ms = (os.clock() - t0) * 1000
	local kb1 = collectgarbage("count")
	local breakdown = {}
	table.insert(tickTimes, { ms, sim.tick, #w.ids, #sim.combat.proj, breakdown, kb1 - kb0 })
	for name, total in timing.total do
		local d = (total - (last[name] or 0)) * 1000
		if d >= 0.5 then
			table.insert(breakdown, string.format("%s %.1f", string.gsub(name, "Sim%.", ""), d))
		end
		last[name] = total
		if d > (sysPeak[name] or 0) then
			sysPeak[name] = d
			sysPeakTick[name] = sim.tick
		end
		sysTotal[name] = (sysTotal[name] or 0) + d
	end
end

local lines = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end
local sorted = table.clone(tickTimes)
table.sort(sorted, function(a, b)
	return a[1] < b[1]
end)
local sum = 0
for _, t in tickTimes do
	sum += t[1]
end
out(string.format("ticks %d: avg %.2f ms, p99 %.2f ms, worst %.2f ms (tick %d, %d units, %d projectiles)", TICKS, sum / TICKS, sorted[math.floor(#sorted * 0.99)][1], sorted[#sorted][1], sorted[#sorted][2], sorted[#sorted][3], sorted[#sorted][4]))
for k = #sorted, math.max(#sorted - 4, 1), -1 do
	local t = sorted[k]
	out(string.format("  worst: tick %d %.2f ms (heap %+.0f KB): %s", t[2], t[1], t[6], table.concat(t[5], ", ")))
end
do
	local wc = Work.counts
	out(string.format("work (deterministic, S-99): route %d, flow field %d, sensor lookups %d, known-target lookups %d", wc.routeWork, wc.flowWork, wc.sensorLookups, wc.knownLookups))
end
out(string.format("%-20s %9s %9s %8s", "system", "avg ms", "peak ms", "budget"))
for _, b in BUDGETS do
	local avg, peak, at = 0, 0, {}
	for _, name in b[2] do
		avg += (sysTotal[name] or 0) / TICKS
		peak += sysPeak[name] or 0
		table.insert(at, tostring(sysPeakTick[name]))
	end
	out(string.format("%-20s %9.3f %9.3f %8d  (tick %s)%s", b[1], avg, peak, b[3], table.concat(at, "/"), if peak > b[3] then "  PEAK OVER" else ""))
end
out(string.format("units at the end: %d; state hash %08x (equal before and after an optimisation = same behaviour)", #w.ids, Sim.hash(sim)))
fs.writeDir("debug_out")
fs.writeFile("debug_out/normandy_profile.txt", table.concat(lines, "\n") .. "\n")
