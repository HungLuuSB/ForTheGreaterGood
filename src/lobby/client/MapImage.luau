--!strict
-- A map preview (L-5): the server's preview bytes colored into an
-- EditableImage (one per map, shared by every view of it), with the starts
-- as numbered markers, colored by the player who starts there. A
-- greyscale version too, for the skirmish cards (BAR's scenario grid:
-- grey until hovered or chosen).

local AssetService = game:GetService("AssetService")

local MapPreview = require("../shared/MapPreview")
local Ui = require("./Ui")

local Kit = Ui.Kit

local MapImage = {}

local contents: { [string]: any } = {}

local function contentOf(map: any, grey: boolean?): any
	local id = if grey then map.id .. ":grey" else map.id
	if contents[id] ~= nil then
		return contents[id] or nil
	end
	local p = map.preview
	local ok, img = pcall(function()
		return (AssetService :: any):CreateEditableImage({ Size = Vector2.new(p.w, p.h) })
	end)
	if not ok or img == nil then
		contents[id] = false
		return nil
	end
	local buf = buffer.create(p.w * p.h * 4)
	for i = 0, p.w * p.h - 1 do
		local r, g, b = MapPreview.color(buffer.readu8(p.data, i))
		if grey then
			local l = math.floor((0.3 * r + 0.59 * g + 0.11 * b) * 0.85)
			r, g, b = l, l, l
		end
		buffer.writeu8(buf, i * 4, r)
		buffer.writeu8(buf, i * 4 + 1, g)
		buffer.writeu8(buf, i * 4 + 2, b)
		buffer.writeu8(buf, i * 4 + 3, 255)
	end
	-- a published place refuses EditableImage writes until the experience
	-- allows them (Game Settings > Security): the map's name shows instead
	local wrote, content = pcall(function()
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(p.w, p.h), buf)
		return (Content :: any).fromObject(img)
	end)
	if not wrote then
		contents[id] = false
		return nil
	end
	contents[id] = content
	return content
end

export type MapImage = {
	frame: Frame,
	set: (map: any?, colors: { [number]: Color3 }?) -> (),
	setGrey: (grey: boolean) -> (), -- the greyscale picture (or back to color)
}

-- A preview that fills `parent` keeping the map's aspect ratio (`fill`:
-- covering it, cropped, as on the skirmish cards).
function MapImage.new(parent: Instance, markers: boolean?, fill: boolean?): MapImage
	local holder = Ui.frame(parent, "MapImage", UDim2.fromScale(1, 1))
	local image = Instance.new("ImageLabel")
	image.Name = "Map"
	image.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	image.BorderSizePixel = 0
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(1, 1)
	image.ResampleMode = Enum.ResamplerMode.Default
	image.Parent = holder
	Ui.corner(image, 6)
	Ui.stroke(image, 0.85)
	local aspect = Instance.new("UIAspectRatioConstraint")
	if fill then
		image.ScaleType = Enum.ScaleType.Crop
	else
		aspect.Parent = image
	end
	local note = Kit.text(image, "", "small", Kit.COLOR.faint)
	note.Size = UDim2.fromScale(1, 1)
	note.TextXAlignment = Enum.TextXAlignment.Center
	local marks: { Frame } = {}
	local shown: any = nil
	local isGrey = false
	return {
		frame = holder,
		setGrey = function(grey: boolean)
			isGrey = grey
			if shown and shown.preview then
				local content = contentOf(shown, grey)
				if content then
					image.ImageContent = content
				end
			end
		end,
		set = function(map: any?, colors: { [number]: Color3 }?)
			for _, m in marks do
				m:Destroy()
			end
			table.clear(marks)
			if map == nil or map.preview == nil then
				image.ImageContent = (Content :: any).none
				note.Text = "Loading map..."
				return
			end
			shown = map
			local p = map.preview
			aspect.AspectRatio = p.w / p.h
			local content = contentOf(map, isGrey)
			if content then
				image.ImageContent = content
				note.Text = ""
			else
				note.Text = map.name
			end
			if markers == false then
				return
			end
			for i, s in p.starts do
				local dot = Instance.new("Frame")
				dot.Name = `Start{i}`
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.fromScale(s[1], s[2])
				dot.Size = UDim2.fromOffset(22, 22)
				local c = colors and colors[i]
				dot.BackgroundColor3 = c or Color3.fromRGB(20, 22, 27)
				dot.BackgroundTransparency = if c then 0 else 0.2
				dot.BorderSizePixel = 0
				dot.ZIndex = 3
				dot.Parent = image
				Ui.corner(dot, 11)
				Ui.stroke(dot, 0.2, Color3.new(1, 1, 1))
				local n = Kit.text(dot, tostring(i), "small", Color3.new(1, 1, 1))
				n.Size = UDim2.fromScale(1, 1)
				n.TextXAlignment = Enum.TextXAlignment.Center
				n.FontFace = Kit.font(Enum.FontWeight.Bold)
				n.ZIndex = 4
				table.insert(marks, dot)
			end
		end,
	}
end

return MapImage
