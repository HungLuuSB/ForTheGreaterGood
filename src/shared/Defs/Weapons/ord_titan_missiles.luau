--!strict
-- Titan's heat-seeking vertical-launch missile (S-209, H40). One small
-- missile a volley that hunts anything but submarines, air included
-- (FTGG-FEEDBACK-4, the user: was a salvo of 4 against the ground only).
return {
	id = "ord_titan_missiles",
	type = "HOMING",
	range = 351, -- shorter T3 range (S-213, the user): was 520; -10% (S-234): was 390
	reload = 6,
	projectileSpeed = 300,
	accuracy = 1,
	turnRate = 80,
	launch = "vertical",
	climbHeight = 50,
	guidance = "IR",
	lockRange = 468, -- -10% (S-234): was 520
	terminalRange = 40,
	damage = { LIGHT = 220, ARMORED = 180, STRUCTURE = 150, SHIP = 160, AIR = 180, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE", "AIR" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_small", trail = "smoke_thin", impact = "explosion_medium", sound = "sam_radar" },
}
