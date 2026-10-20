--!strict
-- System 1: apply the commands queued since the last tick (guide 3.3, 19).
--
-- Commands were decoded (structurally validated) by Sim.submit. Here each one
-- is recorded into the replay, then applied to the units the sender owns;
-- other unit IDs are skipped. Orders that need movement or combat (MOVE,
-- ATTACK, BUILD...) are accepted and recorded but have no effect until those
-- systems exist (M1–M3).

local Schema = require("@shared/Net/Schema")
local Replay = require("../Replay")
local Types = require("../Types")
local World = require("../World")

local CT = Schema.CmdType
local bor, band, bnot = bit32.bor, bit32.band, bit32.bnot
local TOGGLED_ON = World.State.TOGGLED_ON

local function apply(sim: Types.Sim, player: number, cmd: Schema.Command)
	local w = sim.world
	local cmdType = cmd.cmdType
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
