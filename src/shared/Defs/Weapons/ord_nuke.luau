--!strict
-- Reckoning warhead (S-48, client request 26): strategic missile, fired only
-- on an attack-ground order, anywhere on the map. Straight up 120 studs, a
-- pitch-over, then a lofted arc peaking 300 studs up (Shared/Combat/Lofted,
-- S-51): ~12 s in the air whatever the distance, so radar SAMs get time.
return {
	id = "ord_nuke",
	type = "BALLISTIC",
	range = 8192, -- anywhere on the map
	reload = 10,
	projectileSpeed = 150, -- boost speed straight up (S-51)
	climbHeight = 120, -- boost to this height above the ground, then turn (S-51, the user asked)
	turnRate = 90, -- pitch-over toward the lofted arc, degrees per second (S-51)
	gravity = 12, -- with the boost and pitch-over, ~12.7 s of flight (S-51)
	apex = 300, -- the arc peaks this high above the ordered spot; low enough to stay on screen (S-49)
	accuracy = 0,
	strategic = true,
	manualFire = true,
	stockpile = { capacity = 10, buildTime = 120, cost = { supply = 1500, power = 40000 } }, -- (10, the user, 2026-10-27)
	damage = { LIGHT = 8000, ARMORED = 8000, STRUCTURE = 10000, SHIP = 8000, AIR = 4000, SUB = 3000 },
	aoe = 150,
	edgeEffectiveness = 0.05, -- the edge counts (S-178, F16): 400 at the rim, 8000 at the centre
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	fx = { muzzle = "nuke_launch", trail = "smoke_huge", impact = "explosion_nuke", sound = "nuke_launch" },
}
