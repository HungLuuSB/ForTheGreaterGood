--!strict
-- Cheat / test commands (S-102; the user's request, 2026-10-23). A CHEAT
-- command is an ordinary command: queued, recorded in the replay and applied
-- by the Commands system in order, so replays repeat it exactly. It is
-- applied only when the match allows cheats (match option `cheats`, or the
-- Sim config's `cheats` for sandboxes); otherwise it is answered CHEATS_OFF
-- and does nothing. The first applied cheat marks the match: CheatsState
-- `used`, the replay header's `cheated`, Stats.series' `cheated` and each
-- player's Stats.report `cheats` count.
--
-- Every command is answered with a CHEAT_RESULT event to its sender (NetOut,
-- owner only): Schema.CheatResult and two counts. Team 0 is the sender's.
--   GIVE        finished units of `defIndex` around (x, z) in a square
--               formation; structures snap to the grid and skip cells where
--               Placement.check fails, mobile units cells they can't enter.
--               Owned by the sender, or by the lowest player ID on `team`.
--               No unit cap. Answer: placed of asked.
--   RES         a team's stored supply / power set to `amount` (CHEAT_MAX:
--               full); storage is raised to fit (a lasting bonus).
--   INCOME      a flat bonus per second to a team's supply / power, 0 clears.
--   INSTABUILD  every frame and factory item, every team's, finishes on its
--               next build step, free.
--   REVEAL      full sight (sight, air sight, sonar, radar) everywhere for
--               the team's ally team.
--   GOD         the sender's units take no damage (KILL still works).
--   KILL        the units listed (SELECTED: any owner), every unit of a team
--               (TEAM), or every unit within `radius` of (x, z) (AREA); they
--               self-destruct on this tick's Damage step, no wrecks.
--   SPEED       the sim speed the tick driver should run at (`speed` / 100,
--               0.25..8); only offline / in Studio (Sim config `offline`).
--               The sim itself never reads it.
--   AI          pause / resume the skirmish AI of every AI player on `team`
--               (Skirmish.tick skips paused players).

local Grid = require("@shared/Grid/Grid")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local Combat = require("./Combat/Combat")
local Placement = require("./Placement")
local Sensors = require("./Sensors")
local Spawn = require("./Spawn")
local Types = require("./Types")

local Cheats = {}

Cheats.MAX_GIVE = 100 -- units per GIVE
Cheats.MAX_AMOUNT = 10_000_000 -- RES / INCOME
Cheats.MIN_SPEED, Cheats.MAX_SPEED = 25, 800 -- SPEED, × 100
Cheats.MAX_RESULTS = 32 -- answers kept per player until NetOut sends them

local OP = Schema.CheatOp
local R = Schema.CheatResult
local RES = Schema.CheatResource

-- The lowest player ID on `team`, or nil.
local function playerOnTeam(sim: Types.Sim, team: number): number?
	for _, pid in sim.playerOrder do
		if sim.players[pid].team == team then
			return pid
		end
	end
	return nil
end

local function resources(arg: number): { "supply" | "power" }
	if arg == RES.SUPPLY then
		return { "supply" }
	elseif arg == RES.POWER then
		return { "power" }
	end
	return { "supply", "power" }
end

-- Spots of a square formation of `n` around (x, z), `spacing` apart, row by row.
local function formation(n: number, x: number, z: number, spacing: number): { { number } }
	local side = math.ceil(math.sqrt(n))
	local out = {}
	for i = 0, n - 1 do
		local col, row = i % side, i // side
		table.insert(out, { x + (col - (side - 1) / 2) * spacing, z + (row - (side - 1) / 2) * spacing })
	end
	return out
end

local function give(sim: Types.Sim, owner: number, cmd: Schema.Command): (number, number, number)
	local d = sim.defs.unitByIndex[cmd.defIndex :: number]
	local count = cmd.amount :: number
	if d == nil or count < 1 or count > Cheats.MAX_GIVE then
		return R.BAD_ARGS, 0, count
	end
	local pm = sim.map
	if pm == nil then
		return R.NO_MAP, 0, count
	end
	local structure = d.domain == "structure"
	local size = if structure then d.footprint * Grid.CELL_SIZE + Grid.CELL_SIZE else math.max(2 * Grid.CELL_SIZE, (d.footprint or 1) * Grid.CELL_SIZE + Grid.CELL_SIZE)
	local placed = 0
	for _, spot in formation(count, cmd.x :: number, cmd.z :: number, size) do
		local x, z = spot[1], spot[2]
		if structure then
			local ok, _, _, _, _, _, replaces = Placement.check(sim, d, x, z, owner)
			if not ok or replaces ~= 0 then
				continue
			end
		else
			local g = pm.grid
			local cx, cz = g:cellAt(x, z)
			if not g:inBounds(cx, cz) or (d.moveClass ~= nil and not Passability.canEnter(pm, d.moveClass, g:index(cx, cz))) then
				continue
			end
		end
		Spawn.unit(sim, d.id, owner, x, z, 0)
		placed += 1
	end
	return if placed == 0 then R.NO_ROOM else R.OK, placed, count
end

local function kill(sim: Types.Sim, ids: { number }): number
	local w = sim.world
	local s = sim.cheats
	local n = 0
	for _, id in ids do
		if w.slot[id] ~= nil and not s.killing[id] and w.health[id] > 0 then
			s.killing[id] = true
			Combat.queueDamage(sim.combat, id, w.health[id] * 4 + 1, 0) -- self-destruct: no wreck (as Match's)
			n += 1
		end
	end
	return n
end

-- Applies one CHEAT command from `player` and queues its answer.
function Cheats.apply(sim: Types.Sim, player: number, cmd: Schema.Command)
	local s = sim.cheats
	local op = cmd.cheatOp :: number
	local arg = cmd.cheatArg :: number
	local result, count, total = R.OK, 0, 0
	local team = if cmd.cheatTeam == 0 then sim.players[player].team else cmd.cheatTeam :: number
	local onTeam = playerOnTeam(sim, team)
	if not s.enabled then
		result = R.CHEATS_OFF
	elseif onTeam == nil and (op == OP.GIVE or op == OP.RES or op == OP.INCOME or op == OP.REVEAL or op == OP.AI or (op == OP.KILL and arg == Schema.CheatKill.TEAM)) then
		result = R.NO_TEAM
	elseif op == OP.GIVE then
		local owner = if team == sim.players[player].team then player else onTeam :: number
		result, count, total = give(sim, owner, cmd)
	elseif op == OP.RES or op == OP.INCOME then
		local amount = cmd.amount :: number
		if amount ~= Schema.CHEAT_MAX and amount > Cheats.MAX_AMOUNT or (op == OP.INCOME and amount == Schema.CHEAT_MAX) then
			result = R.BAD_ARGS
		else
			local acc = sim.eco.accounts[team]
			for _, kind in resources(arg) do
				local r = acc[kind]
				if op == OP.INCOME then
					r.bonusIncome = if amount > 0 then amount else nil
				elseif amount == Schema.CHEAT_MAX then
					r.stored = r.storage
				else
					if amount > r.storage then
						r.bonusStorage = (r.bonusStorage or 0) + amount - r.storage
						r.storage = amount
					end
					r.stored = amount
				end
				count = math.floor(if op == OP.RES then r.stored else amount)
			end
		end
	elseif op == OP.INSTABUILD then
		s.instabuild = arg == 1
	elseif op == OP.REVEAL then
		local ally = sim.allyOf[team]
		local on = arg == 1
		if (s.revealed[ally] or false) ~= on then
			s.revealed[ally] = on or nil
			Sensors.reveal(sim, ally, if on then 1 else -1)
		end
	elseif op == OP.GOD then
		s.god[player] = if arg == 1 then true else nil
	elseif op == OP.KILL then
		local w = sim.world
		local ids = {}
		if arg == Schema.CheatKill.SELECTED then
			ids = cmd.unitIds
		elseif arg == Schema.CheatKill.TEAM then
			for _, id in w.ids do
				if w.team[id] == team then
					table.insert(ids, id)
				end
			end
		elseif arg == Schema.CheatKill.AREA then
			local x, z, r = cmd.x :: number, cmd.z :: number, cmd.radius :: number
			for _, id in w.ids do
				local dx, dz = w.posX[id] - x, w.posZ[id] - z
				if dx * dx + dz * dz <= r * r then
					table.insert(ids, id)
				end
			end
		else
			result = R.BAD_ARGS
		end
		if result == R.OK then
			count = kill(sim, ids)
			total = count
		end
	elseif op == OP.SPEED then
		local v = cmd.amount :: number
		if not s.offline then
			result = R.NOT_OFFLINE
		elseif v < Cheats.MIN_SPEED or v > Cheats.MAX_SPEED then
			result = R.BAD_ARGS
		else
			s.speed = v / 100
			count = v
		end
	elseif op == OP.AI then
		local n = 0
		for _, pid in sim.playerOrder do
			if sim.players[pid].team == team and sim.match.ai[pid] then
				s.aiPaused[pid] = if arg == 1 then true else nil
				n += 1
			end
		end
		if n == 0 then
			result = R.NO_AI
		end
		count = n
	end
	if result == R.OK then
		s.used = true
		s.usedBy[player] = (s.usedBy[player] or 0) + 1
		sim.replay.header.cheated = true
		sim.statSeries.cheated = true
	end
	local q = s.results[player]
	if q == nil then
		q = {}
		s.results[player] = q
	end
	table.insert(q, { op = op, result = result, count = count, total = total })
	if #q > Cheats.MAX_RESULTS then
		table.remove(q, 1) -- nobody is draining them (a headless sim)
	end
end

-- The player's answers since the last call (NetOut), or nil.
function Cheats.drain(sim: Types.Sim, player: number): { Schema.Event }?
	local q = sim.cheats.results[player]
	if q == nil or #q == 0 then
		return nil
	end
	sim.cheats.results[player] = nil
	local out = {}
	for _, r in q do
		table.insert(out, { kind = Schema.EventKind.CHEAT_RESULT, cheatOp = r.op, cheatResult = r.result, count = r.count, total = r.total })
	end
	return out
end

return Cheats
