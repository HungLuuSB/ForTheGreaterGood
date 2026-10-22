--!strict
-- Sanction missile: a T2 missile battery's radar-guided missile against ground
-- targets, artillery first (S-106, the user's pick (a) of S-96's T2
-- defenses): it outranges mobile artillery and can fire at radar contacts.
return {
	id = "ord_sanction_missile",
	type = "HOMING",
	range = 760,
	reload = 6,
	salvo = { count = 2, delay = 0.4 },
	projectileSpeed = 300,
	accuracy = 1,
	turnRate = 70,
	launch = "vertical", -- straight up, then over (S-42)
	climbHeight = 60,
	guidance = "RADAR",
	lockRange = 760,
	burnThrough = 0.35,
	terminalRange = 40,
	canTargetRadar = true,
	damage = { LIGHT = 300, ARMORED = 240, STRUCTURE = 180, SHIP = 200, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARTILLERY", "GROUND", "STRUCTURE" },
	turret = { yawRate = 60, pitchRate = 45, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_medium", sound = "sam_radar" },
}
