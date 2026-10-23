--!strict
-- Each map's own look (C-155, the user: "each map will have its own
-- environment + lighting settings + effects + time of day"): its lighting
-- preset (Render/Atmosphere, with the time of day), the colour of the land
-- past its edge, and its ambient particles (Render/Environment). Maps
-- without an entry get the default, the moonlit night (C-101). The
-- Settings atmosphere "map" (the default) follows this; the other presets
-- override it.

local MapLook = {}

-- Pure Luau (C-7): colours as { r, g, b } 0..255, vectors as { x, y, z }.
export type Particles = {
	color: { number },
	wind: { number }, -- acceleration, studs/s²
}

export type Look = {
	atmosphere: string, -- a Render/Atmosphere preset name
	skirt: { number }, -- ground beyond the map's edge
	dust: Particles,
	mist: Particles,
}

MapLook.DEFAULT = table.freeze({
	atmosphere = "night",
	skirt = { 30, 32, 36 },
	dust = { color = { 200, 210, 230 }, wind = { 1.5, 0.1, 0.6 } }, -- motes in the moonlight
	mist = { color = { 150, 160, 180 }, wind = { 0.8, 0, 0.3 } },
} :: Look)

MapLook.LOOKS = table.freeze({
	-- The Canyon (S-132): a desert at mid-afternoon, sand blowing across
	["map:canyon"] = table.freeze({
		atmosphere = "desert",
		skirt = { 150, 116, 80 },
		dust = { color = { 226, 196, 150 }, wind = { 4, 0.2, 1.5 } },
		mist = { color = { 222, 196, 158 }, wind = { 2, 0, 0.8 } },
	} :: Look),
} :: { [string]: Look })

function MapLook.of(mapId: string?): Look
	return if mapId then MapLook.LOOKS[mapId] or MapLook.DEFAULT else MapLook.DEFAULT
end

return MapLook
