--!strict
-- Player-facing replays (S-18, guide 17.1): the spectator stream and a
-- player's stream recorded into a PlayerReplay file; playing the file back
-- through a client rebuilds exactly the view a client watching live had,
-- without re-simulating.
local NetOut = require("../Sim/NetOut")
local NetState = require("../Sim/NetState")
local PlayerReplay = require("@shared/Net/PlayerReplay")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local TICKS = 900 * 4 -- four minutes: workers, extractors, the first fights
local CHECK_EVERY = 150

-- Everything a client view holds, as a string: units (tier, team, type,
-- icon, flags, position, heading, altitude, health, build, state, targets),
-- projectiles, the economy and the WELCOME.
local function digest(view: Client.View): string
	local ids = {}
	for id in view.units do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ids do
		local u = view.units[id]
		local targets = {}
		for slot, t in u.targets or {} do
			targets[slot] = tostring(t)
		end
		table.insert(parts, string.format("%d:%s:%d:%s:%s:%s:%.6f:%.6f:%s:%s:%s:%s:%s:%s", id, u.tier, u.team, tostring(u.defIndex), tostring(u.icon), tostring(u.flags), u.x, u.z,
			tostring(u.heading), tostring(u.alt), tostring(u.health), tostring(u.build), tostring(u.state), table.concat(targets, ",")))
	end
	local pids = {}
	for id in view.projectiles do
		table.insert(pids, id)
	end
	table.sort(pids)
	for _, id in pids do
		local p = view.projectiles[id]
		table.insert(parts, string.format("p%d:%d:%.6f:%.6f:%.6f", id, p.weaponIndex, p.x, p.y, p.z))
	end
	local e = view.economy
	if e then
		table.insert(parts, string.format("eco:%d:%d:%d:%d", e.supply.stored, e.supply.income, e.power.stored, e.power.income))
	end
	local wl = view.welcome
	if wl then
		table.insert(parts, string.format("welcome:%d:%d:%d", wl.player :: number, wl.team :: number, wl.allyTeam :: number))
	end
	return table.concat(parts, "|")
end

type Run = {
	sim: Sim.Sim,
	spectator: Client.View,
	player: Client.View,
	replays: { PlayerReplay.Replay }, -- spectator, player 1
	checks: { { [number]: string } }, -- per replay: tick → live digest
}

-- An AI-vs-AI match with a spectator and player 1's client watching live
-- while both streams are recorded.
local function play(): Run
	local sim = Sim.new({
		seed = 5,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = "normal", [2] = "normal" } },
	})
	local g = (sim.map :: any).grid
	local sid = NetOut.addSpectator(sim)
	NetOut.setCamera(sim, 1, 0, 0, 95, 191) -- player 1 watches the west half
	local function header(viewer: number): PlayerReplay.Header
		local players = {}
		for _, pid in sim.playerOrder do
			local p = sim.players[pid]
			table.insert(players, { id = pid, team = p.team, allyTeam = p.allyTeam :: number })
		end
		return { protocol = Schema.PROTOCOL_VERSION, defsHash = sim.defs.hash, mapId = sim.mapId, viewer = viewer, players = players }
	end
	local run: Run = {
		sim = sim,
		spectator = Client.new(g),
		player = Client.new(g),
		replays = { PlayerReplay.new(header(0), sim.tick + 1), PlayerReplay.new(header(1), sim.tick + 1) },
		checks = { {}, {} },
	}
	local brains = Skirmish.forMatch(sim)
	for _ = 1, TICKS do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		local outboxes = { sim.net.spectators[sid].outbox, sim.net.players[1].outbox }
		local views = { run.spectator, run.player }
		for k = 1, 2 do
			Client.receive(views[k], outboxes[k])
			PlayerReplay.record(run.replays[k], sim.tick, outboxes[k])
			if sim.tick % CHECK_EVERY == 0 then
				run.checks[k][sim.tick] = digest(views[k])
			end
		end
	end
	return run
end

