--!strict
-- A simple, deterministic skirmish AI (DECISIONS D90). It plays like a
-- player: it reads only what its ally team knows (Sensors), its own units,
-- its own economy and the map's start positions, and acts only through
-- commands (Sim.submit), so its games are recorded in the replay like any
-- other player's. Build sites are planned with the team's knowledge
-- (Placement.check with `knower`); enemy types are known only for VISIBLE
-- units and ghosts, never for radar blips (D101).
--
-- Every THINK_PERIOD ticks (players spread over the period) it:
--   1. Builders (the Command Vehicle stays home): a Vehicle Plant first;
--      generators when power runs short; extractors on the nearest free
--      deposits (home first, then expansions); a radar tower once the plant
--      and two extractors stand; an IR SAM site when enemy aircraft come
--      near home; an Advanced Vehicle Plant once supply piles up (S-7); a
--      second plant when supply piles up; otherwise assist a factory frame,
--      or a factory.
--   2. Factories keep QUEUE_TARGET items queued. Vehicle Plant: workers
--      until it has WORKERS of them; IR SAM trucks while it has fewer than
--      one per two enemy aircraft its team knows (at most MAX_AA); one
--      mobile radar; then tanks with one artillery piece in four. Advanced
--      plant: one mobile fire-control radar, then MLRS and main battle
--      tanks.
--   3. Army: idle new units gather at a rally point. Enemies near home are
--      attacked by everyone. When the army reaches the wave size, the wave
--      attack-moves at the nearest known enemy (structures and the Command
--      Vehicle first), or the enemy start if nothing is known; the next
--      wave is larger. Radar and fire-control vehicles guard the wave, so
--      its artillery can fire on radar contacts with tracking (S-7).
--      Artillery kites: a known enemy inside KITE_RANGE of its range makes
--      it back off, then rejoin the wave's attack.
-- Its only randomness is its own Prng (seeded from the match seed and the
-- player ID), used for the production mix.
--
-- Levels (S-17; a match option, `match.ai = { [player] = level }`):
--   easy    thinks every 2 s, 2 workers, one item queued per factory, at
--           most 6 extractors, one plant, no radar, anti-air, tech-up or
--           kiting; attacks early with small waves (6, growing by 2).
--   normal  everything above (the default).
--   hard    thinks every 2/3 s; expands only to deposits nearer its own
--           start than any enemy start, escorting workers to the far ones;
--           waits for bigger waves (12, growing by 4) that go for the enemy
--           Command Vehicle first; from 5 extractors and 4 army units,
--           gun turrets (two on the way home, one more per two far
--           extractors); once 6 extractors and 6 army units stand, an
--           airfield (helicopters and bombers; fighters against known
--           aircraft) and, when a sea is near, a shipyard whose fleet
--           attacks on its own.

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
local World = require("../World")

local Skirmish = {}

Skirmish.THINK_PERIOD = 15 -- ticks (1 s)
Skirmish.QUEUE_TARGET = 2
Skirmish.WORKERS = 3
Skirmish.FIRST_WAVE = 8
Skirmish.WAVE_GROWTH = 2
Skirmish.HOME_RADIUS = 260 -- studs: enemies inside it are attacked by everyone
Skirmish.CLAIM_TICKS = 900 -- a deposit someone was sent to stays reserved this long
Skirmish.SECOND_PLANT_SUPPLY = 600
Skirmish.ADV_PLANT_SUPPLY = 900 -- supply stored before the Advanced Vehicle Plant (S-7)
Skirmish.MAX_AA = 4 -- IR SAM trucks wanted at most
Skirmish.KITE_RANGE = 0.5 -- of its range: artillery backs off from enemies closer than this
Skirmish.KITE_STEP = 100 -- studs it backs off
Skirmish.KITE_TICKS = 45 -- how long a kiting unit is left out of wave orders
Skirmish.FLEET_SIZE = 4 -- ships gathered before the fleet attacks (hard)
Skirmish.MAX_TURRETS = 6
Skirmish.ESCORT_RADIUS = 160 -- studs: workers sent to deposits farther from home get an escort (hard)

