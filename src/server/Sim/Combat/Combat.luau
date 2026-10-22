--!strict
-- Combat state shared by the Targeting, Weapons, Projectiles and Damage
-- systems (guide 10): per-def collision/weapon profiles, the contact grid,
-- the projectile pool, the damage queue, wrecks and this tick's events.
--
-- Collision volumes are vertical cylinders: radius 0.45 × footprint × 8
-- studs (the same as movement), height UNIT_HEIGHT × footprint, standing on
-- the terrain under the unit's center (plus altitude for air units).

local Aim = require("@shared/Combat/Aim")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Hash = require("@shared/Util/Hash")
local Layers = require("@shared/Grid/Layers")
local Ballistics = require("./Ballistics")
local ContactGrid = require("./ContactGrid")
local World = require("../World")

local Combat = {}

Combat.UNIT_HEIGHT = 6 -- studs per footprint cell
Combat.MUZZLE_HEIGHT = 0.6 -- fraction of unit height
Combat.RADIUS_PER_FOOTPRINT = PlacementRules.RADIUS_PER_FOOTPRINT -- the same as Nav's (shared, S-9)
Combat.MAX_PROJECTILES = 2000 -- guide 10.5
Combat.WRECK_SUPPLY_FRACTION = 0.5 -- of the unit's supply cost (guide 8.7)
Combat.WRECK_MAX_SEVERITY = 0.5 -- overkill above this fraction of max health leaves no wreck
Combat.DRAFT = 3 -- studs a ship's hull reaches below the surface
Combat.SUB_DEPTH = 10 -- studs below the surface a submarine's hull starts
Combat.TORPEDO_DEPTH = 1.5 -- studs below the surface torpedoes run

export type UnitProfile = {
	radius: number,
	height: number,
	muzzleHeight: number,
	armorClass: string,
	categoryMask: number,
	maxHealth: number,
	weapons: { Defs.WeaponDef }, -- by slot
	naval: boolean, -- floats: hull from the water surface down by DRAFT
	hover: boolean, -- HOVER move class: rides on the water surface over water (S-39)
}

export type Event = {
	kind: "FIRE"
		| "SPAWN_PROJ"
		| "IMPACT"
		| "DECOYED"
		| "LOST_LOCK"
		| "DEATH"
		| "BUILD_START"
		| "BUILD_DONE"
		| "BUILD_FAILED"
		| "PRODUCED"
		| "RECLAIMED"
		| "LAUNCH" -- a strategic missile left its silo: unit = silo, other = projectile, x/y/z = launch (S-48)
		| "BLAST" -- a unit with a deathBlast exploded as it died: unit = the dying unit, x/z = where (S-70)
		| "INTERCEPTED" -- a strategic missile destroyed in flight: other = projectile, x/y/z = where (S-48)
		| "SHIELD_HIT" -- a shell turned or broke through a dome: unit = generator, other = projectile, x/y/z = the dome point (S-79)
		| "SHIELD_FIELD" -- a projectile came into a dome's field: unit = generator, other = projectile (S-79)
		| "ELIMINATED" -- other = player
		| "MATCH_END", -- other = winning ally team (0 = nobody)
	tick: number,
	unit: number, -- shooter (FIRE, SPAWN_PROJ), hit unit or 0 (IMPACT), missile's target (DECOYED, LOST_LOCK), dead unit (DEATH)
	other: number, -- target (FIRE), projectile (SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK), wreck or 0 (DEATH)
	slot: number?, -- FIRE, SPAWN_PROJ
	hit: boolean?, -- FIRE (hitscan)
	severity: number?, -- DEATH: 0..255
	reason: string?, -- BUILD_FAILED
	x: number?,
	y: number?,
	z: number?,
	sx: number?, -- FIRE: where the shot started (the muzzle; S-43)
	sy: number?,
	sz: number?,
	breach: boolean?, -- SHIELD_HIT: it broke through (else it turned back)
	mass: number?, -- SHIELD_HIT: the shell's mass (ShieldField.mass)
}

