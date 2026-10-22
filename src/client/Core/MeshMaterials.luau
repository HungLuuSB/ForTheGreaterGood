--!strict
-- The Rojo model file of the meshed models' surface appearances (C-103),
-- pure: `render` gives the text of place/MeshMaterials.model.json from
-- the mesh manifest (`lune run mesh_materials` writes it). A Folder of
-- SurfaceAppearances: one per unit model in the manifest, named by def ID,
-- and one per effect mesh (Meshes.fx: missiles, the shield emitter), named
-- `fx_<id>` (C-107, models-C's request), and one per unit's wreck mesh
-- (`wreck_<id>`, C-115), each with
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
	local entries: { { name: string, maps: any } } = {}
	for id, e in Meshes.units do
		table.insert(entries, { name = id, maps = e.maps })
	end
	for id, e in (Meshes :: any).fx or {} do
		table.insert(entries, { name = "fx_" .. id, maps = e.maps })
		-- an fx entry with look variants (fx.deposit, C-123): fx_<id>_<i> each
		for i, v in e.variants or {} do
			table.insert(entries, { name = `fx_{id}_{i}`, maps = v.maps })
		end
	end
	for id, e in Meshes.units do
		local wreck = (e :: any).wreck
		if wreck and wreck.maps then
			table.insert(entries, { name = "wreck_" .. id, maps = wreck.maps })
		end
	end
	table.sort(entries, function(a, b)
		return a.name < b.name
	end)
	local children = {
		appearance("Glow", {
			{ "EmissiveMaskContent", quote(Meshes.glowMask) },
			{ "EmissiveStrength", "1" },
		}),
	}
	for _, entry in entries do
		local maps = entry.maps
		table.insert(
			children,
			appearance(entry.name, {
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