export type Level = {
	think: number, -- ticks between thinks
	workers: number,
	queue: number, -- items kept queued per factory
	firstWave: number,
	waveGrowth: number,
	maxExtractors: number,
	secondPlant: boolean,
	secondPlantSupply: number, -- supply stored before the second plant
	secondPlantExtractors: number, -- and extractors standing
	techUp: boolean, -- Advanced Vehicle Plant
	kite: boolean,
	antiAir: boolean, -- IR SAM trucks and sites against known aircraft
	radar: boolean, -- radar tower and mobile radar
	artyChance: number, -- share of artillery in plant production
	defenses: number, -- gun turrets at home (0 = none)
	escorts: number, -- army units guarding a worker sent to a far deposit
	air: boolean, -- an airfield
	naval: boolean, -- a shipyard when a sea is near
	safeExpansion: boolean, -- claims only deposits nearer its start than any enemy start
	hunt: boolean, -- waves go for the enemy Command Vehicle first (it ends the match)
}

Skirmish.LEVELS = table.freeze({
	easy = {
		think = 30,
		workers = 2,
		queue = 1,
		firstWave = 6,
		waveGrowth = 2,
		maxExtractors = 6,
		secondPlant = false,
		secondPlantSupply = math.huge,
		secondPlantExtractors = 0,
		techUp = false,
		kite = false,
		antiAir = false,
		radar = false,
		artyChance = 0.15,
		defenses = 0,
		escorts = 0,
		air = false,
		naval = false,
		safeExpansion = false,
		hunt = false,
	},
	normal = {
		think = Skirmish.THINK_PERIOD,
		workers = Skirmish.WORKERS,
		queue = Skirmish.QUEUE_TARGET,
		firstWave = Skirmish.FIRST_WAVE,
		waveGrowth = Skirmish.WAVE_GROWTH,
		maxExtractors = math.huge,
		secondPlant = true,
		secondPlantSupply = Skirmish.SECOND_PLANT_SUPPLY,
		secondPlantExtractors = 0,
		techUp = true,
		kite = true,
		antiAir = true,
		radar = true,
		artyChance = 0.25,
		defenses = 0,
		escorts = 0,
		air = false,
		naval = false,
		safeExpansion = false,
		hunt = false,
	},
	hard = {
		think = 10,
		workers = Skirmish.WORKERS,
		queue = 2,
		firstWave = 12,
		waveGrowth = 4,
		maxExtractors = math.huge,
		secondPlant = true,
		secondPlantSupply = Skirmish.SECOND_PLANT_SUPPLY,
		secondPlantExtractors = 0,
		techUp = true,
		kite = true,
		antiAir = true,
		radar = true,
		artyChance = 0.25,
		defenses = 2,
		escorts = 3,
		air = true,
		naval = true,
		safeExpansion = true,
		hunt = true,
	},
} :: { [string]: Level })

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
	kiting: { [number]: number }, -- unit → tick it last backed off (S-7)
	level: string, -- "easy" | "normal" | "hard" (S-17)
	cfg: Level,
	dirX: number, -- unit vector from home toward the enemy start
	dirZ: number,
	escorts: { [number]: number }, -- army unit → the worker it guards (hard)
	escortWanted: { [number]: number }, -- workers on their way to a far deposit → tick sent; waiting for an escort
	seaX: number?, -- a navigable sea spot near home (hard, naval maps)
	seaZ: number?,
	lastFleetOrder: number,
	lastFarX: number?, -- the last far deposit a worker was sent to (hard: turrets go there)
	lastFarZ: number?,
	thinkOffset: number, -- ticks into the think period this player thinks at
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

