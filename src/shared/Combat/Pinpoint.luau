--!strict
-- Radar precision from Pinpointer structures (S-59, client request 34;
-- guide 11.4). Shared: the server applies it, and a client counting its
-- team's finished Pinpointers (unit defs with `pinpointer = true`; every
-- type has its own icon since S-58) shows the same number.
--
-- Precision grows linearly with the ally team's finished Pinpointers, full
-- at FULL of them. At precision p:
--   * radar contacts wobble by radarError × (1 - REDUCTION × p), and
--     fire-control tracks by trackError × (1 - REDUCTION × p): at full
--     precision a blip barely moves;
--   * a radar-guided missile chasing a target its team has only on radar
--     (not in sight) loses its lock with chance LOCK_LOSS × (1 - p) at each
--     midcourse check (EW), so long-range radar shots without Pinpointers
--     often fail.

local Pinpoint = {}

Pinpoint.FULL = 6 -- Pinpointers for full precision
Pinpoint.REDUCTION = 0.9 -- share of the radar and track error removed at full precision
Pinpoint.LOCK_LOSS = 0.1 -- per midcourse check, with no Pinpointer: a long shot (6–8 checks) fails about half the time

-- Precision 0..1 for `count` finished Pinpointers.
function Pinpoint.precision(count: number): number
	return math.min(count, Pinpoint.FULL) / Pinpoint.FULL
end

-- Multiplier on radar and track error at precision `p`.
function Pinpoint.errorScale(p: number): number
	return 1 - Pinpoint.REDUCTION * p
end

return Pinpoint
