--!strict
-- Rigs an imported unit model per docs/contracts/rig.md, from the rig.json
-- the Blender build wrote (docs/art/pipeline.md, step 7). Studio only: run
-- in the Edit datamodel through execute_luau (or require a copy kept in
-- ServerStorage.ModelsTools in "FTGG Art"):
--   RigModel.normalize(src, rig, 0.01, true, "_bar")
--   RigModel.check(src, rig, "_bar")            -- problems, empty when fine
--   RigModel.rig(src, rig, "_bar")              -- the rigged Model, not parented
-- It moves the MeshParts into a new Model named after the unit, places the
-- unit origin at (0, 0, 0), joints the pieces at the rig.json pivots and
-- welds the glow parts (rig.json "glow", the emissive pass, M-22) to their
-- pieces with their channel's tint and strength (docs/contracts/fx.md).

local CollectionService = game:GetService("CollectionService")

local RigModel = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function find(src: Instance, name: string): MeshPart?
	if src:IsA("MeshPart") and src.Name == name then
		return src
	end
	for _, d in src:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == name then
			return d
		end
	end
	return nil
end

-- Every rig.json piece as a MeshPart under `src` (or `src` itself), named
-- `<piece><suffix>` (an FBX can carry several variants: base_a, base_b, ...).
local function findPieces(src: Instance, rig: any, suffix: string?): { [string]: MeshPart }
	local parts: { [string]: MeshPart } = {}
	for name in rig.pieces do
		local part = find(src, name .. (suffix or ""))
		assert(part, `rig: no MeshPart named {name}{suffix or ""} in {src:GetFullName()}`)
		parts[name] = part
	end
	return parts
end

-- The glow parts (`<piece>_glow_<channel><suffix>`), by their rig.json name.
local function findGlow(src: Instance, rig: any, suffix: string?): { [string]: MeshPart }
	local parts: { [string]: MeshPart } = {}
	for _, g in rig.glow or {} do
		local part = find(src, g.name .. (suffix or ""))
		assert(part, `rig: no glow MeshPart named {g.name}{suffix or ""} in {src:GetFullName()}`)
		parts[g.name] = part
	end
	return parts
end

-- Undoes an import's unit and axis conversion about the scene origin: the
-- 3D Importer (and an Open Cloud model upload) read Blender's FBX as
-- centimeters (x100, clamped to 2048 studs on the longest side) and turned it
-- 180° about Y (pipeline.md, import notes). Mesh orientation inside a
-- MeshPart doesn't matter to the rig: joints are computed from world CFrames.
function RigModel.normalize(src: Instance, rig: any, scale: number, turnY: boolean, suffix: string?)
	local turn = if turnY then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	local all = findPieces(src, rig, suffix)
	for name, part in findGlow(src, rig, suffix) do
		all[name] = part
	end
	for _, part in all do
		local cf = part.CFrame
		part.Size *= scale
		part.CFrame = turn * (cf - cf.Position + cf.Position * scale)
	end
end

-- Checks that the pieces have the Blender sizes and positions (studs).
function RigModel.check(src: Instance, rig: any, suffix: string?): { string }
	local parts = findPieces(src, rig, suffix)
	local problems = {}
	for name, part in parts do
		local want = v3(rig.pieces[name].size)
		-- world-space extent of the part (it may be turned about Y)
		local got = part.CFrame:VectorToWorldSpace(part.Size)
		got = Vector3.new(math.abs(got.X), math.abs(got.Y), math.abs(got.Z))
		if (got - want).Magnitude > 0.05 * want.Magnitude then
			table.insert(problems, `{name}: size {got} vs {want}`)
		end
	end
	local function rel(name: string): Vector3
		return parts[name].Position - parts.base.Position
	end
	for name, piece in rig.pieces do
		local want = v3(piece.center) - v3(rig.pieces.base.center)
		if (rel(name) - want).Magnitude > 0.05 then
			table.insert(problems, `{name}: offset {rel(name)} vs {want}`)
		end
	end
	for name, part in findGlow(src, rig, suffix) do
		for _, g in rig.glow do
			if g.name == name then
				local want = v3(g.center) - v3(rig.pieces.base.center)
				local got = part.Position - parts.base.Position
				if (got - want).Magnitude > 0.05 then
					table.insert(problems, `{name}: offset {got} vs {want}`)
				end
			end
		end
	end
	return problems
end