export type Combat = {
	profiles: { [number]: UnitProfile }, -- by unit def index
	maxRadius: number, -- largest collision radius of any def
	maxSpeedStep: number, -- farthest any unit moves in one tick (studs), for swept queries
	layers: Layers.Layers?,
	grid: Grid.Grid?,
	contacts: ContactGrid.ContactGrid,
	friendlyFire: boolean, -- AoE damages allies (direct hits never do)
	events: { Event },

	-- projectiles (struct-of-arrays, u16 IDs)
	proj: { number }, -- dense list of live projectile IDs
	projSlot: { [number]: number },
	px: { [number]: number },
	py: { [number]: number },
	pz: { [number]: number },
	pvx: { [number]: number },
	pvy: { [number]: number },
	pvz: { [number]: number },
	pWeapon: { [number]: number }, -- weapon def index
	pOwner: { [number]: number },
	pOwnerGen: { [number]: number }, -- generations of the shooter and the homing target (D109)
	pPlayer: { [number]: number }, -- the shooter's player, kept after it dies (Stats, S-63)
	pTargetGen: { [number]: number },
	pTeam: { [number]: number },
	pTtl: { [number]: number }, -- seconds left
	pTarget: { [number]: number }, -- unit a homing projectile steers toward (0 = none)
	pFlags: { [number]: number }, -- guided missiles: EW.Flag bits (terminal rolled, lock lost)
	pDecoy: { [number]: { number } }, -- decoyed missiles: { x, y, z, ticks left, countermeasure } (S-28, S-38)
	pSerial: { [number]: number }, -- spawn serial: (id, serial) names one projectile though IDs are reused (S-48)
	pTargetProj: { [number]: number }, -- interceptors: the strategic missile they steer at (0 = none; S-48)
	pTargetSerial: { [number]: number },
	projSerial: number, -- last serial given
	strategic: { number }, -- strategic missiles in flight, in launch order (S-48)
	pGoal: { [number]: { number } }, -- lofted missiles: the ordered spot { x, y, z } (S-51)
	-- shield fields (S-79, Sim/Shield): the dome generator a projectile is in
	-- the field of and its ShieldField phase there; the last dome done with it
	pShield: { [number]: number },
	pShieldPhase: { [number]: number },
	pShieldDone: { [number]: number },
	-- shield dome generators (S-79), in the order they entered: charge in
	-- shell masses, up (the dome stands), and the power share of their last
	-- recharge step (0..1)
	shieldIds: { number },
	shieldCharge: { [number]: number },
	shieldUp: { [number]: boolean },
	shieldPower: { [number]: number },
	-- overkill accounting (S-29, guide 10.2): the unit a projectile was fired
	-- at, its generation, and the direct damage it would deal
	pAim: { [number]: number },
	pAimGen: { [number]: number },
	pAimDmg: { [number]: number },
	pending: { [number]: number }, -- target → direct damage of projectiles in flight at it
	pendingGen: { [number]: number }, -- the target generation `pending` counts for
	queued: { [number]: number }, -- target → damage queued this tick (hitscan, impacts), until Damage applies it
	nextProjId: number,
	freeProj: { number }, -- FIFO of freed IDs
	freeHead: number,
	freeTail: number,

	-- damage queued this tick (applied by the Damage system, in order)
	dmgTarget: { number },
	dmgAmount: { number },
	dmgAttacker: { number },
	dmgPlayer: { number }, -- the attacker's player (0 = none), for Stats (S-63)
	dmgCount: number,

	-- wrecks
	wreckIds: { number },
	wreckX: { [number]: number },
	wreckZ: { [number]: number },
	wreckDef: { [number]: number },
	wreckHeading: { [number]: number }, -- the unit's heading when it died (radians; S-26)
	wreckSupply: { [number]: number },
	nextWreckId: number,

	stats: { shots: number, hits: number, kills: number },
}

