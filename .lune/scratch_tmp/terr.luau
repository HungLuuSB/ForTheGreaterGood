local MapRegistry = require("../../src/shared/Grid/MapRegistry")
local Layers = require("../../src/shared/Grid/Layers")
for _, id in { "map:ridgeline", "map:coastline", "map:twin_lakes", "map:crossroads" } do
	local l = MapRegistry.load(id)
	local counts = { [0] = 0, 0, 0, 0 }
	for i = 0, l.grid.cellCount - 1 do
		local t = Layers.getTerrain(l, i)
		counts[t] += 1
	end
	print(id, "grass", counts[0], "rock", counts[1], "sand", counts[2])
end
