--!strict
-- A unit type's icon on screen (C-74): its tile of the user's icon sprite
-- sheet (UI/IconAtlas, white with a dark edge) tinted with the team color;
-- ghosts at 45% opacity, selected icons lightened. Used by the icon layer,
-- the build grid and the unit panel.

local Icons = require("../Core/Icons")
local IconAtlas = require("./IconAtlas")

local Glyph = {}

export type G = { root: ImageLabel }

local RECT = Vector2.new(IconAtlas.TILE_W, IconAtlas.TILE_H)
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 70, 55)
local blinkOn = false

-- The blink phase for under-attack icons (the icon layer sets it each frame).
function Glyph.setBlink(on: boolean)
	blinkOn = on
end

function Glyph.new(parent: Instance): G
	local root = Instance.new("ImageLabel")
	root.Name = "Glyph"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Image = IconAtlas.image
	root.ImageRectSize = RECT
	root.ScaleType = Enum.ScaleType.Stretch
	root.Parent = parent
	return { root = root }
end

-- Shows `style` (Core/Icons.Style) in `color`.
function Glyph.apply(g: G, style: Icons.Style, color: Color3)
	local w = style.size
	g.root.Size = UDim2.fromOffset(w, math.floor(w * IconAtlas.TILE_H / IconAtlas.TILE_W + 0.5))
	local p = IconAtlas.tiles[style.tile]
	g.root.ImageRectOffset = if p then Vector2.new(p[1], p[2]) else Vector2.zero
	g.root.ImageColor3 = if style.selected then color:Lerp(WHITE, 0.55) else color
	if style.attacked and blinkOn then
		g.root.ImageColor3 = RED -- under attack (S-68): blinks red
	end
	g.root.ImageTransparency = 1 - style.alpha
end

return Glyph
