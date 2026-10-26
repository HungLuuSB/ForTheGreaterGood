--!strict
-- Baked map ground (C-167, docs/contracts/map-ground.md): which maps have
-- mesh tiles in the models stream's manifest (`ground`), whether to use
-- them (approved, or review with the Studio switch), and the plain look a
-- tile gets while its texture (`groundMaterials`) isn't there. Pure Luau
-- (C-7): colours as { r, g, b }; Render/MeshGround builds the tiles.

local Meshes = require("@shared/Defs/Meshes/Registry")

local GroundMeshes = {}

GroundMeshes.ANYWAY = false -- Studio: draw review entries too (Invoke("groundanyway", true))

export type Piece = { mesh: string, center: { number }, size: { number }, material: string }
export type Entry = { status: string, tiles: { Piece }, details: { Piece }?, step: number? } -- step: the bake's height sampling (map-ground.md; 4 when absent)

GroundMeshes.STEP = 4 -- studs: a bake's height sampling unless its entry says otherwise

-- The plain look per material key: a Roblox material name and a colour,
-- the voxel terrain's own (Render/Terrain) so a map looks the same before
-- its textures arrive.
GroundMeshes.FALLBACK = table.freeze({
	grass = { material = "Grass", color = { 72, 90, 66 } },
	leafy = { material = "LeafyGrass", color = { 76, 96, 56 } },
	rock = { material = "Rock", color = { 92, 96, 104 } },
	sand = { material = "Sand", color = { 150, 145, 122 } },
	road = { material = "Asphalt", color = { 58, 62, 66 } },
	ground = { material = "Ground", color = { 104, 96, 80 } },
	bridge = { material = "WoodPlanks", color = { 120, 104, 80 } },
	desert = { material = "Limestone", color = { 186, 148, 100 } },
	redrock = { material = "Sandstone", color = { 168, 88, 58 } },
	cliff = { material = "Sandstone", color = { 150, 78, 52 } }, -- strata walls (details only; models-C, M-35)
} :: { [string]: { material: string, color: { number } } })

-- The map name in an ID ("map:canyon" → "canyon"), or nil.
function GroundMeshes.nameOf(mapId: string?): string?
	return if mapId then string.match(mapId, "^map:([%w_]+)$") else nil
end

-- The baked ground to draw for map `mapId`, or nil (the voxel terrain then).
-- `manifest` defaults to the mesh manifest's `ground` table.
function GroundMeshes.entryFor(mapId: string?, manifest: { [string]: Entry }?): Entry?
	local name = GroundMeshes.nameOf(mapId)
	local all = manifest or ((Meshes :: any).ground :: { [string]: Entry }?)
	local e = if name and all then all[name] else nil
	if e == nil or #(e.tiles or {}) == 0 then
		return nil
	end
	if e.status == "approved" or GroundMeshes.ANYWAY then
		return e
	end
	return nil
end

-- The height sampling of the baked ground drawn for `mapId` when it is
-- coarser than the sim's smooth ground can stand on unchanged (C-235): the
-- step in studs, or nil (no mesh ground, or a 4-stud bake).
function GroundMeshes.drawnStep(mapId: string?, manifest: { [string]: Entry }?): number?
	local e = GroundMeshes.entryFor(mapId, manifest)
	if e == nil then
		return nil
	end
	local step = e.step or GroundMeshes.STEP
	return if step > GroundMeshes.STEP then step else nil
end

-- The plain look of material key `key` (unknown keys look like grass).
function GroundMeshes.fallback(key: string): { material: string, color: { number } }
	return GroundMeshes.FALLBACK[key] or GroundMeshes.FALLBACK.grass
end

return GroundMeshes
