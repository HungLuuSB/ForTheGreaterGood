--!strict
-- Model templates by unit def (docs/contracts/rig.md): the real model in
-- ReplicatedStorage.Models when there is one, else a blockout built once
-- (hand-made if registered, else generic). Templates are never parented;
-- the model pool clones them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blockout = require("@shared/Defs/Blockouts/Blockout")
local BlockoutBuilder = require("./BlockoutBuilder")

local Models = {}

local templates: { [string]: Model } = {}

function Models.template(def: any): Model
	local cached = templates[def.id]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild("Models")
	local real = folder and folder:FindFirstChild(def.model)
	local template: Model
	if real and real:IsA("Model") and real.PrimaryPart then
		template = real:Clone()
		if template:GetAttribute("RootOffset") == nil then
			template:SetAttribute("RootOffset", (template.PrimaryPart :: BasePart).CFrame)
		end
	else
		local bp = Blockout.forDef(def)
		template = BlockoutBuilder.build(bp, def)
	end
	templates[def.id] = template
	return template
end

return Models
