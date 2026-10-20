--!strict
-- A simple, deterministic skirmish AI (DECISIONS D90). It plays like a
-- player: it reads only what its ally team knows (Sensors), its own units,
-- its own economy and the map's start positions, and acts only through
-- commands (Sim.submit), so its games are recorded in the replay like any
-- other player's.
--
-- Every THINK_PERIOD ticks (offset by player ID) it:
--   1. Builders (the Command Vehicle stays home): a Vehicle Plant first;
--      generators when power runs short; extractors on the nearest free
--      deposits (home first, then expansions); a second plant when supply
--      piles up; otherwise assist a factory.
--   2. Factories keep QUEUE_TARGET items queued: workers until it has
--      WORKERS of them, then tanks with one artillery piece in four.
--   3. Army: idle new units gather at a rally point. Enemies near home are
--      attacked by everyone. When the army reaches the wave size, the wave
--      attack-moves at the nearest known enemy (structures and the Command
--      Vehicle first), or the enemy start if nothing is known; the next
--      wave is larger.
-- Its only randomness is its own Prng (seeded from the match seed and the
-- player ID), used for the production mix.

local Categories = require("@shared/Defs/Categories")
local Defs = require("@shared/Defs/Defs")
local Layers = require("@shared/Grid/Layers")
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Prng = require("@shared/Util/Prng")
local Schema = require("@shared/Net/Schema")
local Placement = require("../Placement")
local Sensors = require("../Sensors")
local Sim = require("../Sim")
local Types = require("../Types")

local Skirmish = {}

Skirmish.THINK_PERIOD = 15 -- ticks (1 s)
Skirmish.QUEUE_TARGET = 2
Skirmish.WORKERS = 3
Skirmish.FIRST_WAVE = 8
Skirmish.WAVE_GROWTH = 2
Skirmish.HOME_RADIUS = 260 -- studs: enemies inside it are attacked by everyone
Skirmish.CLAIM_TICKS = 900 -- a deposit someone was sent to stays reserved this long
Skirmish.SECOND_PLANT_SUPPLY = 600

local CT = Schema.CmdType
local BIT = Categories.Bit

export type Brain = {
	sim: Types.Sim,
	player: number,
	team: number,
	ally: number,
	prefix: string,
	rng: Prng.Prng,
	homeX: number,
	homeZ: number,
	enemyX: number,
	enemyZ: number,
	toward: number, -- +1 when the enemy start is east
	waveSize: number,
	attacking: { [number]: boolean }, -- units sent with a wave
	claims: { [number]: number }, -- cell → tick a builder was sent there
	deposits: { number }, -- deposit cells, nearest home first
	waves: number,
	lastWaveOrder: number, -- tick the wave was last sent at its target
}

