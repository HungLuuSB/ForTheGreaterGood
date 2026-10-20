--!strict
-- The build ghost (guide 15.6): a translucent copy of the structure's model
-- on its snapped spot, over a footprint plate, tinted green (valid) or red
-- (the client's placement check fails). Follows Api.state.placement.

local Api = require("../Api")
local World = require("../Core/World")
local Models = require("./Models")

local PlacementGhost = {}

local VALID = Color3.fromRGB(90, 230, 110)
local INVALID = Color3.fromRGB(235, 70, 60)

export type Ghost = {
	folder: Folder,
	plate: Part,
	highlight: Highlight,
	model: Model?,
	defId: string?,
}

function PlacementGhost.new(): Ghost
	local folder = Instance.new("Folder")
	folder.Name = "Ghost"
	local plate = Instance.new("Part")
	plate.Name = "Footprint"
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Material = Enum.Material.Neon
	plate.Transparency = 0.6
	plate.Parent = folder
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder
	return { folder = folder, plate = plate, highlight = highlight, model = nil, defId = nil }
end

-- Facing 0..3 (Schema.Facing: north, east, south, west) as a sim heading
-- (forward = (sin h, cos h); north is -Z).
local function headingOf(facing: number): number
	return math.pi - facing * math.pi / 2
end

local function setModel(g: Ghost, def: any)
	if g.defId == def.id then
		return
	end
	if g.model then
		g.model:Destroy()
	end
	local model = Models.template(def):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.45)
			d.CastShadow = false
		end
	end
	model.Parent = g.folder
	g.model, g.defId = model, def.id
	g.highlight.Adornee = model
end

function PlacementGhost.step(g: Ghost, api: Api.Api)
	local p = api.state.placement
	if p == nil then
		if g.folder.Parent ~= nil then
			g.folder.Parent = nil
		end
		return
	end
	local world = api.world
	local def = world.defs.unitByIndex[p.defIndex]
	setModel(g, def)
	local model = g.model :: Model
	local color = if p.valid then VALID else INVALID
	local y = World.groundY(world, p.x, p.z)
	local size = def.footprint * 8
	g.plate.Size = Vector3.new(size, 0.2, size)
	g.plate.CFrame = CFrame.new(p.x, y + 0.1, p.z)
	g.plate.Color = color
	g.highlight.FillColor = color
	g.highlight.OutlineColor = color
	local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
	;(model.PrimaryPart :: BasePart).CFrame = CFrame.new(p.x, y, p.z) * CFrame.Angles(0, headingOf(p.facing) + math.pi, 0) * offset
	if g.folder.Parent == nil then
		g.folder.Parent = workspace
	end
end

return PlacementGhost
