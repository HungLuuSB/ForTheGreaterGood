--!strict
-- Radar precision from Pinpointer structures (S-59, client request 34;
-- guide 11.4). Shared: the server applies it, and a client counting its
-- team's finished Pinpointers (unit defs with `pinpointer = true`; every
-- type has its own icon since S-58) shows the same number.
--
-- Precision grows linearly with the ally team's finished Pinpointers, full
-- at FULL of them. Since S-62 a type can need fewer or more (`pinpointFull`:
-- Order's Witness 5, Chaos's Augur 7): each one counts FULL / pinpointFull,
-- `Pinpoint.weight`, so the precision of a mixed team adds up. At precision p:
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

-- How many standard Pinpointers one finished unit of `def` counts as (S-62):
-- FULL / def.pinpointFull, 0 for a def that isn't a Pinpointer.
function Pinpoint.weight(def: { pinpointer: boolean?, pinpointFull: number? }): number
	if not def.pinpointer then
		return 0
	end
	return Pinpoint.FULL / (def.pinpointFull or Pinpoint.FULL)
end

-- Precision 0..1 for `count` standard Pinpointers (the sum of their weights).
function Pinpoint.precision(count: number): number
	return math.min(count, Pinpoint.FULL) / Pinpoint.FULL
end

-- Multiplier on radar and track error at precision `p`.
function Pinpoint.errorScale(p: number): number
	return 1 - Pinpoint.REDUCTION * p
end

return Pinpoint
