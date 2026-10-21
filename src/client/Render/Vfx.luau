--!strict
-- Detailed combat effects for Render/Effects (C-47): explosions, muzzle
-- flashes, hit sparks, a missile's launch cloud and the flares or chaff a
-- decoyed missile goes for. Each is a pooled rig: an invisible carrier with
-- particle emitters (Studio's built-in textures, Emit only, never a Rate),
-- a light and a few animated parts. A rig is reused only once its longest
-- particles have faded (or, at its pool's cap, the oldest one is taken).
-- Scorch marks are their own pool of fading discs on the ground.
--
-- Sizes scale with the weapon's blast: `scale` 1 is a 7-stud explosion (the
-- smallest impact, C-18); a burst of diameter d gets scale d / 7, capped.
-- Particles live in world space, so smoke stays where it was made, and
-- they age in real time (they keep fading while the sim is slowed or paused).
--
-- Templates: an effect saved in the place as ReplicatedStorage.Vfx.<Name>
-- (TEMPLATE_NAMES: Impact, Death, MuzzleFlash, Hit, Launch, Decoy, Flare,
-- Chaff) replaces the built-in one, e.g. one made with a VFX plugin. It may
-- be an Attachment, a Part or Model, or a Folder of Attachments, holding
-- ParticleEmitters (and PointLights). Each emitter emits its `EmitCount`
-- attribute (on it or on the template; default 10) after `EmitDelay`
-- seconds; an emitter saved Enabled with no EmitCount runs for
-- `EmitDuration` seconds (default 0.2). Sizes and speeds scale like the
-- built-in effects; lights flash and fade over `LightSeconds` (0.25). It
-- faces the burst's direction (a shot, a flight) with its -Z (LookVector).
-- Looked up on every burst, so effects added during a playtest show at once.

local Vfx = {}

local TEX = {
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	core = "rbxasset://textures/particles/explosion01_core_main.dds",
	shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	puff = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	square = "rbxasset://textures/particles/SquareParticle.png",
}

Vfx.MAX_SCALE = 6
Vfx.GROUND_BURST = 4 -- studs: a burst this close to the ground is a ground burst (dust, ring, scorch)
Vfx.SCORCH_SECONDS = 14
Vfx.MAX_LIGHTS = 12 -- explosion and muzzle lights at once
Vfx.TEMPLATE_NAMES = table.freeze({
	impact = "Impact",
	death = "Death",
	muzzle = "MuzzleFlash",
	hit = "Hit",
	launch = "Launch",
	decoy = "Decoy",
	flare = "Flare",
	chaff = "Chaff",
} :: { [string]: string })
Vfx.TEMPLATE_CAP = 24 -- copies of one template at once
local RING_DIRECTIONS = 8

local function seq(points: { { number } }, scale: number?): NumberSequence
	local k = scale or 1
	local out = table.create(#points)
	for i, p in points do
		out[i] = NumberSequenceKeypoint.new(p[1], p[2] * k, (p[3] or 0) * k)
	end
	return NumberSequence.new(out)
end

local function colors(points: { { any } }): ColorSequence
	local out = table.create(#points)
	for i, p in points do
		out[i] = ColorSequenceKeypoint.new(p[1], p[2])
	end
	return ColorSequence.new(out)
end

-- An emitter's look at scale 1: sizes and speeds grow with the scale,
-- counts more slowly (cost); `ground` emitters only fire for ground bursts,
-- `air` ones only for air bursts.
type Spec = {
	name: string,
	texture: string,
	life: { number },
	speed: { number },
	size: { { number } },
	transparency: { { number } },
	color: ColorSequence,
	count: number,
	light: number?, -- LightEmission
	drag: number?,
	accel: Vector3?,
	spread: Vector2?,
	rotSpeed: number?,
	facing: Enum.ParticleOrientation?,
	direction: Enum.NormalId?, -- relative to the rig's facing (the shot, the flight)
	ground: boolean?,
	air: boolean?,
	ring: boolean?, -- emitted outward along the ground in RING_DIRECTIONS directions (dust)
	z: number?, -- ZOffset: drawn in front of the rest
}

local ORANGE = Color3.fromRGB(255, 150, 50)
local YELLOW = Color3.fromRGB(255, 235, 160)
local GREY = Color3.fromRGB(120, 118, 115)
local LIGHT_GREY = Color3.fromRGB(205, 203, 198)
local DUST = Color3.fromRGB(150, 130, 100)

local EXPLOSION: { Spec } = {
	{ name = "Core", texture = TEX.core, life = { 0.12, 0.18 }, speed = { 0, 0 }, size = { { 0, 5 }, { 1, 8 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, YELLOW }, { 1, ORANGE } }), count = 2, light = 1, z = 2 },
	{ name = "Fireball", texture = TEX.fire, life = { 0.35, 0.65 }, speed = { 3, 9 }, size = { { 0, 2.5 }, { 0.4, 4.5 }, { 1, 5.5 } }, transparency = { { 0, 0.05 }, { 0.6, 0.35 }, { 1, 1 } }, color = colors({ { 0, YELLOW }, { 0.35, ORANGE }, { 1, Color3.fromRGB(120, 40, 20) } }), count = 10, light = 0.8, drag = 5, rotSpeed = 90, z = 1 },
	{ name = "Sparks", texture = TEX.sparks, life = { 0.4, 0.9 }, speed = { 18, 42 }, size = { { 0, 0.7 }, { 1, 0.1 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, YELLOW }, { 1, ORANGE } }), count = 14, light = 1, drag = 1.5, accel = Vector3.new(0, -35, 0) },
	{ name = "Smoke", texture = TEX.smoke, life = { 2.4, 3.6 }, speed = { 1.5, 4.5 }, size = { { 0, 2.5 }, { 1, 7.5 } }, transparency = { { 0, 0.45 }, { 0.5, 0.7 }, { 1, 1 } }, color = colors({ { 0, Color3.fromRGB(80, 75, 70) }, { 1, Color3.fromRGB(150, 148, 145) } }), count = 6, drag = 1.5, accel = Vector3.new(0, 2.5, 0), rotSpeed = 25 },
	{ name = "Dust", texture = TEX.smoke, life = { 1.2, 2 }, speed = { 10, 20 }, size = { { 0, 2 }, { 1, 6 } }, transparency = { { 0, 0.4 }, { 1, 1 } }, color = colors({ { 0, DUST }, { 1, LIGHT_GREY } }), count = 10, drag = 6, spread = Vector2.new(12, 12), direction = Enum.NormalId.Front, ground = true, ring = true },
	{ name = "Shockwave", texture = TEX.shock, life = { 0.25, 0.25 }, speed = { 0, 0 }, size = { { 0, 3 }, { 1, 13 } }, transparency = { { 0, 0.35 }, { 1, 1 } }, color = colors({ { 0, Color3.new(1, 1, 1) }, { 1, LIGHT_GREY } }), count = 1, light = 0.3, air = true },
}

local DEATH_EXTRA: { Spec } = {
	{ name = "Debris", texture = TEX.square, life = { 0.9, 1.6 }, speed = { 14, 30 }, size = { { 0, 0.7 }, { 1, 0.5 } }, transparency = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } }, color = colors({ { 0, Color3.fromRGB(60, 58, 55) }, { 1, Color3.fromRGB(30, 28, 26) } }), count = 10, accel = Vector3.new(0, -45, 0), rotSpeed = 300, spread = Vector2.new(60, 60), direction = Enum.NormalId.Top },
	{ name = "BlackSmoke", texture = TEX.smoke, life = { 4, 6 }, speed = { 1, 3 }, size = { { 0, 3 }, { 1, 10 } }, transparency = { { 0, 0.4 }, { 0.5, 0.65 }, { 1, 1 } }, color = colors({ { 0, Color3.fromRGB(45, 43, 41) }, { 1, Color3.fromRGB(105, 103, 100) } }), count = 6, accel = Vector3.new(0, 4, 0), rotSpeed = 20 },
}

