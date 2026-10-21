--!strict
-- Replays and spectators (C-79): a player's stream recorded as a
-- PlayerReplay plays back through the client to the same view the live
-- client had, also after seeking forward and back, paused and sped up, and
-- through the file format; a spectator's client sees every unit.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local ReplayPlayer = require("../../src/client/Core/ReplayPlayer")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local PlayerReplay = require("@shared/Net/PlayerReplay")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

-- A compact fingerprint of a client's view: unit IDs with tier, rounded
-- position and health.
local function view(world: World.World): string
	local ids = {}
	for id in world.units do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ids do
		local u = world.units[id]
		table.insert(parts, string.format("%d:%s:%d:%d:%d", id, u.tier, math.floor(u.x + 0.5), math.floor(u.z + 0.5), math.floor((u.health or 1) * 255 + 0.5)))
	end
	return table.concat(parts, ",")
end

local function record(seconds: number, marks: { number })
	local sim = Sim.new({
		seed = 12,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "map:crossroads",
		scenario = "standard_start",
		match = { mode = "FFA", win = "ANNIHILATION", ai = { [1] = "normal", [2] = "normal" } },
	})
	local brains = Skirmish.forMatch(sim)
	local live = World.new(sim.defs)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	local header: PlayerReplay.Header = { protocol = Schema.PROTOCOL_VERSION, defsHash = sim.defs.hash, mapId = sim.mapId, viewer = 1, players = {} }
	for _, pid in sim.playerOrder do
		local p = sim.players[pid]
		table.insert(header.players, { id = pid, team = p.team, allyTeam = p.allyTeam })
	end
	local rep = PlayerReplay.new(header, sim.tick + 1)
	local views: { [number]: string } = {}
	local spectatorIndex = NetOut.addSpectator(sim)
	local spectator = World.new(sim.defs)
	for _ = 1, math.floor(seconds * 15) do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		local outbox = sim.net.players[1].outbox
		PlayerReplay.record(rep, sim.tick, outbox)
		NetIn.applyOutbox(live, outbox, sim.tick * DT)
		NetIn.applyOutbox(spectator, sim.net.spectators[spectatorIndex].outbox, sim.tick * DT)
		if table.find(marks, sim.tick) then
			views[sim.tick] = view(live)
		end
		table.clear(live.died)
		table.clear(spectator.died)
	end
	return sim, rep, views, spectator
end

return function(t: any)
	t.test("playback, seeks both ways, pause and speed reproduce the live view", function()
		local _sim, rep, views = record(40, { 150, 300, 450, 600 })
		local world = World.new(_sim.defs)
		local p = ReplayPlayer.new(rep)
		local function deliver(tick: number, outbox: any)
			NetIn.applyOutbox(world, outbox, tick * DT)
			table.clear(world.died)
		end
		-- play 10 s at normal speed in 1/30 s frames
		for _ = 1, 300 do
			ReplayPlayer.advance(p, 1 / 30, deliver)
		end
		t.equal(p.tick, rep.firstTick - 1 + 150, "10 s = 150 ticks")
		t.equal(view(world), views[150], "the live view at 10 s")
		-- paused: nothing moves
		p.paused = true
		ReplayPlayer.advance(p, 5, deliver)
		t.equal(p.tick, rep.firstTick - 1 + 150, "paused")
		p.paused = false
		-- 4x for 2.5 s of real time = 10 s of match
		p.speed = 4
		for _ = 1, 75 do
			ReplayPlayer.advance(p, 1 / 30, deliver)
		end
		t.equal(p.tick, rep.firstTick - 1 + 300, "4x speed")
		t.equal(view(world), views[300])
		-- forward seek, then back: starts over and rebuilds the same view
		ReplayPlayer.seek(p, rep.firstTick - 1 + 600, deliver)
		t.equal(view(world), views[600], "seek forward")
		ReplayPlayer.seek(p, rep.firstTick - 1 + 450, deliver)
		t.equal(p.restarts, 1, "a seek back starts over")
		t.equal(view(world), views[450], "seek back")
		local played, total = ReplayPlayer.progress(p)
		t.expect(math.abs(played - 30) < 0.1 and math.abs(total - 40) < 0.1, `progress {played} / {total}`)
		ReplayPlayer.seek(p, 1e9, deliver)
		t.expect(ReplayPlayer.done(p), "the end")
	end)

	t.test("through the file: serialize, parse, play back the same", function()
		local sim, rep, views = record(20, { 240 })
		local file = PlayerReplay.serialize(rep)
		local back = PlayerReplay.parse(file)
		t.equal(back.header.viewer, 1)
		t.equal(back.header.mapId, "map:crossroads")
		local world = World.new(sim.defs)
		local p = ReplayPlayer.new(back)
		ReplayPlayer.seek(p, back.firstTick - 1 + 240, function(tick, outbox)
			NetIn.applyOutbox(world, outbox, tick * DT)
			table.clear(world.died)
		end)
		t.equal(view(world), views[240], "the parsed file plays to the same view")
		print(string.format("    20 s of a 2-AI match: %d bytes (%.1f KB/s)", buffer.len(file), buffer.len(file) / 1024 / 20))
	end)

	t.test("a spectator's client sees every unit, as player 0", function()
		local sim, _rep, _views, spectator = record(20, {})
		t.expect(spectator.joined, "the spectator joined")
		t.equal(spectator.me.player, 0)
		t.equal(spectator.me.team, 0)
		local missing = 0
		for _, id in sim.world.ids do
			local u = spectator.units[id]
			if u == nil or u.tier ~= "tactical" then
				missing += 1
			end
		end
		t.equal(missing, 0, "every unit of both players, in detail")
		t.expect(#World.ownIds(spectator) == 0, "nothing of its own")
	end)
end