return function(t: RunAll.Context)
	local run: Run? = nil
	local function get(): Run
		run = run or play()
		return run :: Run
	end

	t.test("a spectator sees every unit, in its tactical tier, and every team", function()
		local r = get()
		local w = r.sim.world
		local missing, wrong = 0, 0
		for _, id in w.ids do
			local u = r.spectator.units[id]
			if u == nil then
				missing += 1
			elseif u.tier ~= "tactical" or u.team ~= w.team[id] or u.defIndex ~= w.defIndex[id] then
				wrong += 1
			end
		end
		t.equal(missing, 0, `units the spectator doesn't have (of {#w.ids})`)
		t.equal(wrong, 0, "units it has wrong")
		t.equal(r.spectator.welcome and r.spectator.welcome.player, 0, "its WELCOME names player 0")
		t.equal(r.spectator.economy, nil, "spectators get no team economy")
		local hidden = 0
		for _, id in w.ids do
			if r.player.units[id] == nil then
				hidden += 1
			end
		end
		t.expect(hidden > 0, `player 1 doesn't see everything ({hidden} units hidden): fog still applies to players`)
	end)

	t.test("playing a recorded stream back rebuilds the live view, without the sim", function()
		local r = get()
		for k, rep in r.replays do
			local file = PlayerReplay.serialize(rep)
			local back = PlayerReplay.parse(file)
			t.equal(buffer.tostring(PlayerReplay.serialize(back)), buffer.tostring(file), "the file round-trips byte for byte")
			local view = Client.new((r.sim.map :: any).grid)
			local checked, differ = 0, 0
			PlayerReplay.play(back, function(tick, outbox)
				Client.receive(view, outbox)
				local want = r.checks[k][tick]
				if want then
					checked += 1
					if digest(view) ~= want then
						differ += 1
					end
				end
			end)
			local name = if k == 1 then "spectator" else "player 1"
			t.equal(checked, TICKS // CHECK_EVERY, `{name}: views compared`)
			t.equal(differ, 0, `{name}: playback views that differ from live`)
			t.equal(digest(view), digest(if k == 1 then r.spectator else r.player), `{name}: the final view`)
			print(string.format("    %s replay: %.1f KB for %.0f min (%.1f KB/min), %d frames", name, buffer.len(file) / 1024, TICKS / 900, buffer.len(file) / 1024 / (TICKS / 900), #back.frames))
		end
	end)

	t.test("replay files: header, channel numbering, malformed files refused", function()
		t.deepEqual(PlayerReplay.CHANNELS, NetState.CHANNELS, "the file numbers the server's channels")
		local rep = PlayerReplay.new({ protocol = Schema.PROTOCOL_VERSION, defsHash = 0xDEADBEEF, mapId = "map:ridgeline", viewer = 0, players = { { id = 1, team = 1, allyTeam = 1 } } }, 10)
		local msg = buffer.fromstring(string.rep("x", 300))
		PlayerReplay.record(rep, 10, { Events = { msg } })
		PlayerReplay.record(rep, 11, {})
		PlayerReplay.record(rep, 12, { Tactical = { buffer.fromstring("ab") }, Eco = { buffer.fromstring("c") } })
		t.throws(function()
			PlayerReplay.record(rep, 14, {})
		end, "expected tick 13")
		local back = PlayerReplay.parse(PlayerReplay.serialize(rep))
		t.deepEqual(back.header, rep.header, "header")
		t.equal(back.firstTick, 10)
		t.equal(back.lastTick, 12)
		t.equal(#back.frames, 2, "ticks without messages take no frame")
		t.equal(buffer.tostring(back.frames[1].messages[1].data), string.rep("x", 300), "a long message (two-byte length)")
		t.equal(back.frames[2].messages[2].channel, "Eco")
		local delivered = {}
		PlayerReplay.play(back, function(tick, outbox)
			table.insert(delivered, `{tick}:{#outbox.Events}:{#outbox.Tactical}`)
		end)
		t.deepEqual(delivered, { "10:1:0", "11:0:0", "12:0:1" }, "playback feeds every tick, empty ones too")
		t.throws(function()
			PlayerReplay.parse(buffer.fromstring("FTGR\1"))
		end, "not a player replay")
		local file = buffer.tostring(PlayerReplay.serialize(rep))
		t.throws(function()
			PlayerReplay.parse(buffer.fromstring("FTGP\9" .. string.sub(file, 6)))
		end, "unsupported format version 9")
		t.throws(function()
			PlayerReplay.parse(buffer.fromstring(string.sub(file, 1, #file - 5)))
		end, "truncated")
	end)
end
