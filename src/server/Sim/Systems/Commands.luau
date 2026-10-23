--!strict
-- System 1: apply the commands queued since the last tick (guide 3.3, 19).
--
-- Commands were decoded (structurally validated) by Sim.submit. Here each one
-- is recorded into the replay, then applied to the units the sender owns;
-- other unit IDs are skipped.
--
-- Effects: fire state, move state, toggle (factories: repeat on / off);
-- orders through Orders (S-4): MOVE, FIGHT, PATROL, ATTACK, GUARD,
-- ATTACK_GROUND, REPAIR, RECLAIM and mobile builders' BUILD replace a unit's
-- queue, or append to it with the queue flag; STOP clears it. Orders given
-- to a factory go on its order list for the units it produces (S-95); BUILD
-- given to a factory queues the unit. ATTACK and GUARD need a target the
-- sender's team knows.
--
-- Big orders are spread over ticks (S-100, next.md item 3): each tick
-- applies a player's commands, in the order they came, until UNITS_PER_TICK
-- of their unit IDs have gone; the rest wait in the queue, still in order,
-- for the next tick (a later command of that player waits behind them). A
-- select-all of 800 units, sent as four commands of 200, starts over four
-- ticks: the same as the four arriving a tick apart. Commands are recorded
-- in the replay on the tick they are applied, so replays match.
--
-- CHEAT commands (S-102) go to Sim/Cheats, recorded like any other.

local Schema = require("@shared/Net/Schema")
local Build = require("../Build")
local Cheats = require("../Cheats")
local Orders = require("../Orders")
local Sensors = require("../Sensors")
local Nav = require("../Nav")
local NetOut = require("../NetOut")
local Replay = require("../Replay")
local Types = require("../Types")
local World = require("../World")

local CT = Schema.CmdType
local bor, band, bnot = bit32.bor, bit32.band, bit32.bnot
local TOGGLED_ON = World.State.TOGGLED_ON
local LINE = Schema.CmdFlag.LINE
local QUEUE = Schema.CmdFlag.QUEUE
local GROUP = Schema.CmdFlag.GROUP

local Commands = {}
Commands.UNITS_PER_TICK = 200 -- unit IDs per player per tick (S-100)

local KIND_OF: { [number]: string } = { [CT.MOVE] = "move", [CT.FIGHT] = "fight", [CT.PATROL] = "patrol" }

local function ownedUnits(w: World.World, player: number, unitIds: { number }): { number }
	local out = {}
	for _, id in unitIds do
		if w.owner[id] == player then
			table.insert(out, id)
		end
	end
	return out
end

local function applyMove(sim: Types.Sim, player: number, cmd: Schema.Command)
	local nav = sim.nav
	if nav == nil then
		return
	end
	local g = nav.grid
	local cell = cmd.cell :: number
	if cell >= g.cellCount then
		return -- outside this map: ignore (the record itself was well-formed)
	end
	local units = ownedUnits(sim.world, player, cmd.unitIds)
	if #units == 0 then
		return
	end
	local x, z = g:decode(cell, cmd.offX :: number, cmd.offZ :: number)
	local lx, lz
	if band(cmd.flags, LINE) ~= 0 then
		local cell2 = cmd.cell2 :: number
		if cell2 >= g.cellCount then
			return
		end
		lx, lz = g:decode(cell2, cmd.offX2 :: number, cmd.offZ2 :: number)
	end
	local kind = KIND_OF[cmd.cmdType] :: any
	Orders.give(sim, units, { kind = kind, x = x, z = z, lx = lx, lz = lz, group = band(cmd.flags, GROUP) ~= 0 }, band(cmd.flags, QUEUE) ~= 0)
end

-- ATTACK / GUARD / REPAIR / RECLAIM: an order on a target. ATTACK needs a
-- unit the sender's team knows (a ghost too); GUARD and REPAIR an allied
-- live unit; RECLAIM a wreck.
local function applyTargeted(sim: Types.Sim, player: number, cmd: Schema.Command)
	local w = sim.world
	local units = ownedUnits(w, player, cmd.unitIds)
	if #units == 0 then
		return
	end
	local t = cmd.targetId :: number
	local ally = sim.players[player].allyTeam :: number
	local kind, gen
	if cmd.cmdType == CT.ATTACK then
		local kx, _, level = Sensors.knownTarget(sim, ally, t)
		if kx == nil or (w.slot[t] ~= nil and w.ally[t] == ally) then
			return -- unknown to the team, or an ally
		end
		kind = "attack"
		gen = if w.slot[t] ~= nil then w.gen[t] else nil
		if level == Sensors.Level.GHOST and w.slot[t] == nil then
			gen = sim.sensors.ghosts[ally][t].gen
		end
	elseif cmd.cmdType == CT.RECLAIM then
		if sim.combat.wreckX[t] == nil then
			return
		end
		kind = "reclaim"
	else
		if w.slot[t] == nil or w.ally[t] ~= ally then
			return
		end
		kind = if cmd.cmdType == CT.GUARD then "guard" else "repair"
		gen = w.gen[t]
	end
	Orders.give(sim, units, { kind = kind :: any, target = t, gen = gen }, band(cmd.flags, QUEUE) ~= 0)
