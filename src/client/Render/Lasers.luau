--!strict
-- Laser bolts (C-199, the user's reference for Overwatch and Geryon): a
-- bright core, white at the muzzle turning to the weapon's colour, thick
-- where it leaves and tapering to a thread at the target, inside a soft
-- glow of that colour; a flare at the muzzle and a glowing orb where it
-- lands. Every laser (fx.tracer = "laser", S-157) draws this way in its own
-- colour, sized by its weapon.
-- A held beam (a weapon with a `ramp`: the Beamer, the user's second
-- reference) is a thread instead: a thin, flickering white core with a
-- coloured fringe, the same width all the way, a small flare at the muzzle
-- and a cone of light opening at the target; it widens with its ramp.
-- Pooled: three Beams on three attachments, and three balls, per bolt.

local Lasers = {}

Lasers.CORE = 0.55 -- studs: the core's width at the muzzle (scale 1)
Lasers.TIP = 0.07 -- and at the target
Lasers.GLOW = 1.7 -- the glow's width at the muzzle
Lasers.GLOW_TIP = 0.35
Lasers.FLARE = 1.1 -- the muzzle flare's diameter
Lasers.ORB = 1.3 -- the impact orb's diameter (its halo twice that)
Lasers.THREAD = 0.14 -- a held beam's core width (ramp 0)
-- weapons drawn wider (F11, the user: Sentry and Overwatch beams, both
-- factions): their glow by this, the core by its square root, so a wider
-- beam stays a bright core in a soft glow, not a solid rod (the user)
Lasers.WIDER = table.freeze({ ord_sentry_laser = 1.8, chs_guard_laser = 1.8, ord_overwatch_laser = 1.8, chs_twin_laser = 1.8 }) :: { [string]: number }
Lasers.PULSE = 0.22 -- a bolt's width wavers by this share as it lives
Lasers.FLARE_OVER_GLOW = 1.15 -- the muzzle halo's diameter over the glow's width at the muzzle
Lasers.FRINGE = 0.45 -- and its coloured fringe
Lasers.CONE = 1.8 -- its impact cone's mouth, and length 1.4 times that
Lasers.SPARKS = 10 -- flicker keypoints along a held beam's core

type Bolt = { a0: Attachment, a1: Attachment, a2: Attachment, core: Beam, glow: Beam, cone: Beam, flare: Part, muzzleHalo: Part, orb: Part, halo: Part }
export type State = { folder: Folder, bolts: { Bolt }, used: number }

local WHITE = Color3.new(1, 1, 1)

local function ball(folder: Folder, name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = folder
	return p
end

local function beam(a0: Attachment, a1: Attachment, folder: Folder, name: string): Beam
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Segments = 1
	b.Enabled = false
	b.Parent = folder
	return b
end

function Lasers.new(folder: Folder): State
	local f = Instance.new("Folder")
	f.Name = "Lasers"
	f.Parent = folder
	return { folder = f, bolts = {}, used = 0 }
end

local function bolt(s: State, i: number): Bolt
	local b = s.bolts[i]
	if b == nil then
		local a0 = Instance.new("Attachment")
		a0.Parent = workspace.Terrain
		local a1 = Instance.new("Attachment")
		a1.Parent = workspace.Terrain
		local a2 = Instance.new("Attachment")
		a2.Parent = workspace.Terrain
		b = {
			a0 = a0,
			a1 = a1,
			a2 = a2,
			cone = beam(a1, a2, s.folder, "LaserCone"),
			glow = beam(a0, a1, s.folder, "LaserGlow"),
			core = beam(a0, a1, s.folder, "LaserCore"),
			flare = ball(s.folder, "LaserFlare"),
			muzzleHalo = ball(s.folder, "LaserMuzzleHalo"),
			orb = ball(s.folder, "LaserOrb"),
			halo = ball(s.folder, "LaserHalo"),
		}
		b.core.ZOffset = 1
		b.cone.Transparency = NumberSequence.new(0.15, 1)
		s.bolts[i] = b
	end
	return b
end

-- A held beam's look: the thread, its flicker, the cone where it lands.
-- It doesn't fade between bolts: they join into one beam (C-198).
local function thread(b: Bolt, color: Color3, ramp: number, from: Vector3, to: Vector3, now: number, n: number)
	local grow = 1 + 0.6 * ramp
	-- the core flickers: white and colour alternating along it, moving each frame
	local keys, alpha = table.create(Lasers.SPARKS + 2), table.create(Lasers.SPARKS + 2)
	keys[1] = ColorSequenceKeypoint.new(0, WHITE)
	alpha[1] = NumberSequenceKeypoint.new(0, 0)
	for i = 1, Lasers.SPARKS do
		local h = math.sin(now * 91.7 + i * 12.9898 + n * 78.233) * 43758.5453
		h -= math.floor(h) -- 0..1, a fresh hash each frame
		local at = (i - 0.5 + 0.8 * (h - 0.5)) / Lasers.SPARKS
		keys[i + 1] = ColorSequenceKeypoint.new(at, if h > 0.45 then WHITE else WHITE:Lerp(color, 0.7))
		alpha[i + 1] = NumberSequenceKeypoint.new(at, 0.35 * h)
	end
	keys[Lasers.SPARKS + 2] = ColorSequenceKeypoint.new(1, WHITE:Lerp(color, 0.5))
	alpha[Lasers.SPARKS + 2] = NumberSequenceKeypoint.new(1, 0.2)
	b.core.Color = ColorSequence.new(keys)
	b.core.Transparency = NumberSequence.new(alpha)
	local w = Lasers.THREAD * grow * (0.85 + 0.3 * math.abs(math.sin(now * 53 + n)))
	b.core.Width0, b.core.Width1 = w, w * 0.8
	b.glow.Width0, b.glow.Width1 = Lasers.FRINGE * grow, Lasers.FRINGE * grow * 0.8
	b.glow.Color = ColorSequence.new(color)
	b.glow.Transparency = NumberSequence.new(0.45, 0.6)
	b.core.Enabled, b.glow.Enabled = true, true
	-- the cone: its mouth at the target, narrowing back along the beam
	local back = from - to
	local len = back.Magnitude
	local cone = Lasers.CONE * grow
	b.a2.WorldPosition = if len > 1e-3 then to + back.Unit * math.min(cone * 1.4, len) else to
	b.cone.Width0, b.cone.Width1 = cone, 0.1
	b.cone.Color = ColorSequence.new(WHITE:Lerp(color, 0.6), color)
	b.cone.Enabled = true
	local flare = 0.55 * grow * (1 + 0.2 * math.sin(now * 40 + n))
	b.flare.Size = Vector3.new(flare, flare, flare)
	b.flare.CFrame = CFrame.new(from)
	b.flare.Color = color
	b.flare.Transparency = 0.2
	b.muzzleHalo.Transparency = 1 -- (a bolt's: pooled bolts change kind)
	local orb = 0.6 * grow
	b.orb.Size = Vector3.new(orb, orb, orb)
	b.orb.CFrame = CFrame.new(to)
	b.orb.Color = WHITE:Lerp(color, 0.4)
	b.orb.Transparency = 0.1
	b.halo.Size = Vector3.new(orb * 2.2, orb * 2.2, orb * 2.2)
	b.halo.CFrame = CFrame.new(to)
	b.halo.Color = color
	b.halo.Transparency = 0.65
end

-- Draws this frame's laser tracers (Core/Effects' tracers with `laser`).
function Lasers.step(s: State, tracers: { any }, now: number)
	local n = 0
	for _, t in tracers do
		local rgb = t.laser
		if rgb == nil then
			continue
		end
		n += 1
		local b = bolt(s, n)
		local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		local from, to = Vector3.new(t.x0, t.y0, t.z0), Vector3.new(t.x1, t.y1, t.z1)
		b.a0.WorldPosition, b.a1.WorldPosition = from, to
		if t.ramp then
			thread(b, color, t.ramp, from, to, now, n)
			continue
		end
		b.cone.Enabled = false
		local scale = math.clamp(0.55 + 0.15 * (t.size or 1), 0.7, 1.3)
		local wider = Lasers.WIDER[t.weaponId or ""] or 1
		local k = math.clamp((now - t.born) / t.life, 0, 1)
		local fade = math.max(0, k - 0.35) / 0.65
		local pulse = 1 + Lasers.PULSE * math.sin(now * 55 + n * 1.7)
		local coreW = scale * math.sqrt(wider) * pulse
		b.core.Width0, b.core.Width1 = Lasers.CORE * coreW, Lasers.TIP * coreW
		b.core.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.25, WHITE:Lerp(color, 0.55)),
			ColorSequenceKeypoint.new(1, color),
		})
		b.core.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.min(1, 0.0 + fade)),
			NumberSequenceKeypoint.new(1, math.min(1, 0.15 + fade)),
		})
		b.glow.Width0, b.glow.Width1 = Lasers.GLOW * scale * wider, Lasers.GLOW_TIP * scale * wider
		b.glow.Color = ColorSequence.new(color)
		-- soft: brightest near the muzzle, fading along the line
		b.glow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.min(1, 0.6 + 0.4 * fade)),
			NumberSequenceKeypoint.new(0.5, math.min(1, 0.78 + 0.22 * fade)),
			NumberSequenceKeypoint.new(1, math.min(1, 0.9 + 0.1 * fade)),
		})
		b.core.Enabled, b.glow.Enabled = true, true
		-- the muzzle: a white-hot flash, and a soft halo in the beam's colour
		-- as wide as the glow leaving it (the user: without one the glow
		-- looked wider than the point it came from)
		local flicker = 1 + 0.15 * math.sin(now * 40 + n)
		local flare = Lasers.FLARE * scale * math.sqrt(wider) * flicker
		b.flare.Size = Vector3.new(flare, flare, flare)
		local mh = Lasers.GLOW * scale * wider * Lasers.FLARE_OVER_GLOW * flicker
		b.muzzleHalo.Size = Vector3.new(mh, mh, mh)
		b.muzzleHalo.CFrame = CFrame.new(from)
		b.muzzleHalo.Color = color
		b.muzzleHalo.Transparency = math.min(1, 0.55 + 0.45 * fade)
		b.flare.CFrame = CFrame.new(from)
		b.flare.Color = WHITE:Lerp(color, 0.35)
		b.flare.Transparency = math.min(1, 0.15 + fade)
		local orb = Lasers.ORB * scale
		b.orb.Size = Vector3.new(orb, orb, orb)
		b.orb.CFrame = CFrame.new(to)
		b.orb.Color = color
		b.orb.Transparency = math.min(1, 0.1 + fade)
		b.halo.Size = Vector3.new(orb * 1.6, orb * 1.6, orb * 1.6)
		b.halo.CFrame = CFrame.new(to)
		b.halo.Color = color
		b.halo.Transparency = math.min(1, 0.82 + 0.18 * fade)
	end
	for i = n + 1, s.used do
		local b = s.bolts[i]
		b.core.Enabled, b.glow.Enabled, b.cone.Enabled = false, false, false
		b.flare.Transparency, b.muzzleHalo.Transparency, b.orb.Transparency, b.halo.Transparency = 1, 1, 1, 1
	end
	s.used = n
end

return Lasers