local MUZZLE: { Spec } = {
	{ name = "Flash", texture = TEX.core, life = { 0.05, 0.08 }, speed = { 0, 0 }, size = { { 0, 2.2 }, { 1, 0.6 } }, transparency = { { 0, 0 }, { 1, 0.9 } }, color = colors({ { 0, Color3.new(1, 1, 0.9) }, { 1, YELLOW } }), count = 2, light = 1, z = 2 },
	{ name = "Jet", texture = TEX.fire, life = { 0.06, 0.1 }, speed = { 25, 40 }, size = { { 0, 1.3 }, { 1, 0.3 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, YELLOW }, { 1, ORANGE } }), count = 4, light = 1, spread = Vector2.new(8, 8), direction = Enum.NormalId.Front, z = 1 },
	{ name = "Puff", texture = TEX.smoke, life = { 0.6, 1 }, speed = { 3, 7 }, size = { { 0, 0.8 }, { 1, 2.6 } }, transparency = { { 0, 0.45 }, { 1, 1 } }, color = colors({ { 0, LIGHT_GREY }, { 1, GREY } }), count = 3, drag = 3, spread = Vector2.new(25, 25), direction = Enum.NormalId.Front, accel = Vector3.new(0, 1.5, 0) },
}

local HIT: { Spec } = {
	{ name = "Spark", texture = TEX.sparks, life = { 0.2, 0.45 }, speed = { 12, 30 }, size = { { 0, 0.5 }, { 1, 0.05 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, Color3.new(1, 1, 0.85) }, { 1, ORANGE } }), count = 8, light = 1, accel = Vector3.new(0, -30, 0) },
	{ name = "Flash", texture = TEX.core, life = { 0.06, 0.09 }, speed = { 0, 0 }, size = { { 0, 1.6 }, { 1, 0.4 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, Color3.new(1, 1, 0.9) }, { 1, YELLOW } }), count = 1, light = 1 },
}