local function settle(part: BasePart, anchored: boolean, shadow: boolean)
	for _, d in part:GetChildren() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	part.PivotOffset = CFrame.identity
	part.Anchored = anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = shadow
	if part:IsA("MeshPart") then
		part.RenderFidelity = Enum.RenderFidelity.Automatic
	end
end

-- The emissive settings of one SurfaceAppearance: a glow part glows in its
-- channel's tint; a piece doesn't glow (its glow faces moved to glow parts).
-- Emission is albedo × EmissiveTint × strength, so the baked near-white glow
-- faces clip to white in daylight: a glow part drops the color map and takes
-- its tint as BasePart.Color (M-22).
function RigModel.applyGlow(part: MeshPart, mask: string?)
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if not sa then
		return
	end
	local channel = part:GetAttribute("GlowChannel")
	if channel and mask and mask ~= "" then
		local tint = part:GetAttribute("GlowTint") :: Color3
		sa.ColorMap = ""
		part.Color = tint
		sa.EmissiveMaskContent = Content.fromUri(mask)
		sa.EmissiveTint = tint
		sa.EmissiveStrength = part:GetAttribute("GlowStrength") :: number
	else
		sa.EmissiveStrength = 0
	end
end

function RigModel.rig(src: Instance, rig: any, suffix: string?): Model
	local parts = findPieces(src, rig, suffix)
	local glowParts = findGlow(src, rig, suffix)
	-- unit origin: base's geometry center sits at rig.pieces.base.center
	local shift = parts.base.Position - v3(rig.pieces.base.center)

	local model = Instance.new("Model")
	model.Name = rig.id
	for name, part in parts do
		part.CFrame -= shift
		settle(part, name == "base", true)
		part.Name = name -- drop the variant suffix
		part.Parent = model
	end

	for name, piece in rig.pieces do
		if piece.parent then
			local part0, part1 = parts[piece.parent], parts[name]
			local pivot = CFrame.new(v3(piece.pivot))
			local joint = Instance.new("Motor6D")
			joint.Name = name
			joint.Part0 = part0
			joint.Part1 = part1
			joint.C0 = part0.CFrame:Inverse() * pivot
			joint.C1 = part1.CFrame:Inverse() * pivot
			joint.Parent = part1
		end
	end
	for name, a in rig.attachments or {} do
		local att = Instance.new("Attachment")
		att.Name = name
		att.CFrame = parts[a.parent].CFrame:Inverse() * CFrame.new(v3(a.at))
		att.Parent = parts[a.parent]
	end
	for _, name in rig.teamColorPieces or {} do
		CollectionService:AddTag(parts[name], "TeamColor")
	end

	-- glow parts: welded to their piece, decorations by rig.md, tagged `Glow`
	for _, g in rig.glow or {} do
		local part = glowParts[g.name]
		part.CFrame -= shift
		settle(part, false, false)
		part.Name = g.name
		part:SetAttribute("GlowChannel", g.channel)
		part:SetAttribute("GlowPiece", g.piece)
		part:SetAttribute("GlowTint", Color3.fromRGB(g.tint[1], g.tint[2], g.tint[3]))
		part:SetAttribute("GlowStrength", g.strength)
		CollectionService:AddTag(part, "Glow")
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = parts[g.piece]
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	-- the emissive mask: the FBX carries it on a probe quad's color map, since
	-- the importer uploads only maps a material uses (M-15)
	local mask: string? = nil
	if rig.emissive then
		local probe = src:FindFirstChild(rig.emissive.probe, true)
		mask = probe and probe:IsA("MeshPart") and (probe:FindFirstChildOfClass("SurfaceAppearance") and probe:FindFirstChildOfClass("SurfaceAppearance").ColorMap or probe.TextureID) or nil
		assert(mask and mask ~= "", `rig: no emissive mask on {rig.emissive.probe}`)
		model:SetAttribute("EmissiveMask", mask)
	end
	for _, part in model:GetChildren() do
		if part:IsA("MeshPart") then
			RigModel.applyGlow(part, mask)
		end
	end

	model.PrimaryPart = parts.base
	model:SetAttribute("DefId", rig.id)
	model:SetAttribute("RootOffset", parts.base.CFrame)
	if rig.footprintStuds then
		model:SetAttribute("FootprintStuds", rig.footprintStuds)
	end
	if rig.triangles then
		model:SetAttribute("Triangles", rig.triangles.total)
	end
	return model
end

return RigModel
