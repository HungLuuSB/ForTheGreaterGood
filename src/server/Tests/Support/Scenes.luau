--!strict
-- Ready-made matches for tooling and tests (lune run balance / export):
-- a sim plus a driver that issues commands each tick, like players would.
--
--   ai                          Order AI vs Chaos AI on skirmish:192 (D90)
--   matchup:<order>:<chaos>[:close|long]
--                               the balance report's equal-value fight (D89)
--   siege:<unit>                an equal-value group of <unit> against an
--                               enemy base (plant, 3 generators, radar tower)
--
-- Bomber groups bring their faction's T1 radar tower (D96): bombs need
-- radar contacts or ghosts to line up runs from beyond the bomber's sight,
-- as they would with a match's base radar. The tower is not part of the
-- trade, and attack-moves aim at enemy units, not at structures, when
-- there are any.
--   <Sim scenario name>         that scenario; every player's units
--                               attack-move at the enemy centroid every 2 s

local Air = require("../../Sim/Air")
local Categories = require("@shared/Defs/Categories")
local Defs = require("@shared/Defs/Defs")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Scenarios = require("../../Sim/Scenarios")
local Sim = require("../../Sim/Sim")
local Skirmish = require("../../Sim/AI/Skirmish")
local Spawn = require("../../Sim/Spawn")

local Scenes = {}

Scenes.BUDGET = 3000 -- matchup value per side
Scenes.MATCHUP_TICKS = 1800

export type Scene = {
	sim: Sim.Sim,
	drive: (Sim.Sim) -> (), -- call before every Sim.step
	done: (Sim.Sim) -> boolean,
	maxTicks: number,
	sides: { { number } }?, -- matchup: the two groups' unit IDs
}

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

function Scenes.value(d: Defs.UnitDef): number
	return d.cost.supply + d.cost.power / 10
end

local BIT = Categories.Bit
function Scenes.isCombat(d: Defs.UnitDef): boolean
	return d.domain ~= "structure" and #d.weapons > 0 and bit32.band(d.categoryMask, BIT.WORKER + BIT.COMMANDER) == 0
end

-- Each player's units attack-move at the centroid of everyone else's.
local function fightDriver(every: number): (Sim.Sim) -> ()
	return function(sim: Sim.Sim)
		if sim.tick % every ~= 0 then
			return
		end
		local w = sim.world
		local g = (sim.map :: any).grid
		for _, pid in sim.playerOrder do
			local mine, ex, ez, n = {}, 0, 0, 0
			local sx, sz, sn = 0, 0, 0 -- enemy structures: the goal only when no units are left
			for _, id in w.ids do
				local isStructure = sim.defs.unitByIndex[w.defIndex[id]].domain == "structure"
				if w.owner[id] == pid then
					if not isStructure then
						table.insert(mine, id)
					end
				elseif w.ally[id] ~= sim.players[pid].allyTeam then
					if isStructure then
						sx += w.posX[id]
						sz += w.posZ[id]
						sn += 1
					else
						ex += w.posX[id]
						ez += w.posZ[id]
						n += 1
					end
				end
			end
			if n == 0 then
				ex, ez, n = sx, sz, sn
			end
			if #mine > 0 and n > 0 then
				local cell, ox, oz = g:encode(ex / n, ez / n)
				for i = 1, #mine, 200 do
					submit(sim, pid, {
						cmdType = CT.FIGHT,
						flags = 0,
						unitIds = table.move(mine, i, math.min(i + 199, #mine), 1, {}),
						cell = cell,
						offX = ox,
						offZ = oz,
					})
				end
			end
		end
	end
end

-- Where each side's group stands for a matchup (map, centre x of each side).
local SHORE = -512 -- sea:256: land west of x = -512
function Scenes.layout(a: Defs.UnitDef, b: Defs.UnitDef, gap: number): (string, number, number)
	if a.domain ~= "naval" and b.domain ~= "naval" then
		return "flat:128", -gap / 2, gap / 2
	end
	if a.domain == "naval" and b.domain == "naval" then
		return "sea:256", -gap / 2, gap / 2
	end
	if a.domain == "naval" then
		return "sea:256", SHORE + 60 + gap, SHORE - 40
	end
	return "sea:256", SHORE - 40, SHORE + 60 + gap
end

local function spawnGroup(sim: Sim.Sim, d: Defs.UnitDef, owner: number, cx: number, facing: number): { number }
	local count = math.clamp(math.floor(Scenes.BUDGET / Scenes.value(d) + 0.5), 1, 20)
	local spacing = 8 * d.footprint + 6
	local ids = {}
	for i = 0, count - 1 do
		local row, col = i // 5, i % 5
		local x = cx + (if facing > 0 then -1 else 1) * row * spacing
		table.insert(ids, Spawn.unit(sim, d.id, owner, x, (col - 2) * spacing, facing))
	end
	if Air.isBomber(sim, d) then
		-- the team's radar, beside the group's start (outside the formation)
		Spawn.unit(sim, if d.faction == "order" then "ord_watchtower" else "chs_eye", owner, cx, -3 * spacing - 40)
	end
	return ids
end

function Scenes.matchup(aId: string, bId: string, kind: string, seed: number): Scene
	local defs = Defs.load()
	local a, b = defs.units[aId], defs.units[bId]
	assert(a and b, `Scenes.matchup: unknown unit {aId} or {bId}`)
	local gap = if kind == "close" then 120 else 600
	local mapId, xa, xb = Scenes.layout(a, b, gap)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = mapId })
	local sideA = spawnGroup(sim, a, 1, xa, math.pi / 2)
	local sideB = spawnGroup(sim, b, 2, xb, -math.pi / 2)
	local function alive(ids: { number }): number
		local n = 0
		for _, id in ids do
			if sim.world.slot[id] then
				n += 1
			end
		end
		return n
	end
	return {
		sim = sim,
		drive = fightDriver(30),
		done = function(s: Sim.Sim): boolean
			return alive(sideA) == 0 or alive(sideB) == 0
		end,
		maxTicks = Scenes.MATCHUP_TICKS,
		sides = { sideA, sideB },
	}
