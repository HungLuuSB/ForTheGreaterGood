--!strict
-- The pre-game (S-169, the user): with the match option startMode = "choose"
-- a match boots without units. Each player picks where its Commander will
-- start (START_POS, inside its side's start area: Shared/Match/StartAreas),
-- may queue builds for it (BUILD with no unit IDs; QUEUE appends, else it
-- replaces; STOP with no unit IDs clears), and says READY. Everyone sees
-- every pick. When every player is ready (or TIMEOUT has passed) a COUNTDOWN
-- of 5 s runs; anyone un-readying cancels it. Then the scenario places the
-- Commanders on the picks (unpicked players get their side's next free
-- suggestion), each Commander takes its queue as build orders, and the
-- match starts on that tick.
--
-- While the pre-game lasts only Commands and NetOut run (Sim.step); ticks
-- advance, and every pre-game command is an ordinary recorded command, so
-- replays rebuild the same picks. The skirmish AI picks and readies through
-- commands too (Skirmish.tick), since AI levels aren't in the replay.

local Schema = require("@shared/Net/Schema")
local StartAreas = require("@shared/Match/StartAreas")
local Nav = require("./Nav")
local Orders = require("./Orders")
local Types = require("./Types")

local Pregame = {}

Pregame.TIMEOUT = 90 * 15 -- ticks: then everyone counts as ready
Pregame.COUNTDOWN = 5 * 15 -- ticks
Pregame.SUGGESTION_RINGS = 6 -- rings of suggestions around a side's start

export type Build = { defIndex: number, x: number, z: number, facing: number }
export type State = {
	phase: "pick" | "countdown",
	deadline: number, -- tick
	countdownEnd: number?, -- tick the match starts on
	picks: { [number]: { number } }, -- player → { x, z }
	ready: { [number]: boolean },
	builds: { [number]: { Build } }, -- player → its Commander's queue
	sides: StartAreas.Sides,
	setup: (sim: Types.Sim) -> (), -- the scenario, run at the start
}

local CT = Schema.CmdType

-- The Commander def a player will get (faction by team parity, as
-- Scenarios.standard_start).
function Pregame.commanderDef(sim: Types.Sim, player: number): any
	return sim.defs.units[if sim.players[player].team % 2 == 1 then "ord_sovereign" else "chs_warlord"]
end

function Pregame.new(sim: Types.Sim, setup: (sim: Types.Sim) -> ()): State
	local map = sim.map
	if map == nil then
		error("Pregame: needs a map", 0)
	end
	return {
		phase = "pick",
		deadline = sim.tick + Pregame.TIMEOUT,
		countdownEnd = nil,
		picks = {},
		ready = {},
		builds = {},
		sides = StartAreas.sides(sim.allyTeams, #map.layers.starts),
		setup = setup,
	}
end

-- Can `player`'s Commander start at (x, z)? On the map, in its side's start
-- area, on ground it can stand on, and SPACING from the other picks
-- (`picks`, default the current ones).
function Pregame.validPick(sim: Types.Sim, player: number, x: number, z: number, picks: { [number]: { number } }?): boolean
	local pg = sim.pregame :: State
	local map = sim.map :: any
	local g = map.grid
	if not g:inBounds(g:cellAt(x, z)) then
		return false
	end
	if StartAreas.sideAt(pg.sides, map.layers.starts, x, z) ~= sim.players[player].allyTeam then
		return false
	end
	local nav = sim.nav :: Nav.Nav
	local p = nav.profiles[Pregame.commanderDef(sim, player).index]
	if p == nil or not Nav.fits(nav, p, x, z) then
		return false
	end
	return StartAreas.spaced(picks or pg.picks, player, x, z)
end

-- `player`'s suggested start: the first valid point among its side's
-- suggestions for its place in the side (by player ID), clear of `picks`.
function Pregame.suggest(sim: Types.Sim, player: number, picks: { [number]: { number } }?): (number?, number?)
	local pg = sim.pregame :: State
	local ally = sim.players[player].allyTeam :: number
	local k = 0
	for _, pid in sim.playerOrder do
		if sim.players[pid].allyTeam == ally then
			k += 1
		end
		if pid == player then
			break
		end
	end
	for _, pt in StartAreas.suggestions(pg.sides, (sim.map :: any).layers.starts, ally, k, Pregame.SUGGESTION_RINGS) do
		if Pregame.validPick(sim, player, pt[1], pt[2], picks) then
			return pt[1], pt[2]
		end
	end
	return nil, nil
end

-- A pre-game command (Commands): true when it was one (applied or refused).
-- Others (CAMERA, CHEAT) go on as usual; the rest is ignored.
function Pregame.command(sim: Types.Sim, player: number, cmd: Schema.Command): boolean
	local pg = sim.pregame :: State
	local t = cmd.cmdType
	if t == CT.CAMERA or t == CT.CHEAT then
		return false
	end
	local g = (sim.map :: any).grid
	if t == CT.START_POS then
		local cell = cmd.cell :: number
		if cell < g.cellCount then
			local x, z = g:decode(cell, cmd.offX :: number, cmd.offZ :: number)
			if Pregame.validPick(sim, player, x, z) then
				pg.picks[player] = { x, z }
			end
		end
	elseif t == CT.READY then
		pg.ready[player] = cmd.value == 1 or nil
	elseif t == CT.BUILD and #cmd.unitIds == 0 then
		local d = sim.defs.unitByIndex[cmd.defIndex :: number]
		local options = Pregame.commanderDef(sim, player).buildOptions
		local cell = cmd.cell :: number
		if d and options and table.find(options, d.id) and cell < g.cellCount then
			local list = if bit32.band(cmd.flags, Schema.CmdFlag.QUEUE) ~= 0 then pg.builds[player] or {} else {}
			if #list < Schema.PREBUILD_MAX then
				local x, z = g:decode(cell, cmd.offX :: number, cmd.offZ :: number)
				table.insert(list, { defIndex = d.index, x = x, z = z, facing = cmd.facing or 0 })
			end
			pg.builds[player] = list
		end
	elseif t == CT.STOP and #cmd.unitIds == 0 then
		pg.builds[player] = nil
	end
	return true
end

-- Places every Commander, hands over the queues and ends the pre-game.
local function start(sim: Types.Sim)
	local pg = sim.pregame :: State
	local positions: { [number]: { number } } = {}
	for pid, p in pg.picks do
		positions[pid] = p
	end
	for _, pid in sim.playerOrder do
		if positions[pid] == nil then
			local x, z = Pregame.suggest(sim, pid, positions)
			if x == nil or z == nil then
				local s = (sim.map :: any).layers.starts
				local own = pg.sides.startsOf[sim.players[pid].allyTeam :: number]
				x, z = s[own[1]][1], s[own[1]][2] -- (a crowded side: on its start)
			end
			positions[pid] = { x :: number, z :: number }
		end
	end
	sim.startPositions = positions
	sim.pregame = nil
	sim.match.startTick = sim.tick
	pg.setup(sim)
	-- each Commander takes its player's pre-game queue, in order
	local w = sim.world
	for _, pid in sim.playerOrder do
		local list = pg.builds[pid]
		if list and #list > 0 then
			for _, id in w.ids do
				if w.owner[id] == pid and table.find(sim.defs.unitByIndex[w.defIndex[id]].categories, "COMMANDER") then
					for k, b in list do
						Orders.give(sim, { id }, { kind = "build", x = b.x, z = b.z, defIndex = b.defIndex, facing = b.facing }, k > 1)
					end
					break
				end
			end
		end
	end
end

-- Seconds left in the countdown (5..1), or nil.
function Pregame.secondsLeft(sim: Types.Sim): number?
	local pg = sim.pregame
	if pg == nil or pg.phase ~= "countdown" then
		return nil
	end
	return math.max(1, math.ceil(((pg.countdownEnd :: number) - sim.tick) / 15))
end

-- After the tick's commands (Commands.step): the countdown and the start.
function Pregame.step(sim: Types.Sim)
	local pg = sim.pregame :: State
	local all = true
	for _, pid in sim.playerOrder do
		if not pg.ready[pid] then
			all = false
		end
	end
	if sim.tick >= pg.deadline then
		all = true -- the timeout: whoever isn't ready plays from their pick or suggestion
	end
	if pg.phase == "pick" and all then
		pg.phase = "countdown"
		pg.countdownEnd = sim.tick + Pregame.COUNTDOWN
	elseif pg.phase == "countdown" and not all then
		pg.phase = "pick"
		pg.countdownEnd = nil
	end
	if pg.phase == "countdown" and sim.tick >= (pg.countdownEnd :: number) then
		start(sim)
	end
end

return Pregame