function Combat.new(defs: Defs.DefSet, layers: Layers.Layers?): Combat
	local profiles = {}
	local maxRadius = 0
	local maxSpeed = 0
	for index, def in defs.unitByIndex do
		local weapons = {}
		for slot, ws in def.weapons do
			weapons[slot] = defs.weaponByIndex[ws.weaponIndex]
		end
		local height = Combat.UNIT_HEIGHT * def.footprint
		local radius = def.footprint * Combat.RADIUS_PER_FOOTPRINT
		maxRadius = math.max(maxRadius, radius)
		if def.movement then
			maxSpeed = math.max(maxSpeed, def.movement.maxSpeed)
		end
		profiles[index] = {
			radius = radius,
			height = height,
			muzzleHeight = height * Combat.MUZZLE_HEIGHT,
			armorClass = def.armorClass,
			categoryMask = def.categoryMask,
			maxHealth = def.health,
			weapons = weapons,
			naval = def.domain == "naval",
			hover = def.moveClass == "HOVER",
		}
	end
	local grid = if layers then layers.grid else nil
	return {
		profiles = profiles,
		maxRadius = maxRadius,
		maxSpeedStep = maxSpeed / 15,
		layers = layers,
		grid = grid,
		contacts = ContactGrid.new(grid),
		friendlyFire = true,
		events = {},
		proj = {},
		projSlot = {},
		px = {},
		py = {},
		pz = {},
		pvx = {},
		pvy = {},
		pvz = {},
		pWeapon = {},
		pOwner = {},
		pOwnerGen = {},
		pPlayer = {},
		pTargetGen = {},
		pTeam = {},
		pTtl = {},
		pTarget = {},
		pFlags = {},
		pDecoy = {},
		pSerial = {},
		pTargetProj = {},
		pTargetSerial = {},
		projSerial = 0,
		strategic = {},
		pGoal = {},
		pShield = {},
		pShieldPhase = {},
		pShieldDone = {},
		shieldIds = {},
		shieldCharge = {},
		shieldUp = {},
		shieldPower = {},
		pAim = {},
		pAimGen = {},
		pAimDmg = {},
		pending = {},
		pendingGen = {},
		queued = {},
		nextProjId = 1,
		freeProj = {},
		freeHead = 1,
		freeTail = 1,
		dmgTarget = {},
		dmgAmount = {},
		dmgAttacker = {},
		dmgPlayer = {},
		dmgCount = 0,
		wreckIds = {},
		wreckX = {},
		wreckZ = {},
		wreckDef = {},
		wreckHeading = {},
		wreckSupply = {},
		nextWreckId = 1,
		stats = { shots = 0, hits = 0, kills = 0 },
	}
end

-- Terrain height at (x, z); 0 without a map. Positions outside clamp to the edge.
function Combat.groundHeight(c: Combat, x: number, z: number): number
	local layers = c.layers
	if layers == nil then
		return 0
	end
	return Layers.heightAt(layers, x, z) -- shared with the client (S-44)
end

-- Water surface height at (x, z) (= ground where dry).
function Combat.surfaceHeight(c: Combat, x: number, z: number): number
	local layers = c.layers
	if layers == nil then
		return 0
	end
	local g = layers.grid
	local cx, cz = g:cellAt(x, z)
	cx = math.clamp(cx, 0, g.cellsX - 1)
	cz = math.clamp(cz, 0, g.cellsZ - 1)
	local i = cz * g.cellsX + cx
	return Layers.getHeight(layers, i) + Layers.getWater(layers, i)
end

function Combat.waterDepth(c: Combat, x: number, z: number): number
	local layers = c.layers
	if layers == nil then
		return 0
	end
	local g = layers.grid
	local cx, cz = g:cellAt(x, z)
	if not g:inBounds(cx, cz) then
		return 0
	end
	return Layers.getWater(layers, cz * g.cellsX + cx)