end

local function applyBuild(sim: Types.Sim, player: number, cmd: Schema.Command)
	local w = sim.world
	local units = ownedUnits(w, player, cmd.unitIds)
	if #units == 0 or sim.map == nil then
		return
	end
	local g = (sim.map :: any).grid
	local cell = cmd.cell :: number
	if cell >= g.cellCount then
		return
	end
	local x, z = g:decode(cell, cmd.offX :: number, cmd.offZ :: number)
	-- factories queue the unit; mobile builders take a (queueable) build order
	local factories, builders = {}, {}
	for _, id in units do
		table.insert(if sim.defs.unitByIndex[w.defIndex[id]].domain == "structure" then factories else builders, id)
	end
	if #factories > 0 then
		Build.commandBuild(sim, factories, cmd.defIndex :: number, x, z, cmd.facing :: number)
	end
	if #builders > 0 then
		Orders.give(sim, builders, { kind = "build", x = x, z = z, defIndex = cmd.defIndex, facing = cmd.facing }, band(cmd.flags, QUEUE) ~= 0)
	end
end

local function apply(sim: Types.Sim, player: number, cmd: Schema.Command)
	local w = sim.world
	local cmdType = cmd.cmdType
	if KIND_OF[cmdType] then
		applyMove(sim, player, cmd)
		return
	elseif cmdType == CT.BUILD then
		applyBuild(sim, player, cmd)
		return
	elseif cmdType == CT.ATTACK or cmdType == CT.GUARD or cmdType == CT.REPAIR or cmdType == CT.RECLAIM then
		applyTargeted(sim, player, cmd)
		return
	elseif cmdType == CT.ATTACK_GROUND then
		local g = if sim.map then (sim.map :: any).grid else nil
		local cell = cmd.cell :: number
		if g == nil or cell >= g.cellCount then
			return
		end
		local x, z = g:decode(cell, cmd.offX :: number, cmd.offZ :: number)
		Orders.give(sim, ownedUnits(w, player, cmd.unitIds), { kind = "attackGround", x = x, z = z }, band(cmd.flags, QUEUE) ~= 0)
		return
	elseif cmdType == CT.CAMERA then
		NetOut.setCamera(sim, player, cmd.minX :: number, cmd.minZ :: number, cmd.maxX :: number, cmd.maxZ :: number)
		return
	elseif cmdType == CT.CHEAT then
		Cheats.apply(sim, player, cmd) -- (S-102) answered CHEATS_OFF unless the match allows them
		return
	end
	for _, id in cmd.unitIds do
		if w.owner[id] ~= player then
			continue -- dead, never existed, or someone else's
		end
		if cmdType == CT.SET_FIRE_STATE then
			World.setFireState(w, id, cmd.value :: number)
		elseif cmdType == CT.SET_MOVE_STATE then
			World.setMoveState(w, id, cmd.value :: number)
		elseif cmdType == CT.TOGGLE then
			local state = w.state[id]
			World.setState(w, id, if cmd.value == 1 then bor(state, TOGGLED_ON) else band(state, bnot(TOGGLED_ON)))
		elseif cmdType == CT.REPEAT then
			Orders.setRepeat(sim, id, cmd.value == 1) -- factories only (S-13)
		elseif cmdType == CT.CANCEL then
			-- an unfinished frame goes; a factory drops a queue item (S-35).
			-- An unfinished factory with a queue (S-138) drops queue items
			-- first: value 0 clears its queue, and the next CANCEL 0 the frame
			local q = sim.build.queue[id]
			if q ~= nil and #q > 0 then
				Build.cancelQueued(sim, id, cmd.value :: number)
			elseif not Build.cancelFrame(sim, id) then
				Build.cancelQueued(sim, id, cmd.value :: number)
			end
		elseif cmdType == CT.STOP then
			Orders.stopCommand(sim, id) -- (drops the manual target too, S-115)
		end
	end
end

function Commands.step(sim: Types.Sim)
	local queue = sim.queue
	local used: { [number]: number } = {} -- player → unit IDs applied this tick
	local waiting: { [number]: boolean } = {} -- player → a command of theirs waits: later ones too
	local keep = {}
	for _, q in queue do
		local n = #q.cmd.unitIds
		local u = used[q.player] or 0
		if waiting[q.player] or (u > 0 and u + n > Commands.UNITS_PER_TICK) then
			waiting[q.player] = true
			table.insert(keep, q) -- next tick (S-100)
			continue
		end
		used[q.player] = u + n
		Replay.addCommand(sim.replay, sim.tick, q.player, q.payload)
		apply(sim, q.player, q.cmd)
		sim.stats.commandsApplied += 1
	end
	table.clear(queue)
	table.move(keep, 1, #keep, 1, queue)
	Orders.step(sim) -- start and check every unit's head order
end

return Commands
