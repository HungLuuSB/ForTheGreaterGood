--!strict
-- System 1: apply the commands queued since the last tick (guide 3.3, 19).
--
-- Commands were decoded (structurally validated) by Sim.submit. Here each one
-- is recorded into the replay, then applied to the units the sender owns;
-- other unit IDs are skipped.
--
-- Effects: fire state, move state, toggle; MOVE (plus FIGHT and PATROL, which
-- act as plain moves for now) and STOP when the sim has a map; BUILD (mobile
-- builders start structures, factories queue units), REPAIR (assist a frame
-- or a factory) and RECLAIM (wrecks). ATTACK and GUARD are recorded but have
-- no effect yet.

local Schema = require("@shared/Net/Schema")
local Build = require("../Build")
local Nav = require("../Nav")
local NetOut = require("../NetOut")
local Replay = require("../Replay")
local Types = require("../Types")
local World = require("../World")

local CT = Schema.CmdType
local bor, band, bnot = bit32.bor, bit32.band, bit32.bnot
local TOGGLED_ON = World.State.TOGGLED_ON
local LINE = Schema.CmdFlag.LINE

local MOVE_LIKE = {
	[CT.MOVE] = true,
	[CT.FIGHT] = true,
	[CT.PATROL] = true,
}

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
	Build.commandIdle(sim, units)
	local x, z = g:decode(cell, cmd.offX :: number, cmd.offZ :: number)
	local lx, lz
	if band(cmd.flags, LINE) ~= 0 then
		local cell2 = cmd.cell2 :: number
		if cell2 >= g.cellCount then
			return
		end
		lx, lz = g:decode(cell2, cmd.offX2 :: number, cmd.offZ2 :: number)
	end
	Nav.issueMove(nav, sim.world, sim.tick, units, x, z, lx, lz)
end

local function applyBuild(sim: Types.Sim, player: number, cmd: Schema.Command)
	local units = ownedUnits(sim.world, player, cmd.unitIds)
	if #units == 0 or sim.map == nil then
		return
	end
	local g = (sim.map :: any).grid
	local cell = cmd.cell :: number
	if cell >= g.cellCount then
		return
	end
	local x, z = g:decode(cell, cmd.offX :: number, cmd.offZ :: number)
	Build.commandBuild(sim, units, cmd.defIndex :: number, x, z, cmd.facing :: number)
end

local function apply(sim: Types.Sim, player: number, cmd: Schema.Command)
	local w = sim.world
	local cmdType = cmd.cmdType
	if MOVE_LIKE[cmdType] then
		applyMove(sim, player, cmd)
		return
	elseif cmdType == CT.BUILD then
		applyBuild(sim, player, cmd)
		return
	elseif cmdType == CT.REPAIR then
		Build.commandAssist(sim, ownedUnits(w, player, cmd.unitIds), cmd.targetId :: number)
		return
	elseif cmdType == CT.RECLAIM then
		Build.commandReclaim(sim, ownedUnits(w, player, cmd.unitIds), cmd.targetId :: number)
		return
	elseif cmdType == CT.CAMERA then
		NetOut.setCamera(sim, player, cmd.minX :: number, cmd.minZ :: number, cmd.maxX :: number, cmd.maxZ :: number)
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
		elseif cmdType == CT.STOP then
			Build.commandIdle(sim, { id })
			if sim.nav then
				Nav.clearOrder(sim.nav, w, id)
				-- hold where it stands
				w.goalX[id], w.goalZ[id] = w.posX[id], w.posZ[id]
			end
		end
	end
end

return function(sim: Types.Sim)
	local queue = sim.queue
	if #queue == 0 then
		return
	end
	for _, q in queue do
		Replay.addCommand(sim.replay, sim.tick, q.player, q.payload)
		apply(sim, q.player, q.cmd)
		sim.stats.commandsApplied += 1
	end
	table.clear(queue)
end
