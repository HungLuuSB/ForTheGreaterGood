--!strict
-- Shield dome hits (C-87, a client-only prototype; no sim mechanic yet):
-- where a hit's hexagon plates sit on the dome, how they heat and fade, how
-- nearby hits merge, and a deflected shell's brake and bounce. Pure Luau
-- (C-7); Render/ShieldFx draws it.
--
-- A hit lights a patch of honeycomb cells around the hit point: cells in
-- hex rings round the centre, laid on the sphere along great circles so the
-- patch wraps the dome. Since C-132 (the user, BAR's plasma deflector) the
-- wave runs inward: the outermost ring lights first, each ring in RING_DELAY
-- later, the centre last and hottest. Cells grow toward the centre (smaller
-- at the rim, bigger inside, spaced a little wider), and the whole patch is
-- pushed in like a bowl, deepest at the centre, then eases back to the
-- surface (never past it: the bounce out read as cells moving outward, the
-- user, C-134): the dome caving in to repel the shot.

local Shield = {}

export type V3 = { x: number, y: number, z: number }

export type Plate = {
	pos: V3, -- on the sphere
	normal: V3, -- outward
	right: V3, -- the plate's in-plane axis (the hex grid's orientation)
	ring: number, -- hex rings from the centre
	scale: number, -- the cell's size, × PLATE (bigger at the centre, C-132)
}

export type Patch = {
	hit: V3,
	strength: number, -- 1 = a typical shell; heat, size and dent grow with it
	born: number, -- its latest hit
	rings: number,
	plates: { Plate },
	waves: { number }, -- each hit's time: its own wave out from the centre (C-117)
}

export type Dome = {
	center: V3,
	radius: number,
	patches: { Patch },
	idle: { Patch }, -- faint team-coloured flickers that show the hex shell at rest
	charge: number, -- 0..1: the field's force follows it (the prototype's stand-in for the sim)
	up: boolean, -- false once collapsed at 0%, until recharged to RAISE_AT
}

Shield.PLATE = 2.6 -- studs across a cell's flats (4.5 in C-116..C-130; outlined cells since C-131: BAR's fine honeycomb)
Shield.GAP = 0 -- studs between cells: outlines touch, a honeycomb
Shield.RING_DELAY = 0.07 -- seconds between rings lighting: a visible wave out (0.045 until C-117)
Shield.MAX_WAVES = 4 -- waves a patch keeps at once
Shield.LIFE = 0.65 -- seconds a plate glows after it lights
Shield.RING_ALPHA = 0.45 -- each ring out is this much as opaque as the one inside it (0.3 in C-104; up with the second ring every hit lights, C-116)
Shield.MAX_PATCHES = 6 -- patches per dome at once (the oldest goes)
Shield.MERGE = 6 -- studs: a hit this close to a young patch heats it instead
Shield.MERGE_AGE = 0.65 -- while it glows (Shield.LIFE): a later hit adds a wave instead of a second grid on top (C-117)
Shield.MAX_RINGS = 5
Shield.DENT = 1.4 -- studs the centre pushes in at strength 1 (the rings less, a bowl)
Shield.CENTER_SCALE = 1.3 -- the centre cell's size, × PLATE; the rim's is CENTER_SCALE − RIM_SHRINK
Shield.RIM_SHRINK = 0.55
Shield.SPREAD = 0.3 -- inner rings sit this much further apart than the rim's (positions follow the sizes)
Shield.DENT_PEAK = 0.12 -- seconds after a cell lights when it is pushed in deepest

-- A cell's size in a patch of `rings` rings, × PLATE.
function Shield.cellScale(ring: number, rings: number): number
	return Shield.CENTER_SCALE - Shield.RIM_SHRINK * ring / math.max(rings, 1)
end

local SQRT3 = math.sqrt(3)

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end
local function sub(a: V3, b: V3): V3
	return v(a.x - b.x, a.y - b.y, a.z - b.z)
