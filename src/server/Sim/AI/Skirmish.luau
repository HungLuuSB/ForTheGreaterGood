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
--      generators when power runs short (a stall within the last 5 s,
--      S-31); extractors on the nearest free
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
--      attacked by everyone. When the army's value (supply + power / 10)
--      reaches the wave value (S-92: the same for both factions), the wave
--      attack-moves at the nearest known enemy (structures and the Command
--      Vehicle first), or the enemy start if nothing is known; the next
--      wave is larger. Radar and fire-control vehicles guard the wave, so
--      its artillery can fire on radar contacts with tracking (S-7).
--      Artillery kites: a known enemy inside KITE_RANGE of its range makes
--      it back off, then rejoin the wave's attack.
--      Retreat (S-92; normal and hard): a wave out in the field that knows
--      enemy forces near it worth more than RETREAT_RATIO times its own
--      value falls back to the rally point; the next wave waits until the
--      army is worth RETREAT_MARGIN times what it fled, and none leaves
--      for RETREAT_HOLD ticks.
--      Scouting and massing (S-105; normal and hard): the plant builds one
--      scout (Herald / Jackal) at a time, a new one at most every
--      SCOUT_EVERY ticks; it loops round every enemy start, so the team
--      remembers the turrets and structures there. A wave leaves only when
--      the army is worth ATTACK_MARGIN times the known defence (armed
--      units and structures, turrets included) within DEFENSE_RADIUS of
--      its target; until then it masses at the rally point. An army of
--      MASS_SHARE of the unit cap (at most MASS_UNITS) goes anyway.
--   4. T2 (S-101, next.md item 7; normal and hard): once its advanced plant
--      stands and supply passes ADV_BUILDER_SUPPLY, the plant builds one
--      T2 builder (Architect / Forgemaster). It first upgrades its own T1
--      extractors in place, nearest home first, skipping any with known
--      enemies near (S-108). Then it builds a shield generator over the
--      base, PINPOINTERS Pinpointers behind it, the T2 defences (S-106: a
--      heavy turret toward the enemy, a missile battery behind it, a flak
--      tower once enemy aircraft are known, a beam tower), an anti-nuke
--      (Providence / Cerberus, S-111) over the base (S-110; a second once
--      an enemy silo is known), then (Order hard, with CITADEL_SUPPLY stored) a Citadel
--      toward the enemy, and (hard, rich) a nuke silo behind the base,
--      which launches at the best known target at most every NUKE_EVERY
--      ticks (S-110). Order
--      hard's T1 builders also raise a wall of BARRIERS Barrier segments
--      across the front once the base is established. Normal builds an
--      airfield (and a shipyard on a sea map) once established, as hard did.
-- Its only randomness is its own Prng (seeded from the match seed and the
-- player ID), used for the production mix.
--
-- Faction styles (S-76; docs/design/factions.md section 7), on top of the
-- level (Skirmish.styled; easy keeps only the production mix):
--   Order   more artillery in its waves (its pricier units make them
--           later); hard: only safe deposits (as before) and a gun turret
--           more at home; its advanced
--           plant builds Wardens (deployable guns) among its tanks; hard
--           recalls its army against enemy waves too.
--   Chaos   a worker more (it expands wider); waves split in two
--           lanes from LANE_MIN front units so half comes round a flank; a
--           Shroud jammer guards each wave; its plant builds Locusts among its
--           tanks and its advanced plant Minotaurs (siege).
--
-- Levels (S-17; a match option, `match.ai = { [player] = level }`):
--   easy    for a new player (S-57): thinks every 2 s, 2 workers, one item
--           queued per factory and at most one army unit per 20 s, an army
--           of at most 8, at most 6 extractors, one plant, no radar,
--           anti-air, tech-up or kiting; no wave before 8 minutes, then
--           waves of 4, 5, ... units at least 2 minutes apart.
--   normal  everything above (the default); thinks every 4/3 s (S-31: a
--           multiple of THINK_ALIGN; it was 1 s). S-57: from its second
--           generator, its plant builds 2–3 tanks before more workers and
--           it builds no third generator until they are out; an enemy wave of 3+
--           ground units near the base (the recall radius) brings the whole
--           army home, and no wave leaves for 20 s after.
-- Missile stockpiles (S-57): the generator rule plans for the power its
-- SAMs' refills want (up to REFILL_POWER_CAP); while enemy aircraft were
-- near home in the last AIR_MEMORY ticks, half its mobile SAMs stay home,
-- and with SAMs refilling under a power stall it queues no new army units.
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
local Nav = require("../Nav")
local Placement = require("../Placement")
local Pregame = require("../Pregame")
local Quadtree = require("../Path/Quadtree")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Sensors = require("../Sensors")
local Sim = require("../Sim")
local Types = require("../Types")
local World = require("../World")

local Skirmish = {}

Skirmish.THINK_PERIOD = 15 -- ticks (1 s): the AI's timers
Skirmish.THINK_ALIGN = 10 -- ticks: think periods and offsets are multiples of it, the economy (5) and sensor (2) periods' common multiple (S-31)
Skirmish.POWER_MEMORY = 75 -- ticks a power stall is remembered for the generator rule (S-31)
Skirmish.QUEUE_TARGET = 2
Skirmish.WORKERS = 3
Skirmish.FIRST_WAVE = 8
Skirmish.WAVE_GROWTH = 2
Skirmish.HOME_RADIUS = 260 -- studs: enemies inside it are attacked by everyone
Skirmish.CLAIM_TICKS = 900 -- a deposit someone was sent to stays reserved this long
-- A builder sent to build that gets no closer to the site for this long
-- (walled in, or the site is out of its reach) gives up; the site is left
-- alone for BAD_SITE_TICKS (S-133: footprint-2 Commanders can't pass
-- 1-cell gaps between buildings of different sizes)
Skirmish.STALL_TICKS = 300 -- 20 s
Skirmish.BAD_SITE_TICKS = 2700 -- 3 min
Skirmish.giveUpHook = nil :: ((brain: any, builder: number, order: any, distance: number, best: number) -> ())? -- debug tools only (lune run debug_giveups)
Skirmish.SECOND_PLANT_SUPPLY = 600
Skirmish.ADV_PLANT_SUPPLY = 900 -- supply stored before the Advanced Vehicle Plant (S-7)
Skirmish.MAX_AA = 4 -- IR SAM trucks wanted at most
Skirmish.KITE_RANGE = 0.5 -- of its range: artillery backs off from enemies closer than this
Skirmish.KITE_STEP = 100 -- studs it backs off
Skirmish.KITE_TICKS = 45 -- how long a kiting unit is left out of wave orders
Skirmish.FLEET_SIZE = 4 -- ships gathered before the fleet attacks (hard)
Skirmish.MAX_TURRETS = 6
Skirmish.ESCORT_RADIUS = 160 -- studs: workers sent to deposits farther from home get an escort (hard)
Skirmish.ARMY_FIRST_RATIO = 0.6 -- normal's tanks-before-the-third-generator rule holds only while power runs at least this well (S-94)
Skirmish.MIN_GENERATORS = 2 -- generators before the extractor-first rule applies (S-114)
Skirmish.GEN_SLACK = 1 -- generators beyond the planned need while only power stalls (S-114)
Skirmish.GENERATOR_POWER = 20 -- power per second a generator makes (the generator rule's unit; S-94). Since S-203 (the user's H22) the "generator" is the solar array, the same 20
Skirmish.BUILDER_POWER_PER_WORK = 1 / 6 -- power per build power a busy builder draws on average (extractors 500 / 1,800, generators none; S-114)
Skirmish.POWER_PER_WORK = 1 / 3 -- power per work unit of a T1 tank (Lancer 1,700 / 5,100): what a building factory draws per build power (S-94)
Skirmish.REFILL_POWER_CAP = 60 -- power/s of missile refills the generator rule plans for, at most (S-57)
Skirmish.AIR_MEMORY = 900 -- ticks enemy aircraft near home are remembered: half the mobile SAMs stay home (S-57)
Skirmish.RECALL_RADIUS = 570 -- studs from home: an enemy wave this close brings the army home (S-57)
Skirmish.RECALL_MIN = 3 -- known enemy ground units that make a wave
Skirmish.RECALL_HOLD = 300 -- ticks no new wave leaves after a recall
Skirmish.WAVE_ALIGN = 300 -- ticks: waves leave only at the start of these windows (S-57)
Skirmish.FLANK_OFFSET = 300 -- studs off the straight line: a two-lane wave's flank waypoint (S-76)
Skirmish.LANE_MIN = 12 -- front units a wave needs before it splits in two lanes (smaller halves arrive piecemeal; S-76)
Skirmish.UNIT_VALUE = 300 -- a wave's size in units → its value: about a T1 tank's (S-92)
Skirmish.RETREAT_RADIUS = 450 -- studs round a wave's centre where it counts known enemy forces (S-92)
Skirmish.RETREAT_RATIO = 1.3 -- enemy value / wave value that makes a wave fall back (S-92)
Skirmish.RETREAT_MARGIN = 1.2 -- the next wave needs this times the value it fled (S-92)
Skirmish.RETREAT_HOLD = 300 -- ticks no wave leaves after a retreat (S-92)
Skirmish.NUKE_EVERY = 900 -- ticks between the AI's nuke launches (S-110)
Skirmish.NUKE_RICH = 0.9 -- of supply storage stored before hard starts a silo (S-110)
Skirmish.SCOUT_EVERY = 1800 -- ticks between scouts: a new one at most this long after the last (S-105)
Skirmish.SCOUT_RADIUS = 260 -- studs: the scout's loop round an enemy start (S-105)
Skirmish.DEFENSE_RADIUS = 450 -- studs: known defence counted round a wave's target (S-105)
Skirmish.ATTACK_MARGIN = 1.5 -- a wave leaves worth this times the known defence (S-105)
Skirmish.MASS_SHARE = 0.5 -- of the unit cap: a massed army this large goes anyway (S-105)
Skirmish.MASS_UNITS = 150 -- the same without a cap
Skirmish.CONTESTED_ESCORT = 2 -- army units a Chaos worker needs to take a contested deposit (S-97)
Skirmish.CONTESTED_RADIUS = 300 -- studs: known armed enemies this near a deposit make it contested (S-97)
Skirmish.CONTESTED_REACH = 40 -- studs beyond an enemy structure's range that still contest a deposit (S-116)
Skirmish.ADV_BUILDER_SUPPLY = 600 -- supply stored before the advanced plant builds a T2 builder (S-101)
Skirmish.PINPOINTERS = 2 -- Pinpointers the T2 builder raises (S-101)
Skirmish.CITADEL_SUPPLY = 1500 -- supply stored (or 90% of storage, if less) before Order hard's Citadel (S-101)
Skirmish.BARRIERS = 6 -- Barrier segments in Order hard's wall (S-101)
Skirmish.RALLY_GAP = 600 -- studs at least between two rally points: beyond artillery range (Verdict 480 since S-62) with room for the army's spread (S-57)

