--!strict
-- How a shield dome looks over time (C-90): the deploy and collapse
-- phases, the rings flowing down the dome, the low-strength flicker, the
-- opacity rule, the strategic level of detail and the off-screen test.
-- Pure Luau (C-7); Render/ShieldFx draws it.
--
-- States: "down" → deploy() → "deploying" (the beam shoots up from the
-- emitter, then the dome grows) → "up" → collapse() → "collapsing" (it
-- flickers, shrinks, the beam retracts) → "down". Re-deploy works from any
-- state.

local ShieldLook = {}

-- Ripple sizes (C-116): a ParticleEmitter's Size applies to the particles
-- it already emitted, so one emitter resized per hit made every ripple on
-- the dome jump to a heavy shell's size at once (the user saw it as a burst).
-- Each dome has one emitter per size here, sized once; a hit uses the one
-- nearest its shell (× ShieldFx.RIPPLE_SIZE × R).
ShieldLook.RIPPLE_SCALES = table.freeze({ 0.6, 0.85, 1.2, 1.7 })

-- The ripple emitter for a hit of `intensity` (1 = a typical shell): the
-- scale nearest sqrt(intensity), intensity clamped to 0.3..4.
function ShieldLook.rippleBucket(intensity: number): number
	local want = math.sqrt(math.clamp(intensity, 0.3, 4))
	local best, bestD = 1, math.huge
	for i, s in ShieldLook.RIPPLE_SCALES do
		local d = math.abs(s - want)
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

export type State = "down" | "deploying" | "up" | "collapsing"

ShieldLook.BEAM_SECONDS = 0.4 -- the beam reaching the top
ShieldLook.GROW_SECONDS = 0.6 -- then the dome growing from 0 to full
ShieldLook.COLLAPSE_SECONDS = 0.8
ShieldLook.RINGS = 9 -- per shield, a fixed pool
ShieldLook.RING_PERIOD = 5 -- seconds for a ring to slide from the top to the ground at full strength
ShieldLook.RING_TOP = 0.12 -- radians from the pole where a ring starts (not a point)
ShieldLook.LOW = 0.3 -- below this strength the flicker grows and the rings dim and slow
ShieldLook.FULL = 0.5 -- the dome is fully visible from this strength up (the user's rule)
ShieldLook.LOD_ENTER = 480 -- studs from the camera: strategic detail (only the dome and edge)
ShieldLook.LOD_LEAVE = 420

local function easeOut(k: number): number
	local c = math.clamp(k, 0, 1)
	return 1 - (1 - c) ^ 3
end

local function easeIn(k: number): number
	local c = math.clamp(k, 0, 1)
	return c * c
end

-- The state after `since` seconds in `state`: deploying ends up, collapsing ends down.
function ShieldLook.advance(state: State, since: number): State
	if state == "deploying" and since >= ShieldLook.BEAM_SECONDS + ShieldLook.GROW_SECONDS then
		return "up"
	elseif state == "collapsing" and since >= ShieldLook.COLLAPSE_SECONDS then
		return "down"
	end
	return state
end

-- `since` seconds into `state`: the beam's length (0..1 of the way to the
-- top), the dome's scale (0..1 of its radius), the ground ring flash's
-- progress (0..1, nil when there is none) and a collapse flicker (1 = steady).
function ShieldLook.phase(state: State, since: number): (number, number, number?, number)
	if state == "deploying" then
		local beam = math.clamp(since / ShieldLook.BEAM_SECONDS, 0, 1)
		local k = (since - ShieldLook.BEAM_SECONDS) / ShieldLook.GROW_SECONDS
		local flash = if k >= 0 and k <= 1 then k else nil
		return beam, easeOut(k), flash, 1
	elseif state == "up" then
		return 1, 1, nil, 1
	elseif state == "collapsing" then
		local k = since / ShieldLook.COLLAPSE_SECONDS
		local flicker = if math.floor(since * 24) % 2 == 0 then 1 else 0.35
		local scale = 1 - easeIn((k - 0.25) / 0.5)
		local beam = 1 - math.clamp((k - 0.6) / 0.4, 0, 1)
		return beam, scale, nil, flicker
	end
	return 0, 0, nil, 1
