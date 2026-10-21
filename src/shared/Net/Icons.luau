--!strict
-- Strategic icon numbering on the wire (net.md section 3, S-10, client
-- request 5): the distinct `icon` names of all unit defs, sorted, numbered
-- from 1 and capped at 63 (6 bits; 0 = unknown blip). The server's NetOut
-- and clients both number icons with this, so the two always agree.

local Defs = require("../Defs/Defs")

local Icons = {}

Icons.MAX = 63

-- Icon number → name.
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

-- Unit def index → icon number.
function Icons.byDef(defs: Defs.DefSet): { [number]: number }
	local names = Icons.names(defs)
	local out = {}
	for index, def in defs.unitByIndex do
		out[index] = math.min(table.find(names, def.icon) :: number, Icons.MAX)
	end
	return out
end

return Icons
