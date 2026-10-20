--!strict
-- Unit categories as bit flags (guide 4.4). Defs list categories by name;
-- the loader turns each list into one mask. Max 32 flags (bit32).
-- Values are part of the defs hash: never renumber, only append.

local Categories = {}

Categories.Bit = table.freeze({
	GROUND = 1,
	AIR = 2,
	NAVAL = 4,
	SUB = 8,
	STRUCTURE = 16,
	WORKER = 32,
	COMMANDER = 64,
	ARMORED = 128,
	LIGHT = 256,
	HELI = 512,
	JET = 1024,
	ANTIAIR = 2048,
	ARTILLERY = 4096,
	STEALTH = 8192,
	RADAR_EMITTER = 16384,
	JAMMER = 32768,
})

-- Names → combined mask. Errors on an unknown name.
function Categories.mask(names: { string }): number
	local mask = 0
	for _, name in names do
		local b = Categories.Bit[name]
		if b == nil then
			error(`Categories.mask: unknown category "{name}"`, 2)
		end
		mask = bit32.bor(mask, b)
	end
	return mask
end

return table.freeze(Categories)
