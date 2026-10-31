--!strict
-- Roblox Terrain from a map's layers (C-28), for maps without baked place
-- terrain (every map today; guide 5.4 baked maps will bring their own).
-- The surface is Core/Terrain's smooth ground, written as 4-stud voxels
-- whose occupancy puts the surface at the exact height; water fills up to
-- each water cell's surface (liquid occupancy, so it meets sloped shores).
-- Written chunk by chunk, yielding between chunks, on the client only:
-- nothing here is saved to the place. Terrain the place already has is
-- never touched.

local RunService = game:GetService("RunService")

local Layers = require("@shared/Grid/Layers")
local CoreTerrain = require("../Core/Terrain")

local RenderTerrain = {}

RenderTerrain.CHUNK = 32 -- voxel columns per side per write
RenderTerrain.BUDGET = 0.008 -- seconds of building per frame before yielding
local VOXEL = 4
-- Roblox draws a solid occupancy surface half a voxel above the plain
-- fraction (Studio, coastline: +1.98 studs on flat ground), so solid
-- occupancies are written for a surface this much lower. Liquid occupancy
-- has no such offset (with it the sea drew at 5.98 instead of 8).
RenderTerrain.SURFACE_BIAS = 2
local MARKER = "FtggBuilt" -- attribute on workspace.Terrain: this client wrote it

-- Core/Terrain.material names → Roblox materials (C-66)
local MATERIAL: { [string]: Enum.Material } = {
	grass = Enum.Material.Grass,
	rock = Enum.Material.Rock,
	sand = Enum.Material.Sand,
	road = Enum.Material.Asphalt,
	leafy = Enum.Material.LeafyGrass,
	ground = Enum.Material.Ground,
	bridge = Enum.Material.WoodPlanks,
	-- The Canyon's desert (C-153): materials no other map or atmosphere
	-- preset uses, so their colors (below) touch nothing else
	desert = Enum.Material.Limestone,
	redrock = Enum.Material.Sandstone,
}
RenderTerrain.MATERIAL = MATERIAL
local COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Limestone] = Color3.fromRGB(186, 148, 100), -- pale desert ground (a lighter tan read as snow at night)
	[Enum.Material.Sandstone] = Color3.fromRGB(168, 88, 58), -- reddish rock
} -- deposits tint their patch with the surrounding terrain's color (C-123)

export type Stats = { seconds: number, cpu: number, voxels: number, chunks: number, mode: string } -- seconds: wall time (yields included)

