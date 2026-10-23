--!strict
-- The meshed models' surface appearances (C-103): the Rojo model file
-- matches the mesh manifest (rerun `lune run mesh_materials` when not).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local MeshMaterials = require("../../src/client/Core/MeshMaterials")
local Meshes = require("@shared/Defs/Meshes/Registry")

return function(t: any)
	t.test("MeshMaterials.model.json is current with the manifest", function()
		local text = MeshMaterials.render()
		t.expect(fs.isFile(MeshMaterials.FILE), "the file exists")
		local onDisk = string.gsub(fs.readFile(MeshMaterials.FILE), "\r\n", "\n") -- git may check it out with CRLF
		t.expect(onDisk == text, "stale: run `lune run mesh_materials`")
	end)

	t.test("one appearance per model, plus the glow mask; valid JSON", function()
		-- (effect meshes too, as fx_<id>)
		local data = serde.decode("json", MeshMaterials.render())
		local names = {}
		for _, c in data.Children do
			names[c.Name] = c
			t.equal(c.ClassName, "SurfaceAppearance")
		end
		t.equal(names.Glow.Properties.EmissiveMaskContent, Meshes.glowMask)
		for id, e in Meshes.units do
			local c = names[id]
			t.expect(c ~= nil, `{id} has an appearance`)
			t.equal(c.Properties.ColorMapContent, e.maps.ALB)
			t.equal(c.Properties.AlphaMode, "Overlay")
		end
		for id, e in (Meshes :: any).fx or {} do
			local c = names["fx_" .. id]
			t.expect(c ~= nil, `fx {id} has an appearance`)
			for i, v in (e :: any).variants or {} do
				local cv = names[`fx_{id}_{i}`]
				t.expect(cv ~= nil and cv.Properties.ColorMapContent == v.maps.ALB, `fx {id} variant {i} has its appearance`)
			end
			t.equal(c.Properties.ColorMapContent, e.maps.ALB)
		end
		for id, e in Meshes.units do
			local wreck = (e :: any).wreck
			if wreck then
				local c = names["wreck_" .. id]
				t.expect(c ~= nil, `wreck {id} has an appearance`)
				t.equal(c.Properties.ColorMapContent, wreck.maps.ALB)
			end
		end
	end)
end