end

-- An equal-value group of `aId` attacks an enemy base of passive structures:
-- the balance report's "Structure" column (guide 12.4). Ships attack a
-- base on the beach from offshore.
function Scenes.siege(aId: string, seed: number): Scene
	local defs = Defs.load()
	local a = defs.units[aId]
	assert(a, `Scenes.siege: unknown unit {aId}`)
	local attacker = if a.faction == "order" then 1 else 2
	local enemy = 3 - attacker
	local p = if enemy == 1 then "ord_" else "chs_"
	local naval = a.domain == "naval"
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = if naval then "sea:256" else "flat:128" })
	local bx = if naval then SHORE - 90 else 250
	local ax = if naval then SHORE + 350 else -250
	local base = {
		Spawn.unit(sim, p .. "vehplant", enemy, bx, 0),
		Spawn.unit(sim, p .. "generator", enemy, bx - 50, -60),
		Spawn.unit(sim, p .. "generator", enemy, bx - 50, 60),
		Spawn.unit(sim, p .. "generator", enemy, bx + 50, -60),
		Spawn.unit(sim, p .. (if enemy == 1 then "watchtower" else "eye"), enemy, bx + 50, 60),
	}
	local group = spawnGroup(sim, a, attacker, ax, if ax < bx then math.pi / 2 else -math.pi / 2)
	local function alive(ids: { number }): number
		local n = 0
		for _, id in ids do
			if sim.world.slot[id] then
				n += 1
			end
		end
		return n
	end
	return {
		sim = sim,
		drive = fightDriver(30),
		done = function(_s: Sim.Sim): boolean
			return alive(base) == 0 or alive(group) == 0
		end,
		maxTicks = Scenes.MATCHUP_TICKS,
		sides = if attacker == 1 then { group, base } else { base, group },
	}
end

function Scenes.ai(seed: number, mapId: string?): Scene
	local sim = Sim.new({
		seed = seed,
		players = PLAYERS,
		mapId = mapId or "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
	local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
	return {
		sim = sim,
		drive = function(_s: Sim.Sim)
			for _, brain in brains do
				Skirmish.tick(brain)
			end
		end,
		done = function(s: Sim.Sim): boolean
			return s.match.over
		end,
		maxTicks = 27000,
	}
end

-- Any of the above by name (see the header). `mapId` overrides the map of
-- plain Sim scenarios (default flat:128).
function Scenes.byName(name: string, seed: number, mapId: string?): Scene
	if name == "ai" then
		return Scenes.ai(seed, mapId)
	end
	local besieger = string.match(name, "^siege:([%w_]+)$")
	if besieger then
		return Scenes.siege(besieger, seed)
	end
	local a, b, kind = string.match(name, "^matchup:([%w_]+):([%w_]+):?(%a*)$")
	if a and b then
		return Scenes.matchup(a, b, if kind == "long" then "long" else "close", seed)
	end
	if Scenarios[name] == nil then
		error(`Scenes: unknown scene "{name}" (ai, matchup:<a>:<b>[:close|long], or a Sim scenario)`, 2)
	end
	local players = PLAYERS
	if name == "match_test" then
		players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
	end
	local sim = Sim.new({ seed = seed, players = players, mapId = mapId or "flat:128", scenario = name })
	return {
		sim = sim,
		drive = fightDriver(30),
		done = function(_s: Sim.Sim): boolean
			return false
		end,
		maxTicks = 1800,
	}
end

return Scenes
