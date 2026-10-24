--!strict
-- Queued structures (C-23): every BUILD your own builders still have queued
-- (Core/Waypoints) shows as a translucent copy of the structure on its spot,
-- over a faint footprint, until its frame starts. Pooled per def; rebuilt
-- only when the set of queued builds changes.

local Facing = require("../Core/Facing")
local Api = require("../Api")
local Schema = require("@shared/Net/Schema")
local World = require("../Core/World")
local Models = require("./Models")

local QueuedBuilds = {}

QueuedBuilds.TRANSPARENCY = 0.6

local CT = Schema.CmdType

export type Queued = {
	folder: Folder,
	free: { [string]: { Model } },
	shown: { Model },
	plates: { BasePart },
	key: string,
}

function QueuedBuilds.new(): Queued
	local folder = Instance.new("Folder")
	folder.Name = "Queued"
	folder.Parent = workspace
	return { folder = folder, free = {}, shown = {}, plates = {}, key = "" }
end

local function take(q: Queued, def: any): Model
	local list = q.free[def.id]
	if list and #list > 0 then
		return table.remove(list) :: Model
	end
	local model = Models.template(def):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, QueuedBuilds.TRANSPARENCY)
			d.CastShadow = false
		end
	end
	return model
end

local function plate(q: Queued, i: number): BasePart
	local p = q.plates[i]
	if p == nil then
		local part = Instance.new("Part")
		part.Name = "QueuedFootprint"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(235, 220, 80)
		part.Transparency = 0.8
		q.plates[i] = part
		p = part
	end
	return p :: BasePart
end

function QueuedBuilds.step(q: Queued, api: Api.Api)
	local world = api.world
	-- what is queued now
	local items = {}
	local parts = {}
	for id, list in api.waypoints.byUnit do
		local u = world.units[id]
		if u == nil or u.team ~= world.me.team then
			continue
		end
		for _, p in list do
			if p.kind == CT.BUILD and p.defIndex then
				table.insert(items, p)
				table.insert(parts, `{p.defIndex}:{p.x}:{p.z}:{p.facing or 0}`)
			end
		end
	end
	table.sort(parts)
	local key = table.concat(parts, ",")
	if key == q.key then
		return
	end
	q.key = key

	for _, model in q.shown do
		local id = model:GetAttribute("DefId") :: string
		q.free[id] = q.free[id] or {}
		table.insert(q.free[id], model)
		model.Parent = nil
	end
	table.clear(q.shown)
	for i, p in items do
		local def = world.defs.unitByIndex[p.defIndex :: number]
		local model = take(q, def)
		local y = World.groundY(world, p.x, p.z)
		local heading = Facing.heading(p.facing or 0) -- as the built frame turns (C-206)
		local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
		;(model.PrimaryPart :: BasePart).CFrame = CFrame.new(p.x, y, p.z) * CFrame.Angles(0, heading + math.pi, 0) * offset
		model.Parent = q.folder
		table.insert(q.shown, model)
		local size = def.footprint * 8
		local fp = plate(q, i)
		fp.Size = Vector3.new(size, 0.15, size)
		fp.CFrame = CFrame.new(p.x, y + 0.08, p.z)
		fp.Parent = q.folder
	end
	for i = #items + 1, #q.plates do
		q.plates[i].Parent = nil
	end
end

return QueuedBuilds