-- Creates the AI for `player` at `level` (default: the match's `ai` option
-- for the player, else "normal"). Needs a map with start positions.
function Skirmish.new(sim: Types.Sim, player: number, level: string?): Brain
	local levelName = level or sim.match.ai[player] or "normal"
	local cfg = Skirmish.LEVELS[levelName]
	assert(cfg, `Skirmish.new: unknown level {levelName}`)
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
	-- deposits it may claim: all but those (within a cell) equally near its
	-- own start and an enemy start. On a mirrored map those would be a race
	-- that unit IDs and player order decide, not play (S-17); armies fight
	-- over them.
	local enemyStarts = {}
	for _, s in layers.starts do
		local near = (s[1] - homeX) ^ 2 + (s[2] - homeZ) ^ 2 < 1
		if not near then
			table.insert(enemyStarts, s)
		end
	end
	local deposits = {}
	for i = 0, g.cellCount - 1 do
		if Layers.getSupply(layers, i) > 0 then
			local x, z = g:cellCenter(g:coords(i))
			local own = math.sqrt((x - homeX) ^ 2 + (z - homeZ) ^ 2)
			local mine = true
			for _, s in enemyStarts do
				local theirs = math.sqrt((x - s[1]) ^ 2 + (z - s[2]) ^ 2)
				if math.abs(theirs - own) < 8 or (cfg.safeExpansion and theirs < own) then
					mine = false
				end
			end
			if mine then
				table.insert(deposits, i)
			end
		end
	end
	-- nearest home first; ties go to the one farther from the enemy start
	-- (safer, and the same choice for both starts of a mirrored map, S-17),
	-- then the lower cell
	table.sort(deposits, function(a, b)
		local ax, az = g:cellCenter(g:coords(a))
		local bx, bz = g:cellCenter(g:coords(b))
		local da, db = (ax - homeX) ^ 2 + (az - homeZ) ^ 2, (bx - homeX) ^ 2 + (bz - homeZ) ^ 2
		if da ~= db then
			return da < db
		end
		local ea, eb = (ax - enemyX) ^ 2 + (az - enemyZ) ^ 2, (bx - enemyX) ^ 2 + (bz - enemyZ) ^ 2
		if ea ~= eb then
			return ea > eb
		end
		return a < b
	end)
	local dl = math.max(math.sqrt((enemyX - homeX) ^ 2 + (enemyZ - homeZ) ^ 2), 1)
	-- hard, naval: the nearest deep, open water within 64 cells (room for
	-- footprint-3 ships)
	local seaX, seaZ = nil, nil
	if cfg.naval then
		local ships = map.clearance.SHIP
		local hx, hz = g:cellAt(homeX, homeZ)
		local best = 64 * 64
		for cz = math.max(0, hz - 64), math.min(g.cellsZ - 1, hz + 64) do
			for cx = math.max(0, hx - 64), math.min(g.cellsX - 1, hx + 64) do
				local d = (cx - hx) ^ 2 + (cz - hz) ^ 2
				if d < best and buffer.readu8(ships, g:index(cx, cz)) >= 4 then
					best = d
					seaX, seaZ = g:cellCenter(cx, cz)
				end
			end
		end
	end
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
		waveSize = cfg.firstWave,
		attacking = {},
		claims = {},
		deposits = deposits,
		waves = 0,
		lastWaveOrder = -math.huge,
		kiting = {},
		level = levelName,
		cfg = cfg,
		dirX = (enemyX - homeX) / dl,
		dirZ = (enemyZ - homeZ) / dl,
		escorts = {},
		escortWanted = {},
		seaX = seaX,
		seaZ = seaZ,
		lastFleetOrder = -math.huge,
		-- players spread evenly over the think period: with `tick + player`
		-- the higher player always thought a tick earlier and won every race
		-- for a contested deposit (S-17)
		thinkOffset = ((table.find(sim.playerOrder, player) :: number) - 1) * cfg.think // #sim.playerOrder,
	}
end

-- A brain for every player the match's `ai` option names, in player order.
function Skirmish.forMatch(sim: Types.Sim): { Brain }
	local brains = {}
	for _, pid in sim.playerOrder do
		if sim.match.ai[pid] then
			table.insert(brains, Skirmish.new(sim, pid))
		end
	end
	return brains
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
-- Each ring is swept from the enemy's side, mirrored by `toward`, so the two
-- starts of a mirrored map build mirrored bases (S-17: sweeping from +x for
-- both gave the east start a different, safer base).
local function spotNear(brain: Brain, defId: string, cx: number, cz: number): (number?, number?)
	local sim = brain.sim
	local def = sim.defs.units[defId]
	local g = (sim.map :: Passability.PassMap).grid
	local step = 8 * def.footprint + 16
	for ring = 1, 8 do
		local n = ring * 8
		for k = 0, n - 1 do
			local a = k / n * 2 * math.pi
			local x, z = cx + brain.toward * math.cos(a) * ring * step, cz + math.sin(a) * ring * step
			local gx, gz = g:cellAt(x, z)
			if not g:inBounds(gx, gz) then
				continue
			end
			local cell = g:index(gx, gz)
			if (brain.claims[cell] or -math.huge) + Skirmish.CLAIM_TICKS < sim.tick and Placement.check(sim, def, x, z, nil, brain.ally) then
				brain.claims[cell] = sim.tick
				return x, z
			end
		end
	end
	return nil, nil
end

