--!strict
-- Player replay sizes (S-77): lune run replay_size [file.ftgp] [minutes]
-- With a file: its size as format 1 (plain frames) and format 2
-- (transformed and LZ-compressed), per channel, and a round-trip check.
-- Without: records a Normal-vs-Normal AI match on skirmish:192 for
-- `minutes` (default 10) from player 1's view and a spectator's, and reports
-- both. Report only.

local fs = require("@lune/fs")
local process = require("@lune/process")

local NetOut = require("../src/server/Sim/NetOut")
local PlayerReplay = require("../src/shared/Net/PlayerReplay")
local Schema = require("../src/shared/Net/Schema")
local Sim = require("../src/server/Sim/Sim")
local Skirmish = require("../src/server/Sim/AI/Skirmish")

local function report(name: string, rep: PlayerReplay.Replay)
	local t0 = os.clock()
	local v1 = PlayerReplay.serialize(rep, 1)
	local t1 = os.clock()
	local v2 = PlayerReplay.serialize(rep)
	local t2 = os.clock()
	local back = PlayerReplay.parse(v2)
	local t3 = os.clock()
	local same = buffer.tostring(PlayerReplay.serialize(back, 1)) == buffer.tostring(v1)
	local minutes = (rep.lastTick - rep.firstTick + 1) / 900
	local perChannel: { [string]: number } = {}
	for _, f in rep.frames do
		for _, m in f.messages do
			perChannel[m.channel] = (perChannel[m.channel] or 0) + buffer.len(m.data)
		end
	end
	local parts = {}
	for _, ch in PlayerReplay.CHANNELS do
		if perChannel[ch] then
			table.insert(parts, string.format("%s %.0f", ch, perChannel[ch] / 1024))
		end
	end
	print(string.format("%s: %.1f min; format 1 %.0f KB (%.1f KB/min), format 2 %.0f KB (%.1f KB/min, %.0f%%); write %.2f s (format 1 %.2f s), read %.2f s; round trip %s",
		name, minutes, buffer.len(v1) / 1024, buffer.len(v1) / 1024 / minutes, buffer.len(v2) / 1024, buffer.len(v2) / 1024 / minutes, buffer.len(v2) / buffer.len(v1) * 100,
		t2 - t1, t1 - t0, t3 - t2, if same then "identical" else "DIFFERS"))
	print("  per channel (KB, plain): " .. table.concat(parts, ", "))
end

local file = process.args[1]
if file and string.find(file, "%.ftgp$") then
	report(file, PlayerReplay.parse(buffer.fromstring(fs.readFile(file))))
	return
end

local minutes = tonumber(process.args[1]) or 10
local sim = Sim.new({
	seed = 3,
	players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 } },
	mapId = "skirmish:192",
	scenario = "standard_start",
	match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = "normal", [2] = "normal" } },
})
local spectator = NetOut.addSpectator(sim)
local function header(viewer: number): PlayerReplay.Header
	local players = {}
	for _, pid in sim.playerOrder do
		local p = sim.players[pid]
		table.insert(players, { id = pid, team = p.team, allyTeam = p.allyTeam :: number })
	end
	return { protocol = Schema.PROTOCOL_VERSION, defsHash = sim.defs.hash, mapId = sim.mapId, viewer = viewer, players = players }
end
local player = PlayerReplay.new(header(1), 1)
local spec = PlayerReplay.new(header(0), 1)
-- player 1's camera over its own base, the spectator's over the middle
local g = (sim.map :: any).grid
local brains = Skirmish.forMatch(sim)
for _ = 1, minutes * 900 do
	for _, b in brains do
		Skirmish.tick(b)
	end
	Sim.step(sim)
	PlayerReplay.record(player, sim.tick, sim.net.players[1].outbox)
	PlayerReplay.record(spec, sim.tick, sim.net.spectators[spectator].outbox)
	if sim.match.over then
		break
	end
end
local _ = g
report("player 1", player)
report("spectator", spec)
