--!strict
-- The pre-game (S-169, S-171, S-174, the user): a match boots without units
-- (match option startMode "choose", which every match from the lobby uses;
-- "fixed" is left for headless tests and tools). Each player picks where
-- its Commander will start (START_POS, inside its side's spawn box:
-- Shared/Match/StartAreas, or the box the host drew in the lobby), may
-- switch faction while not ready (FACTION; its queue is cleared), may queue
-- builds for it (BUILD with no unit IDs; QUEUE appends, else it replaces;
-- STOP with no unit IDs clears), and says READY. Everyone sees every pick
-- and faction. After PICK_TIME, players who haven't picked get the best
-- free spot (they still say READY themselves). When everyone is ready the
-- match's host starts it (START; with no host it starts by itself); the
-- host may also force a start at any time (START 1), and after MAX_WAIT it
-- starts anyway. A COUNTDOWN of 3 s runs; anyone un-readying cancels it,
-- unless forced. Then the scenario places the Commanders on the picks; they
-- land for Schema.LANDING_TICKS (the client's star flare), taking no orders
-- (Commands holds them), and then take their queues as build orders.
--
-- The clocks (PICK_TIME, MAX_WAIT) start once every human player has loaded:
-- sent its first command (the client's CAMERA after WELCOME), or after
-- LOAD_WAIT (client-B's Studio run: 41 s of loading came out of the pick
-- time). Commands are recorded, so a replay starts them on the same tick.
--
-- The map's start positions are hints (S-171): the AI, and anyone who
-- didn't pick, takes its side's k-th hint as the side's k-th player; past
-- the hints (or with the hint taken), the best free spot in the box:
-- free deposits near it, open ground, close to the side's hints.
--
-- While the pre-game lasts only Commands and NetOut run (Sim.step); ticks
-- advance, and every pre-game command is an ordinary recorded command, so
-- replays rebuild the same picks. The skirmish AI picks and readies through
-- commands too (Skirmish.tick), since AI levels aren't in the replay.

local Layers = require("@shared/Grid/Layers")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local StartAreas = require("@shared/Match/StartAreas")
local Nav = require("./Nav")
local Orders = require("./Orders")
local Types = require("./Types")

local Pregame = {}

Pregame.PICK_TIME = 150 * 15 -- ticks: then the unpicked get a spot (S-174)
Pregame.MAX_WAIT = 300 * 15 -- ticks: then the match starts anyway, ready or not
Pregame.COUNTDOWN = 3 * 15 -- ticks
Pregame.WARN = 30 * 15 -- ticks before MAX_WAIT: PICK_CLOCK counts down to it
Pregame.LOAD_WAIT = 60 * 15 -- ticks: the clocks start then even if a human hasn't loaded
Pregame.SCAN_STEP = 16 -- studs between candidate spots in a box (bestSpot)
Pregame.DEPOSIT_RADIUS = 160 -- studs: deposits that count for a spot
Pregame.CLAIM_RADIUS = 100 -- studs: deposits this near another pick are taken

export type Build = { defIndex: number, x: number, z: number, facing: number }
export type State = {
	phase: "pick" | "countdown",
	loaded: { [number]: boolean }, -- players whose first command arrived
	begun: boolean, -- everyone loaded (or LOAD_WAIT): the clocks run
	loadUntil: number, -- tick the clocks start on at the latest
	deadline: number, -- tick the pick time ends on (math.huge until begun)
	autoPicked: boolean, -- the pick time is over: everyone has a spot
	maxWait: number, -- tick the match starts on, ready or not
	countdownEnd: number?, -- tick the match starts on
	forced: boolean, -- a forced countdown: un-readying doesn't cancel it
	host: number?, -- the player who starts the match; nil: it starts when everyone is ready
	picks: { [number]: { number } }, -- player → { x, z }
	ready: { [number]: boolean },
	builds: { [number]: { Build } }, -- player → its Commander's queue
	sides: StartAreas.Sides,
	boxes: { [number]: StartAreas.Box }, -- ally team → its spawn box
	deposits: { { number } }, -- { x, z } of every deposit cell (bestSpot)
	setup: (sim: Types.Sim) -> (), -- the scenario, run at the start
}

local CT = Schema.CmdType

-- The Commander def a player will get (its faction, as
-- Scenarios.standard_start).
function Pregame.commanderDef(sim: Types.Sim, player: number): any
	return sim.defs.units[if sim.players[player].faction == "order" then "ord_sovereign" else "chs_warlord"]
end

-- `host`: the match's host (nil: none); `startBoxes`: the lobby's boxes per
-- ally team as fractions of the map (Sim.new checked them).
function Pregame.new(sim: Types.Sim, setup: (sim: Types.Sim) -> (), host: number?, startBoxes: { [number]: { number } }?): State
	local map = sim.map
	if map == nil then
		error("Pregame: needs a map", 0)
	end
	local layers = map.layers
	local sides = StartAreas.sides(sim.allyTeams, #layers.starts)
	local g = map.grid
	local deposits = {}
	for i = 0, g.cellCount - 1 do
		if Layers.getSupply(layers, i) > 0 then
			table.insert(deposits, { g:cellCenter(g:coords(i)) })
		end
	end
	local bounds = StartAreas.bounds(g)
	local boxes = StartAreas.boxes(sides, layers.starts, bounds, layers.startBoxes)
	for ally, f in startBoxes or {} do
		local w, d = bounds[3] - bounds[1], bounds[4] - bounds[2]
		boxes[ally] = { bounds[1] + f[1] * w, bounds[2] + f[2] * d, bounds[1] + f[3] * w, bounds[2] + f[4] * d }
	end
	return {
		phase = "pick",
		loaded = {},
		begun = false,
		loadUntil = sim.tick + Pregame.LOAD_WAIT,
		deadline = math.huge,
		autoPicked = false,
		maxWait = math.huge,
		countdownEnd = nil,
		forced = false,
		host = host,
		picks = {},
		ready = {},
		builds = {},
		sides = sides,
		boxes = boxes,
		deposits = deposits,
		setup = setup,
	}
end

-- Can `player`'s Commander start at (x, z)? On the map, in its side's spawn
-- box, on ground it can stand on, and SPACING from the other picks
-- (`picks`, default the current ones).
function Pregame.validPick(sim: Types.Sim, player: number, x: number, z: number, picks: { [number]: { number } }?): boolean
	local pg = sim.pregame :: State
	local map = sim.map :: any
	local g = map.grid
	if not g:inBounds(g:cellAt(x, z)) then
		return false
	end
	if not StartAreas.inBox(pg.boxes[sim.players[player].allyTeam :: number], x, z) then
		return false
	end
	local nav = sim.nav :: Nav.Nav
	local p = nav.profiles[Pregame.commanderDef(sim, player).index]
	if p == nil or not Nav.fits(nav, p, x, z) then
		return false
	end
	return StartAreas.spaced(picks or pg.picks, player, x, z)
end

-- The spot the AI (or a player who never picked) takes (S-171): as the
-- k-th player of its side (by player ID) its side's k-th hint, when valid;
-- else the best valid spot in its box on a SCAN_STEP grid, by free
-- deposits within DEPOSIT_RADIUS (none within CLAIM_RADIUS of another pick)
-- × 10, open ground (the Commander's clearance, up to 6) × 2, less the
-- distance to the side's nearest hint / 16; the first best in scan order.
-- `picks` default the current ones. Nil when the box has no valid spot.
function Pregame.bestSpot(sim: Types.Sim, player: number, picks: { [number]: { number } }?): (number?, number?)
	local pg = sim.pregame :: State
	local taken = picks or pg.picks
	local ally = sim.players[player].allyTeam :: number
	local starts = (sim.map :: any).layers.starts
	local hints = pg.sides.startsOf[ally]
	local k = 0
	for _, pid in sim.playerOrder do
		if sim.players[pid].allyTeam == ally then
			k += 1
		end
		if pid == player then
			break
		end
	end
	local hint = hints[k]
	if hint and Pregame.validPick(sim, player, starts[hint][1], starts[hint][2], taken) then
		return starts[hint][1], starts[hint][2]
	end
	local box = pg.boxes[ally]
	local map = sim.map :: any
	local g = map.grid
	local moveClass = Pregame.commanderDef(sim, player).moveClass or "TRACKED"
	local step = Pregame.SCAN_STEP
	local r2, c2 = Pregame.DEPOSIT_RADIUS ^ 2, Pregame.CLAIM_RADIUS ^ 2
	-- deposits nobody's pick has claimed
	local free = {}
	for _, d in pg.deposits do
		local claimed = false
		for pid, p in taken do
			if pid ~= player and (p[1] - d[1]) ^ 2 + (p[2] - d[2]) ^ 2 < c2 then
				claimed = true
				break
			end
		end
		if not claimed then
			table.insert(free, d)
		end
	end
	local bestX, bestZ, bestScore = nil, nil, -math.huge
	local x = box[1] + step / 2
	while x <= box[3] do
		local z = box[2] + step / 2
		while z <= box[4] do
			if Pregame.validPick(sim, player, x, z, taken) then
				local n = 0
				for _, d in free do
					if (d[1] - x) ^ 2 + (d[2] - z) ^ 2 <= r2 then
						n += 1
					end
				end
				local near = math.huge
				for _, h in hints do
					near = math.min(near, math.sqrt((starts[h][1] - x) ^ 2 + (starts[h][2] - z) ^ 2))
				end
				local open = math.min(Passability.clearance(map, moveClass, g:index(g:cellAt(x, z))), 6)
				local score = n * 10 + open * 2 - near / 16
				if score > bestScore then
					bestX, bestZ, bestScore = x, z, score
				end
			end
			z += step
		end
		x += step
	end
	return bestX, bestZ
end

local function allReady(sim: Types.Sim): boolean
	local pg = sim.pregame :: State
	for _, pid in sim.playerOrder do
		if not pg.ready[pid] then
			return false
		end
	end
	return true
end
Pregame.allReady = allReady

local function countdown(sim: Types.Sim, forced: boolean)
	local pg = sim.pregame :: State
	pg.phase = "countdown"
	pg.forced = forced
	pg.countdownEnd = sim.tick + Pregame.COUNTDOWN
end

-- Every unpicked player's spot when the pick time ends (in player order).
local function autoPick(sim: Types.Sim)
	local pg = sim.pregame :: State
	for _, pid in sim.playerOrder do
		if pg.picks[pid] == nil then
			local x, z = Pregame.bestSpot(sim, pid)
			if x and z then
				pg.picks[pid] = { x, z }
			end
		end
	end
	pg.autoPicked = true
end

-- A pre-game command (Commands): true when it was one (applied or refused).
-- Others (CAMERA, CHEAT) go on as usual; the rest is ignored.
function Pregame.command(sim: Types.Sim, player: number, cmd: Schema.Command): boolean
	local pg = sim.pregame :: State
	pg.loaded[player] = true
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
	elseif t == CT.FACTION then
		if not pg.ready[player] and pg.phase == "pick" then
			local p = sim.players[player]
			local faction: Types.Faction = if cmd.value == 0 then "order" else "chaos"
			if p.faction ~= faction then
				p.faction = faction
				pg.builds[player] = nil -- the other Commander builds other things
				local pick = pg.picks[player]
				if pick then
					pg.picks[player] = nil
					if Pregame.validPick(sim, player, pick[1], pick[2]) then
						pg.picks[player] = pick
					end
				end
			end
		end
	elseif t == CT.START then
		if player == pg.host and pg.phase == "pick" then
			if cmd.value == 1 then
				countdown(sim, true)
			elseif allReady(sim) then
				countdown(sim, false)
			end
		end
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
			local x, z = Pregame.bestSpot(sim, pid, positions)
			if x == nil or z == nil then
				local s = (sim.map :: any).layers.starts
				local own = pg.sides.startsOf[sim.players[pid].allyTeam :: number]
				x, z = s[own[1]][1], s[own[1]][2] -- (a box with no valid spot left: on its first hint)
			end
			positions[pid] = { x :: number, z :: number }
		end
	end
	sim.startPositions = positions
	sim.pregame = nil
	sim.match.startTick = sim.tick
	pg.setup(sim)
	sim.landing = { untilTick = sim.tick + Schema.LANDING_TICKS, builds = pg.builds }
end

-- When the landing is over (Commands, before the tick's commands): each
-- Commander takes its player's pre-game queue, in order.
function Pregame.land(sim: Types.Sim)
	local landing = sim.landing :: Types.Landing
	sim.landing = nil
	local w = sim.world
	for _, pid in sim.playerOrder do
		local list = landing.builds[pid]
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

-- Seconds left in the countdown (3..1), or nil.
function Pregame.secondsLeft(sim: Types.Sim): number?
	local pg = sim.pregame
	if pg == nil or pg.phase ~= "countdown" then
		return nil
	end
	return math.max(1, math.ceil(((pg.countdownEnd :: number) - sim.tick) / 15))
end

-- What PICK_CLOCK shows: seconds (of pick time, or to the forced start
-- once MAX_WAIT is near) and Schema.PickClockFlag bits.
function Pregame.clock(sim: Types.Sim): (number, number)
	local pg = sim.pregame :: State
	local flags = if allReady(sim) then Schema.PickClockFlag.ALL_READY else 0
	if not pg.begun then
		return Pregame.PICK_TIME // 15, flags + Schema.PickClockFlag.LOADING
	end
	if pg.phase == "pick" and sim.tick >= pg.maxWait - Pregame.WARN then
		return math.max(0, math.ceil((pg.maxWait - sim.tick) / 15)), flags + Schema.PickClockFlag.MAX_WAIT
	end
	return math.max(0, math.ceil((pg.deadline - sim.tick) / 15)), flags
end

-- After the tick's commands (Commands.step): the pick time, the countdown
-- and the start.
function Pregame.step(sim: Types.Sim)
	local pg = sim.pregame :: State
	if not pg.begun then
		local all = true
		for _, pid in sim.playerOrder do
			if not sim.match.ai[pid] and not pg.loaded[pid] then
				all = false
			end
		end
		if all or sim.tick >= pg.loadUntil then
			pg.begun = true
			pg.deadline = sim.tick + Pregame.PICK_TIME
			pg.maxWait = sim.tick + Pregame.MAX_WAIT
		end
	end
	if not pg.autoPicked and sim.tick >= pg.deadline then
		autoPick(sim)
	end
	local all = allReady(sim)
	if pg.phase == "pick" then
		if sim.tick >= pg.maxWait then
			countdown(sim, true) -- waited long enough
		elseif all and pg.host == nil then
			countdown(sim, false)
		end
	elseif pg.phase == "countdown" and not all and not pg.forced then
		pg.phase = "pick"
		pg.countdownEnd = nil
	end
	if pg.phase == "countdown" and sim.tick >= (pg.countdownEnd :: number) then
		start(sim)
	end
end

return Pregame