local function submit(sim: Types.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, err = Sim.submit(sim, player, w:finish())
	assert(ok, err)
end

local function unitDef(sim: Types.Sim, id: number): Defs.UnitDef
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

-- Creates the AI for `player`. Needs a map with start positions.
function Skirmish.new(sim: Types.Sim, player: number): Brain
	local p = sim.players[player]
	local map = sim.map :: Passability.PassMap
	local layers = map.layers
	local w = sim.world
	local homeX, homeZ = 0, 0
	for _, id in w.ids do
		if w.owner[id] == player and bit32.band(unitDef(sim, id).categoryMask, BIT.COMMANDER) ~= 0 then
			homeX, homeZ = w.posX[id], w.posZ[id]
		end
	end
	-- the enemy start: the start position farthest from home
	local enemyX, enemyZ, far = homeX, homeZ, -1
	for _, s in layers.starts do
		local d = (s[1] - homeX) ^ 2 + (s[2] - homeZ) ^ 2
		if d > far then
			enemyX, enemyZ, far = s[1], s[2], d
		end
	end
	local g = map.grid
	local deposits = {}
	for i = 0, g.cellCount - 1 do
		if Layers.getSupply(layers, i) > 0 then
			table.insert(deposits, i)
		end
	end
	table.sort(deposits, function(a, b)
		local ax, az = g:cellCenter(g:coords(a))
		local bx, bz = g:cellCenter(g:coords(b))
		local da, db = (ax - homeX) ^ 2 + (az - homeZ) ^ 2, (bx - homeX) ^ 2 + (bz - homeZ) ^ 2
		if da ~= db then
			return da < db
		end
		return a < b
	end)
	return {
		sim = sim,
		player = player,
		team = p.team,
		ally = p.allyTeam :: number,
		prefix = if p.team % 2 == 1 then "ord_" else "chs_",
		rng = Prng.new((sim.seed * 31 + player * 7919) % 4294967296),
		homeX = homeX,
		homeZ = homeZ,
		enemyX = enemyX,
		enemyZ = enemyZ,
		toward = if enemyX >= homeX then 1 else -1,
		waveSize = Skirmish.FIRST_WAVE,
		attacking = {},
		claims = {},
		deposits = deposits,
		waves = 0,
		lastWaveOrder = -math.huge,
	}
end

local function faction(brain: Brain, order: string, chaos: string): string
	return brain.prefix .. (if brain.prefix == "ord_" then order else chaos)
end

local function build(brain: Brain, builder: number, defId: string, x: number, z: number, facing: number)
	local g = (brain.sim.map :: Passability.PassMap).grid
	local cell, ox, oz = g:encode(x, z)
	submit(brain.sim, brain.player, {
		cmdType = CT.BUILD,
		flags = 0,
		unitIds = { builder },
		defIndex = brain.sim.defs.units[defId].index,
		cell = cell,
		offX = ox,
		offZ = oz,
		facing = facing,
	})
end

-- A free spot for `defId` near home: positions on rings around the home
-- point, nearest first, that pass placement and nobody was sent to lately.
local function spotNear(brain: Brain, defId: string, cx: number, cz: number): (number?, number?)
	local sim = brain.sim
	local def = sim.defs.units[defId]
	local g = (sim.map :: Passability.PassMap).grid
	local step = 8 * def.footprint + 16
	for ring = 1, 8 do
		local n = ring * 8
		for k = 0, n - 1 do
			local a = k / n * 2 * math.pi
			local x, z = cx + math.cos(a) * ring * step, cz + math.sin(a) * ring * step
			local gx, gz = g:cellAt(x, z)
			if not g:inBounds(gx, gz) then
				continue
			end
			local cell = g:index(gx, gz)
			if (brain.claims[cell] or -math.huge) + Skirmish.CLAIM_TICKS < sim.tick and Placement.check(sim, def, x, z) then
				brain.claims[cell] = sim.tick
				return x, z
			end
		end
	end
	return nil, nil
end

-- The nearest deposit with nothing on it and nobody sent there lately.
local function freeDeposit(brain: Brain): number?
	local sim = brain.sim
	local pm = sim.map :: Passability.PassMap
	local def = sim.defs.units[faction(brain, "extractor", "extractor")]
	for _, cell in brain.deposits do
		if Passability.occupant(pm, cell) == 0 and (brain.claims[cell] or -math.huge) + Skirmish.CLAIM_TICKS < sim.tick then
			local x, z = pm.grid:cellCenter(pm.grid:coords(cell))
			if Placement.check(sim, def, x, z) then
				return cell
			end
		end
	end
	return nil
end

type Census = {
	commander: number,
	builders: { number },
	factories: { number },
	frames: number, -- factory frames under construction
	army: { number },
	workers: number,
}

local function census(brain: Brain): Census
	local sim = brain.sim
	local w = sim.world
	local c: Census = { commander = 0, builders = {}, factories = {}, frames = 0, army = {}, workers = 0 }
	for _, id in w.ids do
		if w.owner[id] ~= brain.player then
			continue
		end
		local d = unitDef(sim, id)
		if bit32.band(d.categoryMask, BIT.COMMANDER) ~= 0 then
			c.commander = id
		elseif d.domain == "structure" then
			if d.buildOptions then
				if w.buildProgress[id] >= 1 then
					table.insert(c.factories, id)
				else
					c.frames += 1
				end
			end
		elseif d.buildOptions then
			table.insert(c.builders, id)
			c.workers += 1
		elseif #d.weapons > 0 then
			table.insert(c.army, id)
		end
	end
	return c
end

local function idleBuilder(sim: Types.Sim, id: number): boolean
	local b = sim.build
	return b.order[id] == nil and (b.target[id] or 0) == 0 and (b.reclaim[id] or 0) == 0
end

local function think(brain: Brain)
	local sim = brain.sim
	local w = sim.world
	local c = census(brain)
	local acc = sim.eco.accounts[brain.team]
	local plant = faction(brain, "vehplant", "vehplant")

	-- 1. builders
	local workers = table.clone(c.builders)
	if c.commander ~= 0 then
		table.insert(workers, 1, c.commander)
	end
	local plantsWanted = if acc.supply.stored > Skirmish.SECOND_PLANT_SUPPLY then 2 else 1
	for _, id in workers do
		if not idleBuilder(sim, id) then
			continue
		end
		local isCommander = id == c.commander
		if #c.factories + c.frames < plantsWanted and #c.factories + c.frames < 2 then
			local x, z = spotNear(brain, plant, brain.homeX + brain.toward * 90, brain.homeZ)
			if x and z then
				build(brain, id, plant, x, z, if brain.toward > 0 then 1 else 3)
				c.frames += 1
				continue
			end
		end
		if acc.power.ratio < 0.95 or acc.power.income < 20 * #c.factories + 20 then
			local gen = faction(brain, "generator", "generator")
			local x, z = spotNear(brain, gen, brain.homeX - brain.toward * 60, brain.homeZ)
			if x and z then
				build(brain, id, gen, x, z, 0)
				continue
			end
		end
		local cell = freeDeposit(brain)
		if cell then
			local g = (sim.map :: Passability.PassMap).grid
			local x, z = g:cellCenter(g:coords(cell))
			-- the Command Vehicle only takes deposits near home
			if not isCommander or (x - brain.homeX) ^ 2 + (z - brain.homeZ) ^ 2 < Skirmish.HOME_RADIUS ^ 2 then
				brain.claims[cell] = sim.tick
				build(brain, id, faction(brain, "extractor", "extractor"), x, z, 0)
				continue
			end
		end
		if #c.factories > 0 then
			submit(sim, brain.player, { cmdType = CT.REPAIR, flags = 0, unitIds = { id }, targetId = c.factories[1] })
		end
	end

	-- 2. factories
	local tank = faction(brain, "lancer", "ravager")
	local arty = faction(brain, "verdict", "hellmouth")
	local worker = faction(brain, "mason", "scrapper")
	local queuedWorkers = 0
	for _, f in c.factories do
		for _, di in sim.build.queue[f] or {} do
			if sim.defs.unitByIndex[di].id == worker then
				queuedWorkers += 1
			end
		end
	end
	for _, f in c.factories do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, Skirmish.QUEUE_TARGET do
			local item
			if c.workers + queuedWorkers < Skirmish.WORKERS then
				item = worker
				queuedWorkers += 1
			else
				item = if brain.rng:chance(0.25) then arty else tank
			end
			submit(sim, brain.player, {
				cmdType = CT.BUILD,
				flags = 0,
				unitIds = { f },
				defIndex = sim.defs.units[item].index,
				cell = 0,
				offX = 0,
				offZ = 0,
				facing = 0,
			})
		end
	end

	-- 3. army
	local g = (sim.map :: Passability.PassMap).grid
	local function fight(ids: { number }, x: number, z: number)
		if #ids == 0 then
			return
		end
		local cell, ox, oz = g:encode(x, z)
		for i = 1, #ids, 200 do
			submit(sim, brain.player, {
				cmdType = CT.FIGHT,
				flags = 0,
				unitIds = table.move(ids, i, math.min(i + 199, #ids), 1, {}),
				cell = cell,
				offX = ox,
				offZ = oz,
			})
		end
	end
	-- known enemies: the nearest one near home, and the best attack target
	local threatX, threatZ, threatD = nil, nil, math.huge
	local targetX, targetZ, targetScore = nil, nil, math.huge
	for _, id in w.ids do
		if w.ally[id] == brain.ally then
			continue
		end
		local kx, kz = Sensors.knownPosition(sim, brain.ally, id)
		if kx and kz then
			local dh = (kx - brain.homeX) ^ 2 + (kz - brain.homeZ) ^ 2
			if dh < Skirmish.HOME_RADIUS ^ 2 and dh < threatD and w.slot[id] then
				threatX, threatZ, threatD = kx, kz, dh
			end
			local d = unitDef(sim, id)
			local important = d.domain == "structure" or bit32.band(d.categoryMask, BIT.COMMANDER) ~= 0
			local score = dh * (if important then 0.25 else 1)
			if score < targetScore then
				targetX, targetZ, targetScore = kx, kz, score
			end
		end
	end
	local home, wave = {}, {}
	local attacking: { [number]: boolean } = {} -- rebuilt from the living army
	for _, id in c.army do
		if brain.attacking[id] then
			attacking[id] = true
			table.insert(wave, id)
		else
			table.insert(home, id)
		end
	end
	brain.attacking = attacking
	local newWave = false
	if threatX and threatZ then
		fight(home, threatX, threatZ) -- defend
	elseif #home >= brain.waveSize then
		for _, id in home do
			brain.attacking[id] = true
			table.insert(wave, id)
		end
		home = {}
		newWave = true
		brain.waves += 1
		brain.waveSize += Skirmish.WAVE_GROWTH
	else
		local idle = {}
		for _, id in home do
			if w.orderId[id] == 0 then
				table.insert(idle, id)
			end
		end
		local rx, rz = brain.homeX + brain.toward * 160, brain.homeZ
		local cell, ox, oz = g:encode(rx, rz)
		local far = {}
		for _, id in idle do
			if (w.posX[id] - rx) ^ 2 + (w.posZ[id] - rz) ^ 2 > 60 ^ 2 then
				table.insert(far, id)
			end
		end
		if #far > 0 then
			submit(sim, brain.player, { cmdType = CT.MOVE, flags = 0, unitIds = far, cell = cell, offX = ox, offZ = oz })
		end
	end
	-- the wave re-targets every 5 s
	if #wave > 0 and (newWave or sim.tick - brain.lastWaveOrder >= Skirmish.THINK_PERIOD * 5) then
		brain.lastWaveOrder = sim.tick
		fight(wave, targetX or brain.enemyX, targetZ or brain.enemyZ)
	end
end

-- Call once per tick, before Sim.step.
function Skirmish.tick(brain: Brain)
	local sim = brain.sim
	if sim.match.eliminated[brain.player] or (sim.tick + brain.player) % Skirmish.THINK_PERIOD ~= 0 then
		return
	end
	think(brain)
end

return Skirmish
