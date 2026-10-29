--!strict
-- Mammoth: Chaos's heavily armored T2 assault bot (S-209, the user's
-- playtest 3 H41): elephant-like, tougher than the Fatboy, extremely slow.
-- Two barrels fire the green laser left, right, left: 2 shots a second,
-- each one heavy; it clears swarms and stands up to heavies.
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_mammoth",
	name = "Mammoth",
	description = "Heavily armored assault bot. Very slow; twin green lasers fire left and right, two heavy shots a second.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 2,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 720, power = 8200, buildTime = 18000 },
	health = 6200, -- more than the Fatboy's 4,800 (H41)
	movement = { maxSpeed = 6, accel = 8, brake = 18, turnRate = 120 },
	sensors = { sight = 210 },
	weapons = { { def = "chs_mammoth_laser", turretPiece = "turret", pitchPiece = "barrels", muzzle = "muzzleL", muzzles = { "muzzleL", "muzzleR" } } },
	pieces = { "base", "legFL", "legFR", "legBL", "legBR", "turret", "barrels", "muzzleL", "muzzleR" },
	icon = "tank_heavy",
	model = "chs_mammoth",
})
