--!strict
-- Unit models by def (guide 15.2, docs/contracts/rig.md section 5): take one
-- from the pool (or clone the template), team-color it, reset its joints;
-- give it back when the unit leaves the tactical tier or dies. Pooled models
-- are unparented, not destroyed.

local CollectionService = game:GetService("CollectionService")

local CoreGlow = require("../Core/Glow")
local MeshModels = require("./MeshModels")
local Models = require("./Models")
local TeamColors = require("./TeamColors")

local ModelPool = {}

local TEAM_TAG = "TeamColor"

local free: { [string]: { Model } } = {}
local folder: Folder? = nil
local visible = true

local function unitsFolder(): Folder
	if folder == nil then
		local f = Instance.new("Folder")
		f.Name = "Units"
		f.Parent = if visible then workspace else nil
		folder = f
	end
	return folder :: Folder
end

-- The folder every drawn unit model is in (click picking raycasts it).
function ModelPool.folder(): Folder
	return unitsFolder()
end

-- Shows or hides every unit model at once (strategic zoom, guide 15.4).
function ModelPool.setVisible(on: boolean)
	visible = on
	local f = unitsFolder()
	local parent = if on then workspace else nil
	if f.Parent ~= parent then
		f.Parent = parent
	end
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
		-- clicks raycast unit models (Controls.pickModel, C-38); other
		-- raycasts include only the ground, so they never hit units
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanQuery = true
			end
		end
	end
	local color = TeamColors.of(team)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, TEAM_TAG) then
			d.Color = color
		elseif d:IsA("BasePart") then
			-- a glow part: white where the team color clashes with the glow (C-106)
			local channel = d:GetAttribute("GlowChannel")
			local tint = d:GetAttribute("GlowTint")
			if type(channel) == "string" and typeof(tint) == "Color3" then
				local w = CoreGlow.CLASH_WHITE
				local c = if CoreGlow.clashes(def.faction, team, channel) then Color3.fromRGB(w[1], w[2], w[3]) else tint
				d.Color = c
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				if sa then
					sa.EmissiveTint = c
				end
			end
		end
	end
	resetJoints(model)
	model.Parent = unitsFolder()
	return model
end

-- Destroys every pooled model (the Detailed models setting flipped).
function ModelPool.flushAll()
	for id in free do
		ModelPool.flush(id)
	end
end

-- Destroys the pooled models of def `id` (a better model replaced them).
function ModelPool.flush(id: string)
	for _, m in free[id] or {} do
		m:Destroy()
	end
	free[id] = nil
end

function ModelPool.release(model: Model)
	local id = model:GetAttribute("DefId") :: string?
	model.Parent = nil
	local wrong = if Models.DETAILED then model:GetAttribute("Blockout") and MeshModels.get(id) ~= nil else model:GetAttribute("Blockout") == nil
	if id == nil or wrong then
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