-- The nearest deposit with nothing on it, as far as the team knows, and
-- nobody sent there lately.
function Skirmish.freeDeposit(brain: Brain): number?
	local sim = brain.sim
	local pm = sim.map :: Passability.PassMap
	local def = sim.defs.units[faction(brain, "extractor", "extractor")]
	for _, cell in brain.deposits do
		if (brain.claims[cell] or -math.huge) + Skirmish.CLAIM_TICKS < sim.tick then
			local x, z = pm.grid:cellCenter(pm.grid:coords(cell))
			if Placement.check(sim, def, x, z, nil, brain.ally) then
				return cell
			end
		end
	end
	return nil
end
local freeDeposit = Skirmish.freeDeposit

-- Known enemies (D101): the nearest one near home (a threat), and the best
-- attack target, where structures and the Command Vehicle count four times
-- closer. Untracked radar blips have no known type (D107); remembered
-- structures count even if they died unseen. Returns threatX, threatZ, targetX, targetZ (nil when
-- none).
function Skirmish.knownTargets(brain: Brain): (number?, number?, number?, number?)
	local hunt = brain.cfg.hunt
	local sim = brain.sim
	local w = sim.world
	local L = Sensors.Level
	local threatX, threatZ, threatD = nil, nil, math.huge
	local targetX, targetZ, targetScore = nil, nil, math.huge
	local function consider(id: number, gen: number?)
		local kx, kz, level, defIndex = Sensors.knownTarget(sim, brain.ally, id, gen)
		if kx == nil or kz == nil then
			return
		end
		local dh = (kx - brain.homeX) ^ 2 + (kz - brain.homeZ) ^ 2
		if dh < Skirmish.HOME_RADIUS ^ 2 and dh < threatD then
			threatX, threatZ, threatD = kx, kz, dh
		end
		local important, commander = false, false
		if Sensors.typeKnown(sim, brain.ally, id, level) then -- visible, remembered or tracked (D107)
			local d = sim.defs.unitByIndex[defIndex :: number]
			commander = bit32.band(d.categoryMask, BIT.COMMANDER) ~= 0
			important = d.domain == "structure" or commander
		end
		local score = dh * (if hunt and commander then 0.02 elseif important then 0.25 else 1)
		if score < targetScore then
			targetX, targetZ, targetScore = kx, kz, score
		end
	end
	for _, id in w.ids do
		if w.ally[id] ~= brain.ally then
			consider(id)
		end
	end
	for _, gid in sim.sensors.ghostIds[brain.ally] or {} do
		local ghost = sim.sensors.ghosts[brain.ally][gid]
		if not World.isRef(w, gid, ghost.gen) then
			consider(gid, ghost.gen)
		end
	end
	return threatX, threatZ, targetX, targetZ
end

type Census = {
	commander: number,
	builders: { number },
	factories: { number }, -- complete Vehicle Plants
	advFactories: { number }, -- complete Advanced Vehicle Plants
	frames: number, -- Vehicle Plant frames under construction
	advFrames: { number }, -- Advanced Vehicle Plant frames
	extractors: number,
	radarTowers: number, -- radar towers, frames included
	samSites: number, -- IR SAM sites, frames included
	army: { number },
	aa: number, -- IR SAM trucks
	radarTrucks: { number }, -- mobile radars
	trackers: { number }, -- mobile fire-control radars
	workers: number,
	enemyAir: number, -- enemy aircraft the team knows (any detection: radar reveals the domain, D107)
	enemyAirNearHome: number,
	turrets: number, -- gun turrets, frames included (hard)
	farExtractors: number, -- extractors outside HOME_RADIUS
	airfields: { number }, -- complete airfields (hard)
	airFrames: number,
	shipyards: { number }, -- complete shipyards (hard)
	shipFrames: number,
	fleet: { number }, -- armed ships and submarines
	fighters: number, -- own anti-air aircraft
}