local LAUNCH: { Spec } = {
	{ name = "Flash", texture = TEX.core, life = { 0.12, 0.2 }, speed = { 0, 0 }, size = { { 0, 3 }, { 1, 5 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, YELLOW }, { 1, ORANGE } }), count = 2, light = 1, z = 2 },
	{ name = "Blast", texture = TEX.fire, life = { 0.15, 0.3 }, speed = { 10, 25 }, size = { { 0, 1.5 }, { 1, 0.4 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, YELLOW }, { 1, ORANGE } }), count = 8, light = 1, spread = Vector2.new(15, 15), direction = Enum.NormalId.Back, z = 1 },
	{ name = "Cloud", texture = TEX.smoke, life = { 2.5, 4 }, speed = { 4, 12 }, size = { { 0, 2 }, { 1, 8 } }, transparency = { { 0, 0.25 }, { 0.6, 0.55 }, { 1, 1 } }, color = colors({ { 0, Color3.fromRGB(240, 238, 232) }, { 1, Color3.fromRGB(170, 168, 164) } }), count = 14, drag = 2.5, spread = Vector2.new(60, 60), direction = Enum.NormalId.Back, accel = Vector3.new(0, 1.5, 0), rotSpeed = 20 },
	{ name = "Dust", texture = TEX.smoke, life = { 1.5, 2.5 }, speed = { 12, 22 }, size = { { 0, 2 }, { 1, 6 } }, transparency = { { 0, 0.45 }, { 1, 1 } }, color = colors({ { 0, DUST }, { 1, LIGHT_GREY } }), count = 10, drag = 5, spread = Vector2.new(12, 12), direction = Enum.NormalId.Front, ground = true, ring = true },
}

local DECOY: { Spec } = {
	{ name = "Pop", texture = TEX.sparkle, life = { 0.2, 0.35 }, speed = { 4, 10 }, size = { { 0, 1.6 }, { 1, 0.3 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(190, 220, 255) } }), count = 6, light = 1 },
}

local JAM: { Spec } = {
	{ name = "Glint", texture = TEX.sparkle, life = { 0.15, 0.3 }, speed = { 2, 6 }, size = { { 0, 2.2 }, { 1, 0.4 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(255, 120, 90) } }), count = 6, light = 1, z = 2 },
}

local CHAFF: { Spec } = {
	{ name = "Chaff", texture = TEX.sparkle, life = { 1.2, 2 }, speed = { 4, 12 }, size = { { 0, 0.5 }, { 1, 0.3 } }, transparency = { { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } }, color = colors({ { 0, Color3.fromRGB(220, 225, 235) }, { 1, Color3.fromRGB(160, 165, 175) } }), count = 30, light = 0.6, drag = 2, accel = Vector3.new(0, -4, 0), rotSpeed = 400 },
	{ name = "Haze", texture = TEX.smoke, life = { 1.5, 2.2 }, speed = { 1, 3 }, size = { { 0, 3 }, { 1, 7 } }, transparency = { { 0, 0.7 }, { 1, 1 } }, color = colors({ { 0, LIGHT_GREY }, { 1, LIGHT_GREY } }), count = 4, drag = 1 },
}

type Kind = {
	specs: { Spec },
	cap: number,
	life: number, -- seconds until its longest particles are gone
	light: { color: Color3, range: number, brightness: number, seconds: number }?,
	flash: { color: Color3, size: number, seconds: number }?, -- a Neon ball that grows and fades (the scene dump sees it)
	ring: boolean?, -- ground bursts: an expanding dust ring on the ground
	ringSize: number?, -- its final diameter at scale 1 (default: 7 studs × 2.7) and how long it takes
	ringSeconds: number?,
	scorch: boolean?, -- ground bursts: a scorch mark
	scorchSize: number?, -- its diameter at scale 1 (default 5.6 studs)
	flares: number?, -- falling flares, each a bright ball with a smoke trail
	laser: boolean?, -- a beam from the burst to its target point (DIRCM); the emitters play at the target
}

local function longest(specs: { Spec }): number
	local m = 0
	for _, s in specs do
		m = math.max(m, s.life[2])
	end
	return m
end

local function combine(a: { Spec }, b: { Spec }): { Spec }
	local out = table.clone(a)
	for _, s in b do
		table.insert(out, s)
	end
	return out
end