-- Builds the terrain for `layers` (yielding), materials from the sim's
-- terrain types or the map's features (Core/Terrain.material). Returns nil
-- when the place has terrain of its own (left alone).
-- `waterOnly`: the ground is drawn by baked mesh tiles (Render/MeshGround,
-- C-167): only the water goes into the terrain. `noWater`: the water is
-- drawn as mesh planes (Render/Ground, C-236): only the ground goes in.
function RenderTerrain.build(layers: Layers.Layers, feature: CoreTerrain.Feature?, waterOnly: boolean?, noWater: boolean?): Stats?
	local terrain = workspace.Terrain
	if terrain:GetAttribute(MARKER) then
		terrain:Clear() -- ours, from an earlier map
	elseif terrain:CountCells() > 0 then
		warn("[Client] the place has terrain of its own: not drawing the map's layers over it")
		return nil
	end
	terrain:SetAttribute(MARKER, true)
	for material, color in COLORS do
		terrain:SetMaterialColor(material, color)
	end
	local t0 = os.clock()
	local g = layers.grid
	local lo, hi = CoreTerrain.bounds(layers)
	local y0 = math.floor((lo - 8) / VOXEL) * VOXEL
	local ny = math.ceil((hi + VOXEL - y0) / VOXEL)
	local nx, nz = math.ceil(g.sizeX / VOXEL), math.ceil(g.sizeZ / VOXEL)
	local channels = true
	local voxels, chunks, cpu = 0, 0, 0
	local sliceStart = os.clock()
	for bz = 0, nz - 1, RenderTerrain.CHUNK do
		for bx = 0, nx - 1, RenderTerrain.CHUNK do
			local cx, cz = math.min(RenderTerrain.CHUNK, nx - bx), math.min(RenderTerrain.CHUNK, nz - bz)
			local mats, occ, liquid = table.create(cx), table.create(cx), table.create(cx)
			for i = 1, cx do
				local mi, oi, li = table.create(ny), table.create(ny), table.create(ny)
				mats[i], occ[i], liquid[i] = mi, oi, li
				for j = 1, ny do
					mi[j], oi[j], li[j] = table.create(cz), table.create(cz), table.create(cz)
				end
				local x = g.originX + (bx + i - 1) * VOXEL + VOXEL / 2
				for k = 1, cz do
					local z = g.originZ + (bz + k - 1) * VOXEL + VOXEL / 2
					local ground = CoreTerrain.groundY(layers, x, z)
					local water = if noWater then nil else CoreTerrain.waterY(layers, x, z)
					local mat = MATERIAL[CoreTerrain.material(layers, x, z, feature)] or Enum.Material.Grass
					for j = 1, ny do
						local vy = y0 + (j - 1) * VOXEL
						local o = if waterOnly then 0 else math.clamp((ground - RenderTerrain.SURFACE_BIAS - vy) / VOXEL, 0, 1)
						mi[j][k] = if o > 0 then mat else Enum.Material.Air
						oi[j][k] = o
						li[j][k] = if water then math.clamp((water - vy) / VOXEL, 0, 1) else 0
					end
				end
			end
			local min = Vector3.new(g.originX + bx * VOXEL, y0, g.originZ + bz * VOXEL)
			local region = Region3.new(min, min + Vector3.new(cx * VOXEL, ny * VOXEL, cz * VOXEL))
			if channels then
				local ok = pcall(function()
					terrain:WriteVoxelChannels(region, VOXEL, { SolidMaterial = mats, SolidOccupancy = occ, LiquidOccupancy = liquid })
				end)
				channels = ok
			end
			if not channels then
				-- older terrain: one material per voxel, water where no ground is
				for i = 1, cx do
					for j = 1, ny do
						for k = 1, cz do
							if occ[i][j][k] < 0.5 and liquid[i][j][k] > 0 then
								mats[i][j][k], occ[i][j][k] = Enum.Material.Water, liquid[i][j][k]
							end
						end
					end
				end
				terrain:WriteVoxels(region, VOXEL, mats, occ)
			end
			voxels += cx * cz * ny
			chunks += 1
			if os.clock() - sliceStart > RenderTerrain.BUDGET then
				cpu += os.clock() - sliceStart
				RunService.RenderStepped:Wait()
				sliceStart = os.clock()
			end
		end
	end
	cpu += os.clock() - sliceStart
	return { seconds = os.clock() - t0, cpu = cpu, voxels = voxels, chunks = chunks, mode = if channels then "channels" else "voxels" }
end

-- Removes terrain this client built (never the place's own).
function RenderTerrain.clear()
	local terrain = workspace.Terrain
	if terrain:GetAttribute(MARKER) then
		terrain:Clear()
		terrain:SetAttribute(MARKER, nil)
	end
end

-- The 3D terrain's color at (x, z): its ground type's material color (what a
-- team-masked ground patch takes: deposits, scrap heaps (C-281)).
function RenderTerrain.tintAt(layers: any, x: number, z: number): Color3
	local material = MATERIAL[CoreTerrain.kind(layers, x, z)] or Enum.Material.Grass
	local ok, color = pcall(function()
		return workspace.Terrain:GetMaterialColor(material)
	end)
	return if ok and typeof(color) == "Color3" then color else Color3.fromRGB(96, 110, 70)
end

return RenderTerrain