end
local function add(a: V3, b: V3): V3
	return v(a.x + b.x, a.y + b.y, a.z + b.z)
end
local function mul(a: V3, k: number): V3
	return v(a.x * k, a.y * k, a.z * k)
end
local function dot(a: V3, b: V3): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end
local function cross(a: V3, b: V3): V3
	return v(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end
local function len(a: V3): number
	return math.sqrt(dot(a, a))
end
local function unit(a: V3): V3
	local l = len(a)
	return if l > 1e-9 then mul(a, 1 / l) else v(0, 1, 0)
end
Shield.unit, Shield.dot, Shield.len, Shield.sub = unit, dot, len, sub

-- Rings of hexagons by a hit's strength: a light hit lights the centre and
-- one ring (7 plates), a heavy one up to MAX_RINGS (37).
function Shield.ringsFor(strength: number): number
	-- three rings at least (37 cells), four for a typical shell (61), five for
	-- heavy ones (91): a wide patch of fine cells (C-131, the BAR reference)
	return math.clamp(math.floor(3 + strength), 3, Shield.MAX_RINGS)
end

-- The plates of a patch on a sphere (`center`, `radius`) round the point
-- of the sphere nearest `hit`.
function Shield.layout(center: V3, radius: number, hit: V3, rings: number): { Plate }
	local n = unit(sub(hit, center))
	-- a tangent basis at the hit; any `up` not parallel to n will do
	local ref = if math.abs(n.y) < 0.9 then v(0, 1, 0) else v(1, 0, 0)
	local u = unit(cross(ref, n))
	local w = cross(n, u)
	local step = Shield.PLATE + Shield.GAP
	local reach = step * math.max(rings, 1)
	local out: { Plate } = {}
	for q = -rings, rings do
		for r = math.max(-rings, -q - rings), math.min(rings, -q + rings) do
			local ring = math.max(math.abs(q), math.abs(r), math.abs(q + r))
			-- axial hex coordinates to the tangent plane (flat sides across u)
			local px, py = step * (q + r / 2), step * (r * SQRT3 / 2)
			local d = math.sqrt(px * px + py * py)
			local pos, normal
			if d < 1e-9 then
				normal = n
			else
				-- walk the arc along the great circle towards (px, py); the inner rings
				-- spread a little (their cells are bigger), the rim's draw in
				local dir = unit(add(mul(u, px), mul(w, py)))
				local a = d * (1 + Shield.SPREAD * (1 - d / reach)) / radius
				normal = unit(add(mul(n, math.cos(a)), mul(dir, math.sin(a))))
			end
			pos = add(center, mul(normal, radius))
			-- carry the grid's axis onto this plate's tangent plane
			local right = unit(sub(u, mul(normal, dot(u, normal))))
			table.insert(out, { pos = pos, normal = normal, right = right, ring = ring, scale = Shield.cellScale(ring, rings) })
		end
	end
	return out
end

-- A cell's look `age` seconds after its wave was born, in a patch of
-- `rings` rings: heat (1 = white hot, 0 = cold), opacity (0..1) and dent
-- (studs inward, never outward).
function Shield.plateAt(age: number, ring: number, strength: number, rings: number): (number, number, number)
	-- the wave runs in: the rim first, the centre last (C-132)
	local t = age - (rings - ring) * Shield.RING_DELAY
	if t < 0 then
		return 0, 0, 0
	end
	-- outer rings fade sooner, so an older patch keeps a hot core
	local life = Shield.LIFE * (0.8 + 0.2 * math.min(strength, 3)) * (1 - 0.15 * ring)
	if t >= life then
		return 0, 0, 0
	end
	local k = t / life
	-- one bright centre, the rings around it much fainter and greyer: equal
	-- rings bloomed into separate white blobs and one shell read as five or
	-- six hitting at once (the user, C-104)
	local peak = math.clamp(0.55 + 0.25 * strength, 0.4, 1) * math.max(0.2, 1 - ring * 0.4)
	local heat = peak * (1 - k) ^ 1.6
	local alpha = math.min(1, t / 0.04) * (1 - k ^ 2) * Shield.RING_ALPHA ^ ring
	-- the patch caves in like a bowl (deepest at the centre) and eases back
	-- to the surface: in, then home, no swing past it (C-134)
	local depth = Shield.DENT * math.min(strength, 3) * (1 - (ring / (rings + 1)) ^ 2)
	local x = t / Shield.DENT_PEAK
	local dent = depth * x * math.exp(1 - x)
	return heat, alpha, dent
end

local RAMP = {
	{ 0, 150, 154, 160 },
	{ 1, 255, 255, 255 },
}
-- The plate colour for a heat: white at its hottest, fading to grey (the
-- user: no red or orange, C-95).
function Shield.color(heat: number): (number, number, number)
	local h = math.clamp(heat, 0, 1)
	local a, b = RAMP[1], RAMP[2]
	return a[2] + (b[2] - a[2]) * h, a[3] + (b[3] - a[3]) * h, a[4] + (b[4] - a[4]) * h
end

function Shield.newDome(center: V3, radius: number): Dome
	return { center = center, radius = radius, patches = {}, idle = {}, charge = 1, up = true }
end

-- Idle flickers: a centre plate and one ring, fading in and out over
-- IDLE_LIFE, at most MAX_IDLE at once (the oldest goes).
Shield.IDLE_LIFE = 1.4
Shield.MAX_IDLE = 18
Shield.IDLE_CLEAR = 14 -- studs: no flicker this close to a live hit patch

-- Returns nil (no flicker) next to a live hit patch: idle hexes drawn over
-- hot ones look wrong.
function Shield.idle(dome: Dome, at: V3, now: number): Patch?
	local n = unit(sub(at, dome.center))
	local on = add(dome.center, mul(n, dome.radius))
	for _, p in dome.patches do
		if len(sub(p.hit, on)) < Shield.IDLE_CLEAR + p.rings * (Shield.PLATE + Shield.GAP) then
			return nil
		end
	end
	local patch = { hit = on, strength = 0, born = now, rings = 1, plates = Shield.layout(dome.center, dome.radius, on, 1), waves = { now } }
	table.insert(dome.idle, patch)
	if #dome.idle > Shield.MAX_IDLE then
		table.remove(dome.idle, 1)
	end
	return patch
end

-- An idle plate's opacity `age` seconds in: up and down, the ring a little later.
function Shield.idleAt(age: number, ring: number): number
	local t = age - ring * 0.12
	if t <= 0 or t >= Shield.IDLE_LIFE then
		return 0
	end
	return math.sin(math.pi * t / Shield.IDLE_LIFE) * (if ring == 0 then 1 else 0.6)
end

-- A hit on `dome` at `now`: heats a young patch within MERGE, else opens a
-- new one (dropping the oldest at MAX_PATCHES). Returns the patch.
function Shield.hit(dome: Dome, hit: V3, strength: number, now: number): Patch
	local n = unit(sub(hit, dome.center))
	local on = add(dome.center, mul(n, dome.radius))
	for _, p in dome.patches do
		if now - p.born < Shield.MERGE_AGE and len(sub(p.hit, on)) < Shield.MERGE then
			p.strength = math.min(p.strength + strength * 0.6, 4)
			-- a new wave through the same grid; the earlier ones keep fading.
			-- Restarting the patch snapped it back to full heat, so under steady
			-- fire it sat lit and looked solid, not animated (the user, C-117)
			p.born = now
			table.insert(p.waves, now)
			if #p.waves > Shield.MAX_WAVES then
				table.remove(p.waves, 1)
			end
			local rings = Shield.ringsFor(p.strength)
			if rings > p.rings then
				p.rings = rings
				p.plates = Shield.layout(dome.center, dome.radius, p.hit, rings)
			end
			return p
		end
	end
	-- idle flickers next to a new hit go
	for i = #dome.idle, 1, -1 do
		if len(sub(dome.idle[i].hit, on)) < Shield.IDLE_CLEAR + Shield.ringsFor(strength) * (Shield.PLATE + Shield.GAP) then
			table.remove(dome.idle, i)
		end
	end
	local rings = Shield.ringsFor(strength)
	local patch = { hit = on, strength = strength, born = now, rings = rings, plates = Shield.layout(dome.center, dome.radius, on, rings), waves = { now } }
	table.insert(dome.patches, patch)
	if #dome.patches > Shield.MAX_PATCHES then
		table.remove(dome.patches, 1)
	end
	return patch
end

-- A plate of `patch` at `now`: the brightest of its waves (heat, opacity, dent).
function Shield.plateLook(patch: Patch, ring: number, now: number): (number, number, number)
	local heat, alpha, dent = 0, 0, 0
	for _, born in patch.waves do
		local h, a, d = Shield.plateAt(now - born, ring, patch.strength, patch.rings)
		if a > alpha then
			heat, alpha = h, a
		end
		if math.abs(d) > math.abs(dent) then
			dent = d
		end
	end
	return heat, alpha, dent
end

-- Drops patches whose last plate has faded.
function Shield.expire(dome: Dome, now: number)
	for i = #dome.patches, 1, -1 do
		local p = dome.patches[i]
		if now - p.born > Shield.LIFE * 1.5 + p.rings * Shield.RING_DELAY then
			table.remove(dome.patches, i)
		end
	end
	for i = #dome.idle, 1, -1 do
		if now - dome.idle[i].born > Shield.IDLE_LIFE + 0.2 then
			table.remove(dome.idle, i)
		end
	end
end

-- A deflected shell (the prototype's fake shots; a repulsor field, C-87).
-- Inside the BAND studs outside the dome the field pushes along the
-- surface normal: an inbound shell's radial speed bleeds off (a constant
-- part plus drag, stronger deeper in) until it turns round, which is the
-- hit (the plates light where it turned), then the same field throws it
-- back out, faster the deeper it got. The field's force is the dome's
-- charge over FULL_FORCE (full at 50% charge and above), divided by the
-- shell's mass: a heavy shell takes longer to stop, and a weak dome lets it
-- reach the surface still inbound, which is a breach: it carries on inside.
Shield.BAND = 50
Shield.FULL_FORCE = 0.5 -- charge at and above which the field is at full force
Shield.BRAKE = 500 -- studs/s² of radial braking at full force, mass 1, mid-band
Shield.DRAG = 9 -- 1/s of radial drag at full force, mass 1, mid-band
Shield.PUSH = 1400 -- studs/s² outward after the turn, at full force, mass 1, at the surface
Shield.MASS_EXP = 0.6 -- the field divides by mass to this power: heavy shells take longer, not hopelessly
Shield.TANGENT_DRAG = 1.5 -- 1/s on the speed along the surface while in the field
Shield.HIT_COST = 0.004 -- charge per unit of mass turned back (the user: 10x the capacity of the first 0.04)
Shield.BREACH_COST = 0.002 -- charge per unit of mass that broke through
Shield.RECHARGE = 0.05 -- charge per second (from the team's power, in the real thing)
Shield.RAISE_AT = 0.25 -- a collapsed dome rises again at this charge

export type ShellEvent = "turn" | "breach"

export type Shell = {
	pos: V3,
	vel: V3,
	mass: number, -- 1 = a typical shell
	entry: number, -- speed when it reached the band (0 before)
	state: "flying" | "braking" | "repelled" | "spent" | "breached",
	hitAt: V3?, -- where it turned or broke through, once
}

-- The field's force at `charge` (0..1), before the shell's mass.
function Shield.force(charge: number): number
	return math.clamp(charge / Shield.FULL_FORCE, 0, 1)
end

-- The field's force on dome `d`: none while it's down.
function Shield.domeForce(d: Dome): number
	return if d.up then Shield.force(d.charge) else 0
end

-- Takes `amount` of charge; at 0% the dome collapses.
function Shield.drain(dome: Dome, amount: number)
	dome.charge = math.max(0, dome.charge - amount)
	if dome.charge <= 0 then
		dome.up = false
	end
end

-- Recharges by dt; a collapsed dome rises again at RAISE_AT.
function Shield.recharge(dome: Dome, dt: number)
	dome.charge = math.min(1, dome.charge + Shield.RECHARGE * dt)
	if not dome.up and dome.charge >= Shield.RAISE_AT then
		dome.up = true
	end
end

-- The plasma core's colour at a charge: green full, orange, red empty.
local CORE = {
	{ 0, 230, 40, 30 },
	{ 0.4, 255, 150, 40 },
	{ 1, 70, 255, 120 },
}
function Shield.coreColor(charge: number): (number, number, number)
	local c = math.clamp(charge, 0, 1)
	for i = 2, #CORE do
		local b = CORE[i]
		if c <= b[1] then
			local a = CORE[i - 1]
			local k = (c - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k
		end
	end
	local e = CORE[#CORE]
	return e[2], e[3], e[4]
end

function Shield.newShell(from: V3, vel: V3, mass: number?): Shell
	return { pos = from, vel = vel, mass = mass or 1, entry = 0, state = "flying", hitAt = nil }
end

-- Advances `s` by dt against `dome`; returns "turn" on the frame it turns
-- back (the hit), "breach" on the frame it breaks through, else nil.
function Shield.stepShell(s: Shell, dome: Dome, dt: number): ShellEvent?
	local R, edge = dome.radius, dome.radius + Shield.BAND
	local rel = sub(s.pos, dome.center)
	local r = len(rel)
	local n = unit(rel)
	local vr = dot(s.vel, n)
	local vt = sub(s.vel, mul(n, vr))
	if not dome.up and (s.state == "braking" or s.state == "repelled") then
		-- the dome went down under it: no field, it carries on
		s.state = if s.state == "braking" then "breached" else "spent"
	end
	if dome.up and s.state == "flying" and r <= edge and vr < 0 then
		s.state = "braking"
		s.entry = len(s.vel)
	end
	local event: ShellEvent? = nil
	if s.state == "braking" or s.state == "repelled" then
		local k = Shield.domeForce(dome) / s.mass ^ Shield.MASS_EXP
		local depth = math.clamp((edge - r) / Shield.BAND, 0, 1)
		if s.state == "braking" then
			vr += k * (0.4 + depth) * (Shield.BRAKE + Shield.DRAG * math.abs(vr)) * dt
			if vr >= 0 then
				vr = 0
				s.state = "repelled"
				s.hitAt = add(dome.center, mul(n, R))
				Shield.drain(dome, Shield.HIT_COST * s.mass)
				event = "turn"
			end
		else
			vr += k * Shield.PUSH * (0.2 + depth) * dt
			if r > edge then
				s.state = "spent"
			end
		end
		vt = mul(vt, math.exp(-Shield.TANGENT_DRAG * dt))
		s.vel = add(mul(n, vr), vt)
	end
	local nextPos = add(s.pos, mul(s.vel, dt))
	if s.state == "braking" and len(sub(nextPos, dome.center)) <= R then
		s.state = "breached"
		s.hitAt = add(dome.center, mul(n, R))
		Shield.drain(dome, Shield.BREACH_COST * s.mass)
		event = "breach"
	end
	s.pos = nextPos
	if s.state == "spent" or s.state == "breached" then
		s.vel = add(s.vel, v(0, -40 * dt, 0)) -- falls away
	end
	return event
end

return Shield
