--!strict
-- The unit encyclopedia's data (L-18): every buildable unit and structure
-- by role, with its other-faction counterpart, and the numbers its article
-- shows. Pure Luau over the shared defs (`Defs.load()`), so Lune tests it.
--
-- The defs have no role field: the roles below are guide section 13's
-- tables (one role, its Order and its Chaos units; a faction-only role
-- leaves the other side empty). A def no role lists still shows, under
-- "Other", so a new unit never breaks the page. A role may name a unit
-- the defs don't have yet (announced by the sim stream ahead of its def);
-- it shows once the def lands. Retired defs (`retired`, or nothing can
-- build them and they're not a Command Vehicle) don't show, and neither
-- side lists the other's missing or retired units as counterparts.
--
-- The numbers follow the in-game unit panel (client-B's Core/UnitStats):
-- damage per second = damage per shot × shots per reload ÷ reload, against
-- the weapon's main armor class (the first armor class in its priority).

local ArmorClasses = require("@shared/Defs/ArmorClasses")

local Codex = {}

export type Role = {
	name: string,
	section: string,
	tier: number,
	order: { string },
	chaos: { string },
}

-- The list's sections, in order; `structures` marks the ones the
-- Structures filter keeps.
Codex.SECTIONS = table.freeze({
	{ id = "command", name = "Command and workers", structures = false },
	{ id = "ground", name = "Ground", structures = false },
	{ id = "air", name = "Air", structures = false },
	{ id = "naval", name = "Naval", structures = false },
	{ id = "defence", name = "Defences", structures = true },
	{ id = "sensors", name = "Sensors and EW", structures = true },
	{ id = "strategic", name = "Strategic", structures = true },
	{ id = "economy", name = "Economy", structures = true },
	{ id = "factory", name = "Factories", structures = true },
	{ id = "other", name = "Other", structures = false },
})

local function r(section: string, name: string, tier: number, order: { string }, chaos: { string }): Role
	return { name = name, section = section, tier = tier, order = order, chaos = chaos }
end

-- Units the sim stream announced ahead of their defs (the decision that
-- adds them): the roles may name them before the defs reach this branch.
-- Remove each once its def is on main.
Codex.ANNOUNCED = table.freeze({
	ord_courier = "S-219",
	chs_buzzard = "S-219",
	ord_ark = "S-219",
	chs_charon = "S-219",
})

-- Guide 13.1-13.5 plus the economy, factories and the units added since.
Codex.ROLES = {
	r("command", "Command Vehicle", 0, { "ord_sovereign" }, { "chs_warlord" }),
	r("command", "Ground worker", 1, { "ord_mason" }, { "chs_scrapper" }),
	r("command", "Advanced ground worker", 2, { "ord_architect" }, { "chs_forgemaster" }),
	r("command", "Air worker", 1, { "ord_skywright" }, { "chs_vulture" }),
	r("command", "Advanced air worker", 2, { "ord_zenith" }, { "chs_condor" }),
	r("command", "Naval worker", 1, { "ord_tidewright" }, { "chs_wrecker" }),
	r("command", "Advanced naval worker", 2, { "ord_harbormaster" }, { "chs_reaver" }),
	r("command", "Bot constructor", 1, { "ord_artisan" }, { "chs_tinker" }),
	r("command", "Field engineer (repair, resurrect, reclaim)", 1, { "ord_lazarus" }, { "chs_graverobber" }),

	r("ground", "Scout", 1, { "ord_herald" }, { "chs_jackal" }),
	r("ground", "Light tank", 1, { "ord_lancer" }, { "chs_ravager" }),
	r("ground", "Swarm tank", 1, {}, { "chs_locust" }),
	r("ground", "Self-propelled artillery", 1, { "ord_verdict" }, { "chs_hellmouth" }),
	r("ground", "Mobile IR SAM", 1, { "ord_halo" }, { "chs_hornet" }),
	r("ground", "Mobile radar", 1, { "ord_oracle" }, { "chs_watcher" }),
	r("ground", "Main battle tank", 2, { "ord_paladin" }, {}), -- Chaos: none until the user picks one (S-213 retired the Goliath, chs_goliath)
	r("ground", "MLRS", 2, { "ord_judgement" }, { "chs_hydra" }),
	r("ground", "Mobile radar SAM", 2, { "ord_seraph" }, { "chs_gorgon" }),
	r("ground", "Mobile jammer", 2, { "ord_veil" }, { "chs_shroud" }),
	r("ground", "Mobile fire-control radar", 2, { "ord_arbiter" }, { "chs_stalker" }),
	r("ground", "Amphibious tank", 2, { "ord_tideguard" }, { "chs_mire" }),
	r("ground", "Mobile point defence", 2, { "ord_shepherd" }, { "chs_griffin" }),
	r("ground", "Mobile anti-nuke", 2, { "ord_custodian" }, { "chs_chimera" }),
	r("ground", "Deployable gun", 2, { "ord_warden" }, {}),
	r("ground", "Siege ram", 2, {}, { "chs_minotaur" }),
	r("ground", "Siege mortar", 2, {}, { "chs_cyclops" }),
	-- bots (S-181): ground units that climb steep terrain and turn in place
	r("ground", "Scout bot", 1, { "ord_glint" }, { "chs_skitter" }),
	r("ground", "Light combat bot", 1, { "ord_mace" }, { "chs_thug" }),
	r("ground", "AA bot", 1, { "ord_kestrel" }, { "chs_needle" }),
	r("ground", "Heavy plasma", 2, { "ord_fatboy" }, { "chs_tzar" }),
	r("ground", "Heavy laser bot", 2, {}, { "chs_centurion" }),
	r("ground", "Heavy assault bot", 2, {}, { "chs_mammoth" }),
	r("ground", "Experimental assault walker", 3, { "ord_titan" }, { "chs_juggernaut" }),

	r("air", "Fighter", 1, { "ord_falcon" }, { "chs_harpy" }),
	r("air", "Attack helicopter", 1, { "ord_guardian" }, { "chs_wasp" }),
	r("air", "Bomber", 1, { "ord_absolution" }, { "chs_plague" }),
	r("air", "Air transport", 1, { "ord_courier" }, { "chs_buzzard" }), -- S-219
	r("air", "Air superiority fighter", 2, { "ord_archon" }, { "chs_manticore" }),
	r("air", "Strategic bomber", 2, { "ord_phantom" }, { "chs_behemoth" }),
	r("air", "ASW helicopter", 2, { "ord_tidewatch" }, { "chs_leech" }),
	r("air", "Support aircraft", 2, { "ord_archangel" }, { "chs_banshee" }),
	r("air", "Heavy air transport", 2, { "ord_ark" }, { "chs_charon" }), -- S-219
	r("air", "Decoy drone", 2, {}, { "chs_wraith" }),
	r("air", "Heavy bomber", 2, { "ord_liche" }, {}),
	r("air", "Flying fortress", 2, {}, { "chs_dragon" }),

	r("naval", "Corvette", 1, { "ord_sentry" }, { "chs_barracuda" }),
	r("naval", "Submarine", 1, { "ord_silence" }, { "chs_lamprey" }),
	r("naval", "Destroyer", 2, { "ord_crusader" }, { "chs_corsair" }),
	r("naval", "Cruiser", 2, { "ord_dominion" }, { "chs_kraken" }),
	r("naval", "Carrier", 2, { "ord_sanctuary" }, { "chs_leviathan" }),
	r("naval", "EW ship", 2, {}, { "chs_siren" }),

	r("defence", "Laser tower", 1, { "ord_sentry_tower" }, { "chs_guard" }),
	r("defence", "Heavy laser tower", 1, { "ord_overwatch" }, { "chs_twin_guard", "chs_geryon" }),
	r("defence", "Ramping beam tower", 1, { "ord_beamer" }, {}),
	r("defence", "Lobbing gun", 1, { "ord_gauntlet" }, { "chs_talos" }),
	r("defence", "Wall", 1, { "ord_barrier" }, {}),
	r("defence", "IR SAM site", 1, { "ord_vigil" }, { "chs_thorn" }),
	r("defence", "Floating turret", 1, { "ord_moat" }, { "chs_riptide" }),
	r("defence", "Torpedo launcher", 1, { "ord_undertow" }, { "chs_fang" }),
	r("defence", "Heavy turret", 2, { "ord_bastion" }, { "chs_maw" }),
	r("defence", "Beam tower", 2, { "ord_radiance" }, { "chs_bulwark" }),
	r("defence", "Flak tower", 2, { "ord_lumen" }, { "chs_hailstorm" }),
	r("defence", "Radar SAM site", 2, { "ord_aegis" }, { "chs_wyvern" }),
	r("defence", "Artillery emplacement", 2, { "ord_edict" }, { "chs_cataclysm" }),
	r("defence", "Missile battery", 2, { "ord_sanction" }, { "chs_scourge" }),
	r("defence", "Coastal battery", 2, { "ord_rampart" }, { "chs_breaker" }),
	r("defence", "Naval SAM platform", 2, { "ord_pharos" }, { "chs_scylla" }),
	r("defence", "Fortress", 3, { "ord_citadel" }, {}),

	r("sensors", "Radar tower", 1, { "ord_watchtower" }, { "chs_eye" }),
	r("sensors", "Jammer tower", 1, { "ord_curtain" }, { "chs_smog" }),
	r("sensors", "Sonar buoy", 1, { "ord_ear" }, { "chs_listener" }),
	r("sensors", "Long-range radar", 2, { "ord_beacon" }, { "chs_allseer" }),
	r("sensors", "Advanced jammer tower", 2, { "ord_veilspire" }, { "chs_blackout" }),
	r("sensors", "Fire-control radar", 2, { "ord_tribunal" }, { "chs_seekerspire" }),
	r("sensors", "Pinpointer", 2, { "ord_witness" }, { "chs_augur" }),
	r("sensors", "Sonar station", 2, { "ord_choir" }, { "chs_deepear" }),

	r("strategic", "Point defence", 2, { "ord_sanctum" }, { "chs_basilisk" }),
	r("strategic", "Shield dome", 2, { "ord_phalanx" }, { "chs_carapace" }),
	r("strategic", "Anti-nuke", 2, { "ord_providence" }, { "chs_cerberus" }),
	r("strategic", "Nuclear missile silo", 3, { "ord_reckoning" }, { "chs_ragnarok" }),

	r("economy", "Supply extractor", 1, { "ord_extractor" }, { "chs_extractor" }),
	r("economy", "Underwater supply extractor", 1, { "ord_seaextractor" }, { "chs_seaextractor" }),
	r("economy", "Solar array", 1, { "ord_solar" }, { "chs_solar" }),
	r("economy", "Advanced solar collector", 1, { "ord_advsolar" }, { "chs_advsolar" }),
	r("economy", "Wind turbine", 1, { "ord_windmill" }, { "chs_windmill" }),
	r("economy", "Tidal generator", 1, { "ord_tidal" }, { "chs_tidal" }),
	r("economy", "Supply converter", 1, { "ord_converter" }, { "chs_converter" }),
	r("economy", "Depot", 1, { "ord_depot" }, { "chs_depot" }),
	r("economy", "Energy storage", 1, { "ord_capacitor" }, { "chs_accumulator" }),
	r("economy", "Advanced extractor", 2, { "ord_advextractor" }, { "chs_advextractor" }),
	r("economy", "Advanced supply converter", 2, { "ord_advconverter" }, { "chs_advconverter" }),
	r("economy", "Advanced depot", 2, { "ord_advdepot" }, { "chs_advdepot" }),
	r("economy", "Advanced energy storage", 2, { "ord_advcapacitor" }, { "chs_advaccumulator" }),
	r("economy", "Fusion reactor", 2, { "ord_fusion" }, { "chs_fusion" }),
	r("economy", "Advanced fusion reactor", 2, { "ord_advfusion" }, { "chs_advfusion" }),

	r("factory", "Vehicle plant", 1, { "ord_vehplant" }, { "chs_vehplant" }),
	r("factory", "Airfield", 1, { "ord_airfield" }, { "chs_airfield" }),
	r("factory", "Shipyard", 1, { "ord_shipyard" }, { "chs_shipyard" }),
	r("factory", "Rearm pad", 1, { "ord_airpad" }, { "chs_airpad" }),
	r("factory", "Bot lab", 1, { "ord_botlab" }, { "chs_botlab" }),
	r("factory", "Construction turret", 1, { "ord_nano" }, { "chs_nano" }),
	r("factory", "Advanced vehicle plant", 2, { "ord_advvehplant" }, { "chs_advvehplant" }),
	r("factory", "Advanced airfield", 2, { "ord_advairfield" }, { "chs_advairfield" }),
	r("factory", "Advanced shipyard", 2, { "ord_advshipyard" }, { "chs_advshipyard" }),
	r("factory", "Advanced rearm pad", 2, { "ord_empyrean" }, { "chs_rookery" }),
	r("factory", "Advanced bot lab", 2, { "ord_advbotlab" }, { "chs_advbotlab" }),
	r("factory", "Experimental gantry", 3, { "ord_gantry" }, { "chs_gantry" }),
}

export type Entry = {
	id: string,
	def: any,
	faction: string,
	role: Role?,
	section: string,
	counterparts: { string }, -- the other faction's units in the same role
	builtBy: { string },
}

export type Codex = {
	defs: any,
	entries: { [string]: Entry },
	byFaction: { [string]: { Entry } }, -- in list order: section, then role order, then name
}

local SECTION_ORDER: { [string]: number } = {}
for i, s in Codex.SECTIONS do
	SECTION_ORDER[s.id] = i
end

local function sectionOf(def: any): string
	if def.domain == "air" then
		return "air"
	elseif def.domain == "naval" then
		return "naval"
	elseif def.domain == "ground" then
		return "ground"
	end
	return "other"
end

-- Builds the encyclopedia from loaded defs (`Defs.load()`).
function Codex.build(defs: any): Codex
	local builtBy: { [string]: { string } } = {}
	for id, u in defs.units do
		for _, b in u.buildOptions or {} do
			builtBy[b] = builtBy[b] or {}
			table.insert(builtBy[b], id)
		end
	end
	for _, list in builtBy do
		table.sort(list)
	end
	local roleOf: { [string]: Role } = {}
	local roleIndex: { [Role]: number } = {}
	for i, role in Codex.ROLES do
		roleIndex[role] = i
		for _, id in role.order do
			roleOf[id] = role
		end
		for _, id in role.chaos do
			roleOf[id] = role
		end
	end
	local entries: { [string]: Entry } = {}
	local byFaction: { [string]: { Entry } } = { order = {}, chaos = {} }
	for id, def in defs.units do
		local commander = def.tier == 0
		if def.retired or builtBy[id] == nil and not commander then
			continue -- retired: nothing builds it
		end
		local role = roleOf[id]
		local faction = def.faction
		local other = if role then (if faction == "order" then role.chaos else role.order) else {}
		local e: Entry = {
			id = id,
			def = def,
			faction = faction,
			role = role,
			section = if role then role.section else sectionOf(def),
			counterparts = table.clone(other), -- trimmed to listed entries below
			builtBy = builtBy[id] or {},
		}
		entries[id] = e
		byFaction[faction] = byFaction[faction] or {}
		table.insert(byFaction[faction], e)
	end
	for _, e in entries do
		local shown = {}
		for _, other in e.counterparts do
			if entries[other] then
				table.insert(shown, other)
			end
		end
		e.counterparts = shown
	end
	for _, list in byFaction do
		table.sort(list, function(a, b)
			local sa, sb = SECTION_ORDER[a.section] or 99, SECTION_ORDER[b.section] or 99
			if sa ~= sb then
				return sa < sb
			end
			local ra = if a.role then roleIndex[a.role] else math.huge
			local rb = if b.role then roleIndex[b.role] else math.huge
			if ra ~= rb then
				return ra < rb
			end
			return a.def.name < b.def.name
		end)
	end
	return { defs = defs, entries = entries, byFaction = byFaction }
end

-- Is a section a structures section (the Structures filter)?
function Codex.isStructures(section: string): boolean
	for _, s in Codex.SECTIONS do
		if s.id == section then
			return s.structures
		end
	end
	return false
end

-- weapons ---------------------------------------------------------------------

-- The armor class a weapon is meant for (as the unit panel: the first armor
-- class in its priority with damage, else its best class).
function Codex.mainClass(w: any): string
	for _, p in w.priority or {} do
		if ArmorClasses.set[p] and (w.damage or {})[p] and w.damage[p] > 0 then
			return p
		end
	end
	local best, bestDamage = "LIGHT", -1
	for _, c in ArmorClasses.list do
		local d = (w.damage or {})[c] or 0
		if d > bestDamage then
			best, bestDamage = c, d
		end
	end
	return best
end

function Codex.shots(w: any): number
	local salvo = w.salvo
	local count = if type(salvo) == "table" then salvo.count or 1 elseif type(salvo) == "number" then salvo else 1
	return count * (w.projectiles or 1)
end

function Codex.dps(w: any, class: string?): number
	local c = class or Codex.mainClass(w)
	return ((w.damage or {})[c] or 0) * Codex.shots(w) / math.max(w.reload or 1, 0.05)
end

export type Weapon = {
	id: string,
	kind: string, -- BALLISTIC, HOMING, BEAM, ...
	class: string, -- main armor class
	dps: number,
	damage: { [string]: number }, -- per shot, by armor class (0s dropped)
	shots: number,
	range: number,
	reload: number,
	accuracy: number?,
	aoe: number?,
	guidance: string?,
	lockRange: number?,
	targets: { string },
	stock: number?, -- stockpile capacity
	stockSeconds: number?, -- seconds to build one stockpiled round
	stockPower: number?, -- power one stockpiled round costs
	speed: number?, -- projectile speed (studs/s)
	launch: string?, -- "vertical": straight up, then over
	alpha: number, -- the most one hit does (its best armor class)
}

local function weapon(w: any): Weapon
	local damage = {}
	for _, c in ArmorClasses.list do
		local d = (w.damage or {})[c] or 0
		if d > 0 then
			damage[c] = d
		end
	end
	local class = Codex.mainClass(w)
	return {
		id = w.id,
		kind = w.type or "?",
		class = class,
		dps = Codex.dps(w, class),
		damage = damage,
		shots = Codex.shots(w),
		range = w.range or 0,
		reload = w.reload or 0,
		accuracy = w.accuracy,
		aoe = if w.aoe and w.aoe > 0 then w.aoe else nil,
		guidance = if w.type == "HOMING" or w.type == "TORPEDO" then w.guidance else nil,
		lockRange = w.lockRange,
		targets = table.clone(w.targets or {}),
		stock = if w.stockpile then w.stockpile.capacity else nil,
		stockSeconds = if w.stockpile then w.stockpile.buildTime else nil,
		stockPower = if w.stockpile and w.stockpile.cost then w.stockpile.cost.power else nil,
		speed = if w.type ~= "HITSCAN" and w.type ~= "BEAM" then w.projectileSpeed else nil,
		launch = w.launch,
		alpha = (w.damage or {})[class] or 0,
	}
end

-- The biggest of each article stat over every unit and structure (the bars'
-- full length): supply, power, buildSeconds, health, speed, sight, radar,
-- dps, range, buildPower; for weapons wDps, wRange, wAlpha, wAoe.
function Codex.maxima(c: Codex): { [string]: number }
	local cached = (c :: any).maxima
	if cached then
		return cached
	end
	local m: { [string]: number } = {}
	local function see(key: string, v: number?)
		if v and v > (m[key] or 0) then
			m[key] = v
		end
	end
	for id in c.entries do
		local s = Codex.stats(c, id)
		see("supply", s.supply)
		see("power", s.power)
		see("buildSeconds", s.buildSeconds)
		see("health", s.health)
		see("speed", s.speed)
		see("sight", s.sight)
		see("radar", s.radar)
		see("dps", s.dps)
		see("range", s.range)
		see("buildPower", s.buildPower)
		for _, w in s.weapons do
			see("wDps", w.dps)
			see("wRange", w.range)
			see("wAlpha", w.alpha)
			see("wAoe", w.aoe)
		end
	end
	;(c :: any).maxima = m
	return m
end

-- How a value reads next to its number in a weapon card (BAR's wiki):
-- reload, alpha (one hit), area of effect and range in words.
local WORDS: { [string]: { { number | string } } } = {
	reload = { { 0.5, "very fast" }, { 1.5, "fast" }, { 3, "medium" }, { 6, "slow" }, { math.huge, "very slow" } },
	alpha = { { 50, "light" }, { 200, "medium" }, { 600, "heavy" }, { 1500, "very heavy" }, { math.huge, "devastating" } },
	aoe = { { 8, "small" }, { 20, "medium" }, { 40, "large" }, { 80, "huge" }, { math.huge, "gigantic" } },
	range = { { 150, "short" }, { 300, "medium" }, { 600, "long" }, { math.huge, "very long" } },
}
function Codex.word(kind: string, v: number): string
	for _, step in WORDS[kind] or {} do
		if v < (step[1] :: number) then
			return step[2] :: string
		end
	end
	return ""
end

-- article numbers ---------------------------------------------------------------

export type Stats = {
	supply: number,
	power: number,
	value: number, -- supply + power / 10 (guide 2: how the factions' versions are compared)
	work: number, -- build time in work units
	buildSeconds: number?, -- at its first builder's build power
	builder: string?, -- that builder's id
	health: number,
	armor: string,
	move: string?,
	speed: number?,
	turnRate: number?,
	footprint: number,
	sight: number?,
	airSight: number?,
	radar: number?,
	sonar: number?,
	jam: number?,
	track: number?,
	stealth: number?, -- the radar signature, when below 1
	buildPower: number?,
	ammo: number?,
	countermeasures: { string },
	weapons: { Weapon },
	dps: number, -- every weapon's main-class DPS added up
	range: number, -- the longest weapon
	income: { supply: number, power: number }?,
	storage: { supply: number, power: number }?,
	builds: { string },
}

local function positive(n: any): number?
	return if type(n) == "number" and n > 0 then n else nil
end

function Codex.stats(c: Codex, id: string): Stats
	local e = c.entries[id]
	local def = e.def
	local cost = def.cost or {}
	local supply, power = cost.supply or 0, cost.power or 0
	local s = def.sensors or {}
	local weapons = {}
	local dps, range = 0, 0
	for _, slot in def.weapons or {} do
		local w = c.defs.weapons[slot.def]
		if w then
			local x = weapon(w)
			table.insert(weapons, x)
			dps += x.dps
			range = math.max(range, x.range)
		end
	end
	local builder, seconds = nil, nil
	for _, b in e.builtBy do
		local bp = c.defs.units[b].buildPower
		if bp and bp > 0 then
			builder, seconds = b, (cost.buildTime or 0) / bp
			break
		end
	end
	local cm = {}
	local m = def.countermeasures or {}
	if m.flares then
		table.insert(cm, `Flares ({m.flares.charges or 0})`)
	end
	if m.chaff then
		table.insert(cm, `Chaff ({m.chaff.charges or 0})`)
	end
	if m.dircm then
		table.insert(cm, "DIRCM")
	end
	local p = def.production
	local signature = s.radarSignature
	return {
		supply = supply,
		power = power,
		value = supply + power / 10,
		work = cost.buildTime or 0,
		buildSeconds = seconds,
		builder = builder,
		health = def.health or 0,
		armor = def.armorClass or "?",
		move = def.moveClass,
		speed = positive(def.movement and def.movement.maxSpeed),
		turnRate = positive(def.movement and def.movement.turnRate),
		footprint = def.footprint or 1,
		sight = positive(s.sight),
		airSight = positive(s.airSight),
		radar = positive(s.radar),
		sonar = positive(s.sonar),
		jam = positive(s.jam),
		track = positive(s.track),
		stealth = if type(signature) == "number" and signature < 1 then signature else nil,
		buildPower = positive(def.buildPower),
		ammo = positive(def.ammo),
		countermeasures = cm,
		weapons = weapons,
		dps = dps,
		range = range,
		income = if p and ((p.supply or 0) > 0 or (p.power or 0) > 0) then { supply = p.supply or 0, power = p.power or 0 } else nil,
		storage = if def.storage then { supply = def.storage.supply or 0, power = def.storage.power or 0 } else nil,
		builds = table.clone(def.buildOptions or {}),
	}
end

export type Difference = { label: string, pct: number, better: boolean }

-- How `id` differs from `other` (its counterpart), the biggest first:
-- health, firepower, range, speed, sight and value, each as a percentage of
-- the other's (only differences of 5% or more). `better` is from `id`'s
-- point of view (a lower value is better).
function Codex.compare(c: Codex, id: string, other: string): { Difference }
	local a, b = Codex.stats(c, id), Codex.stats(c, other)
	local out: { Difference } = {}
	local function add(label: string, x: number?, y: number?, lowerIsBetter: boolean?)
		if x == nil or y == nil or y <= 0 or x <= 0 then
			return
		end
		local pct = (x / y - 1) * 100
		if math.abs(pct) < 5 then
			return
		end
		table.insert(out, { label = label, pct = pct, better = if lowerIsBetter then pct < 0 else pct > 0 })
	end
	add("health", a.health, b.health)
	add("damage per second", a.dps, b.dps)
	add("range", a.range, b.range)
	add("speed", a.speed, b.speed)
	add("sight", a.sight, b.sight)
	add("value", a.value, b.value, true)
	table.sort(out, function(x, y)
		return math.abs(x.pct) > math.abs(y.pct)
	end)
	return out
end

-- The tier's label: "Command", "T1", "T2", "T3".
function Codex.tierName(tier: number?): string
	if tier == nil or tier == 0 then
		return "Command"
	end
	return `T{tier}`
end

-- What the Units showroom's firing range (L-22) points a weapon at: "air",
-- "sub" (on a place with water) or "ground" (a board, or a barge on
-- water); nil when it isn't shown (anti-missile and strategic weapons).
function Codex.rangeTarget(weapon: any, water: boolean): string?
	if weapon == nil or weapon.interceptOnly or weapon.strategic or weapon.intercepts then
		return nil
	end
	local list = weapon.targets or {}
	if table.find(list, "AIR") and #list == 1 then
		return "air"
	end
	if table.find(list, "SUB") and water then
		return "sub"
	end
	if table.find(list, "GROUND") or table.find(list, "STRUCTURE") or table.find(list, "NAVAL") then
		return "ground"
	end
	if table.find(list, "SUB") then
		return "ground" -- a torpedo on a land place: at the board
	end
	return nil
end

return Codex
