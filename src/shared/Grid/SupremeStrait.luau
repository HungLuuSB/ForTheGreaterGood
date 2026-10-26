--!strict
-- "map:supreme_strait", Supreme Strait (S-195; rebuilt the BAR way in S-196):
-- a 320 × 320-cell (2560 × 2560-stud) map for ground, air and naval play,
-- after BAR's "Supreme Strait" (24 × 24). Its layers are images in
-- assets/maps/supreme_strait/source/ (height, type, metal, from BAR's
-- preview height map and painted texture), compiled by
-- `lune run map_compile supreme_strait` into Shared/Grid/Maps/supreme_strait
-- (docs/design/maps.md).
--
-- North is the screen's top (-z: the camera at yaw 0 looks toward -z), as in
-- BAR's images. Point-symmetric: two seas with reef islets bite in from the north-west and
-- south-east corners; a sand strait joins the plateaus through the middle;
-- each plateau has a crater lake, mesas and sand paths down to the sea;
-- rocky mountains in the other two corners. 16 start hints, 1-8 south-west.
--
-- `SupremeStrait.feature(cx, cz)` names what a cell is, for drawing: "sea"
-- (any water, the crater lakes too), "beach" (sand), "grass" or "mountain"
-- (rock).

local CompiledMap = require("./CompiledMap")
local Layers = require("./Layers")
local Compiled = require("./Maps/supreme_strait")

local SupremeStrait = {}

SupremeStrait.CELLS = Compiled.cells

function SupremeStrait.build(): Layers.Layers
	return CompiledMap.build(Compiled :: any)
end

local layers: Layers.Layers? = nil
function SupremeStrait.feature(cx: number, cz: number): string
	local l = layers
	if l == nil then
		l = SupremeStrait.build()
		layers = l
	end
	local m = l :: Layers.Layers
	local i = m.grid:index(cx, cz)
	if Layers.getWater(m, i) > 0 then
		return "sea"
	end
	local t = Layers.getTerrain(m, i)
	return if t == Layers.Terrain.ROCK then "mountain" elseif t == Layers.Terrain.GRASS then "grass" else "beach"
end

return SupremeStrait
