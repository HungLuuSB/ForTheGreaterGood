--!strict
-- Unit models by def (guide 15.2, docs/contracts/rig.md section 5): take one
-- from the pool (or clone the template), team-color it, reset its joints;
-- give it back when the unit leaves the tactical tier or dies. Pooled models
-- are unparented, not destroyed.

local CollectionService = game:GetService("CollectionService")

local Models = require("./Models")
local TeamColors = require("./TeamColors")

local ModelPool = {}

local TEAM_TAG = "TeamColor"

local free: { [string]: { Model } } = {}
local folder: Folder? = nil

local function unitsFolder(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "Units"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function resetJoints(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			d.Transform = CFrame.identity
		end
	end
end

function ModelPool.acquire(def: any, team: number): Model
	local list = free[def.id]
	local model: Model
	if list and #list > 0 then
		model = table.remove(list) :: Model
	else
		model = Models.template(def):Clone()
	end
	local color = TeamColors(team)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, TEAM_TAG) then
			d.Color = color
		end
	end
	resetJoints(model)
	model.Parent = unitsFolder()
	return model
end

function ModelPool.release(model: Model)
	local id = model:GetAttribute("DefId") :: string?
	model.Parent = nil
	if id == nil then
		model:Destroy()
		return
	end
	local list = free[id]
	if list == nil then
		list = {}
		free[id] = list
	end
	table.insert(list, model)
end

return ModelPool
