--!strict
-- Baked map ground (C-167, docs/contracts/map-ground.md): the models
-- stream's mesh tiles for a named map, drawn instead of the voxel terrain
-- (which keeps only the water). Uploaded meshes keep full detail at any
-- distance, so a camera jump lands sharp. Each tile is one MeshPart made
-- from its asset ID (CreateMeshPartAsync, many at once; no editable memory),
-- with its material's SurfaceAppearance (`ground_<material>` in
-- ReplicatedStorage.MeshMaterials) or, until that exists, a plain Roblox
-- material and colour (Core/GroundMeshes.FALLBACK).

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundMeshes = require("../Core/GroundMeshes")

local MeshGround = {}

MeshGround.AT_ONCE = 12 -- tiles made at the same time
local TURN = CFrame.Angles(0, math.pi, 0) -- the meshes come in turned 180° about Y (as Render/MeshModels)

export type Stats = { tiles: number, details: number, failed: number, seconds: number, textured: number }

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function make(piece: GroundMeshes.Piece, parent: Instance, materials: Instance?, detail: boolean): (boolean, boolean)
	-- details (rims, caps, boulders) stand above the sim's heights: the fog
	-- blanket samples their real shape (C-213), so they get a convex
	-- decomposition (Default: ~40 ms each) and stay queryable; tiles match the
	-- sim's heights and keep a cheap box nothing queries
	local fidelity = if detail then Enum.CollisionFidelity.Default else Enum.CollisionFidelity.Box
	local ok, part = pcall(function()
		return (AssetService :: any):CreateMeshPartAsync((Content :: any).fromUri(piece.mesh), { RenderFidelity = Enum.RenderFidelity.Precise, CollisionFidelity = fidelity })
	end)
	if not ok or part == nil then
		warn(`[MeshGround] {piece.mesh}: {part}`)
		return false, false
	end
	local mp = part :: MeshPart
	mp.Name = piece.material
	mp.Size = Vector3.new(piece.size[1], piece.size[2], piece.size[3])
	mp.CFrame = CFrame.new(piece.center[1], piece.center[2], piece.center[3]) * TURN
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanTouch = false
	mp.CanQuery = detail -- a tile's box would catch clicks at mesa height: Controls.groundAt marches the sim's heights (C-209); details are only for the fog's height samples
	if detail then
		mp:SetAttribute("GroundDetail", true) -- clicks look through it (Controls.groundAt)
	end
	mp.CastShadow = true
	local look = materials and materials:FindFirstChild("ground_" .. piece.material)
	if look and look:IsA("SurfaceAppearance") then
		look:Clone().Parent = mp
	else
		local f = GroundMeshes.fallback(piece.material)
		mp.Material = (Enum.Material :: any)[f.material]
		mp.Color = rgb(f.color)
	end
	mp.Parent = parent
	return true, look ~= nil
end

-- Builds `entry`'s tiles and details into `folder` (yields until done).
function MeshGround.build(entry: GroundMeshes.Entry, folder: Instance): Stats
	local t0 = os.clock()
	local stats: Stats = { tiles = 0, details = 0, failed = 0, seconds = 0, textured = 0 }
	local holder = Instance.new("Folder")
	holder.Name = "MeshGround"
	holder.Parent = folder
	local materials = ReplicatedStorage:FindFirstChild("MeshMaterials")
	local jobs: { { piece: GroundMeshes.Piece, kind: string } } = {}
	for _, p in entry.tiles do
		table.insert(jobs, { piece = p, kind = "tiles" })
	end
	for _, p in entry.details or {} do
		table.insert(jobs, { piece = p, kind = "details" })
	end
	local nextJob, running = 1, 0
	local me = coroutine.running()
	local function worker()
		while nextJob <= #jobs do
			local job = jobs[nextJob]
			nextJob += 1
			local ok, textured = make(job.piece, holder, materials, job.kind == "details")
			if ok then
				(stats :: any)[job.kind] += 1
				if textured then
					stats.textured += 1
				end
			else
				stats.failed += 1
			end
		end
		running -= 1
		if running == 0 and coroutine.status(me) == "suspended" then
			task.spawn(me)
		end
	end
	for _ = 1, math.min(MeshGround.AT_ONCE, #jobs) do
		running += 1
		task.spawn(worker)
	end
	if running > 0 then
		coroutine.yield()
	end
	stats.seconds = os.clock() - t0
	return stats
end

return MeshGround
