--!strict
-- Armor classes (guide 4.4). Every weapon damage table must cover all of them;
-- a missing entry counts as 0 damage and is logged at load.

local ArmorClasses = {}

-- In this order everywhere (validation messages, hashing).
ArmorClasses.list = table.freeze({ "LIGHT", "ARMORED", "STRUCTURE", "AIR", "SHIP", "SUB" })

local set: { [string]: boolean } = {}
for _, name in ArmorClasses.list do
	set[name] = true
end
ArmorClasses.set = table.freeze(set)

return table.freeze(ArmorClasses)
