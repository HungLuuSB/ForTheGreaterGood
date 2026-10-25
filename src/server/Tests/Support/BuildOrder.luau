--!strict
-- A scripted T1 build order from the match start (scenario "standard_start"),
-- driven only through player commands (Sim.submit), so it is recorded in the
-- replay like a real player's input.
--
-- Per player, the Command Vehicle builds, one after another:
--   extractor, extractor (nearest deposits), generator, generator,
--   vehicle plant (facing the map center)
-- then queues three tanks at the plant and assists it.

local Layers = require("@shared/Grid/Layers")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../../Sim/Sim")

local BuildOrder = {}

export type Step = { def: string, x: number, z: number, facing: number }

export type Timeline = { { tick: number, player: number, what: string } }

export type Driver = {
	sim: Sim.Sim,
	players: { [number]: {
		cv: number,
		steps: { Step },
		next: number,
		factory: number,
		queued: boolean,
		produced: number,
	} },
	timeline: Timeline,
}

local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, err = Sim.submit(sim, player, w:finish())
	assert(ok, err)
end

local function prefix(team: number): string
	return if team % 2 == 1 then "ord_" else "chs_"
end

-- The two deposits nearest (x, z).
local function nearestDeposits(layers: Layers.Layers, x: number, z: number): { { number } }
	local g = layers.grid
	local found = {}
	for i, d in layers.deposits or {} do
		-- each 2 × 2 patch's centre (S-184)
		local wx, wz = d[1], d[2]
		table.insert(found, { wx, wz, (wx - x) ^ 2 + (wz - z) ^ 2, i })
	end
	table.sort(found, function(a, b)
		if a[3] ~= b[3] then
			return a[3] < b[3]
		end
		return a[4] < b[4]
	end)
	return { found[1], found[2] }
end

function BuildOrder.new(sim: Sim.Sim): Driver
	local w = sim.world
	local layers = (sim.map :: any).layers :: Layers.Layers
	local driver: Driver = { sim = sim, players = {}, timeline = {} }
	for _, playerId in sim.playerOrder do
		local cv = 0
		for _, id in w.ids do
			if w.owner[id] == playerId then
				cv = id
			end
		end
		local team = sim.players[playerId].team
		local p = prefix(team)
		local x, z = w.posX[cv], w.posZ[cv]
		local toward = if x < 0 then 1 else -1 -- +1: map center is east
		local deposits = nearestDeposits(layers, x, z)
		driver.players[playerId] = {
			cv = cv,
			steps = {
				{ def = p .. "extractor", x = deposits[1][1], z = deposits[1][2], facing = 0 },
				{ def = p .. "extractor", x = deposits[2][1], z = deposits[2][2], facing = 0 },
				{ def = p .. "generator", x = x - 48 * toward, z = z - 16, facing = 0 }, -- (clear of the 2 × 2 deposit patches, S-184)
				{ def = p .. "generator", x = x - 48 * toward, z = z + 16, facing = 0 },
				{ def = p .. "vehplant", x = x + 64 * toward, z = z, facing = if toward > 0 then 1 else 3 },
			},
			next = 1,
			factory = 0,
			queued = false,
			produced = 0,
		}
	end
	return driver
end

-- Issues the next commands where a player is idle, then steps the sim and
-- records what happened.
function BuildOrder.tick(driver: Driver)
	local sim = driver.sim
	local w = sim.world
	local b = sim.build
	for _, playerId in sim.playerOrder do
		local p = driver.players[playerId]
		local cv = p.cv
		if w.slot[cv] == nil then
			continue
		end
		local busy = b.order[cv] ~= nil or (b.target[cv] or 0) ~= 0
		if not busy and p.next <= #p.steps then
			local step = p.steps[p.next]
			p.next += 1
			local g = (sim.map :: any).grid
			local cell, ox, oz = g:encode(step.x, step.z)
			submit(sim, playerId, {
				cmdType = CT.BUILD,
				flags = 0,
				unitIds = { cv },
				defIndex = sim.defs.units[step.def].index,
				cell = cell,
				offX = ox,
				offZ = oz,
				facing = step.facing,
			})
		elseif not busy and p.factory ~= 0 and not p.queued then
			p.queued = true
			local tank = prefix(sim.players[playerId].team) .. (if sim.players[playerId].team % 2 == 1 then "lancer" else "ravager")
			for _ = 1, 3 do
				submit(sim, playerId, {
					cmdType = CT.BUILD,
					flags = 0,
					unitIds = { p.factory },
					defIndex = sim.defs.units[tank].index,
					cell = 0,
					offX = 0,
					offZ = 0,
					facing = 0,
				})
			end
			submit(sim, playerId, { cmdType = CT.REPAIR, flags = 0, unitIds = { cv }, targetId = p.factory })
		end
	end

	Sim.step(sim)

	for _, e in sim.combat.events do
		local owner = w.owner[e.unit]
		if owner == nil then
			continue
		end
		local p = driver.players[owner]
		local what = sim.defs.unitByIndex[w.defIndex[e.unit]].id
		if e.kind == "BUILD_DONE" then
			table.insert(driver.timeline, { tick = sim.tick, player = owner, what = `built {what}` })
			if string.find(what, "vehplant", 1, true) then
				p.factory = e.unit
			end
		elseif e.kind == "PRODUCED" then
			p.produced += 1
			table.insert(driver.timeline, { tick = sim.tick, player = owner, what = `produced {what}` })
		elseif e.kind == "BUILD_FAILED" then
			table.insert(driver.timeline, { tick = sim.tick, player = owner, what = `FAILED {e.reason}` })
		end
	end
end

-- Runs until every player has `count` units out of its factory, or `limit` ticks.
function BuildOrder.run(sim: Sim.Sim, count: number, limit: number): Driver
	local driver = BuildOrder.new(sim)
	while sim.tick < limit do
		BuildOrder.tick(driver)
		local done = true
		for _, playerId in sim.playerOrder do
			done = done and driver.players[playerId].produced >= count
		end
		if done then
			break
		end
	end
	return driver
end

return BuildOrder
