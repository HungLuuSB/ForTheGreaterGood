--!strict
-- Player settings (C-81), a functional PLACEHOLDER: what UI/SettingsMenu
-- shows and applies. Pure Luau (C-7): the defaults, the graphics presets,
-- validation, the values each setting gives the client's modules, and the
-- key bindings reference. Settings live for the session (a Roblox client
-- has no local storage; saving them would need the server).
--   camera     pan speed (screen heights per second), zoom step per wheel
--              notch, edge scroll on / off
--   graphics   quality Low / Medium / High: effect caps (explosions,
--              tracers, projectiles drawn, lights, copies of one effect),
--              model detail distance (piece animation LOD), and fog of war shading
--              on / off (the near-zoom fog of war lights; off by default,
--              the user's call from C-32's review)
-- (No atmosphere choice since C-243, the user: "remove the option to
-- change the environment from the setting": every map has its own lighting
-- and time of day, Core/MapLook.)
--   interface  UI scale
-- High is today's look; listed under "Needs my review".

local Settings = {}

export type Quality = "low" | "medium" | "high"

export type State = {
	panSpeed: number,
	zoomStep: number,
	edgeScroll: boolean,
	quality: Quality,
	fog: boolean, -- the fog blanket's shading (C-100); what is hidden stays hidden either way
	uiScale: number,
	detailedModels: boolean, -- BAR mesh models (Render/MeshModels); off: blockouts, nothing loaded (C-106)
	glow: Glow, -- unit glow (Render/Glow): off, low (resting glow, stall dimming), high (also factory pulse, weapon flash)
	headlights: boolean, -- vehicle headlights (Render/Glow's SpotLights)
	devMode: boolean, -- developer mode (C-124): debug keys (T camera follow); on in Studio
	buildGrid: boolean, -- the build grid round the placement ghost (C-166)
}

export type Glow = "off" | "low" | "high"

-- What a quality preset sets.
export type Graphics = {
	explosions: number, -- Effects.MAX_EXPLOSIONS
	tracers: number, -- Effects.MAX_TRACERS
	projectiles: number, -- Effects.MAX_PROJECTILES
	lights: number, -- Vfx.MAX_LIGHTS
	copies: number, -- Vfx.TEMPLATE_CAP
	detailNear: number, -- PieceAnim.NEAR: full piece animation within (studs)
	detailMid: number, -- PieceAnim.MID: reduced animation within
}

Settings.QUALITY = table.freeze({
	low = table.freeze({ explosions = 20, tracers = 40, projectiles = 60, lights = 4, copies = 8, detailNear = 150, detailMid = 300 }),
	medium = table.freeze({ explosions = 40, tracers = 70, projectiles = 100, lights = 8, copies = 16, detailNear = 220, detailMid = 450 }),
	high = table.freeze({ explosions = 60, tracers = 100, projectiles = 150, lights = 12, copies = 24, detailNear = 300, detailMid = 600 }),
}) :: { [Quality]: Graphics }

Settings.QUALITIES = { "low", "medium", "high" } :: { Quality }
Settings.GLOWS = { "off", "low", "high" } :: { Glow }

Settings.LIMITS = table.freeze({
	panSpeed = { 0.4, 3, 0.1 }, -- min, max, step
	zoomStep = { 1.05, 1.4, 0.05 },
	uiScale = { 0.7, 1.5, 0.1 },
})

-- The defaults; `studio` turns edge scroll off (Studio's mouse often rests
-- on the window edge, Camera.EDGE_SCROLL).
function Settings.new(studio: boolean): State
	return { panSpeed = 1.1, zoomStep = 1.15, edgeScroll = not studio, quality = "high", fog = true, uiScale = 1, detailedModels = true, glow = "high", headlights = true, devMode = studio, buildGrid = true }
end

local function round(x: number, step: number): number
	return math.floor(x / step + 0.5) * step
end

-- Sets one setting, validated (numbers clamped to LIMITS and rounded to
-- their step). Returns false for an unknown key or a wrong type.
function Settings.set(s: State, key: string, value: any): boolean
	local t = s :: any
	local limits = (Settings.LIMITS :: any)[key]
	if limits then
		if type(value) ~= "number" or value ~= value then
			return false
		end
		t[key] = math.clamp(round(value, limits[3]), limits[1], limits[2])
		return true
	elseif key == "edgeScroll" or key == "fog" or key == "detailedModels" or key == "headlights" or key == "devMode" or key == "buildGrid" then
		if type(value) ~= "boolean" then
			return false
		end
		t[key] = value
		return true
	elseif key == "glow" then
		if table.find(Settings.GLOWS, value) == nil then
			return false
		end
		s.glow = value
		return true
	elseif key == "quality" then
		if Settings.QUALITY[value] == nil then
			return false
		end
		s.quality = value
		return true
	end
	return false
end

-- One step up or down a numeric setting.
function Settings.nudge(s: State, key: string, up: boolean): boolean
	local limits = (Settings.LIMITS :: any)[key]
	if limits == nil then
		return false
	end
	return Settings.set(s, key, (s :: any)[key] + (if up then limits[3] else -limits[3]))
end

function Settings.graphics(s: State): Graphics
	return Settings.QUALITY[s.quality]
end

-- The fixed keys reference (mouse, groups, modifiers), in groups; the
-- single-key actions are rebindable (Core/Keybinds, C-159).
Settings.KEYS = table.freeze({
	{ "Fixed: selection", {
		{ "Left click / drag", "select / box select (Shift adds, Ctrl toggles)" },
		{ "Double click", "every own unit of that type on screen" },
		{ "Ctrl + 1–9 / 1–9", "set / recall a group (double tap: jump there)" },
	} },
	{ "Fixed: orders and building", {
		{ "Right click", "smart order: attack, guard, repair or move" },
		{ "Right drag", "line move" },
		{ "Shift + order", "queue it" },
		{ "1–0 (build menu open)", "pick (Shift: 5 in a factory, right click drops one)" },
		{ "Drag (extractor)", "an extractor on every deposit in the circle (upgrades too)" },
		{ "Enter or /", "the cheat command line (/help); Ctrl+Shift+G repeats the last /give" },
	} },
	{ "Fixed: camera", {
		{ "Arrow keys / edge", "pan" },
		{ "Wheel / Alt + wheel", "zoom / pitch" },
		{ "Middle drag", "pan" },
		{ "F3", "debug readout (developer mode)" },
		{ "- / = / P", "sim speed and pause (Studio)" },
	} },
})

return Settings
