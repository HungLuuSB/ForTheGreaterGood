--!strict
-- Atmosphere presets (C-83), options for the user to choose from (listed
-- under "Needs my review"); "night" is the default (C-101, the user: the
-- maps have no sun, a dark battlefield), "current" keeps the place's own
-- lighting. Applied on this client only (Lighting is drawn locally):
--   night     a moonlit night, no sun: cool neutral ambient light bright
--             enough to read units, soft shadows, low environment
--             specular (no glossy "plastic" sheen on terrain, units or the
--             fog blanket), desaturated, no sun rays, bloom that makes
--             glows and fire stand out; Roblox's procedural night sky
--             (stars, a moon, a faint horizon glow) instead of the place's
--             day skybox, and darker, duller terrain colours (C-102)
--   current   the place as saved (Roblox's default sky, Atmosphere 0.3,
--             Bloom, faint sun rays)
--   clear     a crisp midday: thinner air, a bluer horizon, a touch more
--             colour and contrast, softer bloom
--   haze      a battlefield haze: thick warm-grey air, muted colours, more
--             contrast, sun rays through the smoke
--   dusk      late afternoon: low warm sun, long shadows, an orange
--             horizon, stronger bloom and sun rays
-- The first apply remembers the place's values (sky and terrain colours
-- included); "current" puts them back.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

export type ColorGrade = { brightness: number, contrast: number, saturation: number, tint: Color3 }

export type Preset = {
	clock: number?,
	brightness: number?,
	ambient: Color3?,
	outdoor: Color3?,
	exposure: number?,
	shadowSoftness: number?,
	air: { density: number, offset: number, haze: number, glare: number, color: Color3, decay: Color3 }?,
	bloom: { intensity: number, size: number, threshold: number }?,
	color: ColorGrade?,
	rays: { intensity: number, spread: number }?,
	specular: number?, -- EnvironmentSpecularScale (sky reflections)
	diffuse: number?, -- EnvironmentDiffuseScale
	-- the Sky: its six skybox faces ("" for all six: Roblox's procedural sky,
	-- which follows the clock with stars and a moon), stars, moon size
	sky: { faces: { string }, stars: number, moon: number }?,
	ground: { [string]: Color3 }?, -- Terrain material colours by Enum.Material name ("Water": WaterColor)
	vignette: number?, -- strength of Render/Grade's dark frame, 0..1 (none when nil)
}

local FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
local PROCEDURAL = { "", "", "", "", "", "" }
-- the materials Render/Terrain draws with (and "Water")
local GROUND = { "Grass", "LeafyGrass", "Rock", "Ground", "Sand", "Asphalt", "Mud", "WoodPlanks", "Water" }

Atmosphere.ORDER = { "night", "current", "clear", "haze", "dusk" }
Atmosphere.NAMES = { night = "Night", current = "Current", clear = "Clear day", haze = "Battle haze", dusk = "Dusk" }
Atmosphere.DEFAULT = "night"
Atmosphere.active = nil :: string? -- the applied preset's name (Render/Glow: headlights at night and dusk)

