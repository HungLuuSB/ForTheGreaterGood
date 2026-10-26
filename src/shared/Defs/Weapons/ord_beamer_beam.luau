--!strict
-- The Beamer's blue beam (S-157, the user: "a continuous blue high intensity
-- beam, more range than Sentry, low damage at first but increase to a capped
-- if the unit decided to stay in its range"): five short hitscan pulses a
-- second, each 10 at first, rising to 50 after 4 s on one target (the damage
-- table is the full 50). Leaving a target pauses it 0.1 s, up to 0.5 s from
-- full intensity. The client draws the beam's width and brightness from the
-- ramp, timed from how long it has fired at one target.
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "ord_beamer_beam",
	type = "HITSCAN",
	range = 220,
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 0.2,
	accuracy = 0,
	damage = { LIGHT = 100, ARMORED = 100, STRUCTURE = 80, SHIP = 91, AIR = 0, SUB = 0 },
	aoe = 0,
	ramp = { from = 20, to = 100, seconds = 4, cooldown = { 0.1, 0.5 } },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 1, minPitch = -60, maxPitch = 60, arc = 360 },
	fx = { tracer = "laser", color = { r = 60, g = 70, b = 255 }, impact = "beam_impact", sound = "beam_hum" }, -- deep blue-violet, the user's reference (S-157)
}