-- A nuke (C-57): sizes are for a 150-stud blast at scale 1 (Vfx.spawn's
-- scale is aoe / 150 for it): a blinding flash, a fireball, a stem and a
-- mushroom cap that climb and spread for seconds, dust thrown out along the
-- ground, a shockwave ring racing out to ~3x the blast and a wide scorch.
local NUKE: { Spec } = {
	{ name = "Core", texture = TEX.core, life = { 0.35, 0.5 }, speed = { 0, 0 }, size = { { 0, 60 }, { 1, 110 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, Color3.new(1, 1, 0.95) }, { 1, YELLOW } }), count = 3, light = 1, z = 3 },
	{ name = "Fireball", texture = TEX.fire, life = { 1.5, 2.6 }, speed = { 20, 55 }, size = { { 0, 28 }, { 0.4, 60 }, { 1, 70 } }, transparency = { { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }, color = colors({ { 0, Color3.new(1, 1, 0.85) }, { 0.3, ORANGE }, { 1, Color3.fromRGB(110, 40, 20) } }), count = 40, light = 0.9, drag = 3, rotSpeed = 40, z = 2 },
	{ name = "Stem", texture = TEX.smoke, life = { 6, 8 }, speed = { 40, 85 }, size = { { 0, 22 }, { 1, 45 } }, transparency = { { 0, 0.2 }, { 0.7, 0.5 }, { 1, 1 } }, color = colors({ { 0, Color3.fromRGB(150, 90, 60) }, { 0.3, Color3.fromRGB(110, 100, 95) }, { 1, Color3.fromRGB(160, 155, 150) } }), count = 30, drag = 0.7, spread = Vector2.new(8, 8), direction = Enum.NormalId.Top, accel = Vector3.new(0, 4, 0), rotSpeed = 15 },
	{ name = "Cap", texture = TEX.smoke, life = { 8, 10 }, speed = { 110, 160 }, size = { { 0, 45 }, { 1, 110 } }, transparency = { { 0, 0.15 }, { 0.6, 0.45 }, { 1, 1 } }, color = colors({ { 0, Color3.fromRGB(230, 140, 70) }, { 0.15, Color3.fromRGB(140, 110, 95) }, { 1, Color3.fromRGB(175, 170, 165) } }), count = 40, drag = 1.3, spread = Vector2.new(28, 28), direction = Enum.NormalId.Top, accel = Vector3.new(0, 2, 0), rotSpeed = 10 },
	{ name = "Dust", texture = TEX.smoke, life = { 4, 6 }, speed = { 120, 200 }, size = { { 0, 25 }, { 1, 60 } }, transparency = { { 0, 0.3 }, { 1, 1 } }, color = colors({ { 0, DUST }, { 1, LIGHT_GREY } }), count = 48, drag = 2, spread = Vector2.new(6, 6), direction = Enum.NormalId.Front, ground = true, ring = true },
	{ name = "Sparks", texture = TEX.sparks, life = { 1.5, 3 }, speed = { 80, 180 }, size = { { 0, 4 }, { 1, 0.5 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = colors({ { 0, YELLOW }, { 1, ORANGE } }), count = 40, light = 1, drag = 1, accel = Vector3.new(0, -60, 0) },
}

-- A shell, bomb or torpedo meeting the water (C-82): a white column that
-- falls back, spray, a drifting mist and a foam ring along the surface.
local FOAM = Color3.fromRGB(235, 245, 250)
local SPRAY = Color3.fromRGB(200, 225, 240)
local SPLASH: { Spec } = {
	{ name = "Column", texture = TEX.smoke, life = { 0.8, 1.3 }, speed = { 22, 42 }, size = { { 0, 1.6 }, { 0.5, 3.5 }, { 1, 5 } }, transparency = { { 0, 0.1 }, { 0.7, 0.4 }, { 1, 1 } }, color = colors({ { 0, FOAM }, { 1, SPRAY } }), count = 14, drag = 1, spread = Vector2.new(10, 10), direction = Enum.NormalId.Top, accel = Vector3.new(0, -45, 0), rotSpeed = 40 },
	{ name = "Spray", texture = TEX.square, life = { 0.6, 1.1 }, speed = { 14, 34 }, size = { { 0, 0.45 }, { 1, 0.2 } }, transparency = { { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }, color = colors({ { 0, FOAM }, { 1, SPRAY } }), count = 16, spread = Vector2.new(40, 40), direction = Enum.NormalId.Top, accel = Vector3.new(0, -60, 0), rotSpeed = 200 },
	{ name = "Mist", texture = TEX.smoke, life = { 1.6, 2.6 }, speed = { 1, 4 }, size = { { 0, 3 }, { 1, 8 } }, transparency = { { 0, 0.5 }, { 1, 1 } }, color = colors({ { 0, FOAM }, { 1, FOAM } }), count = 5, drag = 1.5, accel = Vector3.new(0, 1.5, 0) },
	{ name = "Foam", texture = TEX.smoke, life = { 1.2, 2 }, speed = { 8, 14 }, size = { { 0, 1.5 }, { 1, 4.5 } }, transparency = { { 0, 0.35 }, { 1, 1 } }, color = colors({ { 0, FOAM }, { 1, FOAM } }), count = 8, drag = 4, spread = Vector2.new(10, 10), direction = Enum.NormalId.Front, ground = true, ring = true },
}

local KINDS: { [string]: Kind } = {
	nuke = { specs = NUKE, cap = 4, life = longest(NUKE), light = { color = Color3.fromRGB(255, 230, 190), range = 60, brightness = 12, seconds = 1.5 }, flash = { color = Color3.new(1, 1, 0.9), size = 120, seconds = 0.6 }, ring = true, ringSize = 450, ringSeconds = 1.6 }, -- no scorch decal: a ground burst digs a crater (Render/Crater, C-82)
	impact = { specs = EXPLOSION, cap = 32, life = longest(EXPLOSION), light = { color = ORANGE, range = 12, brightness = 3, seconds = 0.25 }, flash = { color = YELLOW, size = 6, seconds = 0.12 }, ring = true, scorch = true },
	death = { specs = combine(EXPLOSION, DEATH_EXTRA), cap = 16, life = longest(combine(EXPLOSION, DEATH_EXTRA)), light = { color = ORANGE, range = 16, brightness = 3.5, seconds = 0.35 }, flash = { color = YELLOW, size = 8, seconds = 0.15 }, ring = true, scorch = true },
	muzzle = { specs = MUZZLE, cap = 32, life = longest(MUZZLE), light = { color = YELLOW, range = 7, brightness = 2, seconds = 0.06 } },
	hit = { specs = HIT, cap = 24, life = longest(HIT) },
	launch = { specs = LAUNCH, cap = 10, life = longest(LAUNCH), light = { color = ORANGE, range = 10, brightness = 2.5, seconds = 0.3 } },
	decoy = { specs = DECOY, cap = 8, life = longest(DECOY) },
	flare = { specs = DECOY, cap = 6, life = 3, flares = 4 },
	chaff = { specs = CHAFF, cap = 6, life = longest(CHAFF) },
	dircm = { specs = JAM, cap = 6, life = longest(JAM), laser = true },
	splash = { specs = SPLASH, cap = 24, life = longest(SPLASH), flash = { color = FOAM, size = 3, seconds = 0.08 } },
}

type Emitter = { spec: Spec, emitter: ParticleEmitter, scale: number }
type Flare = { part: BasePart, trail: Trail, vx: number, vy: number, vz: number }
type Rig = {
	kind: string,
	carrier: BasePart,
	attachment: Attachment,
	emitters: { Emitter },
	light: PointLight?,
	flash: BasePart?,
	ring: BasePart?,
	laser: BasePart?,
	flares: { Flare },
	born: number,
	freeAt: number,
	scale: number,
	x: number,
	y: number,
	z: number,
	ground: boolean,
	tx: number, -- the target point (flares head there, a laser ends there)
	ty: number,
	tz: number,
	live: boolean, -- still animating (light, flash, ring, laser, flares)
}

type Scorch = { part: BasePart, born: number }

-- A copy of a saved template (see the header).
type TEmitter = { emitter: ParticleEmitter, size: NumberSequence, speed: NumberRange, count: number?, delay: number, duration: number, emitted: boolean }
type TLight = { light: PointLight, brightness: number, range: number, seconds: number }
type TRig = {
	template: Instance,
	root: Instance,
	carrier: BasePart?, -- Attachments and Folders hang from it; Parts and Models move themselves
	emitters: { TEmitter },
	lights: { TLight },
	born: number,
	freeAt: number,
	life: number,
	scale: number,
	live: boolean,
}

export type State = {
	folder: Folder,
	rigs: { [string]: { Rig } },
	copies: { [Instance]: { TRig } }, -- by template
	scorches: { Scorch },
	lights: number, -- lit this frame
	timeScale: number, -- every emitter's TimeScale (the sim speed, at most 1)
	stats: { spawned: { [string]: number }, templated: { [string]: number }, stolen: number, maxLive: number },
}

local function newPart(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	return p
end

local function newEmitter(spec: Spec, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = spec.name
	e.Enabled = false
	e.Rate = 0
	e.Texture = spec.texture
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
	e.Transparency = seq(spec.transparency)
	e.Color = spec.color
	e.LightEmission = spec.light or 0
	e.LightInfluence = if (spec.light or 0) > 0.5 then 0 else 1
	e.Drag = spec.drag or 0
	e.Acceleration = spec.accel or Vector3.zero
	e.SpreadAngle = spec.spread or Vector2.new(180, 180)
	e.EmissionDirection = spec.direction or Enum.NormalId.Top
	e.Orientation = spec.facing or Enum.ParticleOrientation.FacingCamera
	e.ZOffset = spec.z or 0
	if spec.rotSpeed then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-spec.rotSpeed, spec.rotSpeed)
	end
	e.Parent = parent
	return e
end

local function newRig(v: State, kind: string): Rig
	local k = KINDS[kind]
	local carrier = newPart("VfxCarrier")
	carrier.Transparency = 1
	carrier.Size = Vector3.new(0.2, 0.2, 0.2)
	local attachment = Instance.new("Attachment")
	attachment.Parent = carrier
	local emitters = {}
	for _, spec in k.specs do
		local e = newEmitter(spec, attachment)
		e.TimeScale = v.timeScale
		table.insert(emitters, { spec = spec, emitter = e, scale = -1 })
	end
	local light: PointLight? = nil
	if k.light then
		local l = Instance.new("PointLight")
		l.Color = k.light.color
		l.Shadows = false
		l.Enabled = false
		l.Parent = carrier
		light = l
	end
	local flash: BasePart? = nil
	if k.flash then
		local f = newPart("Flash")
		f.Shape = Enum.PartType.Ball
		f.Color = k.flash.color
		f.Transparency = 1
		f.Parent = v.folder
		flash = f
	end
	local ring: BasePart? = nil
	if k.ring then
		local r = newPart("Ring")
		r.Shape = Enum.PartType.Cylinder -- axis X: rotated to stand up
		r.Material = Enum.Material.SmoothPlastic
		r.Color = DUST
		r.Transparency = 1
		r.Parent = v.folder
		ring = r
	end
	local laser: BasePart? = nil
	if k.laser then
		local l = newPart("Laser")
		l.Color = Color3.fromRGB(255, 70, 60)
		l.Transparency = 1
		l.Parent = v.folder
		laser = l
	end
	local flares = {}
	for _ = 1, k.flares or 0 do
		local part = newPart("Flare")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.1, 1.1, 1.1)
		part.Color = Color3.fromRGB(255, 250, 230)
		part.Transparency = 1
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.4, 0), Vector3.new(0, -0.4, 0)
		a0.Parent, a1.Parent = part, part
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 1.4
		trail.FaceCamera = true
		trail.LightInfluence = 1
		trail.Color = ColorSequence.new(Color3.fromRGB(235, 235, 230), Color3.fromRGB(190, 190, 186))
		trail.Transparency = seq({ { 0, 0.2 }, { 1, 1 } })
		trail.WidthScale = seq({ { 0, 1 }, { 1, 4 } })
		trail.Enabled = false
		trail.Parent = part
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 240, 200)
		glow.Range = 10
		glow.Brightness = 3
		glow.Shadows = false
		glow.Parent = part
		part.Parent = v.folder
		table.insert(flares, { part = part, trail = trail, vx = 0, vy = 0, vz = 0 })
	end
	carrier.Parent = v.folder
	return { kind = kind, carrier = carrier, attachment = attachment, emitters = emitters, light = light, flash = flash, ring = ring, laser = laser, flares = flares, born = -math.huge, freeAt = -math.huge, scale = 1, x = 0, y = 0, z = 0, tx = 0, ty = 0, tz = 0, ground = false, live = false }
end

function Vfx.new(folder: Folder): State
	local rigs = {}
	for kind in KINDS do
		rigs[kind] = {}
	end
	return { folder = folder, rigs = rigs, copies = {}, scorches = {}, lights = 0, timeScale = 1, stats = { spawned = {}, templated = {}, stolen = 0, maxLive = 0 } }
end

local function rigFor(v: State, kind: string, now: number): Rig
	local pool = v.rigs[kind]
	local oldest: Rig? = nil
	for _, rig in pool do
		if now >= rig.freeAt then
			return rig
		end
		if oldest == nil or rig.born < oldest.born then
			oldest = rig
		end
	end
	if #pool < KINDS[kind].cap then
		local rig = newRig(v, kind)
		table.insert(pool, rig)
		return rig
	end
	v.stats.stolen += 1
	return oldest :: Rig
end

-- A cheap hash for per-burst variety (render only, no sim randomness).
local function jitter(seed: number, k: number): number
	local h = math.sin(seed * 12.9898 + k * 78.233) * 43758.5453
	return h - math.floor(h) -- 0..1
end

local function scorch(v: State, x: number, y: number, z: number, d: number, now: number)
	local s: Scorch? = nil
	for _, other in v.scorches do
		if now - other.born >= Vfx.SCORCH_SECONDS then
			s = other
			break
		end
	end
	if s == nil then
		if #v.scorches >= 48 then
			local oldest = v.scorches[1]
			for _, other in v.scorches do
				if other.born < oldest.born then
					oldest = other
				end
			end
			s = oldest
		else
			local part = newPart("Scorch")
			part.Shape = Enum.PartType.Cylinder
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(28, 24, 22)
			part.Parent = v.folder
			s = { part = part, born = now }
			table.insert(v.scorches, s :: Scorch)
		end
	end
	local sc = s :: Scorch
	sc.born = now
	sc.part.Size = Vector3.new(0.12, d, d)
	sc.part.CFrame = CFrame.new(x, y + 0.08, z) * CFrame.Angles(0, 0, math.pi / 2)
	sc.part.Transparency = 0.3
end

-- The saved template for `kind`, if the place has one (see the header).
function Vfx.template(kind: string): Instance?
	local name = Vfx.TEMPLATE_NAMES[kind]
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Vfx")
	return if name and folder then folder:FindFirstChild(name) else nil
end

local function attr(inst: Instance, template: Instance, name: string): any
	local value = inst:GetAttribute(name)
	if value == nil then
		value = template:GetAttribute(name)
	end
	return value
end

local function newCopy(v: State, template: Instance): TRig
	local root = template:Clone()
	local carrier: BasePart? = nil
	if root:IsA("BasePart") or root:IsA("Model") then
		local parts = root:GetDescendants()
		table.insert(parts, root)
		for _, d in parts do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			end
		end
		root.Parent = v.folder
	else
		local c = newPart("VfxTemplateCarrier")
		c.Transparency = 1
		c.Size = Vector3.new(0.2, 0.2, 0.2)
		if not root:IsA("Attachment") then
			-- a Folder (or anything else): its children hang from the carrier
			for _, child in root:GetChildren() do
				child.Parent = c
			end
		end
		root.Parent = c
		c.Parent = v.folder
		carrier = c
	end
	local emitters, lights, life = {}, {}, 0.5
	local scope: Instance = carrier or root
	for _, d in scope:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local count = attr(d, template, "EmitCount") :: number?
			local delay = (attr(d, template, "EmitDelay") :: number?) or 0
			local duration = if count == nil and d.Enabled then (attr(d, template, "EmitDuration") :: number?) or 0.2 else 0
			if count == nil and duration == 0 then
				count = 10
			end
			d.Enabled = false
			d.TimeScale = v.timeScale
			table.insert(emitters, { emitter = d, size = d.Size, speed = d.Speed, count = count, delay = delay, duration = duration, emitted = true })
			life = math.max(life, delay + duration + d.Lifetime.Max)
		elseif d:IsA("PointLight") then
			table.insert(lights, { light = d, brightness = d.Brightness, range = d.Range, seconds = (attr(d, template, "LightSeconds") :: number?) or 0.25 })
			d.Enabled = false
		end
	end
	return { template = template, root = root, carrier = carrier, emitters = emitters, lights = lights, born = -math.huge, freeAt = -math.huge, life = life, scale = 1, live = false }
end

local function scaled(n: NumberSequence, k: number): NumberSequence
	local out = {}
	for i, p in n.Keypoints do
		out[i] = NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k)
	end
	return NumberSequence.new(out)
