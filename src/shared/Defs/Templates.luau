--!strict
-- Def templates and the extend() helper (guide 4.1). Unit and weapon modules
-- require this module, not Defs.luau, so Defs can require them without a cycle.
--
--   local Templates = require("../Templates")
--   return Templates.extend(Templates.TankT1, { id = "ord_lancer", ... })

local Templates = {}

local function isArray(t: { [any]: any }): boolean
	return next(t) == nil or t[1] ~= nil
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- Returns a new table: base deep-copied, then overrides applied. Nested
-- records (cost, movement, sensors...) merge key by key; arrays (categories,
-- weapons, pieces...) and empty tables replace the base value whole. Neither
-- input is modified.
function Templates.extend(base: { [string]: any }, overrides: { [string]: any }): { [string]: any }
	local out = deepCopy(base)
	for k, v in overrides do
		local current = out[k]
		if type(v) == "table" and type(current) == "table" and not isArray(v) and not isArray(current) then
			out[k] = Templates.extend(current, v)
		else
			out[k] = deepCopy(v)
		end
	end
	return out
end

-- Defaults shared by every mobile unit.
Templates.Unit = table.freeze({
	sensors = table.freeze({ sight = 0, radar = 0, sonar = 0, radarSignature = 1 }),
	weapons = table.freeze({}),
	footprint = 1,
})

-- T1 light/medium tank: tracked, armored, one turret.
Templates.TankT1 = table.freeze(Templates.extend(Templates.Unit, {
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "TRACKED",
	footprint = 1,
	pieces = { "base", "turret", "barrel", "muzzle" },
	script = "TankScript",
	icon = "tank_light",
}))

-- Immobile structures: built in place, block their footprint (odd sizes).
Templates.Structure = table.freeze(Templates.extend(Templates.Unit, {
	tier = 1,
	domain = "structure",
	categories = { "STRUCTURE" },
	armorClass = "STRUCTURE",
	footprint = 1,
	placement = "land",
	sensors = { sight = 60 },
	pieces = { "base" },
	icon = "structure",
}))

-- Mobile builders (Command Vehicle, workers): tracked, unarmed.
Templates.Builder = table.freeze(Templates.extend(Templates.Unit, {
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "WORKER" },
	armorClass = "ARMORED",
	moveClass = "TRACKED",
	footprint = 1,
	pieces = { "base", "nano" },
	icon = "worker",
}))

return table.freeze(Templates)
