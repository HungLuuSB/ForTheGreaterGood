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
	pTargetGen: { [number]: number },
	pTeam: { [number]: number },
	pTtl: { [number]: number }, -- seconds left
	pTarget: { [number]: number }, -- unit a homing projectile steers toward (0 = none)
	pFlags: { [number]: number }, -- guided missiles: EW.Flag bits (terminal rolled, lock lost)
	nextProjId: number,
	freeProj: { number }, -- FIFO of freed IDs
	freeHead: number,
	freeTail: number,

	-- damage queued this tick (applied by the Damage system, in order)
	dmgTarget: { number },
	dmgAmount: { number },
	dmgAttacker: { number },
	dmgCount: number,

	-- wrecks
	wreckIds: { number },
	wreckX: { [number]: number },
	wreckZ: { [number]: number },
	wreckDef: { [number]: number },
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
		pTargetGen = {},
		pTeam = {},
		pTtl = {},
		pTarget = {},
		pFlags = {},
		nextProjId = 1,
		freeProj = {},
		freeHead = 1,
		freeTail = 1,
		dmgTarget = {},
		dmgAmount = {},
		dmgAttacker = {},
		dmgCount = 0,
		wreckIds = {},
		wreckX = {},
		wreckZ = {},
		wreckDef = {},
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
	local g = layers.grid
	local cx, cz = g:cellAt(x, z)
	cx = math.clamp(cx, 0, g.cellsX - 1)
	cz = math.clamp(cz, 0, g.cellsZ - 1)
	return Layers.getHeight(layers, cz * g.cellsX + cx)
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
	local base = if p.naval then Combat.surfaceHeight(c, x, z) - Combat.DRAFT else Combat.groundHeight(c, x, z)
	return x, base + p.height / 2, z
end

function Combat.addEvent(c: Combat, e: Event)
	table.insert(c.events, e)
end

function Combat.queueDamage(c: Combat, target: number, amount: number, attacker: number)
	local n = c.dmgCount + 1
	c.dmgCount = n
	c.dmgTarget[n] = target
	c.dmgAmount[n] = amount
	c.dmgAttacker[n] = attacker
end

local scratch: { number } = {}

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
	direct: number
)
	local aoe = weapon.aoe or 0
	local edge = weapon.edgeEffectiveness or 0
	if direct ~= 0 and w.slot[direct] ~= nil then
		local p = c.profiles[w.defIndex[direct]]
		Combat.queueDamage(c, direct, weapon.damage[p.armorClass], attacker)
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
			Combat.queueDamage(c, id, weapon.damage[p.armorClass] * f, attacker)
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
	c.pTargetGen[id] = if w and (target or 0) ~= 0 then targetGen or w.gen[target :: number] or 0 else 0
	c.pFlags[id] = 0
	return id
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
	c.freeProj[c.freeTail] = id
	c.freeTail += 1
end

--------------------------------------------------------------------------------
-- Wrecks
--------------------------------------------------------------------------------

function Combat.addWreck(c: Combat, x: number, z: number, def: Defs.UnitDef): number
	local id = c.nextWreckId
	c.nextWreckId += 1
	table.insert(c.wreckIds, id)
	c.wreckX[id] = x
	c.wreckZ[id] = z
	c.wreckDef[id] = def.index
	c.wreckSupply[id] = def.cost.supply * Combat.WRECK_SUPPLY_FRACTION
	return id
end

function Combat.removeWreck(c: Combat, id: number)
	local i = table.find(c.wreckIds, id)
	if i then
		table.remove(c.wreckIds, i)
	end
	c.wreckX[id], c.wreckZ[id], c.wreckDef[id], c.wreckSupply[id] = nil, nil, nil, nil
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
	end
	h = Hash.u32(h, c.nextProjId)
	h = Hash.u32(h, #c.wreckIds)
	for _, id in c.wreckIds do
		h = Hash.u32(h, id)
		h = Hash.number(h, c.wreckX[id])
		h = Hash.number(h, c.wreckZ[id])
		h = Hash.u32(h, c.wreckDef[id])
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
