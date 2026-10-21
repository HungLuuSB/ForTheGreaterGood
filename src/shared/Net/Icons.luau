--!strict
-- Strategic icon numbering on the wire (net.md section 3; S-10, client
-- request 5; unique per unit type since S-58, client request 35): a unit's
-- icon number is its def index (Defs: sorted by ID, from 1), so every unit
-- type has its own icon; 0 = an unknown blip. A u8 on the wire, so at most
-- 255 unit defs. `def.icon` stays the family name (the shape the client
-- draws); `Icons.names` lists the families. The server's NetOut and clients
-- both number icons with this, so the two always agree.

local Defs = require("../Defs/Defs")

local Icons = {}

Icons.MAX = 255

-- The icon family names, sorted.
function Icons.names(defs: Defs.DefSet): { string }
	local names = {}
	for _, def in defs.unitByIndex do
		if table.find(names, def.icon) == nil then
			table.insert(names, def.icon)
		end
	end
	table.sort(names)
	return names
end

-- Unit def index → icon number (the def index itself).
function Icons.byDef(defs: Defs.DefSet): { [number]: number }
	assert(#defs.unitByIndex <= Icons.MAX, `Icons: {#defs.unitByIndex} unit defs don't fit a u8 icon`)
	local out = {}
	for index in defs.unitByIndex do
		out[index] = index
	end
	return out
end

return Icons