local function census(brain: Brain): Census
	local sim = brain.sim
	local w = sim.world
	local c: Census = {
		commander = 0,
		builders = {},
		factories = {},
		advFactories = {},
		frames = 0,
		advFrames = {},
		extractors = 0,
		radarTowers = 0,
		samSites = 0,
		army = {},
		aa = 0,
		radarTrucks = {},
		trackers = {},
		workers = 0,
		enemyAir = 0,
		enemyAirNearHome = 0,
		turrets = 0,
		farExtractors = 0,
		airfields = {},
		airFrames = 0,
		shipyards = {},
		shipFrames = 0,
		fleet = {},
		fighters = 0,
	}
	local advPlant = faction(brain, "advvehplant", "advvehplant")
	local airfield = faction(brain, "airfield", "airfield")
	local shipyard = faction(brain, "shipyard", "shipyard")
	local nearHome = (Skirmish.HOME_RADIUS * 1.5) ^ 2
	for _, id in w.ids do
		if w.owner[id] ~= brain.player then
			if w.ally[id] ~= brain.ally then
				local kx, kz, level, defIndex = Sensors.knownTarget(sim, brain.ally, id)
				if kx and kz and bit32.band(Sensors.knownCategories(sim, brain.ally, id, level, defIndex :: number), BIT.AIR) ~= 0 then
					c.enemyAir += 1
					if (kx - brain.homeX) ^ 2 + (kz - brain.homeZ) ^ 2 < nearHome then
						c.enemyAirNearHome += 1
					end
				end
			end
			continue
		end
		local d = unitDef(sim, id)
		local done = w.buildProgress[id] >= 1
		if bit32.band(d.categoryMask, BIT.COMMANDER) ~= 0 then
			c.commander = id
		elseif d.domain == "structure" then
			if d.buildOptions then
				if d.id == airfield or d.id == shipyard then
					if done then
						table.insert(if d.id == airfield then c.airfields else c.shipyards, id)
					elseif d.id == airfield then
						c.airFrames += 1
					else
						c.shipFrames += 1
					end
				elseif d.id == advPlant then
					if done then
						table.insert(c.advFactories, id)
					else
						table.insert(c.advFrames, id)
					end
				elseif done then
					table.insert(c.factories, id)
				else
					c.frames += 1
				end
			elseif d.extractor then
				c.extractors += 1
				if (w.posX[id] - brain.homeX) ^ 2 + (w.posZ[id] - brain.homeZ) ^ 2 > Skirmish.HOME_RADIUS ^ 2 then
					c.farExtractors += 1
				end
			elseif d.sensors.radar > 0 then
				c.radarTowers += 1
			elseif #d.weapons > 0 and bit32.band(d.categoryMask, BIT.ANTIAIR) ~= 0 then
				c.samSites += 1
			elseif #d.weapons > 0 then
				c.turrets += 1
			end
		elseif d.buildOptions then
			table.insert(c.builders, id)
			c.workers += 1
		elseif #d.weapons > 0 and d.domain == "naval" then
			table.insert(c.fleet, id)
		elseif #d.weapons > 0 then
			table.insert(c.army, id)
			if bit32.band(d.categoryMask, BIT.ANTIAIR) ~= 0 then
				if d.domain == "air" then
					c.fighters += 1
				else
					c.aa += 1
				end
			end
		elseif (d.sensors.track or 0) > 0 then
			table.insert(c.trackers, id)
		elseif d.sensors.radar > 0 then
			table.insert(c.radarTrucks, id)
		end
	end
	return c
end

