--!strict
-- Radiance's beam (S-96, client request 43; BAR's Pulsar): precise, long,
-- a very heavy beam on a long reload, each shot paid in power from the
-- team's stores. S-113 (client request 47): it fires at radar contacts too
-- (aimed at the believed position, so it misses wobbling blips unless
-- Pinpointers sharpen them, S-59), and the beam lingers 3 s (S-115), dealing
-- its damage over that time to every enemy its line crosses (a hit-ray).
return {
	id = "ord_radiance_beam",
	type = "BEAM",
	range = 488, -- -25% (S-203, the user's H7; was 650)
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 9,
	accuracy = 0,
	damage = { LIGHT = 3000, ARMORED = 3000, STRUCTURE = 2300, SHIP = 3000, AIR = 0, SUB = 0 }, -- over the whole beam (S-113)
	beamDuration = 3, -- (S-115, the user: was 2.5)
	pierce = true, -- a hit-ray: every enemy on its line takes the share each tick (S-115)
	canTargetRadar = true,
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 700 },
	turret = { yawRate = 45, pitchRate = 30, tolerance = 1, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy", color = { r = 60, g = 150, b = 255 } }, -- electric blue (S-203, the user's H38)
}
