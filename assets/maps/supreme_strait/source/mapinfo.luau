--!strict
-- Supreme Strait (S-195, S-196): the map's settings, BAR's mapinfo.lua in
-- our form (docs/design/maps.md). Its layers are the images beside this
-- file; `lune run map_compile supreme_strait` builds the map from them.
--
-- Rebuilt from BAR's "Supreme Strait" preview images (the user's G6
-- references): height.png is its 1537-pixel height map, type.png, metal.png
-- and minimap.png come from its painted texture (`lune run map_derive`).
return {
	name = "Supreme Strait",
	description = "Two seas bite in from opposite corners; a land strait joins the plateaus through the middle. Ground, air and naval.",
	size = 24, -- BAR map units a side (512 elmos each): the height map is 64 × 24 + 1 pixels
	cells = 320, -- our cells a side (2,560 studs): BAR's 24 at The Canyon's scale
	-- studs for the height map's black and white (BAR's minheight / maxheight)
	height = { min = -6, max = 83.25 },
	waterLevel = 8, -- studs: the sea's surface (MapGen.WATER_LEVEL)
	-- type.png's greys → ground types (Layers.Terrain)
	types = { GRASS = 0, SAND = 85, ROCK = 170, ROAD = 255 },
	-- metal.png: a spot's deposit value at full red (dimmer red, less)
	metalValue = 3,
	symmetry = "point", -- the compiler makes every cell match its twin (x, z) → (-x, -z)
	-- start hints as fractions of the map (u from the west edge, v from the
	-- north edge): 1-8 the south-west side, 9-16 their twins (the compiler
	-- snaps each to open ground). The user's 8v8 spawn points (2026-10-27),
	-- north to south: 1-4 the side's northern group, 5-8 its southern.
	starts = {
		{ 0.053, 0.548 }, { 0.377, 0.597 }, { 0.208, 0.650 }, { 0.395, 0.698 },
		{ 0.355, 0.781 }, { 0.072, 0.839 }, { 0.394, 0.913 }, { 0.170, 0.952 },
	},
}
