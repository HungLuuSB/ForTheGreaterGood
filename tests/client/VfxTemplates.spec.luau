--!strict
-- The particle templates in place/Vfx.model.json (assets/fx/vfx/build_vfx.py,
-- C-47): Render/Vfx reads each emitter's EmitCount / EmitDelay attributes and
-- a continuous rig's Continuous attribute. Rojo keeps attributes only in the
-- typed Properties.Attributes form; a top-level "Attributes" is dropped
-- without a word (models, 2026-10-30).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local FILE = "place/Vfx.model.json"

local function walk(node: any, f: (any) -> ())
	f(node)
	for _, c in node.Children or {} do
		walk(c, f)
	end
end

return function(t: any)
	t.test("Vfx.model.json: attributes in the typed form Rojo keeps", function()
		local data = serde.decode("json", fs.readFile(FILE))
		walk(data, function(n)
			t.expect(n.Attributes == nil, `{n.Name or "root"}: top-level Attributes are dropped by Rojo`)
		end)
	end)

	t.test("Vfx.model.json: every emitter emits a count or runs at a rate", function()
		local data = serde.decode("json", fs.readFile(FILE))
		for _, template in data.Children do
			local attrs = template.Properties and template.Properties.Attributes and template.Properties.Attributes.Attributes or {}
			local continuous = attrs.Continuous ~= nil and attrs.Continuous.Bool == true
			walk(template, function(n)
				if n.ClassName ~= "ParticleEmitter" then
					return
				end
				local a = n.Properties.Attributes and n.Properties.Attributes.Attributes or {}
				if continuous and (n.Properties.Rate or 0) > 0 then
					t.expect(a.EmitCount == nil, `{template.Name}.{n.Name}: a running emitter has no EmitCount`)
				else
					t.expect(a.EmitCount ~= nil and a.EmitCount.Float64 >= 1, `{template.Name}.{n.Name} has an EmitCount`)
				end
			end)
		end
	end)
end
