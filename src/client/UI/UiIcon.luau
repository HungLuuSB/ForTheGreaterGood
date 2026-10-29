--!strict
-- A UI icon as an ImageLabel (UiIcons, 2D-E's resource and stat icons;
-- C-259), or nil while the atlas isn't uploaded: the caller then keeps its
-- text mark. The atlas has each icon at 16, 24 and 32 px; the smallest one
-- at least `size` is used, so it's scaled down, never up, when it can be.

local UiIcons = require("./UiIcons")

local UiIcon = {}

-- The atlas size drawn for an icon `size` pixels wide.
function UiIcon.pick(size: number): number
	for _, s in UiIcons.sizes do
		if s >= size then
			return s
		end
	end
	return UiIcons.sizes[#UiIcons.sizes]
end

-- Whether icons can be drawn (the atlas is uploaded).
function UiIcon.ready(): boolean
	return UiIcons.image ~= ""
end

-- An icon `key` `size` pixels square, tinted `color` (default: its
-- suggested tint); nil until the atlas is uploaded or for an unknown key.
function UiIcon.make(key: string, size: number, color: Color3?): ImageLabel?
	local icon = UiIcons.icons[key]
	if icon == nil or not UiIcon.ready() then
		return nil
	end
	local r = icon.rect[UiIcon.pick(size)]
	local label = Instance.new("ImageLabel")
	label.Name = "Icon_" .. key
	label.BackgroundTransparency = 1
	label.Image = UiIcons.image
	label.ImageRectOffset = Vector2.new(r[1], r[2])
	label.ImageRectSize = Vector2.new(r[3], r[4])
	label.ImageColor3 = color or Color3.fromRGB(icon.tint[1], icon.tint[2], icon.tint[3])
	label.ScaleType = Enum.ScaleType.Fit
	label.Size = UDim2.fromOffset(size, size)
	return label
end

return UiIcon