end

local function spawnTemplate(v: State, kind: string, template: Instance, frame: CFrame, s: number, now: number)
	local pool = v.copies[template]
	if pool == nil then
		pool = {}
		v.copies[template] = pool
	end
	local copy: TRig? = nil
	for _, c in pool do
		if now >= c.freeAt then
			copy = c
			break
		end
	end
	if copy == nil then
		if #pool < Vfx.TEMPLATE_CAP then
			copy = newCopy(v, template)
			table.insert(pool, copy :: TRig)
		else
			v.stats.stolen += 1
			local oldest = pool[1]
			for _, c in pool do
				if c.born < oldest.born then
					oldest = c
				end
			end
			copy = oldest
		end
	end
	local c = copy :: TRig
	c.born, c.freeAt, c.live = now, now + c.life, true
	local root = c.root
	if c.carrier then
		c.carrier.CFrame = frame
	elseif root:IsA("Model") then
		root:PivotTo(frame)
	elseif root:IsA("BasePart") then
		root.CFrame = frame
	end
	for _, e in c.emitters do
		if c.scale ~= s then
			e.emitter.Size = scaled(e.size, s)
			e.emitter.Speed = NumberRange.new(e.speed.Min * s, e.speed.Max * s)
		end
		e.emitted = false
	end
	c.scale = s
	v.stats.templated[kind] = (v.stats.templated[kind] or 0) + 1
