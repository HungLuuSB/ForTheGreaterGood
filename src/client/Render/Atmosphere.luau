--!strict
-- Atmosphere presets (C-83), options for the user to choose from (listed
-- under "Needs my review"); "night" is the default (C-101, the user: the
-- maps have no sun, a dark battlefield), "current" keeps the place's own
-- lighting. Applied on this client only (Lighting is drawn locally):
--   night     a moonlit night, no sun: cool neutral ambient light bright
--             enough to read units, soft shadows, low environment
--             specular (no glossy "plastic" sheen on terrain, units or the
--             fog blanket), desaturated, no sun rays, bloom that makes
--             glows and fire stand out
--   current   the place as saved (Roblox's default sky, Atmosphere 0.3,
--             Bloom, faint sun rays)
--   clear     a crisp midday: thinner air, a bluer horizon, a touch more
--             colour and contrast, softer bloom
--   haze      a battlefield haze: thick warm-grey air, muted colours, more
--             contrast, sun rays through the smoke
--   dusk      late afternoon: low warm sun, long shadows, an orange
--             horizon, stronger bloom and sun rays
-- The first apply remembers the place's values; "current" puts them back.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

export type Preset = {
	clock: number?,
	brightness: number?,
	ambient: Color3?,
	outdoor: Color3?,
	exposure: number?,
	shadowSoftness: number?,
	air: { density: number, offset: number, haze: number, glare: number, color: Color3, decay: Color3 }?,
	bloom: { intensity: number, size: number, threshold: number }?,
	color: { brightness: number, contrast: number, saturation: number, tint: Color3 }?,
	rays: { intensity: number, spread: number }?,
	specular: number?, -- EnvironmentSpecularScale (sky reflections)
	diffuse: number?, -- EnvironmentDiffuseScale
}

Atmosphere.ORDER = { "night", "current", "clear", "haze", "dusk" }
Atmosphere.NAMES = { night = "Night", current = "Current", clear = "Clear day", haze = "Battlefield haze", dusk = "Dusk" }
Atmosphere.DEFAULT = "night"

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
		color = { brightness = 0, contrast = 0.1, saturation = -0.18, tint = Color3.fromRGB(236, 240, 255) },
		rays = { intensity = 0, spread = 0 },
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
	},
} :: { [string]: Preset }

local saved: Preset? = nil

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
end

return Atmosphere
