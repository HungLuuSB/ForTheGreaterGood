--!strict
-- The colour grade (C-102), pure: what Render/Grade writes to Lighting's
-- ColorCorrection each frame on top of the atmosphere preset's own grade.
--   zoom      the preset's grade in full up close; at strategic zoom it
--             eases off (less contrast, the tint halfway back to white, a
--             lighter vignette) so the whole map reads
--   flash     big blasts on screen (a nuke, a large unit's death) warm and
--             brighten the picture for a moment, fading over DECAY
--   vignette  a soft dark frame drawn once into an image (no asset)
-- Colours are r, g, b in 0..255 (no Color3 here: Lune runs these specs).

local Grade = {}

Grade.NEAR = 150 -- camera distance (studs): the full grade within it
Grade.FAR = 800 -- eased to the strategic grade by here
Grade.FAR_CONTRAST = 0.55 -- share of the contrast kept at strategic zoom
Grade.FAR_TINT = 0.5 -- share of the way the tint goes back to white
Grade.FAR_VIGNETTE = 0.6 -- share of the vignette kept

export type Color = { brightness: number, contrast: number, saturation: number, tint: { number } }

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 up close .. 1 at strategic zoom.
function Grade.zoom(distance: number): number
	return smooth((distance - Grade.NEAR) / (Grade.FAR - Grade.NEAR))
end

-- The grade at zoom `t`: brightness, contrast, saturation, tint r, g, b.
function Grade.mix(c: Color, t: number): (number, number, number, number, number, number)
	local k = 1 + (Grade.FAR_CONTRAST - 1) * t
	local w = Grade.FAR_TINT * t
	local tint = c.tint
	return c.brightness,
		c.contrast * k,
		c.saturation * k,
		tint[1] + (255 - tint[1]) * w,
		tint[2] + (255 - tint[2]) * w,
		tint[3] + (255 - tint[3]) * w
end

-- Flash level added per blast at full strength (a nuke at any size; a death
-- at scale 3, more or less with its size). Impacts never flash, and deaths
-- under FLASH_MIN_SCALE don't: a busy fight would flicker.
Grade.FLASH = table.freeze({ nuke = 1, death = 0.35 }) :: { [string]: number }
Grade.FLASH_MIN_SCALE = 1.5
Grade.DECAY = 0.3 -- seconds for the flash to fall to 1/e
-- the extra grade at flash level 1 (levels add up to 1 at most)
Grade.FLASH_LOOK = table.freeze({ brightness = 0.14, contrast = 0.06, saturation = 0.12, tint = table.freeze({ 255, 222, 186 }) })

export type Flash = { level: number }

function Grade.newFlash(): Flash
	return { level = 0 }
end

-- A blast of `kind` at `scale`, `distance` studs from the camera's focus:
-- counts in full there, falling off to nothing at `view` studs.
function Grade.burst(f: Flash, kind: string, scale: number, distance: number, view: number)
	local base = Grade.FLASH[kind]
	if base == nil or (kind ~= "nuke" and scale < Grade.FLASH_MIN_SCALE) then
		return
	end
	local size = if kind == "nuke" then 1 else math.min(scale / 3, 1.5)
	local near = math.clamp(1 - distance / math.max(view, 1), 0, 1)
	f.level = math.min(1, f.level + base * size * near)
end

function Grade.step(f: Flash, dt: number)
	f.level *= math.exp(-dt / Grade.DECAY)
	if f.level < 1e-3 then
		f.level = 0
	end
end

-- The flash's extra grade now: brightness, contrast, saturation, tint r, g, b.
function Grade.flash(f: Flash): (number, number, number, number, number, number)
	local l, look = f.level, Grade.FLASH_LOOK
	local tint = look.tint
	return look.brightness * l,
		look.contrast * l,
		look.saturation * l,
		255 + (tint[1] - 255) * l,
		255 + (tint[2] - 255) * l,
		255 + (tint[3] - 255) * l
end

-- An n × n RGBA vignette: clear in the middle, darkening smoothly to
-- full alpha in the corners (wider than tall, the screen's shape); the
-- strength is the image's transparency, set per frame.
function Grade.vignette(n: number, r: number, g: number, b: number): buffer
	local out = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
			local a = smooth((math.sqrt(dx * dx * 0.8 + dy * dy) - 0.55) / 0.75)
			local o = (y * n + x) * 4
			buffer.writeu8(out, o, r)
			buffer.writeu8(out, o + 1, g)
			buffer.writeu8(out, o + 2, b)
			buffer.writeu8(out, o + 3, math.floor(a * 255 + 0.5))
		end
	end
	return out
end

return Grade
