--!strict
-- Rigs an imported unit model per docs/contracts/rig.md, from the rig.json
-- the Blender build wrote (docs/art/pipeline.md, step 7). Studio only: run
-- in the Edit datamodel through execute_luau, with this file's source
-- followed by
--   return RigModel.rig(<imported Model or Folder>, HttpService:JSONDecode(<rig.json>), <SurfaceAppearance ids?>)
-- It moves the MeshParts into a new Model named after the unit, places the
-- unit origin at (0, 0, 0), joints the pieces at the rig.json pivots and
-- returns the model (not parented).

local CollectionService = game:GetService("CollectionService")

local RigModel = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- Every rig.json piece as a MeshPart under `src` (or `src` itself).
local function findPieces(src: Instance, rig: any): { [string]: MeshPart }
	local parts: { [string]: MeshPart } = {}
	local candidates = src:GetDescendants()
	table.insert(candidates, src)
	for _, d in candidates do
		if d:IsA("MeshPart") and rig.pieces[d.Name] and not parts[d.Name] then
			parts[d.Name] = d
		end
	end
	for name in rig.pieces do
		assert(parts[name], `rig: no MeshPart named {name} in {src:GetFullName()}`)
	end
	return parts
end

-- Undoes an import's unit and axis conversion about the scene origin: the
-- 3D Importer read Blender's FBX as centimeters (x100) and turned it 180°
-- about Y (pipeline.md, import notes). Mesh orientation inside a MeshPart
-- doesn't matter to the rig: joints are computed from world CFrames.
function RigModel.normalize(src: Instance, rig: any, scale: number, turnY: boolean)
	local turn = if turnY then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	for _, part in findPieces(src, rig) do
		local cf = part.CFrame
		part.Size *= scale
		part.CFrame = turn * (cf - cf.Position + cf.Position * scale)
	end
end

-- Checks that the pieces have the Blender sizes and positions (studs).
function RigModel.check(src: Instance, rig: any): { string }
	local parts = findPieces(src, rig)
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
	return problems
end

function RigModel.rig(src: Instance, rig: any, appearance: { [string]: string }?): Model
	local parts = findPieces(src, rig)
	-- unit origin: base's geometry center sits at rig.pieces.base.center
	local shift = parts.base.Position - v3(rig.pieces.base.center)

	local model = Instance.new("Model")
	model.Name = rig.id
	for name, part in parts do
		for _, d in part:GetChildren() do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				d:Destroy()
			end
		end
		part.CFrame -= shift
		-- the importer's "Set Pivot to Scene Origin" leaves a pivot offset in
		-- the import's units; the model's pivot must be base's own CFrame
		part.PivotOffset = CFrame.identity
		part.Anchored = name == "base"
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		part.RenderFidelity = Enum.RenderFidelity.Automatic
		if appearance then
			local sa = part:FindFirstChildOfClass("SurfaceAppearance") or Instance.new("SurfaceAppearance")
			sa.ColorMap = appearance.ALB
			sa.NormalMap = appearance.NOR
			sa.RoughnessMap = appearance.RGH
			sa.MetalnessMap = appearance.MTL
			sa.AlphaMode = Enum.AlphaMode.Overlay
			sa.Parent = part
		end
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
	for name, a in rig.attachments do
		local att = Instance.new("Attachment")
		att.Name = name
		att.CFrame = parts[a.parent].CFrame:Inverse() * CFrame.new(v3(a.at))
		att.Parent = parts[a.parent]
	end
	for _, name in rig.teamColorPieces do
		CollectionService:AddTag(parts[name], "TeamColor")
	end

	model.PrimaryPart = parts.base
	model:SetAttribute("DefId", rig.id)
	model:SetAttribute("RootOffset", parts.base.CFrame)
	model:SetAttribute("FootprintStuds", rig.footprintStuds)
	model:SetAttribute("Triangles", rig.triangles.total)
	return model
end

return RigModel
