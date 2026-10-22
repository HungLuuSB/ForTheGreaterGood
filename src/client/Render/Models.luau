--!strict
-- Model templates by unit def (docs/contracts/rig.md): the real model in
-- ReplicatedStorage.Models when there is one, else the BAR mesh model built
-- from the mesh manifest (Render/MeshModels, C-103), else a blockout built
-- once (hand-made if registered, else generic). While a mesh model is still
-- building, its blockout stands in (not kept as the template; `forget`
-- drops it once the mesh is ready). Templates are never parented; the model
-- pool clones them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blockout = require("@shared/Defs/Blockouts/Blockout")
local BlockoutBuilder = require("./BlockoutBuilder")
local MeshModels = require("./MeshModels")

local Models = {}

local templates: { [string]: Model } = {}
local standIns: { [string]: Model } = {} -- blockouts drawn while the mesh model builds

function Models.template(def: any): Model
	local cached = templates[def.id]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild("Models")
	local real = folder and folder:FindFirstChild(def.model)
	local template: Model
	local meshed = MeshModels.get(def.id)
	if real and real:IsA("Model") and real.PrimaryPart then
		template = real:Clone()
		template:SetAttribute("DefId", def.id)
		if template:GetAttribute("RootOffset") == nil then
			template:SetAttribute("RootOffset", (template.PrimaryPart :: BasePart).CFrame)
		end
	elseif meshed then
		template = meshed
	elseif MeshModels.pending(def.id) then
		local standIn = standIns[def.id]
		if standIn == nil then
			standIn = BlockoutBuilder.build(Blockout.forDef(def), def)
			standIns[def.id] = standIn
		end
		return standIn :: Model
	else
		local bp = Blockout.forDef(def)
		template = BlockoutBuilder.build(bp, def)
	end
	templates[def.id] = template
	return template
end

-- Drops def `id`'s template and stand-in (its mesh model just became ready).
function Models.forget(id: string)
	templates[id] = nil
	standIns[id] = nil
end

return Models