Atmosphere.PRESETS = {
	night = { -- tuned in Studio on ridgeline at 330 studs, 55° (C-101)
		clock = 0,
		brightness = 2.5,
		ambient = Color3.fromRGB(112, 118, 132),
		outdoor = Color3.fromRGB(140, 146, 162),
		exposure = 1.1,
		shadowSoftness = 0.6,
		specular = 0.15,
		diffuse = 0.6,
		air = { density = 0.2, offset = 0.15, haze = 0.6, glare = 0, color = Color3.fromRGB(80, 88, 104), decay = Color3.fromRGB(40, 44, 58) },
		bloom = { intensity = 0.8, size = 26, threshold = 1.2 },
		-- the grade (C-102, "the most impressive part"): moonlight teal, deep
		-- blacks, bright whites; the tint darkens, the brightness gives it back.
		-- Render/Grade eases it off at strategic zoom and flashes it on big blasts.
		color = { brightness = 0.05, contrast = 0.32, saturation = -0.02, tint = Color3.fromRGB(196, 218, 255) },
		vignette = 0.55,
		rays = { intensity = 0, spread = 0 },
		sky = { faces = PROCEDURAL, stars = 3000, moon = 14 },
		ground = { -- under the cool light the day colours read as bright yellow-green (C-102)
			Grass = Color3.fromRGB(72, 90, 66), -- a cool green the teal grade turns moonlit
			LeafyGrass = Color3.fromRGB(76, 96, 56),
			Rock = Color3.fromRGB(92, 96, 104),
			Ground = Color3.fromRGB(104, 96, 80),
			Sand = Color3.fromRGB(150, 145, 122),
			Asphalt = Color3.fromRGB(58, 62, 66),
			Mud = Color3.fromRGB(90, 84, 74),
			WoodPlanks = Color3.fromRGB(120, 104, 80),
			Water = Color3.fromRGB(10, 44, 54),
		},
	},
	current = {},
	clear = {
		clock = 13,
		brightness = 3.2,
		air = { density = 0.22, offset = 0.2, haze = 0, glare = 0.1, color = Color3.fromRGB(200, 215, 235), decay = Color3.fromRGB(110, 130, 160) },
		bloom = { intensity = 0.6, size = 24, threshold = 1.6 },
		color = { brightness = 0.02, contrast = 0.06, saturation = 0.15, tint = Color3.new(1, 1, 1) },
		rays = { intensity = 0.02, spread = 0.1 },
	},
	haze = {
		clock = 15,
		brightness = 2.4,
		ambient = Color3.fromRGB(85, 80, 75),
		outdoor = Color3.fromRGB(110, 105, 98),
		air = { density = 0.42, offset = 0.1, haze = 1.8, glare = 0.3, color = Color3.fromRGB(199, 190, 175), decay = Color3.fromRGB(120, 100, 85) },
		bloom = { intensity = 0.8, size = 30, threshold = 1.6 },
		color = { brightness = 0, contrast = 0.12, saturation = -0.18, tint = Color3.fromRGB(255, 246, 235) },
		rays = { intensity = 0.06, spread = 0.4 },
		vignette = 0.3,
	},
	dusk = { -- tuned in Studio: the first try was too dark to read a fight
		clock = 17.2,
		brightness = 2.6,
		ambient = Color3.fromRGB(95, 85, 85),
		outdoor = Color3.fromRGB(130, 112, 105),
		exposure = 0.25,
		shadowSoftness = 0.3,
		air = { density = 0.28, offset = 0.25, haze = 0.7, glare = 0.4, color = Color3.fromRGB(255, 210, 175), decay = Color3.fromRGB(140, 100, 105) },
		bloom = { intensity = 1, size = 28, threshold = 1.4 },
		color = { brightness = 0.02, contrast = 0.08, saturation = 0.08, tint = Color3.fromRGB(255, 238, 218) },
		rays = { intensity = 0.1, spread = 0.5 },
		vignette = 0.35,
	},
} :: { [string]: Preset }

local saved: Preset? = nil
local active: Preset? = nil

local function child(className: string, name: string): Instance
	local found = Lighting:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	if made:IsA("ColorCorrectionEffect") then
		made.Enabled = false
	end
	made.Parent = Lighting
	return made
end

