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
-- the Detailed models setting (C-106): off draws blockouts only
Models.DETAILED = true
Models.version = 0 -- bumps when the setting flips (the renderer redraws every unit)
local standIns: { [string]: Model } = {} -- blockouts drawn while the mesh model builds

-- The def's blockout, or its generic one when the hand-made blockout no
-- longer fits the def (a def piece added on one side, its blockout not yet
-- updated): one warning, and the unit still draws. Before, the error
-- stopped the whole render step every frame (the Commanders after S-194).
local warned: { [string]: boolean } = {}
local function blockout(def: any): Model
	local ok, model = pcall(BlockoutBuilder.build, Blockout.forDef(def), def)
	if ok then
		return model
	end
	if not warned[def.id] then
		warned[def.id] = true
		warn(`[Models] {def.id}: {model}; drawing its generic blockout`)
	end
	return BlockoutBuilder.build(Blockout.generic(def), def)
end

function Models.template(def: any): Model
	local cached = templates[def.id]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild("Models")
	local real = folder and folder:FindFirstChild(def.model)
	local template: Model
	local meshed = if Models.DETAILED then MeshModels.get(def.id) else nil
	if not Models.DETAILED then
		real = nil
	end
	if real and real:IsA("Model") and real.PrimaryPart then
		template = real:Clone()
		template:SetAttribute("DefId", def.id)
		if template:GetAttribute("RootOffset") == nil then
			template:SetAttribute("RootOffset", (template.PrimaryPart :: BasePart).CFrame)
		end
	elseif meshed then
		template = meshed
	elseif Models.DETAILED and MeshModels.pending(def.id) then
		local standIn = standIns[def.id]
		if standIn == nil then
			standIn = blockout(def)
			standIns[def.id] = standIn
		end
		return standIn :: Model
	else
		template = blockout(def)
	end
	templates[def.id] = template
	return template
end

-- Turns detailed models on or off; the renderer redraws every unit when
-- `version` changes.
function Models.setDetailed(on: boolean)
	if on == Models.DETAILED then
		return
	end
	Models.DETAILED = on
	table.clear(templates)
	table.clear(standIns)
	Models.version += 1
end

-- Drops def `id`'s template and stand-in (its mesh model just became ready).
function Models.forget(id: string)
	templates[id] = nil
	standIns[id] = nil
end

return Models