end

-- Template copies: delayed emits, timed runs, fading lights. Returns the
-- lights lit.
local function stepTemplates(v: State, now: number, lightsUsed: number): number
	local lit = 0
	for _, pool in v.copies do
		for _, c in pool do
			if not c.live then
				continue
			end
			local age = now - c.born
			local busy = false
			for _, e in c.emitters do
				if not e.emitted and age >= e.delay then
					e.emitted = true
					if e.count then
						e.emitter:Emit(math.max(1, math.floor(e.count * math.clamp(c.scale, 1, 2.5) + 0.5)))
					end
				end
				local running = e.duration > 0 and age >= e.delay and age < e.delay + e.duration
				if e.emitter.Enabled ~= running then
					e.emitter.Enabled = running
				end
				busy = busy or not e.emitted or running
			end
			for _, l in c.lights do
				local t = age / l.seconds
				if t < 1 and lightsUsed + lit < Vfx.MAX_LIGHTS then
					lit += 1
					l.light.Enabled = true
					l.light.Brightness = l.brightness * (1 - t) ^ 2
					l.light.Range = l.range * math.sqrt(c.scale)
					busy = true
				elseif l.light.Enabled then
					l.light.Enabled = false
				end
			end
			c.live = busy
		end
	end
	return lit
end

