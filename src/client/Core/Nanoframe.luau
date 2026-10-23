--!strict
-- Factory production, BAR-style (C-152): the unit in production stands on
-- the factory's `buildpad` (docs/contracts/rig.md section 8) as a nanoframe
-- that fills in from the bottom up while the factory's `nano1..N` emitters
-- spray at the build line. Pure logic here; Render/FactoryFrames draws it.
--
-- The sim spawns a produced unit only when it's finished, so the frame is
-- the client's: drawn from the factory's queue head and its progress (own
-- factories, protocol 20) or its PRODUCING field (allies, protocol 27).

local World = require("./World")

local Nanoframe = {}

Nanoframe.SWEEP = 1.6 -- seconds for a spray point to cross the frame and back
Nanoframe.LINE_SOFT = 0.04 -- a part counts as built once the line is this far (of the height) into it

-- What a factory is producing: its def index and progress 0..1, or nil.
function Nanoframe.producing(u: World.Unit): (number?, number)
	local q = u.queue
	if q and #q > 0 then
		return q[1], u.queueProgress or 0
	end
	local p = u.producing
	if p and p > 0 then
		return p, u.producingProgress or 0
	end
	return nil, 0
end

-- Progress arrives in steps (sixteenths of the build, Stockpile.WIRE_STEPS),
-- seconds apart on a long build. A tracker eases the drawn progress through
-- each step at the rate the last steps came, and says whether the factory
-- is still building (the spray): a step is due within STALL_GAPS of the
-- last gap, or STALL_MIN seconds.
Nanoframe.STEP = 1 / 16
Nanoframe.STALL_GAPS = 2.5
Nanoframe.STALL_MIN = 1.5

export type Tracker = { progress: number, at: number, gap: number, shown: number }

function Nanoframe.tracker(): Tracker
	return { progress = -1, at = 0, gap = 0, shown = 0 }
end

-- Seconds between progress steps at full economy: the item's build time
-- over the factory's build power, a sixteenth of it.
function Nanoframe.expectedGap(buildTime: number, buildPower: number): number
	return Nanoframe.STEP * buildTime / math.max(buildPower, 1)
end

-- The progress to draw at `now`, and whether it's moving. `expected`: the
-- step gap at full economy, used until two steps have been seen.
function Nanoframe.track(tr: Tracker, progress: number, now: number, expected: number?): (number, boolean)
	if progress ~= tr.progress then
		if tr.progress >= 0 and progress > tr.progress then
			tr.gap = now - tr.at
		else
			tr.gap = expected or 0 -- the first reading of an item
			tr.shown = 0
		end
		tr.progress, tr.at = progress, now
	end
	local since = now - tr.at
	local moving = tr.progress >= 0 and since < math.max(Nanoframe.STALL_MIN, tr.gap * Nanoframe.STALL_GAPS)
	local shown = progress
	if tr.gap > 0 and moving then
		shown = math.min(progress + math.min(since / tr.gap, 1) * Nanoframe.STEP, 1)
	end
	-- never back down within an item (a step a little short of the guess)
	tr.shown = math.max(tr.shown, shown)
	return tr.shown, moving
end

-- The build line's height (model space) at `progress` over a frame whose
-- parts span heights lo..hi.
function Nanoframe.lineY(lo: number, hi: number, progress: number): number
	local p = math.clamp(progress, 0, 1)
	return lo + (hi - lo) * p
end

-- Whether a part spanning heights bottom..top is built yet: once the line
-- passes its middle (a flat part, once it reaches it).
function Nanoframe.built(bottom: number, top: number, lineY: number, lo: number, hi: number): boolean
	local soft = (hi - lo) * Nanoframe.LINE_SOFT
	return lineY + soft >= (bottom + top) / 2
end

-- Where emitter `i` of `n` sprays at time `now`: a point on the build line
-- sweeping across the frame's footprint (half sizes hx, hz around its
-- centre), each emitter on its own phase so the streams fan out.
function Nanoframe.sprayPoint(i: number, n: number, now: number, hx: number, hz: number): (number, number)
	local phase = (i - 1) / math.max(n, 1)
	local a = (now / Nanoframe.SWEEP + phase) * 2 * math.pi
	return math.sin(a) * hx * 0.8, math.cos(a * 0.7 + phase * 3) * hz * 0.8
end

return Nanoframe