-- The place's values, as a preset (to put back).
local function capture(): Preset
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local ground = {}
	for _, name in GROUND do
		ground[name] = if name == "Water" then workspace.Terrain.WaterColor else workspace.Terrain:GetMaterialColor((Enum.Material :: any)[name])
	end
	local air = child("Atmosphere", "Atmosphere") :: Atmosphere
	local bloom = child("BloomEffect", "Bloom") :: BloomEffect
	local cc = child("ColorCorrectionEffect", "FtggColor") :: ColorCorrectionEffect
	local rays = child("SunRaysEffect", "SunRays") :: SunRaysEffect
	return {
		clock = Lighting.ClockTime,
		brightness = Lighting.Brightness,
		ambient = Lighting.Ambient,
		outdoor = Lighting.OutdoorAmbient,
		exposure = Lighting.ExposureCompensation,
		shadowSoftness = Lighting.ShadowSoftness,
		air = { density = air.Density, offset = air.Offset, haze = air.Haze, glare = air.Glare, color = air.Color, decay = air.Decay },
		bloom = { intensity = bloom.Intensity, size = bloom.Size, threshold = bloom.Threshold },
		color = if cc.Enabled then { brightness = cc.Brightness, contrast = cc.Contrast, saturation = cc.Saturation, tint = cc.TintColor } else nil,
		rays = { intensity = rays.Intensity, spread = rays.Spread },
		specular = Lighting.EnvironmentSpecularScale,
		diffuse = Lighting.EnvironmentDiffuseScale,
		sky = if sky
			then {
				faces = (function()
					local faces = {}
					for i, face in FACES do
						faces[i] = (sky :: any)[face]
					end
					return faces
				end)(),
				stars = sky.StarCount,
				moon = sky.MoonAngularSize,
			}
			else nil,
		ground = ground,
	}
end

local function set(p: Preset, base: Preset)
	Lighting.ClockTime = p.clock or base.clock :: number
	Lighting.Brightness = p.brightness or base.brightness :: number
	Lighting.Ambient = p.ambient or base.ambient :: Color3
	Lighting.OutdoorAmbient = p.outdoor or base.outdoor :: Color3
	Lighting.ExposureCompensation = p.exposure or base.exposure :: number
	Lighting.ShadowSoftness = p.shadowSoftness or base.shadowSoftness :: number
	Lighting.EnvironmentSpecularScale = p.specular or base.specular :: number
	Lighting.EnvironmentDiffuseScale = p.diffuse or base.diffuse :: number
	local a = p.air or base.air
	if a then
		local air = child("Atmosphere", "Atmosphere") :: Atmosphere
		air.Density, air.Offset, air.Haze, air.Glare, air.Color, air.Decay = a.density, a.offset, a.haze, a.glare, a.color, a.decay
	end
	local b = p.bloom or base.bloom
	if b then
		local bloom = child("BloomEffect", "Bloom") :: BloomEffect
		bloom.Intensity, bloom.Size, bloom.Threshold = b.intensity, b.size, b.threshold
	end
	local cc = child("ColorCorrectionEffect", "FtggColor") :: ColorCorrectionEffect
	local c = p.color or base.color
	cc.Enabled = c ~= nil
	if c then
		cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = c.brightness, c.contrast, c.saturation, c.tint
	end
	local r = p.rays or base.rays
	if r then
		local rays = child("SunRaysEffect", "SunRays") :: SunRaysEffect
		rays.Intensity, rays.Spread = r.intensity, r.spread
	end
	local sk = p.sky or base.sky
	if sk then
		local sky = child("Sky", "Sky") :: Sky
		for i, face in FACES do
			(sky :: any)[face] = sk.faces[i]
		end
		sky.StarCount, sky.MoonAngularSize, sky.CelestialBodiesShown = sk.stars, sk.moon, true
	end
	local g, bg = p.ground or {}, base.ground or {}
	for _, name in GROUND do
		local c = g[name] or bg[name]
		if c and name == "Water" then
			workspace.Terrain.WaterColor = c
		elseif c then
			workspace.Terrain:SetMaterialColor((Enum.Material :: any)[name], c)
		end
	end
end

-- Applies preset `name` ("current" puts the place's values back).
function Atmosphere.apply(name: string)
	local p = Atmosphere.PRESETS[name]
	if p == nil then
		return
	end
	if saved == nil then
		saved = capture()
	end
	set(p, saved :: Preset)
	active = p
	Atmosphere.active = name
end

-- The applied preset's grade for Render/Grade: its colour correction (nil:
-- none, the place's own) and its vignette strength.
function Atmosphere.grade(): (ColorGrade?, number)
	local p = active
	if p == nil then
		return nil, 0
	end
	return p.color or (saved :: Preset).color, p.vignette or 0
end

return Atmosphere