-- Units of `defId` waiting in factory queues.
local function queued(sim: Types.Sim, factories: { number }, defId: string): number
	local n = 0
	local index = sim.defs.units[defId].index
	for _, f in factories do
		for _, di in sim.build.queue[f] or {} do
			if di == index then
				n += 1
			end
		end
	end
	return n
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
	local cfg = brain.cfg
	local plantsWanted = if cfg.secondPlant and acc.supply.stored > cfg.secondPlantSupply and c.extractors >= cfg.secondPlantExtractors then 2 else 1
	-- hard extras come once the economy and an army stand
	local established = c.extractors >= 6 and #c.army >= 6 and acc.supply.stored >= 200
	local turretsWanted = if cfg.defenses > 0 then math.min(cfg.defenses + c.farExtractors // 2, Skirmish.MAX_TURRETS) else 0
	-- hard: builders only assisting a factory leave it for these (the
	-- airfield and shipyard are the Command Vehicle's to build)
	local wantAir = cfg.air and #c.factories > 0 and established and #c.airfields + c.airFrames == 0
	local wantNaval = cfg.naval and brain.seaX ~= nil and #c.factories > 0 and established and #c.shipyards + c.shipFrames == 0
	local wantTurret = c.turrets < turretsWanted and #c.factories > 0 and c.extractors >= 5 and #c.army >= 4
	for _, id in workers do
		local isCommander = id == c.commander
		if not idleBuilder(sim, id) then
			local helping = sim.build.target[id] or 0
			local assisting = helping ~= 0 and w.slot[helping] ~= nil and w.buildProgress[helping] >= 1
			local wanted = if isCommander then wantAir or wantNaval else wantTurret
			if not (assisting and wanted) then
				continue
			end
		end
		if #c.factories + c.frames < plantsWanted and #c.factories + c.frames < 2 then
			local x, z = spotNear(brain, plant, brain.homeX + brain.toward * 90, brain.homeZ)
			if x and z then
				build(brain, id, plant, x, z, if brain.toward > 0 then 1 else 3)
				c.frames += 1
				continue
			end
		end
		if isCommander and wantAir then
			-- hard: an airfield behind the base (S-17)
			local field = faction(brain, "airfield", "airfield")
			local x, z = spotNear(brain, field, brain.homeX - brain.dirX * 80, brain.homeZ - brain.dirZ * 80)
			if x and z then
				build(brain, id, field, x, z, 0)
				c.airFrames += 1
				continue
			end
		end
		if isCommander and wantNaval and brain.seaX and brain.seaZ then
			-- hard: a shipyard on the nearby sea (S-17)
			local yard = faction(brain, "shipyard", "shipyard")
			local x, z = spotNear(brain, yard, brain.seaX :: number, brain.seaZ :: number)
			if x and z then
				build(brain, id, yard, x, z, 0)
				c.shipFrames += 1
				continue
			end
		end
		if not isCommander and wantTurret and c.turrets < turretsWanted then
			-- hard: gun turrets, first on the way home, then by far extractors (S-17)
			local turret = faction(brain, "bulwark", "spike")
			local cx, cz = brain.homeX + brain.dirX * 110, brain.homeZ + brain.dirZ * 110
			if c.turrets >= cfg.defenses and brain.lastFarX and brain.lastFarZ then
				cx, cz = brain.lastFarX :: number, brain.lastFarZ :: number
			end
			local x, z = spotNear(brain, turret, cx, cz)
			if x and z then
				build(brain, id, turret, x, z, 0)
				c.turrets += 1
				continue
			end
		end
		if cfg.radar and not isCommander and #c.factories > 0 and c.extractors >= 2 and c.radarTowers == 0 then
			-- radar: early warning for the artillery (S-7)
			local tower = faction(brain, "watchtower", "eye")
			local x, z = spotNear(brain, tower, brain.homeX + brain.toward * 120, brain.homeZ + 60)
			if x and z then
				build(brain, id, tower, x, z, 0)
				c.radarTowers += 1
				continue
			end
		end
		if cfg.antiAir and c.enemyAirNearHome > 0 and c.samSites == 0 then
			-- enemy aircraft over the base: an IR SAM site (S-7)
			local site = faction(brain, "vigil", "thorn")
			local x, z = spotNear(brain, site, brain.homeX, brain.homeZ - 50)
			if x and z then
				build(brain, id, site, x, z, 0)
				c.samSites += 1
				continue
			end
		end
		if cfg.techUp and not isCommander and #c.factories > 0 and #c.advFactories + #c.advFrames == 0 and acc.supply.stored > Skirmish.ADV_PLANT_SUPPLY then
			-- tech up: the Advanced Vehicle Plant (fire-control radar, MLRS; S-7)
			local adv = faction(brain, "advvehplant", "advvehplant")
			local x, z = spotNear(brain, adv, brain.homeX - brain.toward * 40, brain.homeZ + 120)
			if x and z then
				build(brain, id, adv, x, z, if brain.toward > 0 then 1 else 3)
				table.insert(c.advFrames, 0)
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
		local cell = if c.extractors < cfg.maxExtractors then freeDeposit(brain) else nil
		if cell then
			local g = (sim.map :: Passability.PassMap).grid
			local x, z = g:cellCenter(g:coords(cell))
			-- the Command Vehicle only takes deposits near home
			local far = (x - brain.homeX) ^ 2 + (z - brain.homeZ) ^ 2 >= Skirmish.HOME_RADIUS ^ 2
			if not isCommander or not far then
				brain.claims[cell] = sim.tick
				build(brain, id, faction(brain, "extractor", "extractor"), x, z, 0)
				if cfg.maxExtractors < math.huge then
					c.extractors += 1 -- counts toward the cap at once
				end
				if cfg.escorts > 0 and (x - brain.homeX) ^ 2 + (z - brain.homeZ) ^ 2 > Skirmish.ESCORT_RADIUS ^ 2 then
					brain.escortWanted[id] = sim.tick -- hard: an escort for the expansion
					brain.lastFarX, brain.lastFarZ = x, z
				end
				continue
			end
		end
		local frame = c.advFrames[1]
		if frame and frame ~= 0 then
			submit(sim, brain.player, { cmdType = CT.REPAIR, flags = 0, unitIds = { id }, targetId = frame }) -- help the tech-up
		elseif #c.factories > 0 then
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
	local aaUnit = faction(brain, "halo", "hornet")
	local radarUnit = faction(brain, "oracle", "watcher")
	local trackerUnit = faction(brain, "arbiter", "stalker")
	local aaWanted = if cfg.antiAir then math.min(math.ceil(c.enemyAir / 2), Skirmish.MAX_AA) else 0
	local aaPlanned = c.aa + queued(sim, c.factories, aaUnit)
	local radarPlanned = #c.radarTrucks + queued(sim, c.factories, radarUnit)
	local function queueItem(f: number, item: string)
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
	for _, f in c.factories do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			local item
			if c.workers + queuedWorkers < cfg.workers then
				item = worker
				queuedWorkers += 1
			elseif aaPlanned < aaWanted then
				item = aaUnit -- anti-air against the aircraft the team knows (S-7)
				aaPlanned += 1
			elseif cfg.radar and radarPlanned < 1 and c.workers >= cfg.workers then
				item = radarUnit -- radar to escort the waves (S-7)
				radarPlanned += 1
			else
				item = if brain.rng:chance(cfg.artyChance) then arty else tank
			end
			queueItem(f, item)
		end
	end
	local trackerPlanned = #c.trackers + queued(sim, c.advFactories, trackerUnit)
	for _, f in c.advFactories do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			local item
			if trackerPlanned < 1 then
				item = trackerUnit -- fire-control radar for the artillery (S-7)
				trackerPlanned += 1
			else
				item = if brain.rng:chance(0.5) then faction(brain, "judgement", "hydra") else faction(brain, "paladin", "juggernaut")
			end
			queueItem(f, item)
		end
	end

	-- hard: aircraft (fighters against known aircraft, else helicopters and
	-- bombers) and ships
	local fightersWanted = math.min(math.ceil(c.enemyAir / 2), Skirmish.MAX_AA)
	local fightersPlanned = c.fighters + queued(sim, c.airfields, faction(brain, "falcon", "harpy"))
	for _, f in c.airfields do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			local item
			if fightersPlanned < fightersWanted then
				item = faction(brain, "falcon", "harpy")
				fightersPlanned += 1
			else
				item = if brain.rng:chance(0.35) then faction(brain, "absolution", "plague") else faction(brain, "guardian", "wasp")
			end
			queueItem(f, item)
		end
	end
	for _, f in c.shipyards do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			queueItem(f, if brain.rng:chance(0.3) then faction(brain, "silence", "lamprey") else faction(brain, "sentry", "barracuda"))
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
	local threatX, threatZ, targetX, targetZ = Skirmish.knownTargets(brain)

	-- artillery kites (S-7): a known enemy unit inside KITE_RANGE of its
	-- range → back off, then (queued) rejoin the attack
	local kiting: { [number]: number } = {}
	local L = Sensors.Level
	for _, id in c.army do
		local d = unitDef(sim, id)
		if not cfg.kite or bit32.band(d.categoryMask, BIT.ARTILLERY) == 0 or d.maxRange <= 0 then
			continue
		end
		local x, z = w.posX[id], w.posZ[id]
		local reach = d.maxRange * Skirmish.KITE_RANGE
		local bestX, bestZ, bestD = nil, nil, reach * reach
		for _, e in w.ids do
			if w.ally[e] ~= brain.ally and unitDef(sim, e).domain ~= "structure" and unitDef(sim, e).domain ~= "air" then
				local kx, kz, level = Sensors.knownTarget(sim, brain.ally, e)
				if kx and kz and level == L.VISIBLE then
					local d2 = (kx - x) ^ 2 + (kz - z) ^ 2
					if d2 < bestD then
						bestX, bestZ, bestD = kx, kz, d2
					end
				end
			end
		end
		if bestX and bestZ then
			local dl = math.max(math.sqrt(bestD), 1)
			local ax, az = x + (x - bestX) / dl * Skirmish.KITE_STEP, z + (z - bestZ) / dl * Skirmish.KITE_STEP
			local cell, ox, oz = g:encode(ax, az)
			submit(sim, brain.player, { cmdType = CT.MOVE, flags = 0, unitIds = { id }, cell = cell, offX = ox, offZ = oz })
			local tx, tz = targetX or brain.enemyX, targetZ or brain.enemyZ
			local tcell, tox, toz = g:encode(tx, tz)
			if brain.attacking[id] then
				submit(sim, brain.player, { cmdType = CT.FIGHT, flags = Schema.CmdFlag.QUEUE, unitIds = { id }, cell = tcell, offX = tox, offZ = toz })
			end
			kiting[id] = sim.tick
		elseif brain.kiting[id] and sim.tick - brain.kiting[id] < Skirmish.KITE_TICKS then
			kiting[id] = brain.kiting[id]
		end
	end
	brain.kiting = kiting

	local home, wave = {}, {}
	local attacking: { [number]: boolean } = {} -- rebuilt from the living army
	-- escorts (hard) stay with their worker until it is idle or gone
	local escorts: { [number]: number } = {}
	for unit, worker in brain.escorts do
		if w.owner[unit] == brain.player and w.owner[worker] == brain.player and not idleBuilder(sim, worker) then
			escorts[unit] = worker
		end
	end
	brain.escorts = escorts
	for _, id in c.army do
		if escorts[id] then
			continue
		end
		if kiting[id] then
			if brain.attacking[id] then
				attacking[id] = true -- still in the wave, but left to its kiting orders
			end
			continue
		end
		if brain.attacking[id] then
			attacking[id] = true
			table.insert(wave, id)
		else
			table.insert(home, id)
		end
	end
	brain.attacking = attacking
	-- escort requests wait until home units are free, while the worker is
	-- still on its way or building (its order applies on the next step, so a
	-- worker sent this think still looks idle)
	local waiting = {}
	local wanted = brain.escortWanted
	for worker, since in wanted do
		if w.owner[worker] == brain.player and (since == sim.tick or not idleBuilder(sim, worker)) then
			table.insert(waiting, worker)
		end
	end
	table.sort(waiting)
	brain.escortWanted = {}
	for _, worker in waiting do
		local guards = {}
		while #guards < cfg.escorts and #home > 0 do
			local unit = table.remove(home) :: number
			table.insert(guards, unit)
			brain.escorts[unit] = worker
		end
		if #guards > 0 then
			submit(sim, brain.player, { cmdType = CT.GUARD, flags = 0, unitIds = guards, targetId = worker })
		else
			brain.escortWanted[worker] = wanted[worker]
		end
	end
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
		brain.waveSize += cfg.waveGrowth
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
	-- the wave re-targets every 5 s; radar and fire-control vehicles guard it
	if #wave > 0 and (newWave or sim.tick - brain.lastWaveOrder >= Skirmish.THINK_PERIOD * 5) then
		brain.lastWaveOrder = sim.tick
		fight(wave, targetX or brain.enemyX, targetZ or brain.enemyZ)
		local escorts = {}
		for _, list in { c.radarTrucks, c.trackers } do
			for _, id in list do
				table.insert(escorts, id)
			end
		end
		if #escorts > 0 then
			submit(sim, brain.player, { cmdType = CT.GUARD, flags = 0, unitIds = escorts, targetId = wave[1] })
		end
	end
	-- the fleet (hard): gathers on the home sea, then attacks on its own
	if #c.fleet >= Skirmish.FLEET_SIZE and sim.tick - brain.lastFleetOrder >= Skirmish.THINK_PERIOD * 5 then
		brain.lastFleetOrder = sim.tick
		fight(c.fleet, targetX or brain.enemyX, targetZ or brain.enemyZ)
	elseif #c.fleet > 0 and #c.fleet < Skirmish.FLEET_SIZE and brain.seaX and brain.seaZ then
		local idle = {}
		for _, id in c.fleet do
			if w.orderId[id] == 0 and (w.posX[id] - (brain.seaX :: number)) ^ 2 + (w.posZ[id] - (brain.seaZ :: number)) ^ 2 > 80 ^ 2 then
				table.insert(idle, id)
			end
		end
		if #idle > 0 then
			local cell, ox, oz = g:encode(brain.seaX :: number, brain.seaZ :: number)
			submit(sim, brain.player, { cmdType = CT.MOVE, flags = 0, unitIds = idle, cell = cell, offX = ox, offZ = oz })
		end
	end
end

-- Call once per tick, before Sim.step.
function Skirmish.tick(brain: Brain)
	local sim = brain.sim
	if sim.match.eliminated[brain.player] or (sim.tick - brain.thinkOffset) % brain.cfg.think ~= 0 then
		return
	end
	think(brain)
end

return Skirmish
