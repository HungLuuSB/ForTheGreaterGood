--!strict
-- Report-only duel scenarios (no pass/fail). Prints outcomes for:
--   close: 13 Lancers vs 15 Ravagers (equal supply, 1,950 each), lines 100
--          studs apart so every pair is inside both guns' range
--   kite:  same armies on an open 256×256 map; Ravagers attack-move at the
--          Lancers, Lancers kite: keep each nearest Ravager between 168 and
--          178 studs (Lancer reach 180 + target radius, Ravager reach 160 + radius)
--   lune run report_duels [seeds]

local process = require("@lune/process")

local Packer = require("../src/shared/Net/Packer")
local Schema = require("../src/shared/Net/Schema")
local Sim = require("../src/server/Sim/Sim")
local Spawn = require("../src/server/Sim/Spawn")

local SEEDS = tonumber(process.args[1]) or 5
local LANCERS, RAVAGERS = 13, 15
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number, cmdType: number?)
	local g = (sim.nav :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, player, { cmdType = cmdType or CT.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

local function line(sim: Sim.Sim, defId: string, owner: number, count: number, x: number, facing: number, dir: number)
	for i = 0, count - 1 do
		local row, col = i // 8, i % 8
		Spawn.unit(sim, defId, owner, x + dir * row * 12, (col - 3.5) * 12, facing)
	end
end

local function result(sim: Sim.Sim): (number, number, number, number)
	local n1, n2, hp1, hp2 = 0, 0, 0, 0
	for _, id in sim.world.ids do
		if sim.world.team[id] == 1 then
			n1 += 1
			hp1 += sim.world.health[id]
		else
			n2 += 1
			hp2 += sim.world.health[id]
		end
	end
	return n1, n2, hp1, hp2
end

local function run(kind: string, seed: number): string
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = if kind == "kite" then "flat:256" else "flat:64", scenario = "empty" })
	local w = sim.world
	if kind == "close" then
		line(sim, "ord_lancer", 1, LANCERS, -50, math.pi / 2, -1)
		line(sim, "chs_ravager", 2, RAVAGERS, 50, -math.pi / 2, 1)
	else
		line(sim, "ord_lancer", 1, LANCERS, 0, -math.pi / 2, 1)
		line(sim, "chs_ravager", 2, RAVAGERS, -600, math.pi / 2, -1)
	end
	local t0 = os.clock()
	while sim.tick < 9000 do
		if kind == "kite" then
			local lancers, ravagers = {}, {}
			for _, id in w.ids do
				table.insert(if w.team[id] == 1 then lancers else ravagers, id)
			end
			if #lancers == 0 or #ravagers == 0 then
				break
			end
			if sim.tick % 30 == 0 then
				-- Ravagers: attack-move at the Lancers' centroid
				local cx, cz = 0, 0
				for _, id in lancers do
					cx += w.posX[id] / #lancers
					cz += w.posZ[id] / #lancers
				end
				moveTo(sim, 2, ravagers, cx, cz, CT.FIGHT)
			end
			if sim.tick % 10 == 0 then
				-- Lancers: keep the nearest Ravager at 168..178 studs
				for _, id in lancers do
					local best, bestD = 0, math.huge
					for _, r in ravagers do
						local d = math.sqrt((w.posX[r] - w.posX[id]) ^ 2 + (w.posZ[r] - w.posZ[id]) ^ 2)
						if d < bestD then
							best, bestD = r, d
						end
					end
					local ux, uz = (w.posX[id] - w.posX[best]) / bestD, (w.posZ[id] - w.posZ[best]) / bestD
					if bestD < 168 then
						moveTo(sim, 1, { id }, w.posX[best] + ux * 176, w.posZ[best] + uz * 176)
					elseif bestD > 178 then
						moveTo(sim, 1, { id }, w.posX[best] + ux * 172, w.posZ[best] + uz * 172)
					elseif w.orderId[id] ~= 0 then
						submit(sim, 1, { cmdType = CT.STOP, flags = 0, unitIds = { id } })
					end
				end
			end
		end
		Sim.step(sim)
		local n1, n2 = result(sim)
		if n1 == 0 or n2 == 0 then
			break
		end
	end
	local elapsed = os.clock() - t0
	local n1, n2, hp1, hp2 = result(sim)
	local s = sim.combat.stats
	local winner = if n1 > 0 and n2 == 0 then "Order" elseif n2 > 0 and n1 == 0 then "Chaos" else "draw/timeout"
	return string.format(
		"%-5s seed %d: %-6s wins | Lancers %2d/%d (%5.0f hp) vs Ravagers %2d/%d (%5.0f hp) | %4d ticks (%.0f s) | shots %d, hits %d | %.2f ms/tick",
		kind,
		seed,
		winner,
		n1,
		LANCERS,
		hp1,
		n2,
		RAVAGERS,
		hp2,
		sim.tick,
		sim.tick / 15,
		s.shots,
		s.hits,
		elapsed * 1000 / math.max(sim.tick, 1)
	)
end

for _, kind in { "close", "kite" } do
	for seed = 1, SEEDS do
		print(run(kind, seed))
	end
end