-- Plays `kind` at (x, y, z). `scale`: 1 = a 7-stud explosion; `ground`: the
-- ground height under it; `dx, dy, dz`: the way it faces (a shot, a flight);
-- `tx, ty, tz`: where flares head, or where a laser ends.
-- A template saved in ReplicatedStorage.Vfx plays instead, if there is one.
function Vfx.spawn(v: State, kind: string, x: number, y: number, z: number, scale: number, now: number, ground: number?, dx: number?, dy: number?, dz: number?, tx: number?, ty: number?, tz: number?)
	local k = KINDS[kind]
	if k == nil then
		return
	end
	local s = math.clamp(scale, 0.3, Vfx.MAX_SCALE)
	local template = Vfx.template(kind)
	if template then
		local at = Vector3.new(x, y, z)
		local dir = if dx then Vector3.new(dx, dy :: number, dz :: number) else Vector3.zero
		spawnTemplate(v, kind, template, if dir.Magnitude > 1e-3 then CFrame.lookAt(at, at + dir) else CFrame.new(at), s, now)
		return
	end
	local rig = rigFor(v, kind, now)
	rig.born, rig.freeAt, rig.scale, rig.live = now, now + k.life, s, true
	rig.x, rig.y, rig.z = x, y, z
	rig.tx, rig.ty, rig.tz = tx or x, ty or y, tz or z
	rig.ground = ground ~= nil and y - ground <= Vfx.GROUND_BURST * math.max(1, s * 0.5)
	local at = Vector3.new(x, y, z)
	local dir = if dx then Vector3.new(dx, dy :: number, dz :: number) else Vector3.zero
	local frame = if dir.Magnitude > 1e-3 then CFrame.lookAt(at, at + dir) else CFrame.new(at)
	if k.laser then
		frame = CFrame.new(rig.tx, rig.ty, rig.tz) -- the glint plays on the jammed missile
	end
	rig.carrier.CFrame = frame
	local countScale = math.clamp(s, 1, 2.5)
	for _, em in rig.emitters do
		local spec = em.spec
		if (spec.ground and not rig.ground) or (spec.air and rig.ground) then
			continue
		end
		local e = em.emitter
		if em.scale ~= s then
			em.scale = s
			e.Size = seq(spec.size, s)
			e.Speed = NumberRange.new(spec.speed[1] * s, spec.speed[2] * s)
			if spec.accel then
				e.Acceleration = spec.accel * math.sqrt(s)
			end
		end
		if spec.ring then
			-- outward along the ground, whatever the rig faces
			local each = math.max(1, math.floor(spec.count * countScale / RING_DIRECTIONS + 0.5))
			for i = 1, RING_DIRECTIONS do
				rig.carrier.CFrame = CFrame.new(at) * CFrame.Angles(0, (i + jitter(now, i)) / RING_DIRECTIONS * 2 * math.pi, 0)
				e:Emit(each)
			end
			rig.carrier.CFrame = frame
		else
			e:Emit(math.max(1, math.floor(spec.count * countScale + 0.5)))
		end
	end
	if rig.ring then
		rig.ring.Transparency = 1
	end
	if k.scorch and rig.ground and ground then
		scorch(v, x, ground, z, (k.scorchSize or 5.6) * s, now)
	end
	for i, f in rig.flares do
		-- flares pop out of the aircraft, fan out toward the decoy point the
		-- missile went for (reached in ~0.6 s), then fall burning
		local a = (i / #rig.flares + jitter(now, i) * 0.3) * 2 * math.pi
		local to = Vector3.new(rig.tx - x, rig.ty - y, rig.tz - z) / 0.6
		f.vx = to.X + math.cos(a) * 8
		f.vy = to.Y + 4 + jitter(now, i + 7) * 5
		f.vz = to.Z + math.sin(a) * 8
		f.part.CFrame = CFrame.new(at)
		f.trail:Clear()
		f.trail.Enabled = true
		f.part.Transparency = 0
	end
	v.stats.spawned[kind] = (v.stats.spawned[kind] or 0) + 1
end

-- Animates live rigs (flash balls, lights, dust rings, flares) and fades
-- scorch marks. Call once a frame.
function Vfx.step(v: State, now: number, dt: number)
	local lights, live = 0, 0
	for kind, pool in v.rigs do
		local k = KINDS[kind]
		for _, rig in pool do
			if not rig.live then
				continue
			end
			live += 1
			local age = now - rig.born
			local done = true
			if rig.light and k.light then
				local t = age / k.light.seconds
				if t < 1 and lights < Vfx.MAX_LIGHTS then
					lights += 1
					rig.light.Enabled = true
					rig.light.Range = k.light.range * math.sqrt(rig.scale)
					rig.light.Brightness = k.light.brightness * (1 - t) ^ 2
					done = false
				else
					rig.light.Enabled = false
				end
			end
			if rig.flash and k.flash then
				local t = age / k.flash.seconds
				if t < 1 then
					local d = k.flash.size * rig.scale * (0.4 + 0.6 * t)
					rig.flash.Size = Vector3.new(d, d, d)
					rig.flash.CFrame = CFrame.new(rig.x, rig.y, rig.z)
					rig.flash.Transparency = 0.1 + 0.9 * t * t
					done = false
				elseif rig.flash.Transparency < 1 then
					rig.flash.Transparency = 1
				end
			end
			if rig.ring then
				local t = age / (k.ringSeconds or 0.45)
				if rig.ground and t < 1 then
					local d = (k.ringSize or 7 * 2.7) * rig.scale * (0.18 + 0.82 * t)
					rig.ring.Size = Vector3.new(0.3, d, d)
					rig.ring.CFrame = CFrame.new(rig.x, rig.y - 0.5, rig.z) * CFrame.Angles(0, 0, math.pi / 2)
					rig.ring.Transparency = 0.55 + 0.45 * t
					done = false
				elseif rig.ring.Transparency < 1 then
					rig.ring.Transparency = 1
				end
			end
			if rig.laser then
				local t = age / 0.4
				if t < 1 then
					local a, b = Vector3.new(rig.x, rig.y, rig.z), Vector3.new(rig.tx, rig.ty, rig.tz)
					local len = (b - a).Magnitude
					local flicker = 0.5 + 0.5 * math.sin(age * 90)
					rig.laser.Size = Vector3.new(0.18, 0.18, math.max(len, 0.1))
					rig.laser.CFrame = if len > 1e-3 then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a)
					rig.laser.Transparency = 0.1 + 0.35 * flicker + 0.5 * t
					done = false
				elseif rig.laser.Transparency < 1 then
					rig.laser.Transparency = 1
				end
			end
			if #rig.flares > 0 then
				local burning = age < 1.6
				for _, f in rig.flares do
					if burning then
						f.vy -= 22 * dt
						local p = f.part.Position
						f.part.CFrame = CFrame.new(p.X + f.vx * dt, p.Y + f.vy * dt, p.Z + f.vz * dt)
						f.vx *= 1 - math.min(1, 1.5 * dt)
						f.vz *= 1 - math.min(1, 1.5 * dt)
						f.part.Transparency = math.clamp((age - 1.2) / 0.4, 0, 1)
					elseif f.trail.Enabled then
						f.trail.Enabled = false
						f.part.Transparency = 1
					end
				end
				done = done and not burning
			end
			if done then
				rig.live = false
			end
		end
	end
	v.lights = lights + stepTemplates(v, now, lights)
	v.stats.maxLive = math.max(v.stats.maxLive, live)
	for _, s in v.scorches do
		local t = (now - s.born) / Vfx.SCORCH_SECONDS
		if t < 1 then
			s.part.Transparency = 0.3 + 0.7 * t * t
		elseif s.part.Transparency < 1 then
			s.part.Transparency = 1
		end
	end
end

-- Slows or freezes every effect's particles (the sim speed, at most 1).
function Vfx.setTimeScale(v: State, k: number)
	v.timeScale = k
	for _, pool in v.rigs do
		for _, rig in pool do
			for _, em in rig.emitters do
				em.emitter.TimeScale = k
			end
		end
	end
	for _, pool in v.copies do
		for _, c in pool do
			for _, e in c.emitters do
				e.emitter.TimeScale = k
			end
		end
	end
end

-- The scale for a burst of diameter `d` (1 = 7 studs).
function Vfx.scaleFor(d: number): number
	return d / 7
end

return Vfx