export type Level = {
	think: number, -- ticks between thinks
	workers: number,
	queue: number, -- items kept queued per factory
	armyCooldown: number, -- seconds between army units it queues (0 = none; easy's production handicap)
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
	firstAttack: number, -- ticks before the first wave may leave (S-57; easy: 8 min)
	waveInterval: number, -- ticks at least between two waves leaving (S-57)
	maxArmy: number, -- army units it keeps at most (S-57; easy)
	tanksBeforeGen3: number, -- tanks before its third generator (S-57; normal): this or one more, by its Prng
	recall: boolean, -- pulls the whole army home against an enemy wave near the base (S-57)
	retreat: boolean, -- a wave outnumbered in the field falls back (S-92)
	scout: boolean?, -- one scout loops round the enemy starts (S-105)
	outweigh: boolean?, -- waves wait to outweigh the known defence (S-105)
	nuke: boolean?, -- a nuke silo when rich (hard, S-110)
	-- faction style (S-76; set by Skirmish.styled)
	wardenShare: number?, -- share of advanced-plant army items that are Wardens (Order)
	minotaurShare: number?, -- share of advanced-plant army items that are Minotaurs (Chaos)
	locustShare: number?, -- share of plant tanks that are Locusts (Chaos)
	lanes: number?, -- 2: half of each wave attacks round a flank (Chaos)
	contested: boolean?, -- workers take contested deposits only with an escort of `escorts` (Chaos, S-97)
	t2Builder: boolean?, -- one T2 builder: shield, Pinpointers (S-101)
	citadel: boolean?, -- the T2 builder adds a Citadel when rich (Order hard, S-101)
	barriers: number?, -- Barrier segments its T1 builders wall the front with (Order hard, S-101)
	jammer: boolean?, -- a mobile jammer guards each wave (Chaos)
	-- S-187 (the user's F41): roles in a team, the aggressive hard level, teamwork
	role: string?, -- Skirmish.ROLES: what this AI does for its side
	botLab: boolean?, -- a Bot Lab / Bot Pit (and its advanced lab once teched): bots in the mix
	earlyAir: boolean?, -- an airfield as soon as a plant and two extractors stand (air role)
	airShare: number?, -- army production share that comes from the airfield (air role)
	advAir: boolean?, -- an advanced airfield when rich: Liche / Dragon and T2 aircraft (air role)
	advPlantSupply: number?, -- supply stored before the advanced plant (default ADV_PLANT_SUPPLY; tech role earlier)
	attackMargin: number?, -- a wave leaves worth this times the known defence (default ATTACK_MARGIN)
	raid: boolean?, -- small fast raids on enemy extractors between waves (aggressive)
	teamwork: boolean?, -- joins an ally's wave, answers an ally's call for help
}

Skirmish.LEVELS = table.freeze({
	easy = {
		think = 30,
		workers = 2,
		queue = 1,
		armyCooldown = 20,
		firstWave = 4, -- small waves a new player can hold (S-57)
		waveGrowth = 1,
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
		firstAttack = 8 * 60 * 15, -- no attack before 8 minutes (S-57)
		waveInterval = 120 * 15,
		maxArmy = 8, -- small enough that a normal wave breaks it (S-57)
		tanksBeforeGen3 = 0,
		recall = false,
		retreat = false,
	},
	normal = {
		think = 20, -- a multiple of THINK_ALIGN (S-31)
		workers = Skirmish.WORKERS,
		queue = Skirmish.QUEUE_TARGET,
		armyCooldown = 0,
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
		air = true, -- an airfield once established (S-101)
		naval = true, -- a shipyard on a sea map once established (S-101)
		safeExpansion = false,
		hunt = false,
		firstAttack = 0,
		waveInterval = 0,
		maxArmy = math.huge,
		tanksBeforeGen3 = 2, -- tanks before the third generator (S-57)
		recall = true, -- defends the base against enemy waves (S-57)
		retreat = true,
		t2Builder = true,
		scout = true,
		outweigh = true,
	},
	hard = {
		think = 10,
		workers = Skirmish.WORKERS,
		queue = 2,
		armyCooldown = 0,
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
		firstAttack = 0,
		waveInterval = 0,
		maxArmy = math.huge,
		tanksBeforeGen3 = 0,
		recall = false,
		retreat = true,
		t2Builder = true,
		scout = true,
		outweigh = true,
		nuke = true,
	},
} :: { [string]: Level })

-- Hard - Aggressive (S-187, the user): hard's economy and tech, but it
-- attacks early and often with smaller waves, doesn't wait to outweigh the
-- known defence, never falls back, raids extractors between waves and
-- builds no turrets at home.
do
	local s = table.clone(Skirmish.LEVELS.hard) :: any
	s.firstWave = 6
	s.waveGrowth = 2
	s.defenses = 0
	s.escorts = 0
	s.safeExpansion = false
	s.outweigh = false
	s.retreat = false
	s.recall = false
	s.attackMargin = 0.8
	s.raid = true
	s.botLab = true
	local levels = table.clone(Skirmish.LEVELS) :: any
	levels.hard_aggressive = table.freeze(s)
	Skirmish.LEVELS = table.freeze(levels)
end
Skirmish.LEVEL_NAMES = table.freeze({ "easy", "normal", "hard", "hard_aggressive" })

-- Roles (S-187, the user: "some cover air, some fund tech, some spam cheap
-- units to overrun defences, some specialise in layered defence, guarding
-- chokepoints with jammers and turrets"). Two or more AIs on one side
-- share them out in player order; a lone AI plays balanced.
Skirmish.ROLES = table.freeze({ "balanced", "air", "defense", "spam", "tech" })
-- front (1) to back (5): who takes which spot (S-207)
Skirmish.ROLE_DEPTH = table.freeze({ balanced = 1, spam = 2, defense = 3, tech = 4, air = 5 })
Skirmish.RAID_EVERY = 900 -- ticks between raids (aggressive)
Skirmish.RAID_UNITS = 4
Skirmish.TEAM_JOIN_TICKS = 150 -- an ally's wave left this recently: join it
Skirmish.TEAM_HELP_TICKS = 90 -- an ally's call for help stays this long

-- The role of AI `player` on its side: the side's AIs in player order take
-- ROLES in turn (alone: balanced). Easy plays balanced.
function Skirmish.roleOf(sim: Types.Sim, player: number, level: string): string
	if level == "easy" then
		return "balanced"
	end
	local ally = sim.players[player].allyTeam
	local mine = {}
	for _, pid in sim.playerOrder do
		if sim.match.ai[pid] ~= nil and sim.match.ai[pid] ~= "easy" and sim.players[pid].allyTeam == ally then
			table.insert(mine, pid)
		end
	end
	if #mine < 2 then
		return "balanced"
	end
	-- the side's roles, as many as it has AIs, in ROLES order; then handed
	-- out by spot (S-207, the user's H10: a Normal AI on Supreme Strait's
	-- front spot built a plant and an airfield; it had drawn the air role by
	-- player order): the AIs nearest an enemy Commander get the roles that
	-- fight up front, those farthest back air and tech. Ties keep player
	-- order.
	local roles = {}
	for k = 1, #mine do
		table.insert(roles, Skirmish.ROLES[(k - 1) % #Skirmish.ROLES + 1])
	end
	-- (the lobby's badges ask with a room's config and no world, and the
	-- pre-game has no Commanders yet: the roles in player order, as before)
	local w = sim.world
	local coms = {}
	for _, id in if w then w.ids else {} do
		if bit32.band(sim.defs.unitByIndex[w.defIndex[id]].categoryMask, Categories.Bit.COMMANDER) ~= 0 then
			table.insert(coms, id)
		end
	end
	if #coms == 0 then
		return roles[table.find(mine, player) or 1]
	end
	table.sort(roles, function(a, b)
		return Skirmish.ROLE_DEPTH[a] < Skirmish.ROLE_DEPTH[b]
	end)
	local front: { [number]: number } = {}
	for _, pid in mine do
		local best = math.huge
		for _, me in coms do
			if w.owner[me] == pid then
				for _, them in coms do
					if sim.players[w.owner[them]].allyTeam ~= ally then
						best = math.min(best, (w.posX[me] - w.posX[them]) ^ 2 + (w.posZ[me] - w.posZ[them]) ^ 2)
					end
				end
			end
		end
		front[pid] = best
	end
	local order = table.clone(mine)
	table.sort(order, function(a, b)
		if front[a] ~= front[b] then
			return front[a] < front[b]
		end
		return (table.find(mine, a) :: number) < (table.find(mine, b) :: number)
	end)
	return roles[table.find(order, player) or 1]
end

-- The level's settings for a role (S-187).
function Skirmish.withRole(cfg: Level, role: string, levelName: string): Level
	local s = table.clone(cfg) :: any
	s.role = role
	if levelName ~= "easy" then
		s.teamwork = true
		s.lanes = math.max(cfg.lanes or 1, 2) -- (F19: waves split so they don't swarm one spot)
	end
	if role == "air" then
		s.air = true
		s.earlyAir = true
		s.airShare = 0.6
		s.advAir = true
		s.antiAir = true
	elseif role == "defense" then
		s.defenses = cfg.defenses + 4
		s.barriers = Skirmish.BARRIERS
		s.firstWave = math.ceil(cfg.firstWave * 1.5)
		s.radar = true
	elseif role == "spam" then
		s.botLab = true
		s.queue = cfg.queue + 1
		s.firstWave = math.max(4, math.floor(cfg.firstWave * 0.6))
		s.waveGrowth = 1
		s.artyChance = 0.1
	elseif role == "tech" then
		s.advPlantSupply = 400
		s.firstWave = math.ceil(cfg.firstWave * 1.3)
		s.botLab = true
	end
	return table.freeze(s) :: Level
end

-- Per simulation, per side: the last wave an AI sent and the last call for
-- help (S-187 teamwork). Keyed by the sim (weak), so it never leaks between
-- matches.
local teamStates: { [any]: { [number]: { waveTick: number, waveFrom: number, helpX: number, helpZ: number, helpTick: number, helpFrom: number } } } = setmetatable({}, { __mode = "k" }) :: any
local function teamOf(brain: any): { waveTick: number, waveFrom: number, helpX: number, helpZ: number, helpTick: number, helpFrom: number }
	local bySide = teamStates[brain.sim]
	if bySide == nil then
		bySide = {}
		teamStates[brain.sim] = bySide
	end
	local t = bySide[brain.ally]
	if t == nil then
		t = { waveTick = -math.huge, waveFrom = 0, helpX = 0, helpZ = 0, helpTick = -math.huge, helpFrom = 0 }
		bySide[brain.ally] = t
	end
	return t
end

local CT = Schema.CmdType
local BIT = Categories.Bit

-- The level's settings with the faction's style applied (S-76): `prefix`
-- "ord_" or "chs_". Easy keeps its strength and only takes the production
-- mix, so a new player meets either faction's units at the same pace.
function Skirmish.styled(cfg: Level, prefix: string, levelName: string): Level
	local s = table.clone(cfg) :: any
	local strong = levelName ~= "easy"
	if prefix == "ord_" then
		s.wardenShare = 0.25
		if strong then
			s.artyChance = cfg.artyChance + 0.1
			s.recall = true
		end
		if levelName == "hard" then
			-- (on normal they made Order mirrors stall at their own bases
			-- for the whole match, so normal keeps its expansion)
			s.safeExpansion = true
			s.defenses = cfg.defenses + 1
			s.citadel = true -- (S-101)
			s.barriers = Skirmish.BARRIERS
		end
	else
		s.locustShare = 0.35
		s.minotaurShare = 0.25
		if strong then
			s.workers = cfg.workers + 1
			-- (waves are counted by value since S-92: Chaos's cheaper units
			-- make up the same wave with more of them, no count bonus)
			s.lanes = 2
			s.jammer = true
			-- workers stay off contested deposits until an escort can go
			-- with them (S-97: Chaos lost 75 of 81 workers in Order's half)
			s.contested = true
			s.escorts = math.max(cfg.escorts, Skirmish.CONTESTED_ESCORT)
		end
	end
	return table.freeze(s) :: Level
end

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
	waveSize: number, -- units (easy's cap)
	waveValue: number, -- value the home army needs before a wave leaves (S-92)
	lastRetreatAt: number, -- tick a wave last fell back (S-92)
	retreats: number,
	scoutAt: number, -- tick the last scout was queued (S-105)
	nukeAt: number, -- tick of the last nuke launch (S-110)
	nukes: number, -- launches so far
	held: number, -- thinks a ready wave waited for the known defence (S-105)
	attacking: { [number]: boolean }, -- units sent with a wave
	claims: { [number]: number }, -- cell → tick a builder was sent there
	approach: { [number]: { x: number, z: number, best: number, at: number } }, -- builder → its build site, closest so far, when (S-133)
	gaveUp: number, -- build orders given up as unreachable
	deposits: { number }, -- deposit cells, nearest home first
	waves: number,
	lastWaveOrder: number, -- tick the wave was last sent at its target
	kiting: { [number]: number }, -- unit → tick it last backed off (S-7)
	flanked: { [number]: boolean }, -- two-lane waves: units past their flank waypoint (S-76)
	level: string, -- "easy" | "normal" | "hard" (S-17)
	cfg: Level,
	dirX: number, -- unit vector from home toward the enemy start
	dirZ: number,
	escorts: { [number]: number }, -- army unit → the worker it guards (hard)
	escortWanted: { [number]: number }, -- workers on their way to a far deposit → tick sent; waiting for an escort
	enemyStarts: { { number } }, -- the enemy Commanders' starts { x, z } (S-97: contested deposits; S-207: the enemy side's only)
	seaX: number?, -- a navigable sea spot near home (hard, naval maps)
	seaZ: number?,
	lastFleetOrder: number,
	lastFarX: number?, -- the last far deposit a worker was sent to (hard: turrets go there)
	lastFarZ: number?,
	thinkOffset: number, -- ticks into the think period this player thinks at
	lastArmyQueued: number, -- tick it last queued an army unit (easy's cooldown)
	powerShortAt: number, -- last tick power was stalling (S-31)
	supplyShortAt: number, -- last tick supply was stalling (S-114)
	powerLowAt: number, -- last tick power ran below ARMY_FIRST_RATIO (S-94)
	airNearAt: number, -- last tick enemy aircraft were known near home (S-57)
	lastWaveAt: number, -- tick the last wave left (S-57)
	raidAt: number, -- tick the last raid left (S-187)
	recallUntil: number, -- no new wave before this tick (S-57)
	recallRadius: number, -- RECALL_RADIUS, or less on a small map: never the enemy's own rally point
	tanksFirst: number, -- tanks before its third generator this match: tanksBeforeGen3 or one more, by its Prng (S-57)
	rallyDist: number, -- studs from home to the rally point (S-57)
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
	if sim.pregame then
		-- no Commander yet (S-169): a stand-in that picks and readies, and
		-- becomes the real brain when the match starts (Skirmish.tick)
		return ({ sim = sim, player = player, pendingLevel = level or sim.match.ai[player] or "normal", pending = true } :: any) :: Brain
	end
	local levelName = level or sim.match.ai[player] or "normal"
	local base = Skirmish.LEVELS[levelName]
	assert(base, `Skirmish.new: unknown level {levelName}`)
	local p = sim.players[player]
	local cfg = Skirmish.styled(base, if p.faction == "order" then "ord_" else "chs_", levelName) -- S-76
	cfg = Skirmish.withRole(cfg, Skirmish.roleOf(sim, player, levelName), levelName) -- S-187
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
	-- the enemy side's starts: where its Commanders stand (S-207, the
	-- user's H15: every other map start counted, allies' and empty ones
	-- too, so deposits by an ally or an empty spot were "contested" or
	-- skipped and stayed empty); with no enemy Commander yet, the map's
	-- other starts as before
	local enemyStarts = {}
	local ally = sim.players[player].allyTeam
	for _, id in w.ids do
		if bit32.band(unitDef(sim, id).categoryMask, BIT.COMMANDER) ~= 0 and sim.players[w.owner[id]].allyTeam ~= ally then
			table.insert(enemyStarts, { w.posX[id], w.posZ[id] })
		end
	end
	if #enemyStarts == 0 then
		for _, s in layers.starts do
			local near = (s[1] - homeX) ^ 2 + (s[2] - homeZ) ^ 2 < 1
			if not near then
				table.insert(enemyStarts, s)
			end
		end
	end
	local deposits = {}
	for _, patch in layers.deposits or {} do
		-- each 2 × 2 patch once, by its min-corner cell (S-184)
		local i = g:index(g:cellAt(patch[1] - 4, patch[2] - 4))
		do
			local x, z = patch[1], patch[2]
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
		ax, az, bx, bz = ax + 4, az + 4, bx + 4, bz + 4 -- the patches' centres
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
	local brain: Brain = {
		sim = sim,
		player = player,
		team = p.team,
		ally = p.allyTeam :: number,
		prefix = if p.faction == "order" then "ord_" else "chs_",
		rng = Prng.new((sim.seed * 31 + player * 7919) % 4294967296),
		homeX = homeX,
		homeZ = homeZ,
		enemyX = enemyX,
		enemyZ = enemyZ,
		toward = if enemyX >= homeX then 1 else -1,
		waveSize = cfg.firstWave,
		waveValue = cfg.firstWave * Skirmish.UNIT_VALUE,
		lastRetreatAt = -math.huge,
		retreats = 0,
		scoutAt = -math.huge,
		nukeAt = -math.huge,
		nukes = 0,
		held = 0,
		attacking = {},
		claims = {},
		approach = {},
		gaveUp = 0,
		deposits = deposits,
		waves = 0,
		lastWaveOrder = -math.huge,
		powerShortAt = -math.huge,
		supplyShortAt = -math.huge,
		powerLowAt = -math.huge,
		airNearAt = -math.huge,
		lastWaveAt = -math.huge,
		raidAt = -math.huge, -- (S-187)
		recallUntil = -math.huge,
		recallRadius = math.min(Skirmish.RECALL_RADIUS, dl * 0.45),
		tanksFirst = 0,
		-- the rally point: 160 studs out, but on a small map far enough back
		-- that the two armies parked at their rally points are out of each
		-- other's artillery range (RALLY_GAP apart). Within range, the side
		-- whose artillery saw the other first won the duel, and with mirrored
		-- players that was always the same side (S-57)
		rallyDist = math.clamp((dl - Skirmish.RALLY_GAP) / 2, 40, 160),
		kiting = {},
		flanked = {},
		level = levelName,
		cfg = cfg,
		dirX = (enemyX - homeX) / dl,
		dirZ = (enemyZ - homeZ) / dl,
		escorts = {},
		escortWanted = {},
		enemyStarts = enemyStarts,
		seaX = seaX,
		seaZ = seaZ,
		lastFleetOrder = -math.huge,
		lastArmyQueued = -math.huge,
		-- players spread over the think period in steps of THINK_ALIGN, so
		-- every player thinks at the same phase of the economy (5 ticks) and
		-- sensor (2 ticks) steps: at other phases the same plan finished at
		-- a different point of a player's cycle, and mirrored players made
		-- different choices (S-31). With `tick + player` the higher player
		-- always thought a tick earlier and won every race for a contested
		-- deposit (S-17); players sharing a slot think in the same tick.
		thinkOffset = (((table.find(sim.playerOrder, player) :: number) - 1) * Skirmish.THINK_ALIGN) % cfg.think,
	}
	-- "2–3 tanks" (S-57): the count varies by match through its own Prng, so
	-- mirrored players don't play the same opening every time (a fixed
	-- count made one side win nearly every mirror)
	if cfg.tanksBeforeGen3 > 0 then
		brain.tanksFirst = cfg.tanksBeforeGen3 + (if brain.rng:chance(0.5) then 1 else 0)
	end
	return brain
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

-- The BUILD facing (Schema.Facing) nearest the enemy start (S-160, the
-- user's BAR reference #7): factories face their pad and exit lane that
-- way. East / west wins a tie, as before on the mirrored 1v1 maps.
function Skirmish.enemyFacing(brain: Brain): number
	if math.abs(brain.dirX) >= math.abs(brain.dirZ) then
		return if brain.dirX >= 0 then Schema.Facing.EAST else Schema.Facing.WEST
	end
	return if brain.dirZ > 0 then Schema.Facing.NORTH else Schema.Facing.SOUTH
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
local SNAP_NUDGE = 1e-3 -- studs
Skirmish.EXIT_LANE = 3 -- cells kept clear in front of the AI's factory exits (S-142)

-- Can `builder` get within building range of a footprint whose min cell is
-- (x0, z0)? Some cell on the rings around it, out to its build range (2
-- cells at least), is open ground of the builder's connected region (its
-- move class's quadtree; S-142): a shipyard out on the water is built from
-- the shore. Aircraft and units without a region (inside their factory,
-- say) always can.
local function reachable(sim: Types.Sim, builder: number, size: number, x0: number, z0: number): boolean
	local nav = sim.nav
	if nav == nil then
		return true
	end
	local w = sim.world
	local p = nav.profiles[w.defIndex[builder]]
	if p == nil or p.air then
		return true
	end
	local tree = Nav.tree(nav, p.moveClass, p.need, p.treeKey)
	local g = nav.grid
	local bx, bz = g:cellAt(w.posX[builder], w.posZ[builder])
	if not g:inBounds(bx, bz) or not Quadtree.isOpen(tree, g:index(bx, bz)) then
		return true
	end
	local home = Quadtree.component(tree, g:index(bx, bz))
	local reach = math.max(2, math.floor((unitDef(sim, builder).buildRange or 0) / 8))
	for r = 1, reach do
		for cz = z0 - r, z0 + size - 1 + r do
			for cx = x0 - r, x0 + size - 1 + r do
				local edge = cx == x0 - r or cx == x0 + size - 1 + r or cz == z0 - r or cz == z0 + size - 1 + r
				if edge and g:inBounds(cx, cz) then
					local i = g:index(cx, cz)
					if Quadtree.isOpen(tree, i) and Quadtree.component(tree, i) == home then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Does a footprint (min cell x0, z0) cover the lane in front of one of the
-- player's factories: EXIT_LANE cells out from its front edge, its width
-- (S-142: produced units drive out there, S-133)?
local function onExitLane(brain: Brain, size: number, x0: number, z0: number): boolean
	local sim = brain.sim
	local w = sim.world
	local g = (sim.map :: Passability.PassMap).grid
	for _, id in w.ids do
		if w.owner[id] ~= brain.player then
			continue
		end
		local d = unitDef(sim, id)
		if d.domain ~= "structure" or d.buildOptions == nil or d.footprint == nil then
			continue
		end
		local fx, fz = math.sin(w.heading[id]), math.cos(w.heading[id])
		local half = d.footprint * 4
		local cxs, czs = g:cellAt(w.posX[id] - half + 1e-3, w.posZ[id] - half + 1e-3) -- the factory's min cell
		local n = d.footprint
		local lx0, lz0, lx1, lz1 = cxs, czs, cxs + n - 1, czs + n - 1
		if math.abs(fx) > math.abs(fz) then
			if fx > 0 then
				lx0, lx1 = cxs + n, cxs + n + Skirmish.EXIT_LANE - 1
			else
				lx0, lx1 = cxs - Skirmish.EXIT_LANE, cxs - 1
			end
		else
			if fz > 0 then
				lz0, lz1 = czs + n, czs + n + Skirmish.EXIT_LANE - 1
			else
				lz0, lz1 = czs - Skirmish.EXIT_LANE, czs - 1
			end
		end
		if x0 <= lx1 and x0 + size - 1 >= lx0 and z0 <= lz1 and z0 + size - 1 >= lz0 then
			return true
		end
	end
	return false
end

-- With `builder`, only sites it can reach (S-142).
local function spotNear(brain: Brain, defId: string, cx: number, cz: number, builder: number?): (number?, number?)
	local sim = brain.sim
	local def = sim.defs.units[defId]
	local g = (sim.map :: Passability.PassMap).grid
	local layers = (sim.map :: Passability.PassMap).layers
	local step = 8 * def.footprint + 16 -- 2-cell lanes: 3-cell lanes (S-104) broke mirror fairness (east 10 of 12); review
	for ring = 1, 8 do
		local n = ring * 8
		for k = 0, n - 1 do
			local a = k / n * 2 * math.pi
			-- the nudge toward the enemy keeps points off exact half cells:
			-- snapping rounds halves up (+x) for everyone, which made the
			-- east player's site one cell off the west's mirror image (S-31)
			local x, z = cx + brain.toward * (math.cos(a) * ring * step + SNAP_NUDGE), cz + math.sin(a) * ring * step
			local gx, gz = g:cellAt(x, z)
			if not g:inBounds(gx, gz) then
				continue
			end
			local cell = g:index(gx, gz)
			-- other buildings keep a cell clear of deposits: room for the
			-- extractor and its 3×3 T2 upgrade (S-104)
			local onDeposit = def.extractor == nil and PlacementRules.supplyUnder(layers, def.footprint + 2, x, z) > 0
			if not onDeposit and (brain.claims[cell] or -math.huge) + Skirmish.CLAIM_TICKS < sim.tick then
				local ok, _, x0, z0 = Placement.check(sim, def, x, z, nil, brain.ally)
				-- reachable for its builder, and off the factories' exit lanes (S-142)
				if ok and not onExitLane(brain, def.footprint, x0, z0) and (builder == nil or reachable(sim, builder, def.footprint, x0, z0)) then
					brain.claims[cell] = sim.tick
					return x, z
				end
			end
		end
	end
	return nil, nil
end

-- The nearest deposit with nothing on it, as far as the team knows, and
-- nobody sent there lately.
-- The first free deposit, nearest home first; `accept` may refuse some
-- (contested ones without an escort, S-97).
-- With `builder`, only deposits it can reach (S-161: on Twin Lakes builders
-- stood still for 20 s before deposits their move class can't get to).
-- Generators in a tidy block behind the base (S-187, the playtest's F20:
-- "AI place generators randomly: a messy base"): rows of GEN_ROW along the
-- front line's direction, GEN_GAP studs apart (a lane between every two),
-- filling from the base outward. The first free slot from the k-th on; nil
-- when the block has no room (spotNear then).
Skirmish.GEN_ROW = 4
-- studs between generator centres (16 wide): 16-stud, two-cell lanes, which
-- every footprint-2 unit can drive through (S-193, G3: units wedged into the
-- 8-stud lanes of the 24-stud block, which their clearance let them enter)
Skirmish.GEN_GAP = 32
function Skirmish.blockSpot(brain: Brain, defId: string, k: number, builder: number): (number?, number?)
	local sim = brain.sim
	local def = sim.defs.units[defId]
	local ax, az = brain.homeX - brain.dirX * 70, brain.homeZ - brain.dirZ * 70 -- behind the base
	-- along the front, in world terms (+z first, as the two-lane flank): a
	-- mirrored player fills its block in the mirrored order (S-31)
	local px, pz = -brain.dirZ, brain.dirX
	if pz < 0 or (pz == 0 and px < 0) then
		px, pz = -px, -pz
	end
	for slot = k, k + 15 do
		local row, col = slot // Skirmish.GEN_ROW, slot % Skirmish.GEN_ROW
		local off = (col - (Skirmish.GEN_ROW - 1) / 2) * Skirmish.GEN_GAP
		local x = ax + px * off - brain.dirX * row * Skirmish.GEN_GAP
		local z = az + pz * off - brain.dirZ * row * Skirmish.GEN_GAP
		local ok = Placement.check(sim, def, x, z, nil, brain.ally)
		if ok then
			return x, z
		end
	end
	return nil, nil
end

-- The centre of the deposit patch whose min-corner cell is `cell` (S-184).
function Skirmish.depositPoint(g: any, cell: number): (number, number)
	local x, z = g:cellCenter(g:coords(cell))
	return x + 4, z + 4
end

function Skirmish.freeDeposit(brain: Brain, accept: ((number, number, number) -> boolean)?, builder: number?): number?
	local sim = brain.sim
	local pm = sim.map :: Passability.PassMap
	local def = sim.defs.units[faction(brain, "extractor", "extractor")]
	for _, cell in brain.deposits do
		if (brain.claims[cell] or -math.huge) + Skirmish.CLAIM_TICKS < sim.tick then
			local x, z = Skirmish.depositPoint(pm.grid, cell)
			local ok, _, x0, z0 = Placement.check(sim, def, x, z, nil, brain.ally)
			if ok and (accept == nil or accept(cell, x, z)) and (builder == nil or reachable(sim, builder, def.footprint, x0, z0)) then
				return cell
			end
		end
	end
	return nil
end

-- Is the deposit at (x, z) contested (S-97): nearer an enemy start than
-- its own, or with known armed enemies within CONTESTED_RADIUS?
function Skirmish.contested(brain: Brain, x: number, z: number): boolean
	local own = (x - brain.homeX) ^ 2 + (z - brain.homeZ) ^ 2
	for _, s in brain.enemyStarts do
		if (x - s[1]) ^ 2 + (z - s[2]) ^ 2 < own then
			return true
		end
	end
	-- known armed enemies near it; a structure only within its guns' reach
	-- (S-116, client request 48: a lone turret by the base made every home
	-- deposit contested, and Chaos stopped expanding until it had escorts)
	local sim = brain.sim
	local w = sim.world
	local r2 = Skirmish.CONTESTED_RADIUS ^ 2
	for _, id in w.ids do
		if w.ally[id] ~= brain.ally then
			local kx, kz, level, defIndex = Sensors.knownTarget(sim, brain.ally, id)
			if kx and kz then
				local d2 = (kx - x) ^ 2 + (kz - z) ^ 2
				if d2 <= r2 then
					local shown = Sensors.shownDef(sim, brain.ally, id, level, defIndex :: number)
					if shown == nil then
						return true -- an unidentified contact: assume the worst
					end
					local d = sim.defs.unitByIndex[shown]
					if #d.weapons > 0 and (d.domain ~= "structure" or d2 <= (d.maxRange + Skirmish.CONTESTED_REACH) ^ 2) then
						return true
					end
				end
			end
		end
	end
	return false
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

-- A unit def's value: supply + power / 10 (S-92).
function Skirmish.value(d: Defs.UnitDef): number
	return d.cost.supply + d.cost.power / 10
end

-- The value of the known enemy forces within `radius` of (x, z) (S-92):
-- armed units and structures whose type the team knows (visible, tracked
-- or remembered, D107) by their value; unidentified contacts as one
-- UNIT_VALUE each. Unarmed structures don't count.
function Skirmish.enemyValueNear(brain: Brain, x: number, z: number, radius: number): number
	local sim = brain.sim
	local w = sim.world
	local r2 = radius * radius
	local v = 0
	for _, id in w.ids do
		if w.ally[id] ~= brain.ally then
			local kx, kz, level, defIndex = Sensors.knownTarget(sim, brain.ally, id)
			if kx and kz and (kx - x) ^ 2 + (kz - z) ^ 2 <= r2 then
				local shown = Sensors.shownDef(sim, brain.ally, id, level, defIndex :: number) -- a decoy counts as what it shows (S-109)
				if shown then
					local d = sim.defs.unitByIndex[shown]
					if #d.weapons > 0 then
						v += Skirmish.value(d)
					end
				else
					v += Skirmish.UNIT_VALUE
				end
			end
		end
	end
	return v
end

-- An enemy wave coming at the base (S-57): the known enemy ground units
-- (not structures, not aircraft; radar contacts count by their domain,
-- D107) within the recall radius of home (RECALL_RADIUS, at most 45% of the
-- way to the enemy start, so its army parked at home never counts), and
-- where they are on average.
function Skirmish.incoming(brain: Brain): (number, number, number)
	local sim = brain.sim
	local w = sim.world
	local n, sx, sz = 0, 0, 0
	local r2 = brain.recallRadius ^ 2
	for _, id in w.ids do
		if w.ally[id] ~= brain.ally then
			local kx, kz, level, defIndex = Sensors.knownTarget(sim, brain.ally, id)
			if kx and kz and (kx - brain.homeX) ^ 2 + (kz - brain.homeZ) ^ 2 <= r2 then
				local cats = Sensors.knownCategories(sim, brain.ally, id, level, defIndex :: number)
				if bit32.band(cats, BIT.STRUCTURE + BIT.AIR) == 0 then
					n += 1
					sx += kx
					sz += kz
				end
			end
		end
	end
	if n == 0 then
		return 0, brain.homeX, brain.homeZ
	end
	return n, sx / n, sz / n
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
	jammers: { number }, -- mobile jammers (S-76)
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
	refillPower: number, -- power per second its missile stockpiles below capacity want (S-57)
	generators: number, -- generators, frames included
	aaTrucks: { number }, -- own mobile SAMs, in ID order
	t2Builders: { number }, -- T2 builders (Architect / Forgemaster; S-101)
	shields: number, -- shield generators, frames included (S-101)
	pinpointers: number, -- frames included (S-101)
	citadels: number, -- frames included (S-101)
	barriers: number, -- frames included (S-101)
	scouts: { number }, -- (S-105)
	built: { [string]: number }, -- own structures per def ID, frames included (S-106)
	t1Extractors: { number }, -- own finished T1 extractors not being upgraded (S-108)
	silos: { number }, -- own finished nuke silos (S-110)
	mobileAntiNukes: { number }, -- (S-111)
	enemySilo: boolean, -- the team knows an enemy nuke silo (S-110)
	-- S-187
	botLabs: { number }, -- complete Bot Labs / Pits
	botFrames: number,
	advBotLabs: { number },
	advBotFrames: number,
	advAirfields: { number },
	advAirFrames: number,
	enemyTurrets: number, -- known enemy armed structures (counters: artillery against them)
	enemyArty: number, -- known enemy artillery (counters: fast raiders)
	enemyLight: number, -- known enemy light ground units (counters: heavy, beams)
	enemyExtractors: { { number } }, -- known enemy extractors' { x, z } (raids)
}

local function census(brain: Brain): Census
	local sim = brain.sim
	local w = sim.world
	local scoutId = if brain.prefix == "ord_" then "ord_herald" else "chs_jackal"
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
		jammers = {},
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
		refillPower = 0,
		generators = 0,
		aaTrucks = {},
		t2Builders = {},
		shields = 0,
		pinpointers = 0,
		citadels = 0,
		barriers = 0,
		scouts = {},
		built = {},
		t1Extractors = {},
		silos = {},
		mobileAntiNukes = {},
		enemySilo = false,
		botLabs = {},
		botFrames = 0,
		advBotLabs = {},
		advBotFrames = 0,
		advAirfields = {},
		advAirFrames = 0,
		enemyTurrets = 0,
		enemyArty = 0,
		enemyLight = 0,
		enemyExtractors = {},
	}
	local advPlant = faction(brain, "advvehplant", "advvehplant")
	local generator = faction(brain, "solar", "solar")
	local airfield = faction(brain, "airfield", "airfield")
	local shipyard = faction(brain, "shipyard", "shipyard")
	local nearHome = (Skirmish.HOME_RADIUS * 1.5) ^ 2
	for _, id in w.ids do
		if w.owner[id] ~= brain.player then
			if w.ally[id] ~= brain.ally then
				local kx, kz, level, defIndex = Sensors.knownTarget(sim, brain.ally, id)
				if kx and Sensors.typeKnown(sim, brain.ally, id, level) then
					local ed = sim.defs.unitByIndex[defIndex :: number]
					if ed.id == "ord_reckoning" or ed.id == "chs_ragnarok" then
						c.enemySilo = true -- (S-110) a second umbrella site
					end
					-- what the enemy fields (S-187: counters)
					if ed.domain == "structure" then
						if #ed.weapons > 0 then
							c.enemyTurrets += 1
						elseif ed.extractor then
							table.insert(c.enemyExtractors, { kx :: number, kz :: number })
						end
					elseif bit32.band(ed.categoryMask, BIT.ARTILLERY) ~= 0 then
						c.enemyArty += 1
					elseif bit32.band(ed.categoryMask, BIT.LIGHT) ~= 0 and ed.domain == "ground" then
						c.enemyLight += 1
					end
				end
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
		if done then
			-- missiles still to build (S-47): their power, at full economy
			for slot, s in d.weapons do
				local stock = w.wStock[World.slotKey(id, slot)]
				if stock and s.stockCapacity and stock < s.stockCapacity then
					local sp = sim.defs.weapons[s.def].stockpile :: any
					c.refillPower += (sp.cost.power or 0) / sp.buildTime
				end
			end
		end
		if d.domain == "structure" then
			c.built[d.id] = (c.built[d.id] or 0) + 1
			if done and d.extractor and d.id == brain.prefix .. "extractor" then
				table.insert(c.t1Extractors, id)
			end
			if done and (d.id == "ord_reckoning" or d.id == "chs_ragnarok") then
				table.insert(c.silos, id)
			end
		end
		if bit32.band(d.categoryMask, BIT.COMMANDER) ~= 0 then
			c.commander = id
		elseif d.domain == "structure" then
			if d.buildOptions then
				if d.id == brain.prefix .. "botlab" or d.id == brain.prefix .. "advbotlab" or d.id == brain.prefix .. "advairfield" then
					-- (S-187) bot labs and the advanced airfield: their own lists
					local adv = d.id == brain.prefix .. "advbotlab"
					local air = d.id == brain.prefix .. "advairfield"
					if done then
						table.insert(if air then c.advAirfields elseif adv then c.advBotLabs else c.botLabs, id)
					elseif air then
						c.advAirFrames += 1
					elseif adv then
						c.advBotFrames += 1
					else
						c.botFrames += 1
					end
				elseif d.id == airfield or d.id == shipyard then
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
			elseif d.id == generator then
				c.generators += 1
			elseif d.shield then
				c.shields += 1 -- (S-101)
			elseif d.pinpointer then
				c.pinpointers += 1
			elseif d.id == "ord_citadel" then
				c.citadels += 1
			elseif d.id == "ord_barrier" then
				c.barriers += 1
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
		elseif d.buildOptions and d.tier >= 2 then
			table.insert(c.t2Builders, id) -- (S-101) its own jobs, below
		elseif d.buildOptions then
			table.insert(c.builders, id)
			c.workers += 1
		elseif d.id == scoutId then
			table.insert(c.scouts, id) -- (S-105) not in the army
		elseif d.id == "ord_custodian" or d.id == "chs_chimera" then
			table.insert(c.mobileAntiNukes, id) -- (S-111) escorts, not in the army
		elseif #d.weapons > 0 and d.domain == "naval" then
			table.insert(c.fleet, id)
		elseif #d.weapons > 0 then
			table.insert(c.army, id)
			if bit32.band(d.categoryMask, BIT.ANTIAIR) ~= 0 then
				if d.domain == "air" then
					c.fighters += 1
				else
					c.aa += 1
					table.insert(c.aaTrucks, id)
				end
			end
		elseif (d.sensors.jam or 0) > 0 then
			table.insert(c.jammers, id) -- mobile jammers (S-76)
		elseif (d.sensors.track or 0) > 0 then
			table.insert(c.trackers, id)
		elseif d.sensors.radar > 0 then
			table.insert(c.radarTrucks, id)
		end
	end
	-- extractors ordered but not started yet count too: a builder can still
	-- be walking to its deposit at the next think (the cap held only while
	-- the walk was short; S-104)
	for _, list in { c.builders, { c.commander } } do
		for _, id in list do
			for k, order in sim.orders.queue[id] or {} do
				-- (the head order stays while its frame is built: the frame counts then)
				local framed = k == 1 and order.started and (sim.build.target[id] or 0) ~= 0
				if order.kind == "build" and not framed then
					local od = sim.defs.unitByIndex[order.defIndex :: number]
					if od.extractor then
						c.extractors += 1
					-- factories too (S-193, G1: a second builder ordered a second
					-- bot lab while the first still walked to its site)
					elseif od.id == brain.prefix .. "botlab" then
						c.botFrames += 1
					elseif od.id == brain.prefix .. "advbotlab" then
						c.advBotFrames += 1
					elseif od.id == brain.prefix .. "advairfield" then
						c.advAirFrames += 1
					elseif od.id == airfield then
						c.airFrames += 1
					elseif od.id == shipyard then
						c.shipFrames += 1
					elseif od.id == advPlant then
						table.insert(c.advFrames, 0)
					elseif od.buildOptions and od.domain == "structure" then
						c.frames += 1 -- a vehicle plant
					end
				end
			end
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
	if c.enemyAirNearHome > 0 then
		brain.airNearAt = sim.tick
	end
	local plant = faction(brain, "vehplant", "vehplant")

	-- 1. builders
	local workers = table.clone(c.builders)
	if c.commander ~= 0 then
		table.insert(workers, 1, c.commander)
	end
	-- a builder getting no closer to its site gives up on it (S-133)
	for _, id in workers do
		local o = sim.build.order[id]
		local a = brain.approach[id]
		if o == nil then
			brain.approach[id] = nil
			continue
		end
		local d = math.sqrt((w.posX[id] - o.x) ^ 2 + (w.posZ[id] - o.z) ^ 2)
		if a == nil or a.x ~= o.x or a.z ~= o.z then
			brain.approach[id] = { x = o.x, z = o.z, best = d, at = sim.tick }
		elseif d < a.best - 8 then
			a.best, a.at = d, sim.tick
		elseif sim.tick - a.at > Skirmish.STALL_TICKS then
			if Skirmish.giveUpHook then
				Skirmish.giveUpHook(brain, id, o, d, a.best)
			end
			submit(sim, brain.player, { cmdType = CT.STOP, flags = 0, unitIds = { id } })
			local g = (sim.map :: Passability.PassMap).grid
			local gx, gz = g:cellAt(o.x, o.z)
			brain.claims[g:index(gx, gz)] = sim.tick + Skirmish.BAD_SITE_TICKS
			brain.approach[id] = nil
			brain.gaveUp += 1
		end
	end
	local cfg = brain.cfg
	-- power is short if it stalled in the last POWER_MEMORY ticks (watched
	-- every tick in Skirmish.tick): the stall ratio reads 1 for a moment
	-- whenever a builder has just finished (its demand is gone), which is
	-- exactly when the AI picks the next job; deciding on that moment made
	-- mirrored players choose differently by when they think (S-31)
	local powerShort = sim.tick - brain.powerShortAt <= Skirmish.POWER_MEMORY
	local supplyShort = sim.tick - brain.supplyShortAt <= Skirmish.POWER_MEMORY
	local plantsWanted = if cfg.secondPlant and acc.supply.stored > cfg.secondPlantSupply and c.extractors >= cfg.secondPlantExtractors then 2 else 1
	-- hard extras come once the economy and an army stand
	local established = c.extractors >= 6 and #c.army >= 6 and acc.supply.stored >= 200
	local turretsWanted = if cfg.defenses > 0 then math.min(cfg.defenses + c.farExtractors // 2, Skirmish.MAX_TURRETS) else 0
	-- hard: builders only assisting a factory leave it for these (the
	-- airfield and shipyard are the Command Vehicle's to build)
	local wantAir = cfg.air and #c.factories > 0 and (established or (cfg.earlyAir and c.extractors >= 2)) and #c.airfields + c.airFrames == 0
	local wantNaval = cfg.naval and brain.seaX ~= nil and #c.factories > 0 and established and #c.shipyards + c.shipFrames == 0
	local wantTurret = c.turrets < turretsWanted and #c.factories > 0 and c.extractors >= 5 and #c.army >= 4
	-- normal: once two generators stand, an army before anything else
	-- (S-57): builders start no new job until the plant has rolled out
	-- `tanksBeforeGen3` units; other jobs would split the power and stall
	-- them. (Sending the builders to help the plant gave mirrored players
	-- a side bias: east won 9–11 of 12 Normal mirrors.)
	-- the power its factories draw building at full speed: their build
	-- power times a tank's power per work unit (S-94: plants build twice as
	-- fast as before, so they want about 3 generators each, not 1)
	local factoryPower = 0
	for _, f in c.factories do
		factoryPower += (unitDef(sim, f).buildPower or 0) * Skirmish.POWER_PER_WORK
	end
	-- the builders' draw too (S-114): the Command Vehicle and the workers
	local builderPower = 0
	for _, list in { c.builders, { c.commander } } do
		for _, b in list do
			if b ~= 0 and w.slot[b] then
				builderPower += (unitDef(sim, b).buildPower or 0) * Skirmish.BUILDER_POWER_PER_WORK
			end
		end
	end
	-- (but not while power stalls below ARMY_FIRST_RATIO: the plant would
	-- never finish those tanks, the builders would go on to extractors that
	-- draw more, and no generator would come; S-94)
	local armyFirst = brain.tanksFirst > 0 and c.generators >= 2 and #c.army < brain.tanksFirst and #c.factories > 0
		and sim.tick - brain.powerLowAt > Skirmish.POWER_MEMORY
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
			local x, z = spotNear(brain, plant, brain.homeX + brain.toward * 90, brain.homeZ, id)
			if x and z then
				build(brain, id, plant, x, z, Skirmish.enemyFacing(brain))
				c.frames += 1
				continue
			end
		end
		if isCommander and wantAir then
			-- hard: an airfield behind the base (S-17)
			local field = faction(brain, "airfield", "airfield")
			local x, z = spotNear(brain, field, brain.homeX - brain.dirX * 80, brain.homeZ - brain.dirZ * 80, id)
			if x and z then
				build(brain, id, field, x, z, 0)
				c.airFrames += 1
				continue
			end
		end
		if isCommander and wantNaval and brain.seaX and brain.seaZ then
			-- hard: a shipyard on the nearby sea (S-17)
			local yard = faction(brain, "shipyard", "shipyard")
			local x, z = spotNear(brain, yard, brain.seaX :: number, brain.seaZ :: number, id)
			if x and z then
				build(brain, id, yard, x, z, 0)
				c.shipFrames += 1
				continue
			end
		end
		if not isCommander and (cfg.barriers or 0) > c.barriers and established and #c.factories > 0 then
			-- Order hard: a wall of Barrier segments across the front (S-101)
			local n = cfg.barriers :: number
			local off = (c.barriers - (n - 1) / 2) * 8
			local cx = brain.homeX + brain.dirX * 140 - brain.dirZ * off
			local cz = brain.homeZ + brain.dirZ * 140 + brain.dirX * off
			local x, z = spotNear(brain, "ord_barrier", cx, cz, id)
			if x and z then
				build(brain, id, "ord_barrier", x, z, 0)
				c.barriers += 1
				continue
			end
		end
		if not isCommander and wantTurret and c.turrets < turretsWanted then
			-- hard: gun turrets, first on the way home, then by far extractors (S-17);
			-- the laser towers since S-157
			local turret = faction(brain, "sentry_tower", "guard")
			local cx, cz = brain.homeX + brain.dirX * 110, brain.homeZ + brain.dirZ * 110
			if c.turrets >= cfg.defenses and brain.lastFarX and brain.lastFarZ then
				cx, cz = brain.lastFarX :: number, brain.lastFarZ :: number
			end
			local x, z = spotNear(brain, turret, cx, cz, id)
			if x and z then
				build(brain, id, turret, x, z, 0)
				c.turrets += 1
				continue
			end
		end
		if cfg.radar and not isCommander and #c.factories > 0 and c.extractors >= 2 and c.radarTowers == 0 then
			-- radar: early warning for the artillery (S-7)
			local tower = faction(brain, "watchtower", "eye")
			local x, z = spotNear(brain, tower, brain.homeX + brain.toward * 120, brain.homeZ + 60, id)
			if x and z then
				build(brain, id, tower, x, z, 0)
				c.radarTowers += 1
				continue
			end
		end
		if cfg.antiAir and c.enemyAirNearHome > 0 and c.samSites == 0 then
			-- enemy aircraft over the base: an IR SAM site (S-7)
			local site = faction(brain, "vigil", "thorn")
			local x, z = spotNear(brain, site, brain.homeX, brain.homeZ - 50, id)
			if x and z then
				build(brain, id, site, x, z, 0)
				c.samSites += 1
				continue
			end
		end
		if cfg.botLab and not isCommander and #c.factories > 0 and c.extractors >= 6 and #c.army >= 4 and #c.botLabs + c.botFrames == 0 then
			-- (S-187) a Bot Lab / Pit beside the plant: bots in the mix; only
			-- once 6 extractors and an army stand (S-193, G1: one factory type
			-- early, not a plant and two labs; without `established`'s stored
			-- supply, which an aggressive AI never keeps)
			local lab = brain.prefix .. "botlab"
			local x, z = spotNear(brain, lab, brain.homeX + brain.toward * 60, brain.homeZ - 110, id)
			if x and z then
				build(brain, id, lab, x, z, Skirmish.enemyFacing(brain))
				c.botFrames += 1
				continue
			end
		end
		if cfg.botLab and not isCommander and #c.botLabs > 0 and #c.advFactories > 0 and #c.advBotLabs + c.advBotFrames == 0 and acc.supply.stored > (cfg.advPlantSupply or Skirmish.ADV_PLANT_SUPPLY) then
			-- (S-187) the advanced lab: Fatboys / Centurions
			local lab = brain.prefix .. "advbotlab"
			local x, z = spotNear(brain, lab, brain.homeX - brain.toward * 40, brain.homeZ - 130, id)
			if x and z then
				build(brain, id, lab, x, z, Skirmish.enemyFacing(brain))
				c.advBotFrames += 1
				continue
			end
		end
		if cfg.advAir and not isCommander and #c.airfields > 0 and #c.advFactories > 0 and #c.advAirfields + c.advAirFrames == 0 and acc.supply.stored > Skirmish.ADV_PLANT_SUPPLY then
			-- (S-187, air role) the advanced airfield: Liche / Dragon
			local field = brain.prefix .. "advairfield"
			local x, z = spotNear(brain, field, brain.homeX - brain.dirX * 140, brain.homeZ - brain.dirZ * 140, id)
			if x and z then
				build(brain, id, field, x, z, 0)
				c.advAirFrames += 1
				continue
			end
		end
		if cfg.techUp and not isCommander and #c.factories > 0 and #c.advFactories + #c.advFrames == 0 and acc.supply.stored > (cfg.advPlantSupply or Skirmish.ADV_PLANT_SUPPLY) then
			-- tech up: the Advanced Vehicle Plant (fire-control radar, MLRS; S-7)
			local adv = faction(brain, "advvehplant", "advvehplant")
			local x, z = spotNear(brain, adv, brain.homeX - brain.toward * 40, brain.homeZ + 120, id)
			if x and z then
				build(brain, id, adv, x, z, Skirmish.enemyFacing(brain))
				table.insert(c.advFrames, 0)
				continue
			end
		end
		-- missile refills draw power too (S-47): an AI under air attack whose
		-- SAMs sit empty wants the generators for them (S-57)
		-- normal: no third generator before its first tanks (S-57)
		local genAllowed = not armyFirst
		-- (counted in generators, frames included, not income: a generator
		-- finishing a few ticks earlier on one side of a mirror must not
		-- change the next job; S-94)
		-- contested deposits only with an escort ready (Chaos, S-97)
		local escortReady = false
		local accept = nil
		if cfg.contested then
			local free = 0
			for _, a in c.army do
				if not brain.attacking[a] and not brain.escorts[a] then
					free += 1
				end
			end
			escortReady = free >= cfg.escorts
			accept = function(_cell: number, dx: number, dz: number): boolean
				return escortReady or not Skirmish.contested(brain, dx, dz)
			end
		end
		local cell = if c.extractors < cfg.maxExtractors then freeDeposit(brain, accept, id) else nil
		-- generators (S-114, client request 48: the AI built generator after
		-- generator while deposits stood free): two first; then, while power
		-- doesn't stall, a free deposit comes first when supply stalls or
		-- extractors trail generators; generators only up to the planned
		-- need, and one more only while power stalls and supply doesn't
		-- (counts and stall memories, never the moment's income: mirror-safe,
		-- S-31 / S-94)
		local genWanted = math.ceil((factoryPower + builderPower + 20 + math.min(c.refillPower, Skirmish.REFILL_POWER_CAP)) / Skirmish.GENERATOR_POWER)
		local extractorFirst = cell ~= nil and (c.extractors < c.generators or (supplyShort and not powerShort))
		local genCap = genWanted + (if powerShort and not supplyShort then Skirmish.GEN_SLACK else 0)
		local wantGen = c.generators < Skirmish.MIN_GENERATORS or (not extractorFirst and c.generators < genCap)
		if genAllowed and wantGen then
			local gen = faction(brain, "solar", "solar")
			local x, z = Skirmish.blockSpot(brain, gen, c.generators, id)
			if x == nil then
				x, z = spotNear(brain, gen, brain.homeX - brain.toward * 60, brain.homeZ, id)
			end
			if x and z then
				build(brain, id, gen, x, z, 0)
				c.generators += 1
				continue
			end
		end
		if cell then
			local g = (sim.map :: Passability.PassMap).grid
			local x, z = Skirmish.depositPoint(g, cell) -- the patch's centre: the 2 × 2 extractor sits exactly on it (S-184)
			-- the Command Vehicle only takes deposits near home
			local far = (x - brain.homeX) ^ 2 + (z - brain.homeZ) ^ 2 >= Skirmish.HOME_RADIUS ^ 2
			if not isCommander or not far then
				brain.claims[cell] = sim.tick
				build(brain, id, faction(brain, "extractor", "extractor"), x, z, 0)
				if cfg.maxExtractors < math.huge then
					c.extractors += 1 -- counts toward the cap at once
				end
				if cfg.contested and Skirmish.contested(brain, x, z) then
					brain.escortWanted[id] = sim.tick -- Chaos: the escort goes with it (S-97)
					brain.lastFarX, brain.lastFarZ = x, z
				elseif cfg.escorts > 0 and not cfg.contested and (x - brain.homeX) ^ 2 + (z - brain.homeZ) ^ 2 > Skirmish.ESCORT_RADIUS ^ 2 then
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
	-- T2 builders (S-101): a shield over the base, Pinpointers behind it,
	-- then (Order hard, when rich) a Citadel toward the enemy
	-- extractors already under an upgrade frame (S-108)
	local upgrading: { [number]: boolean } = {}
	for _, old in sim.build.upgrading do
		upgrading[old] = true
	end
	local adv = faction(brain, "advextractor", "advextractor")
	local advDef = sim.defs.units[adv]
	local layers = (sim.map :: Passability.PassMap).layers
	local lg = layers.grid
	-- where a T1 extractor's upgrade goes: centred on it, over its patch (S-184)
	local function depositOf(t1: number): (number?, number?)
		local d = unitDef(sim, t1)
		if PlacementRules.supplyUnder(layers, d.footprint, w.posX[t1], w.posZ[t1]) <= 0 then
			return nil, nil
		end
		return w.posX[t1], w.posZ[t1]
	end
	-- the safest upgrade: nearest home, no known enemy near, nobody sent there lately
	local function nextUpgrade(): (number?, number?)
		local bestX, bestZ, bestD = nil, nil, math.huge
		for _, t1 in c.t1Extractors do
			if upgrading[t1] then
				continue
			end
			local x, z = depositOf(t1)
			if x == nil or z == nil then
				continue
			end
			local cell = lg:index(lg:cellAt(x, z))
			local d2 = (x - brain.homeX) ^ 2 + (z - brain.homeZ) ^ 2
			if d2 < bestD and (brain.claims[cell] or -math.huge) + Skirmish.CLAIM_TICKS < sim.tick
				and Skirmish.enemyValueNear(brain, x, z, Skirmish.CONTESTED_RADIUS) == 0
				and Placement.check(sim, advDef, x, z, brain.player, brain.ally) then
				bestX, bestZ, bestD = x, z, d2
			end
		end
		return bestX, bestZ
	end
	local function count(defId: string): number
		return c.built[defId] or 0
	end
	for _, id in c.t2Builders do
		if not idleBuilder(sim, id) then
			continue
		end
		local ux, uz = nextUpgrade()
		if ux and uz then
			-- in-place upgrade (S-108): straight on the deposit, not via spotNear
			brain.claims[lg:index(lg:cellAt(ux, uz))] = sim.tick
			build(brain, id, adv, ux, uz, 0)
			continue
		end
		local job, cx, cz = nil, 0, 0
		local heavy, battery = faction(brain, "bastion", "maw"), faction(brain, "sanction", "scourge")
		local flak, beam = faction(brain, "lumen", "hailstorm"), faction(brain, "radiance", "bulwark") -- Bulwark in Inferno's place (S-157)
		local umbrella, silo = faction(brain, "providence", "cerberus"), faction(brain, "reckoning", "ragnarok")
		local longRadar = faction(brain, "beacon", "allseer")
		if c.shields == 0 then
			job, cx, cz = faction(brain, "phalanx", "carapace"), brain.homeX + brain.toward * 40, brain.homeZ
			c.shields += 1
		elseif c.pinpointers < Skirmish.PINPOINTERS then
			job, cx, cz = faction(brain, "witness", "augur"), brain.homeX - brain.toward * 70, brain.homeZ + (if c.pinpointers == 0 then 60 else -60)
			c.pinpointers += 1
		elseif count(heavy) == 0 then
			-- T2 defences (S-106): a heavy turret toward the enemy, a missile
			-- battery behind it against artillery, flak once enemy aircraft
			-- are known, a beam tower
			job, cx, cz = heavy, brain.homeX + brain.dirX * 110, brain.homeZ + brain.dirZ * 110
			c.built[heavy] = 1
		elseif count(battery) == 0 then
			job, cx, cz = battery, brain.homeX + brain.dirX * 50, brain.homeZ + brain.dirZ * 50
			c.built[battery] = 1
		elseif count(flak) == 0 and c.enemyAir > 0 then
			job, cx, cz = flak, brain.homeX, brain.homeZ
			c.built[flak] = 1
		elseif count(beam) == 0 then
			job, cx, cz = beam, brain.homeX + brain.dirX * 90, brain.homeZ + brain.dirZ * 90
			c.built[beam] = 1
		elseif count(longRadar) == 0 then
			-- long-range radar behind the beam tower (S-207, the user's H33:
			-- the AI's Radiance never shot blips; its one T1 radar tower
			-- didn't reach the beam's range)
			job, cx, cz = longRadar, brain.homeX + brain.dirX * 30, brain.homeZ + brain.dirZ * 30 + 50
			c.built[longRadar] = 1
		elseif count(umbrella) < (if c.enemySilo then 2 else 1) then
			-- the anti-nuke umbrella (S-110, S-111)
			job, cx, cz = umbrella, brain.homeX - brain.dirX * 40, brain.homeZ - brain.dirZ * 40 + (if count(umbrella) == 0 then 0 else 80)
			c.built[umbrella] = count(umbrella) + 1
		elseif cfg.nuke and count(silo) == 0 and acc.supply.stored >= acc.supply.storage * Skirmish.NUKE_RICH and (not cfg.citadel or c.citadels > 0) then
			job, cx, cz = silo, brain.homeX - brain.dirX * 120, brain.homeZ - brain.dirZ * 120
			c.built[silo] = 1
		elseif cfg.citadel and c.citadels == 0 and acc.supply.stored >= math.min(Skirmish.CITADEL_SUPPLY, acc.supply.storage * 0.9) then
			job, cx, cz = "ord_citadel", brain.homeX + brain.dirX * 120, brain.homeZ + brain.dirZ * 120
			c.citadels += 1
		end
		if job then
			local x, z = spotNear(brain, job, cx, cz, id)
			if x and z then
				build(brain, id, job, x, z, 0)
			end
		end
	end
	local aaUnit = faction(brain, "halo", "hornet")
	local radarUnit = faction(brain, "oracle", "watcher")
	local trackerUnit = faction(brain, "arbiter", "stalker")
	local aaWanted = if cfg.antiAir then math.min(math.ceil(c.enemyAir / 2), Skirmish.MAX_AA) else 0
	local aaPlanned = c.aa + queued(sim, c.factories, aaUnit)
	local radarPlanned = #c.radarTrucks + queued(sim, c.factories, radarUnit)
	local scoutUnit = faction(brain, "herald", "jackal")
	local scoutPlanned = #c.scouts + queued(sim, c.factories, scoutUnit)
	-- under air attack with SAMs waiting for missiles and power stalling:
	-- no new army units until they refill (the economy shares power evenly,
	-- so new production would keep the SAMs empty; S-57)
	local holdArmy = sim.tick - brain.airNearAt <= Skirmish.AIR_MEMORY and c.refillPower > 0 and acc.power.ratio < 0.5
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
			if armyFirst then
				item = tank -- normal: its first tanks before more workers (S-57)
			elseif c.workers + queuedWorkers < cfg.workers then
				item = worker
				queuedWorkers += 1
			elseif aaPlanned < aaWanted then
				item = aaUnit -- anti-air against the aircraft the team knows (S-7)
				aaPlanned += 1
			elseif cfg.radar and radarPlanned < 1 and c.workers >= cfg.workers and not armyFirst then
				item = radarUnit -- radar to escort the waves (S-7)
				radarPlanned += 1
			elseif cfg.scout and scoutPlanned < 1 and c.workers >= cfg.workers and sim.tick - brain.scoutAt >= Skirmish.SCOUT_EVERY then
				item = scoutUnit -- a look at the enemy's defences (S-105)
				scoutPlanned += 1
				brain.scoutAt = sim.tick
			elseif cfg.armyCooldown > 0 and sim.tick - brain.lastArmyQueued < cfg.armyCooldown * 15 then
				break -- easy: no army unit this soon after the last
			elseif holdArmy then
				break
			elseif #c.army >= cfg.maxArmy then
				break -- easy: a small army (S-57)
			elseif cfg.airShare and #c.airfields > 0 and brain.rng:chance(cfg.airShare) then
				break -- (S-187, air role) the airfield takes this share of the power
			else
				-- counters (S-187): artillery against known turrets, fast units
				-- against known artillery
				local artyChance = cfg.artyChance + (if c.enemyTurrets >= 3 then 0.2 else 0)
				item = if brain.rng:chance(artyChance) then arty else tank
				if item == tank and c.enemyArty >= 3 and brain.rng:chance(0.3) then
					item = scoutUnit -- raiders against artillery
				end
				if item == tank and cfg.locustShare and brain.rng:chance(cfg.locustShare) then
					item = "chs_locust" -- Chaos numbers (S-76)
				end
				brain.lastArmyQueued = sim.tick
			end
			queueItem(f, item)
		end
	end
	local trackerPlanned = #c.trackers + queued(sim, c.advFactories, trackerUnit)
	local jammerPlanned = #c.jammers + queued(sim, c.advFactories, "chs_shroud")
	local mobileUnit = faction(brain, "custodian", "chimera")
	local mobilePlanned = #c.mobileAntiNukes + queued(sim, c.advFactories, mobileUnit)
	local t2BuilderUnit = faction(brain, "architect", "forgemaster")
	local t2Planned = #c.t2Builders + queued(sim, c.advFactories, t2BuilderUnit)
	for _, f in c.advFactories do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			local item
			if cfg.t2Builder and t2Planned < 1 and acc.supply.stored >= Skirmish.ADV_BUILDER_SUPPLY then
				item = t2BuilderUnit -- shield and Pinpointers (S-101)
				t2Planned += 1
			elseif c.enemySilo and mobilePlanned < 1 then
				item = mobileUnit -- an enemy silo is known: a mobile anti-nuke for the army (S-111)
				mobilePlanned += 1
			elseif trackerPlanned < 1 then
				item = trackerUnit -- fire-control radar for the artillery (S-7)
				trackerPlanned += 1
			elseif cfg.jammer and jammerPlanned < 1 then
				item = "chs_shroud" -- a jammer to cover the waves (S-76)
				jammerPlanned += 1
			else
				item = if brain.rng:chance(0.5) then faction(brain, "judgement", "hydra") else faction(brain, "paladin", "juggernaut")
				if brain.prefix == "chs_" and brain.rng:chance(if c.enemyTurrets >= 3 then 0.35 else 0.15) then
					item = "chs_tzar" -- (S-187) heavy plasma, more against defences
				elseif cfg.wardenShare and brain.rng:chance(cfg.wardenShare) then
					item = "ord_warden" -- Order's deployable guns (S-76)
				elseif cfg.minotaurShare and brain.rng:chance(cfg.minotaurShare) then
					item = "chs_minotaur" -- Chaos siege (S-76)
				end
			end
			queueItem(f, item)
		end
	end

	-- bot labs (S-187): scouts and the light combat bot, AA bots against
	-- aircraft, a helper or two; the advanced lab its heavy bot
	local botScout, botLine, botAA, botHelp = faction(brain, "glint", "skitter"), faction(brain, "mace", "thug"), faction(brain, "kestrel", "needle"), faction(brain, "lazarus", "graverobber")
	local helpers = queued(sim, c.botLabs, botHelp) + (c.built[botHelp] or 0)
	for _, id in w.ids do
		if w.owner[id] == brain.player and sim.defs.unitByIndex[w.defIndex[id]].id == botHelp then
			helpers += 1
		end
	end
	for _, f in c.botLabs do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			if holdArmy or #c.army >= cfg.maxArmy then
				break
			end
			local item
			if c.enemyAir > 2 and brain.rng:chance(0.3) then
				item = botAA
			elseif helpers < 2 then
				item = botHelp
				helpers += 1
			elseif cfg.role == "spam" or c.enemyArty >= 3 then
				item = if brain.rng:chance(0.5) then botScout else botLine
			else
				item = if brain.rng:chance(0.25) then botScout else botLine
			end
			queueItem(f, item)
		end
	end
	for _, f in c.advBotLabs do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			queueItem(f, faction(brain, "fatboy", "centurion"))
		end
	end
	for _, f in c.advAirfields do
		local q = sim.build.queue[f] or {}
		for _ = #q + 1, cfg.queue do
			-- (S-187, air role) Liche / Dragon, and T2 aircraft
			local item = if brain.rng:chance(0.4) then faction(brain, "liche", "dragon") elseif brain.rng:chance(0.5) then faction(brain, "archon", "manticore") else faction(brain, "phantom", "behemoth")
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
	-- the scout (S-105): idle, it loops round every enemy start
	for _, id in c.scouts do
		if w.orderId[id] ~= 0 then
			continue
		end
		local flags = 0
		for _, st in brain.enemyStarts do
			for k = 0, 3 do
				local a = (k + 0.5) * math.pi / 2
				local px = math.clamp(st[1] + math.cos(a) * Skirmish.SCOUT_RADIUS, g.originX + 24, g.originX + g.sizeX - 24)
				local pz = math.clamp(st[2] + math.sin(a) * Skirmish.SCOUT_RADIUS, g.originZ + 24, g.originZ + g.sizeZ - 24)
				local cell, ox, oz = g:encode(px, pz)
				submit(sim, brain.player, { cmdType = CT.MOVE, flags = flags, unitIds = { id }, cell = cell, offX = ox, offZ = oz })
				flags = Schema.CmdFlag.QUEUE
			end
		end
	end
	-- nukes (S-110): a silo with a warhead launches at the best known
	-- target (structures and the Command Vehicle first), at most every
	-- NUKE_EVERY ticks
	if #c.silos > 0 and targetX and targetZ and sim.tick - brain.nukeAt >= Skirmish.NUKE_EVERY then
		for _, silo in c.silos do
			if (w.wStock[World.slotKey(silo, 1)] or 0) > 0 then
				local cell, ox, oz = g:encode(targetX, targetZ)
				submit(sim, brain.player, { cmdType = CT.ATTACK_GROUND, flags = 0, unitIds = { silo }, cell = cell, offX = ox, offZ = oz })
				brain.nukeAt = sim.tick
				brain.nukes += 1
				break
			end
		end
	end
	-- retreat (S-92): a wave out in the field facing known enemy forces
	-- worth more than RETREAT_RATIO times its own value falls back
	if cfg.retreat and #wave > 0 then
		local wv, wx, wz = 0, 0, 0
		for _, id in wave do
			local v = Skirmish.value(unitDef(sim, id))
			wv += v
			wx += w.posX[id] * v
			wz += w.posZ[id] * v
		end
		wx, wz = wx / wv, wz / wv
		if (wx - brain.homeX) ^ 2 + (wz - brain.homeZ) ^ 2 > brain.recallRadius ^ 2 then
			local ev = Skirmish.enemyValueNear(brain, wx, wz, Skirmish.RETREAT_RADIUS)
			if ev > wv * Skirmish.RETREAT_RATIO then
				local rx, rz = brain.homeX + brain.toward * brain.rallyDist, brain.homeZ
				local cell, ox, oz = g:encode(rx, rz)
				for i = 1, #wave, 200 do
					submit(sim, brain.player, { cmdType = CT.MOVE, flags = 0, unitIds = table.move(wave, i, math.min(i + 199, #wave), 1, {}), cell = cell, offX = ox, offZ = oz })
				end
				for _, id in wave do
					brain.attacking[id] = nil
				end
				brain.waveValue = math.max(brain.waveValue, ev * Skirmish.RETREAT_MARGIN)
				brain.lastRetreatAt = sim.tick
				brain.retreats += 1
				wave = {}
			end
		end
	end
	local newWave = false
	-- enemy aircraft came near home lately: half the mobile SAMs (at least
	-- one) stay home as base air defence instead of leaving with a wave (S-57)
	local guardHome: { [number]: boolean } = {}
	if sim.tick - brain.airNearAt <= Skirmish.AIR_MEMORY then
		local keep = math.ceil(#c.aaTrucks / 2)
		for _, id in c.aaTrucks do
			if keep > 0 and not brain.attacking[id] then
				guardHome[id] = true
				keep -= 1
			end
		end
	end
	-- normal: an enemy wave near the base brings the whole army home (S-57)
	local recalled = false
	if cfg.recall then
		local n, cx, cz = Skirmish.incoming(brain)
		if n >= Skirmish.RECALL_MIN then
			recalled = true
			if #wave > 0 or sim.tick >= brain.recallUntil - Skirmish.RECALL_HOLD + Skirmish.THINK_PERIOD * 3 then
				-- (re-ordered every 3 s while it lasts, not every think)
				local all = table.clone(home)
				table.move(wave, 1, #wave, #all + 1, all)
				fight(all, cx, cz)
				brain.recallUntil = sim.tick + Skirmish.RECALL_HOLD
			end
			brain.attacking = {}
			wave = {}
			home = {}
		end
	end
	-- waves leave only in the first think of each WAVE_ALIGN window: mirrored
	-- players reach the wave size within a think of each other, and the one
	-- whose think came first used to leave first and attack into a defended
	-- base every time (a side bias, S-57)
	local onGrid = sim.tick % Skirmish.WAVE_ALIGN < cfg.think
	local mayAttack = onGrid and sim.tick >= cfg.firstAttack and sim.tick - brain.lastWaveAt >= cfg.waveInterval and sim.tick >= brain.recallUntil
		and sim.tick - brain.lastRetreatAt >= Skirmish.RETREAT_HOLD
	local homeValue = 0
	for _, id in home do
		if not guardHome[id] then
			homeValue += Skirmish.value(unitDef(sim, id))
		end
	end
	-- the known defence where the wave would go (S-105): it leaves only
	-- worth ATTACK_MARGIN times that, or once massed to MASS_SHARE of the cap
	local outweighs = true
	if cfg.outweigh and homeValue >= brain.waveValue and mayAttack then
		local defense = Skirmish.enemyValueNear(brain, targetX or brain.enemyX, targetZ or brain.enemyZ, Skirmish.DEFENSE_RADIUS)
		local cap = sim.match.unitCap
		local massed = #home >= (if cap > 0 then math.min(Skirmish.MASS_UNITS, cap * Skirmish.MASS_SHARE) else Skirmish.MASS_UNITS)
		outweighs = homeValue >= defense * (cfg.attackMargin or Skirmish.ATTACK_MARGIN) or massed
		if not outweighs then
			brain.held += 1
		end
	end
	-- teamwork (S-187): a wave an ally just sent is joined by an army worth
	-- half a wave; an ally's call for help draws half the army at home
	local team = if cfg.teamwork then teamOf(brain) else nil
	local join = team ~= nil and team.waveFrom ~= brain.player and sim.tick - team.waveTick <= Skirmish.TEAM_JOIN_TICKS
		and homeValue >= brain.waveValue * 0.5 and sim.tick >= cfg.firstAttack and sim.tick >= brain.recallUntil
	local helpAlly = team ~= nil and team.helpFrom ~= brain.player and sim.tick - team.helpTick <= Skirmish.TEAM_HELP_TICKS
	if team and threatX and threatZ then
		team.helpX, team.helpZ, team.helpTick, team.helpFrom = threatX, threatZ, sim.tick, brain.player
	end
	if recalled then
		-- defending: nothing else this think
	elseif threatX and threatZ then
		fight(home, threatX, threatZ) -- defend
	elseif helpAlly and team and #home >= 4 then
		-- an ally's base is under attack: half the army goes
		local half = {}
		for i, id in home do
			if i % 2 == 0 and not guardHome[id] then
				table.insert(half, id)
			end
		end
		fight(half, team.helpX, team.helpZ)
	elseif (homeValue >= brain.waveValue and mayAttack and outweighs) or join then
		-- easy (a wave interval) sends only the wave's value; the others wait
		local cap = if cfg.waveInterval > 0 then brain.waveValue else math.huge
		local stay = {}
		local sentValue = 0
		for _, id in home do
			if guardHome[id] or sentValue >= cap then
				table.insert(stay, id)
			else
				brain.attacking[id] = true
				table.insert(wave, id)
				sentValue += Skirmish.value(unitDef(sim, id))
			end
		end
		home = stay
		brain.lastWaveAt = sim.tick
		if team and not join then
			team.waveTick, team.waveFrom = sim.tick, brain.player -- (S-187) the allies may join
		end
		newWave = true
		brain.waves += 1
		brain.waveSize += cfg.waveGrowth
		brain.waveValue += cfg.waveGrowth * Skirmish.UNIT_VALUE
	else
		local idle = {}
		for _, id in home do
			if w.orderId[id] == 0 then
				table.insert(idle, id)
			end
		end
		local rx, rz = brain.homeX + brain.toward * brain.rallyDist, brain.homeZ
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
	-- raids (S-187, aggressive): a few fast units at the nearest known enemy
	-- extractor, every RAID_EVERY ticks, between waves
	if cfg.raid and #c.enemyExtractors > 0 and sim.tick - brain.raidAt >= Skirmish.RAID_EVERY then
		local raiders = {}
		for _, id in home do
			local d = unitDef(sim, id)
			if #raiders < Skirmish.RAID_UNITS and not guardHome[id] and d.movement and d.movement.maxSpeed >= 40 and bit32.band(d.categoryMask, BIT.ANTIAIR) == 0 then
				table.insert(raiders, id)
			end
		end
		if #raiders >= 2 then
			local best, bestD = nil, math.huge
			for _, e in c.enemyExtractors do
				local d = (e[1] - brain.homeX) ^ 2 + (e[2] - brain.homeZ) ^ 2
				if d < bestD then
					best, bestD = e, d
				end
			end
			if best then
				for _, id in raiders do
					brain.attacking[id] = true
				end
				fight(raiders, best[1], best[2])
				brain.raidAt = sim.tick
			end
		end
	end
	-- the wave re-targets every 5 s. Its tanks attack-move; its artillery
	-- guards the lead tank, so it follows the push and fires at whatever is
	-- in range instead of stopping at its own long range while the tanks
	-- go in alone (attack-move holds at weapon range, S-14). Radar and
	-- fire-control vehicles guard the lead too.
	if #wave > 0 and (newWave or sim.tick - brain.lastWaveOrder >= Skirmish.THINK_PERIOD * 5) then
		brain.lastWaveOrder = sim.tick
		local front, support = {}, {}
		for _, id in wave do
			if bit32.band(unitDef(sim, id).categoryMask, BIT.ARTILLERY) ~= 0 then
				table.insert(support, id)
			else
				table.insert(front, id)
			end
		end
		local lead = if #front > 0 then front[1] else wave[1]
		local tx, tz = targetX or brain.enemyX, targetZ or brain.enemyZ
		if #front >= Skirmish.LANE_MIN and (cfg.lanes or 1) >= 2 then
			-- two lanes (S-76): every second unit comes round a flank, through
			-- a waypoint off the straight line, then joins the attack
			local mx, mz = (brain.homeX + tx) / 2, (brain.homeZ + tz) / 2
			local dx, dz = tx - brain.homeX, tz - brain.homeZ
			local dl = math.max(math.sqrt(dx * dx + dz * dz), 1)
			-- the flank side in world terms (+z on even waves): mirrored
			-- players flank the same side of the map, not each its own left
			local px, pz = -dz / dl, dx / dl
			local side = if brain.waves % 2 == 0 then 1 else -1
			if pz < 0 or (pz == 0 and px < 0) then
				side = -side
			end
			local wx = math.clamp(mx + px * Skirmish.FLANK_OFFSET * side, g.originX + 40, g.originX + g.sizeX - 40)
			local wz = math.clamp(mz + pz * Skirmish.FLANK_OFFSET * side, g.originZ + 40, g.originZ + g.sizeZ - 40)
			local direct, flank = {}, {}
			for i, id in front do
				if i % 2 == 0 and not brain.flanked[id] then
					if (w.posX[id] - wx) ^ 2 + (w.posZ[id] - wz) ^ 2 < 120 ^ 2 then
						brain.flanked[id] = true -- round the flank: straight at the target from now
						table.insert(direct, id)
					else
						table.insert(flank, id)
					end
				else
					table.insert(direct, id)
				end
			end
			fight(direct, tx, tz)
			if #flank > 0 then
				fight(flank, wx, wz)
				local cell, ox, oz = g:encode(tx, tz)
				submit(sim, brain.player, { cmdType = CT.FIGHT, flags = Schema.CmdFlag.QUEUE, unitIds = flank, cell = cell, offX = ox, offZ = oz })
			end
			if #support > 0 then
				submit(sim, brain.player, { cmdType = CT.GUARD, flags = 0, unitIds = support, targetId = lead })
			end
		elseif #front > 0 then
			fight(front, targetX or brain.enemyX, targetZ or brain.enemyZ)
			if #support > 0 then
				submit(sim, brain.player, { cmdType = CT.GUARD, flags = 0, unitIds = support, targetId = lead })
			end
		else
			fight(wave, targetX or brain.enemyX, targetZ or brain.enemyZ)
		end
		local escorts = {}
		for _, list in { c.radarTrucks, c.trackers, c.jammers, c.mobileAntiNukes } do
			for _, id in list do
				table.insert(escorts, id)
			end
		end
		if #escorts > 0 then
			submit(sim, brain.player, { cmdType = CT.GUARD, flags = 0, unitIds = escorts, targetId = lead })
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
	local b = brain :: any
	if b.pending then
		if sim.pregame then
			-- the pre-game (S-169, S-171, S-174): once a human has picked (or
			-- there are none, or the pick time is over), its best spot of those
			-- left (a hint first), then ready; as commands, so a replay picks
			-- the same
			local pg = sim.pregame
			if not b.picked then
				local humans, humanPicked = false, false
				for _, pid in sim.playerOrder do
					if not sim.match.ai[pid] then
						humans = true
						humanPicked = humanPicked or pg.picks[pid] ~= nil
					end
				end
				if not humans or humanPicked or pg.autoPicked or pg.picks[brain.player] ~= nil then
					if pg.picks[brain.player] == nil then
						local x, z = Pregame.bestSpot(sim, brain.player)
						if x and z then
							local g = (sim.map :: Passability.PassMap).grid
							local cell, ox, oz = g:encode(x, z)
							submit(sim, brain.player, { cmdType = CT.START_POS, flags = 0, unitIds = {}, cell = cell, offX = ox, offZ = oz })
						end
					end
					submit(sim, brain.player, { cmdType = CT.READY, flags = 0, unitIds = {}, value = 1 })
					b.picked = true
				end
			end
			return
		end
		local real = Skirmish.new(sim, brain.player, b.pendingLevel) :: any
		table.clear(b)
		for k, v in real do
			b[k] = v
		end
	end
	if sim.match.eliminated[brain.player] or sim.cheats.aiPaused[brain.player] then
		return -- out, or paused by the AI cheat (S-102)
	end
	-- watched every tick, not only when thinking: which moments a think
	-- samples must not decide what it sees (S-31)
	local acc = sim.eco.accounts[brain.team]
	if acc and acc.power.ratio < 0.95 then
		brain.powerShortAt = sim.tick
	end
	if acc and acc.supply.ratio < 0.95 then
		brain.supplyShortAt = sim.tick -- (S-114, watched like power)
	end
	if acc and acc.power.ratio < Skirmish.ARMY_FIRST_RATIO then
		brain.powerLowAt = sim.tick -- (S-94; watched every tick like the stall, S-31)
	end
	if (sim.tick - brain.thinkOffset) % brain.cfg.think ~= 0 then
		return
	end
	think(brain)
end

return Skirmish
