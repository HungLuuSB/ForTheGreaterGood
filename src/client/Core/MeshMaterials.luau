--!strict
-- The Rojo model file of the meshed models' surface appearances (C-103),
-- pure: `render` gives the text of place/MeshMaterials.model.json from
-- the mesh manifest (`lune run mesh_materials` writes it). A Folder of
-- SurfaceAppearances: one per model in the manifest, named by def ID, with
-- its color (alpha = team mask, Overlay), normal, roughness and metalness
-- maps; and "Glow", the glow parts' shared white emissive mask. Rojo sets
-- these (game scripts may not); Render/MeshModels clones them.

local Meshes = require("@shared/Defs/Meshes/Registry")

local MeshMaterials = {}

MeshMaterials.FILE = "place/MeshMaterials.model.json"

local function quote(s: string): string
	return '"' .. string.gsub(s, '[%c"\\]', function(c: string): string
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

local function appearance(name: string, props: { { string } }): string
	local lines = {}
	for _, kv in props do
		table.insert(lines, `        {quote(kv[1])}: {kv[2]}`)
	end
	return `    \{\n      "Name": {quote(name)},\n      "ClassName": "SurfaceAppearance",\n      "Properties": \{\n` .. table.concat(lines, ",\n") .. "\n      }\n    }"
end

function MeshMaterials.render(): string
	local ids = {}
	for id in Meshes.units do
		table.insert(ids, id)
	end
	table.sort(ids)
	local children = {
		appearance("Glow", {
			{ "EmissiveMaskContent", quote(Meshes.glowMask) },
			{ "EmissiveStrength", "1" },
		}),
	}
	for _, id in ids do
		local maps = Meshes.units[id].maps
		table.insert(
			children,
			appearance(id, {
				{ "AlphaMode", quote("Overlay") },
				{ "ColorMapContent", quote(maps.ALB) },
				{ "NormalMapContent", quote(maps.NOR) },
				{ "RoughnessMapContent", quote(maps.RGH) },
				{ "MetalnessMapContent", quote(maps.MTL) },
				{ "EmissiveStrength", "0" },
			})
		)
	end
	return '{\n  "ClassName": "Folder",\n  "Children": [\n' .. table.concat(children, ",\n") .. "\n  ]\n}\n"
end

return MeshMaterials
