--!strict
-- Combat state shared by the Targeting, Weapons, Projectiles and Damage
-- systems (guide 10): per-def collision/weapon profiles, the contact grid,
-- the projectile pool, the damage queue, wrecks and this tick's events.
--
-- Collision volumes are vertical cylinders: radius 0.45 × footprint × 8
-- studs (the same as movement), height UNIT_HEIGHT × footprint, standing on
-- the terrain under the unit's center (plus altitude for air units).

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
Combat.RADIUS_PER_FOOTPRINT = 8 * 0.45 -- keep equal to Nav.RADIUS_PER_FOOTPRINT
Combat.MAX_PROJECTILES = 2000 -- guide 10.5
Combat.WRECK_SUPPLY_FRACTION = 0.5 -- of the unit's supply cost (guide 8.7)
Combat.WRECK_MAX_SEVERITY = 0.5 -- overkill above this fraction of max health leaves no wreck

export type UnitProfile = {
	radius: number,
	height: number,
	muzzleHeight: number,
	armorClass: string,
	categoryMask: number,
	maxHealth: number,
	weapons: { Defs.WeaponDef }, -- by slot
}

export type Event = {
	kind: "FIRE" | "SPAWN_PROJ" | "IMPACT" | "DEATH",
	tick: number,
	unit: number, -- shooter (FIRE, SPAWN_PROJ), hit unit or 0 (IMPACT), dead unit (DEATH)
	other: number, -- target (FIRE), projectile (SPAWN_PROJ, IMPACT), wreck or 0 (DEATH)
	slot: number?, -- FIRE, SPAWN_PROJ
	hit: boolean?, -- FIRE (hitscan)
	severity: number?, -- DEATH: 0..255
	x: number?,
	y: number?,
	z: number?,
}

export type Combat = {
	profiles: { [number]: UnitProfile }, -- by unit def index
	maxRadius: number, -- largest collision radius of any def
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
	pTeam: { [number]: number },
	pTtl: { [number]: number }, -- seconds left
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
	for index, def in defs.unitByIndex do
		local weapons = {}
		for slot, ws in def.weapons do
			weapons[slot] = defs.weaponByIndex[ws.weaponIndex]
		end
		local height = Combat.UNIT_HEIGHT * def.footprint
		local radius = def.footprint * Combat.RADIUS_PER_FOOTPRINT
		maxRadius = math.max(maxRadius, radius)
		profiles[index] = {
			radius = radius,
			height = height,
			muzzleHeight = height * Combat.MUZZLE_HEIGHT,
			armorClass = def.armorClass,
			categoryMask = def.categoryMask,
			maxHealth = def.health,
			weapons = weapons,
		}
	end
	local grid = if layers then layers.grid else nil
	return {
		profiles = profiles,
		maxRadius = maxRadius,
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
		pTeam = {},
		pTtl = {},
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

-- Bottom of a unit's collision cylinder.
function Combat.unitBase(c: Combat, w: World.World, id: number): number
	return Combat.groundHeight(c, w.posX[id], w.posZ[id]) + w.alt[id]
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

-- Explosion at (x, y, z) from `weapon` fired by `attacker` of `team`.
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
		if id == direct or (w.team[id] == team and not c.friendlyFire) then
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
	ttl: number
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
	c.pWeapon[id], c.pOwner[id], c.pTeam[id], c.pTtl[id] = nil, nil, nil, nil
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
	end
	h = Hash.u32(h, c.nextProjId)
	h = Hash.u32(h, #c.wreckIds)
	for _, id in c.wreckIds do
		h = Hash.u32(h, id)
		h = Hash.number(h, c.wreckX[id])
		h = Hash.number(h, c.wreckZ[id])
		h = Hash.u32(h, c.wreckDef[id])
	end
	return h
end

return Combat
