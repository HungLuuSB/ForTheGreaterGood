--!strict
-- Builds a placeholder unit Model from a Blockout table (guide 20.2, C-6),
-- rigged per docs/contracts/rig.md: anchored `base`, one Motor6D per piece
-- (pivot at the piece's `pivot`), decorations welded, muzzles as
-- Attachments, team-colored parts tagged `TeamColor`.

local CollectionService = game:GetService("CollectionService")

local Blockout = require("@shared/Defs/Blockouts/Blockout")

local BlockoutBuilder = {}

BlockoutBuilder.TEAM_TAG = "TeamColor"

local function v3(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

-- The part's CFrame and Roblox Size in model space. Roblox cylinders run
-- along their own X axis, so other axes rotate the part and swap the size.
local function placement(p: Blockout.Part): (CFrame, Vector3)
	local cf = CFrame.new(v3(p.at))
	if p.rot then
		cf *= CFrame.fromOrientation(math.rad(p.rot[1]), math.rad(p.rot[2]), math.rad(p.rot[3]))
	end
	local s = p.size
	if p.shape == "cylinder" and p.axis == "z" then
		return cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(s[3], s[2], s[1])
	elseif p.shape == "cylinder" and p.axis == "y" then
		return cf * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(s[2], s[1], s[3])
	end
	return cf, v3(s)
end

local function newPart(p: Blockout.Part): BasePart
	local part: BasePart
	if p.shape == "wedge" then
		part = Instance.new("WedgePart")
	else
		local plain = Instance.new("Part")
		if p.shape == "cylinder" then
			plain.Shape = Enum.PartType.Cylinder
		elseif p.shape == "ball" then
			plain.Shape = Enum.PartType.Ball
		end
		part = plain
	end
	part.Name = p.name
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = p.name == "base"
	return part
end

-- Builds the model at the origin (unit origin = model origin). `faction`
-- picks the palette. Errors if the blockout is invalid for `def`.
function BlockoutBuilder.build(bp: Blockout.Blockout, def: any): Model
	local problems = Blockout.validate(bp, def)
	if #problems > 0 then
		error("invalid blockout:\n" .. table.concat(problems, "\n"), 2)
	end
	local palette = Blockout.PALETTES[def.faction] or Blockout.PALETTES.neutral
	local isPiece: { [string]: boolean } = {}
	for _, piece in def.pieces do
		isPiece[piece] = true
	end

	local model = Instance.new("Model")
	model.Name = def.model
	local parts: { [string]: BasePart } = {}
	local frames: { [string]: CFrame } = {}

	for _, p in bp.parts do
		local cf, size = placement(p)
		local part = newPart(p)
		part.Size = size
		part.CFrame = cf
		local rgb = palette[p.color]
		part.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		if p.color == "team" then
			CollectionService:AddTag(part, BlockoutBuilder.TEAM_TAG)
		end
		part.Parent = model
		parts[p.name] = part
		frames[p.name] = cf

		if p.parent then
			local parentPart = parts[p.parent]
			if isPiece[p.name] then
				local pivot = CFrame.new(v3(p.pivot or p.at))
				local joint = Instance.new("Motor6D")
				joint.Name = p.name
				joint.Part0 = parentPart
				joint.Part1 = part
				joint.C0 = frames[p.parent]:Inverse() * pivot
				joint.C1 = cf:Inverse() * pivot
				joint.Parent = part
			else
				local weld = Instance.new("WeldConstraint")
				weld.Name = "Weld"
				weld.Part0 = parentPart
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end

	for _, a in bp.attachments or {} do
		local attachment = Instance.new("Attachment")
		attachment.Name = a.name
		attachment.CFrame = frames[a.parent]:Inverse() * CFrame.new(v3(a.at))
		attachment.Parent = parts[a.parent]
	end

	model.PrimaryPart = parts.base
	model:SetAttribute("DefId", def.id)
	model:SetAttribute("RootOffset", frames.base)
	model:SetAttribute("FootprintStuds", (def.footprint or 1) * 8)
	model:SetAttribute("Blockout", true)
	return model
end

return BlockoutBuilder
