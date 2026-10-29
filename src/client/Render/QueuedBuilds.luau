--!strict
-- Queued structures (C-23): every BUILD your own builders still have queued
-- (Core/Waypoints) shows as a translucent copy of the structure on its spot,
-- over its footprint's build cells (Render/Footprint, H3: it was a flat
-- plate that sank into slopes), until its frame starts. Pooled per def; rebuilt
-- only when the set of queued builds changes. The copies share one
-- Highlight drawn on top of everything (G15), so a plan behind a hill or
-- under units still shows.

local Facing = require("../Core/Facing")
local Api = require("../Api")
local Schema = require("@shared/Net/Schema")
local World = require("../Core/World")
local Footprint = require("./Footprint")
local Models = require("./Models")

local QueuedBuilds = {}

QueuedBuilds.TRANSPARENCY = 0.6
local CELLS_COLOR = Color3.fromRGB(235, 220, 80)

local CT = Schema.CmdType

export type Queued = {
	folder: Folder,
	planned: Model, -- the copies, under one Highlight
	free: { [string]: { Model } },
	shown: { Model },
	cells: Footprint.Pool,
	key: string,
}

function QueuedBuilds.new(): Queued
	local folder = Instance.new("Folder")
	folder.Name = "Queued"
	local planned = Instance.new("Model")
	planned.Name = "Planned"
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = Color3.fromRGB(235, 220, 80), Color3.fromRGB(235, 220, 80)
	h.FillTransparency, h.OutlineTransparency = 0.8, 0.35
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = planned
	planned.Parent = folder
	folder.Parent = workspace
	return { folder = folder, planned = planned, free = {}, shown = {}, cells = Footprint.new(folder), key = "" }
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
	Footprint.begin(q.cells)

	for _, model in q.shown do
		local id = model:GetAttribute("DefId") :: string
		q.free[id] = q.free[id] or {}
		table.insert(q.free[id], model)
		model.Parent = nil
	end
	table.clear(q.shown)
	for _, p in items do
		local def = world.defs.unitByIndex[p.defIndex :: number]
		local model = take(q, def)
		local y = World.groundY(world, p.x, p.z)
		local heading = Facing.heading(p.facing or 0) -- as the built frame turns (C-206)
		local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
		;(model.PrimaryPart :: BasePart).CFrame = CFrame.new(p.x, y, p.z) * CFrame.Angles(0, heading + math.pi, 0) * offset
		model.Parent = q.planned
		table.insert(q.shown, model)
		Footprint.lay(q.cells, world, p.x, p.z, def.footprint, CELLS_COLOR, 0.35, World.floats(def))
	end
	Footprint.finish(q.cells)
end

return QueuedBuilds