end

-- The dome's opacity (0..1) at a strength: invisible at 0, full from FULL up.
function ShieldLook.opacity(strength: number): number
	return math.clamp(strength / ShieldLook.FULL, 0, 1)
end

-- The low-strength flicker at time `t`: 1 at LOW and above; below, faster
-- and deeper the weaker it is.
function ShieldLook.flicker(strength: number, t: number): number
	if strength >= ShieldLook.LOW then
		return 1
	end
	local k = math.clamp((ShieldLook.LOW - strength) / ShieldLook.LOW, 0, 1)
	local freq = 3 + 12 * k -- Hz
	local depth = 0.15 + 0.6 * k
	return 1 - depth * (0.5 + 0.5 * math.sin(t * freq * 2 * math.pi))
end

-- The rings' speed (1 = full) and brightness (0..1) at a strength: they dim
-- and slow below LOW.
function ShieldLook.ringFlow(strength: number): (number, number)
	if strength >= ShieldLook.LOW then
		return 1, 1
	end
	local k = math.clamp(strength / ShieldLook.LOW, 0, 1)
	return 0.3 + 0.7 * k, 0.25 + 0.75 * k
end

-- Ring `i` of `n` at flow phase `phase` (any number; one unit = one trip
-- top to ground): its angle from the pole, its radius and height as
-- fractions of the dome's (r = sin θ, y = cos θ) and its opacity, fading in
-- under the top and out near the ground.
function ShieldLook.ringAt(i: number, n: number, phase: number): (number, number, number, number)
	local p = ((i - 1) / n + phase) % 1
	local theta = ShieldLook.RING_TOP + p * (math.pi / 2 - ShieldLook.RING_TOP)
	local alpha = math.min(1, p / 0.12) * math.min(1, (1 - p) / 0.3)
	return theta, math.sin(theta), math.cos(theta), alpha
end

-- Strategic level of detail for a shield `distance` studs from the camera, with hysteresis.
function ShieldLook.strategic(was: boolean, distance: number): boolean
	if was then
		return distance > ShieldLook.LOD_LEAVE
	end
	return distance > ShieldLook.LOD_ENTER
end

-- Whether a dome is on screen: its centre's screen position (`sx`, `sy`,
-- `depth` along the view; negative behind), its radius in pixels at that
-- depth, the viewport size, and whether the camera is inside it.
function ShieldLook.onScreen(sx: number, sy: number, depth: number, radiusPx: number, w: number, h: number, inside: boolean): boolean
	if inside then
		return true
	end
	if depth <= 0 then
		return false
	end
	return sx + radiusPx >= 0 and sx - radiusPx <= w and sy + radiusPx >= 0 and sy - radiusPx <= h
end

-- The field's force on a shell over one tick (C-97): its velocity now
-- (vx, vy, vz) and one tick on (nvx, nvy, nvz, from the field step), minus
-- what its own gravity `g` did. Returns the force's unit direction and its
-- size (studs/s gained per tick); size 0 when the field does nothing.
ShieldLook.TICK = 1 / 15
function ShieldLook.force(vx: number, vy: number, vz: number, nvx: number, nvy: number, nvz: number, g: number): (number, number, number, number)
	local fx, fy, fz = nvx - vx, nvy - vy + g * ShieldLook.TICK, nvz - vz
	local size = math.sqrt(fx * fx + fy * fy + fz * fz)
	if size < 1e-6 then
		return 0, 0, 0, 0
	end
	return fx / size, fy / size, fz / size, size
end

-- How long the force plume is (studs) for a force of `size`.
ShieldLook.PLUME_PER_SPEED = 0.2 -- studs per stud/s of change per tick
ShieldLook.PLUME_MIN = 2
ShieldLook.PLUME_MAX = 14
function ShieldLook.plume(size: number): number
	return math.clamp(size * ShieldLook.PLUME_PER_SPEED, ShieldLook.PLUME_MIN, ShieldLook.PLUME_MAX)
end

return ShieldLook