end

-- Bottom of a unit's collision cylinder: terrain + altitude for land and
-- air units; the water surface minus the draft for ships; deeper for
-- submerged submarines.
function Combat.unitBase(c: Combat, w: World.World, id: number): number
	return Combat.baseAt(c, w, id, w.posX[id], w.posZ[id])
end

-- The base unit `id` would have standing at (x, z): the same rules as
-- unitBase, for a believed position (a radar blip, a ghost).
function Combat.baseAt(c: Combat, w: World.World, id: number, x: number, z: number): number
	if c.profiles[w.defIndex[id]].naval then
		local surface = Combat.surfaceHeight(c, x, z)
		if bit32.band(w.state[id], World.State.SUBMERGED) ~= 0 then
			return surface - Combat.SUB_DEPTH - c.profiles[w.defIndex[id]].height
		end
		return surface - Combat.DRAFT
	end
	if c.profiles[w.defIndex[id]].hover then
		return Combat.surfaceHeight(c, x, z) -- over water: on the surface (S-39)
	end
	return Combat.groundHeight(c, x, z) + w.alt[id]
end

-- The point weapons aim at and hits are judged against: the centre of the
-- unit's collision cylinder, at its true position or at (x, z) when given
-- (where the shooter's team believes it is). Ships float and submarines
-- sit below the surface, so this is not terrain + altitude (DECISIONS D95).
function Combat.aimPoint(c: Combat, w: World.World, id: number, x: number?, z: number?): (number, number, number)
	local px, pz = x or w.posX[id], z or w.posZ[id]
	return px, Combat.baseAt(c, w, id, px, pz) + c.profiles[w.defIndex[id]].height / 2, pz
end

-- The aim point of a target as its shooter's team knows it (D100): a live
-- unit at the believed (x, z); a remembered structure (possibly dead: the
-- team can't tell) from its def, standing on the ground or floating; the
-- ground itself when `id` is 0 (attack-ground).
function Combat.knownAimPoint(c: Combat, w: World.World, id: number, defIndex: number?, x: number, z: number): (number, number, number)
	if id ~= 0 and w.slot[id] ~= nil then
		return Combat.aimPoint(c, w, id, x, z)
	end
	if defIndex == nil then
		return x, Combat.groundHeight(c, x, z), z
	end
	local p = c.profiles[defIndex]
	local base = if p.naval then Combat.surfaceHeight(c, x, z) - Combat.DRAFT
		elseif p.hover then Combat.surfaceHeight(c, x, z)
		else Combat.groundHeight(c, x, z)
	return x, base + p.height / 2, z
end

function Combat.addEvent(c: Combat, e: Event)
	table.insert(c.events, e)
end

function Combat.queueDamage(c: Combat, target: number, amount: number, attacker: number, player: number?)
	local n = c.dmgCount + 1
	c.dmgCount = n
	c.dmgTarget[n] = target
	c.dmgAmount[n] = amount
	c.dmgAttacker[n] = attacker
	c.dmgPlayer[n] = player or 0
	c.queued[target] = (c.queued[target] or 0) + amount
end

--------------------------------------------------------------------------------
-- Overkill accounting (S-29, guide 10.2)
--------------------------------------------------------------------------------

-- Projectile `proj` was fired at `target` and would deal `amount` to it.
function Combat.addPending(c: Combat, w: World.World, proj: number, target: number, amount: number)
	local gen = w.gen[target]
	if c.pendingGen[target] ~= gen then
		c.pending[target], c.pendingGen[target] = 0, gen -- a new unit under a reused ID
	end
	c.pending[target] += amount
	c.pAim[proj], c.pAimGen[proj], c.pAimDmg[proj] = target, gen, amount
end

-- The projectile no longer threatens its target (it landed, expired, or was
-- decoyed or lost its lock).
function Combat.dropPending(c: Combat, proj: number)
	local t = c.pAim[proj]
	if t == nil then
		return
	end
	if c.pendingGen[t] == c.pAimGen[proj] then
		local left = c.pending[t] - c.pAimDmg[proj]
		c.pending[t] = if left > 1e-6 then left else 0
	end
	c.pAim[proj], c.pAimGen[proj], c.pAimDmg[proj] = nil, nil, nil
end

Combat.AVOID_OVERKILL = true -- false turns overkill avoidance off (measurements)

--------------------------------------------------------------------------------
-- Line of fire (guide 10.8, S-32)
--------------------------------------------------------------------------------

Combat.LOF_STEP = 8 -- studs between terrain samples along a shot: one per height cell (guide 10.8)
Combat.LOF_END = 6 -- studs at the target end left unchecked (the ground it stands on)

-- Whether `weapon`'s shot from (x0, y0, z0) reaches (x1, y1, z1) above the
-- terrain: a straight line for hitscan and beams, the shell's low arc for
-- ballistic weapons (so artillery lobs over a ridge a tank shell hits).
-- Homing missiles, torpedoes and bombs aren't checked: they steer or fall.
-- Every LOF_STEP studs, the shot must be above the ground there.
function Combat.lineOfFire(c: Combat, weapon: Defs.WeaponDef, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): boolean
	local wtype = weapon.type
	if (wtype ~= "HITSCAN" and wtype ~= "BEAM" and wtype ~= "BALLISTIC") or c.layers == nil then
		return true
	end
	local dx, dz = x1 - x0, z1 - z0
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist <= Combat.LOF_END + Combat.LOF_STEP then
		return true
	end
	local g = if wtype == "BALLISTIC" then weapon.gravity or 0 else 0
	local slope, drop = (y1 - y0) / dist, 0
	if g > 0 then
		local speed = weapon.projectileSpeed or 1
		local pitch = Ballistics.launchPitch(speed, g, dist, y1 - y0)
		if pitch == nil then
			return false -- out of reach
		end
		local hv = speed * math.cos(pitch)
		slope, drop = math.tan(pitch), g / (2 * hv * hv)
	end
	local ux, uz = dx / dist, dz / dist
	local s = Combat.LOF_STEP
	local last = dist - Combat.LOF_END
	while s <= last do
		if y0 + s * slope - drop * s * s < Combat.groundHeight(c, x0 + ux * s, z0 + uz * s) then
			return false
		end
		s += Combat.LOF_STEP
	end
	return true
end

-- Line of fire from unit `id`'s muzzle to where its team believes target `t`
-- is (kx, kz; defIndex nil when the type is unknown).
function Combat.unitLineOfFire(c: Combat, w: World.World, id: number, weapon: Defs.WeaponDef, t: number, defIndex: number?, kx: number, kz: number): boolean
	local wtype = weapon.type
	if wtype ~= "HITSCAN" and wtype ~= "BEAM" and wtype ~= "BALLISTIC" then
		return true
	end
	local _, ty = Combat.knownAimPoint(c, w, t, defIndex, kx, kz)
	local y0 = Combat.unitBase(c, w, id) + c.profiles[w.defIndex[id]].muzzleHeight
	return Combat.lineOfFire(c, weapon, w.posX[id], y0, w.posZ[id], kx, ty, kz)
end

-- The chance a shot from `weapon` at `dist` studs reaches a target of profile
-- `p` (S-29): its hull plus half the blast radius. Spread is uniform in
-- ±accuracy on yaw and on pitch (Weapons). Sideways a shot misses by
-- dist·tan(error). Lengthwise a ballistic arc's range changes by dR/dθ·error
-- (flat ground, low arc: dR/dθ = 2v²·cos 2θ / g), and a shell coming down
-- at θ crosses the hull's height over height / tan θ of ground, so the
-- lengthwise window is radius + blast + height / (2 tan θ); a straight
-- shot's height error is dist·tan(error) against half the hull's height.
-- Guided weapons and torpedoes count as sure hits; bombs spread only
-- sideways. Checked against fired shells at stationary targets
-- (Overkill.spec).
function Combat.hitChance(weapon: Defs.WeaponDef, p: UnitProfile, dist: number): number
	local acc = math.rad(weapon.accuracy or 0)
	local wtype = weapon.type
	if acc <= 0 or wtype == "HOMING" or wtype == "TORPEDO" then
		return 1
	end
	local blast = (weapon.aoe or 0) / 2
	local reach = p.radius + blast
	local side = dist * math.tan(acc)
	local chance = if side > reach then reach / side else 1
	if wtype == "BOMB" then
		return chance
	end
	local g = weapon.gravity or 0
	local along, alongReach
	if wtype == "BALLISTIC" and g > 0 then
		local v2 = (weapon.projectileSpeed or 1) ^ 2
		local sin2 = math.min(1, dist * g / v2)
		along = 2 * v2 * math.sqrt(1 - sin2 * sin2) / g * acc
		local theta = math.asin(sin2) / 2
		alongReach = reach + p.height / (2 * math.max(math.tan(theta), 1e-3))
	else
		along = dist * math.tan(acc)
		alongReach = p.height / 2 + blast
	end
	if along > alongReach then
		chance *= alongReach / along
	end
	return chance
end

-- Whether damage already on its way (projectiles in flight at it, damage
-- queued this tick) will kill live unit `t`.
function Combat.doomed(c: Combat, w: World.World, t: number): boolean
	if not Combat.AVOID_OVERKILL then
		return false
	end
	local incoming = c.queued[t] or 0
	if c.pendingGen[t] == w.gen[t] then
		incoming += c.pending[t]
	end
	return incoming > 0 and incoming >= w.health[t]
end

local scratch: { number } = {}

-- The armor class a hit uses: an aircraft parked on the ground (LANDED) is
-- an easy target, LIGHT (guide 12.2, S-71).
local LANDED = World.State.LANDED
function Combat.armorOf(w: World.World, id: number, p: UnitProfile): string
	if p.armorClass == "AIR" and bit32.band(w.state[id], LANDED) ~= 0 then
		return "LIGHT"
	end
	return p.armorClass
end

-- Explosion at (x, y, z) from `weapon` fired by `attacker` of ally team `team`.
-- `direct` (0 = none) is the unit the projectile struck: it takes full
-- damage. (Projectiles never strike allies directly, guide 10.6, so `direct`
-- is always an enemy.) Every other unit takes damage × falloff by its
-- distance to the explosion, measured to its cylinder; allies only when
-- friendly fire is on.
function Combat.explode(
	c: Combat,
	w: World.World,
	x: number,
	y: number,
	z: number,
	weapon: Defs.WeaponDef,
	attacker: number,
	team: number,
	direct: number,
	player: number? -- default: the attacker's owner
)
	local aoe = weapon.aoe or 0
	local edge = weapon.edgeEffectiveness or 0
	player = player or (if attacker ~= 0 then w.owner[attacker] else 0)
	if direct ~= 0 and w.slot[direct] ~= nil then
		local p = c.profiles[w.defIndex[direct]]
		Combat.queueDamage(c, direct, weapon.damage[Combat.armorOf(w, direct, p)], attacker, player)
	end
	if aoe <= 0 then
		return
	end
	-- A unit's surface can be within aoe while its center is up to aoe + radius away.
	local n = ContactGrid.query(c.contacts, w, x, z, aoe + c.maxRadius, 0, scratch)
	for i = 1, n do
		local id = scratch[i]
		if id == direct or (w.ally[id] == team and not c.friendlyFire) then
			continue
		end
		local p = c.profiles[w.defIndex[id]]
		local base = Combat.unitBase(c, w, id)
		local d = Ballistics.distanceToCylinder(x, y, z, w.posX[id], w.posZ[id], p.radius, base, base + p.height)
		local f = Ballistics.falloff(d, aoe, edge)
		if f > 0 then
			Combat.queueDamage(c, id, weapon.damage[Combat.armorOf(w, id, p)] * f, attacker, player)
		end
	end
end

--------------------------------------------------------------------------------
-- Projectile pool
--------------------------------------------------------------------------------

-- Returns a free projectile ID or nil at the cap. Freed IDs are reused
-- oldest first (IMPACT is reliable and ordered, so no reuse delay is needed).
local function allocProjectile(c: Combat): number?
	if #c.proj >= Combat.MAX_PROJECTILES then
		return nil
	end
	local head = c.freeHead
	if head < c.freeTail then
		local id = c.freeProj[head]
		c.freeProj[head] = nil
		c.freeHead = head + 1
		return id
	end
	if c.nextProjId > 65535 then
		return nil
	end
	local id = c.nextProjId
	c.nextProjId += 1
	return id
end

function Combat.spawnProjectile(
	c: Combat,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	weaponIndex: number,
	owner: number,
	team: number,
	ttl: number,
	target: number?,
	w: World.World?, -- records the shooter's and target's generations (D109)
	targetGen: number? -- default: the live target's
): number?
	local id = allocProjectile(c)
	if id == nil then
		return nil
	end
	table.insert(c.proj, id)
	c.projSlot[id] = #c.proj
	c.px[id], c.py[id], c.pz[id] = x, y, z
	c.pvx[id], c.pvy[id], c.pvz[id] = vx, vy, vz
	c.pWeapon[id] = weaponIndex
	c.pOwner[id] = owner
	c.pTeam[id] = team
	c.pTtl[id] = ttl
	c.pTarget[id] = target or 0
	c.pOwnerGen[id] = if w and owner ~= 0 then w.gen[owner] or 0 else 0
	c.pPlayer[id] = if w and owner ~= 0 then w.owner[owner] or 0 else 0
	c.pTargetGen[id] = if w and (target or 0) ~= 0 then targetGen or w.gen[target :: number] or 0 else 0
	c.pFlags[id] = 0
	c.projSerial += 1
	c.pSerial[id] = c.projSerial
	c.pTargetProj[id] = 0
	c.pTargetSerial[id] = 0
	return id
end

-- Is (id, serial) still the same projectile in flight (S-48)?
function Combat.isProjRef(c: Combat, id: number, serial: number?): boolean
	return id ~= 0 and c.projSlot[id] ~= nil and c.pSerial[id] == serial
end

function Combat.removeProjectile(c: Combat, id: number)
	local s = c.projSlot[id]
	local last = c.proj[#c.proj]
	c.proj[s] = last
	c.projSlot[last] = s
	c.proj[#c.proj] = nil
	c.projSlot[id] = nil
	c.px[id], c.py[id], c.pz[id] = nil, nil, nil
	c.pvx[id], c.pvy[id], c.pvz[id] = nil, nil, nil
	c.pWeapon[id], c.pOwner[id], c.pTeam[id], c.pTtl[id], c.pTarget[id], c.pFlags[id] = nil, nil, nil, nil, nil, nil
	c.pOwnerGen[id], c.pTargetGen[id] = nil, nil
	c.pPlayer[id] = nil
	c.pDecoy[id] = nil
	c.pSerial[id], c.pTargetProj[id], c.pTargetSerial[id] = nil, nil, nil
	c.pGoal[id] = nil
	c.pShield[id], c.pShieldPhase[id], c.pShieldDone[id] = nil, nil, nil
	local si = table.find(c.strategic, id)
	if si then
		table.remove(c.strategic, si)
	end
	Combat.dropPending(c, id)
	c.freeProj[c.freeTail] = id
	c.freeTail += 1
end

--------------------------------------------------------------------------------
-- Wrecks
--------------------------------------------------------------------------------

function Combat.addWreck(c: Combat, x: number, z: number, def: Defs.UnitDef, heading: number?): number
	local id = c.nextWreckId
	c.nextWreckId += 1
	table.insert(c.wreckIds, id)
	c.wreckX[id] = x
	c.wreckZ[id] = z
	c.wreckDef[id] = def.index
	c.wreckHeading[id] = heading or 0
	c.wreckSupply[id] = def.cost.supply * Combat.WRECK_SUPPLY_FRACTION
	return id
end

function Combat.removeWreck(c: Combat, id: number)
	local i = table.find(c.wreckIds, id)
	if i then
		table.remove(c.wreckIds, i)
	end
	c.wreckX[id], c.wreckZ[id], c.wreckDef[id], c.wreckSupply[id], c.wreckHeading[id] = nil, nil, nil, nil, nil
end

--------------------------------------------------------------------------------
-- Hash (part of Sim.hash)
--------------------------------------------------------------------------------

function Combat.hash(c: Combat, h: number): number
	local sorted = table.clone(c.proj)
	table.sort(sorted)
	h = Hash.u32(h, #sorted)
	for _, id in sorted do
		h = Hash.u32(h, id)
		h = Hash.number(h, c.px[id])
		h = Hash.number(h, c.py[id])
		h = Hash.number(h, c.pz[id])
		h = Hash.number(h, c.pvx[id])
		h = Hash.number(h, c.pvy[id])
		h = Hash.number(h, c.pvz[id])
		h = Hash.u32(h, c.pWeapon[id])
		h = Hash.u32(h, c.pOwner[id])
		h = Hash.number(h, c.pTtl[id])
		h = Hash.u32(h, c.pTarget[id])
		h = Hash.u32(Hash.u32(h, c.pOwnerGen[id]), c.pTargetGen[id])
		h = Hash.u32(h, c.pFlags[id])
		h = Hash.u32(h, c.pAim[id] or 0)
		h = Hash.u32(Hash.u32(Hash.u32(h, c.pSerial[id]), c.pTargetProj[id]), c.pTargetSerial[id])
		local goal = c.pGoal[id]
		if goal then
			h = Hash.number(Hash.number(Hash.number(h, goal[1]), goal[2]), goal[3])
		end
		local d = c.pDecoy[id]
		if d then
			h = Hash.u32(Hash.u32(Hash.number(Hash.number(Hash.number(h, d[1]), d[2]), d[3]), d[4]), d[5] or 0)
		end
		h = Hash.u32(Hash.u32(Hash.u32(h, c.pShield[id] or 0), c.pShieldPhase[id] or 0), c.pShieldDone[id] or 0)
	end
	for _, id in c.shieldIds do
		h = Hash.u32(Hash.number(Hash.u32(h, id), c.shieldCharge[id]), if c.shieldUp[id] then 1 else 0)
	end
	h = Hash.u32(h, c.nextProjId)
	h = Hash.u32(h, c.projSerial)
	for _, id in c.strategic do
		h = Hash.u32(h, id)
	end
	h = Hash.u32(h, #c.wreckIds)
	for _, id in c.wreckIds do
		h = Hash.u32(h, id)
		h = Hash.number(h, c.wreckX[id])
		h = Hash.number(h, c.wreckZ[id])
		h = Hash.u32(h, c.wreckDef[id])
		h = Hash.number(h, c.wreckHeading[id])
		h = Hash.number(h, c.wreckSupply[id])
	end
	return h
end

-- The aim each weapon slot of a unit def starts at: its turret's rest pose
-- (Shared/Combat/Aim, S-20). nil when every slot rests at 0, 0.
function Combat.restPoses(sim: any, defIndex: number): { { number } }?
	local out: { { number } }? = nil
	for slot, weapon in sim.combat.profiles[defIndex].weapons do
		local yaw, pitch = Aim.rest(weapon.turret)
		if yaw ~= 0 or pitch ~= 0 then
			out = out or {}
			;(out :: { { number } })[slot] = { yaw, pitch }
		end
	end
	return out
end

return Combat
