--!strict
-- Titan's heat-seeking vertical-launch missiles (S-209, H40).
return {
	id = "ord_titan_missiles",
	type = "HOMING",
	range = 520,
	reload = 6,
	salvo = { count = 4, delay = 0.25 },
	projectileSpeed = 300,
	accuracy = 1,
	turnRate = 80,
	launch = "vertical",
	climbHeight = 50,
	guidance = "IR",
	lockRange = 520,
	terminalRange = 40,
	damage = { LIGHT = 220, ARMORED = 180, STRUCTURE = 150, SHIP = 160, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_medium", sound = "sam_radar" },
}
