--!strict
-- The Studio half of the Open Cloud route (docs/art/pipeline.md): loads a
-- unit uploaded by opencloud.py, rigs it with rig_model.luau and gives every
-- MeshPart a SurfaceAppearance made from the separately uploaded maps (the
-- FBX's own maps can fail to load). Glow parts get their channel's emissive
-- settings (RigModel.applyGlow). Kept in "FTGG Art" as
-- ServerStorage.ModelsTools.OpenCloud; this file is the source.

local InsertService = game:GetService("InsertService")

local OpenCloud = {}

function OpenCloud.imageOf(decalId: number): string
	local res = InsertService:LoadAsset(decalId)
	local d = res:FindFirstChildWhichIsA("Decal", true)
	local tex = d and d.Texture
	res:Destroy()
	assert(tex and tex ~= "", "no image in decal " .. decalId)
	return tex
end

-- rig: decoded rig.json; decals: { ALB, NOR, RGH, MTL, EMI } decal IDs;
-- scale: the import scale (0.01; less for a mesh clamped to 2048 studs)
function OpenCloud.load(RigModel: any, modelId: number, rig: any, decals: { [string]: number }?, scale: number?): (Model?, { string }, { [string]: string })
	local holder = InsertService:LoadAsset(modelId)
	local src = holder:FindFirstChildWhichIsA("Model") or holder
	src.Parent = workspace
	RigModel.normalize(src, rig, scale or 0.01, true, "_bar")
	local problems = RigModel.check(src, rig, "_bar")
	if #problems > 0 then
		holder:Destroy()
		return nil, problems, {}
	end
	local model = RigModel.rig(src, rig, "_bar")
	local images: { [string]: string } = {}
	if decals then
		for k, id in decals do
			images[k] = OpenCloud.imageOf(id)
		end
		for _, part in model:GetChildren() do
			if part:IsA("MeshPart") then
				for _, s in part:GetChildren() do
					if s:IsA("SurfaceAppearance") then
						s:Destroy()
					end
				end
				local sa = Instance.new("SurfaceAppearance")
				sa.ColorMap = images.ALB or ""
				sa.NormalMap = images.NOR or ""
				sa.RoughnessMap = images.RGH or ""
				sa.MetalnessMap = images.MTL or ""
				sa.AlphaMode = Enum.AlphaMode.Overlay
				sa.Parent = part
				RigModel.applyGlow(part, images.EMI)
			end
		end
		if images.EMI then
			model:SetAttribute("EmissiveMask", images.EMI)
		end
	end
	model:SetAttribute("Upload", "OpenCloud")
	holder:Destroy()
	return model, {}, images
end

return OpenCloud
