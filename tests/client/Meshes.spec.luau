--!strict
-- Mesh manifest (M-23, rig.md section 7): every entry matches its unit def,
-- every asset ID is present, and the checks catch broken entries.

local Mesh = require("@shared/Defs/Meshes/Mesh")
local Registry = require("@shared/Defs/Meshes/Registry")
local Defs = require("@shared/Defs/Defs")
local Blockouts = require("@shared/Defs/Blockouts/Registry")

local defs = Defs.load()

local function defById(id: string): any
	for _, def in defs.unitByIndex do
		if def.id == id then
			return def
		end
	end
	return nil
end

return function(t: any)
	t.test("every meshed unit matches a def, with every piece and asset ID", function()
		local n = 0
		for id, e in Registry.units do
			n += 1
			local def = defById(id)
			t.expect(def ~= nil, `{id}: no unit def`)
			local bp = (Blockouts :: any)[id]
			t.deepEqual(Mesh.validate(id, e, def, bp and bp.visualPieces), {}, id)
		end
		t.expect(n >= 22, "the 22 BAR meshes so far are listed")
	end)

	t.test("fx meshes are valid and the glow mask is an asset", function()
		t.expect(Mesh.isAssetId(Registry.glowMask))
		for id, e in Registry.fx do
			t.deepEqual(Mesh.validate(id, e, nil), {}, id)
		end
		t.expect(Registry.fx.shield_emitter ~= nil and Registry.fx.shield_emitter.attachments.core ~= nil)
	end)

	t.test("key arts have four layers back to front, each with its tiles as asset IDs", function()
		for name, art in Registry.keyArt do
			t.expect(art.status == "approved" or art.status == "review", `{name}: status`)
			t.equal(#art.layers, 4, name)
			local last = -1
			for _, layer in art.layers do
				t.expect(layer.depth > last, `{name}: layers back to front`)
				last = layer.depth
				t.equal(#layer.images, art.tiles[1] * art.tiles[2], `{name} {layer.name}`)
				for _, id in layer.images do
					t.expect(Mesh.isAssetId(id), `{name} {layer.name}: {id}`)
				end
			end
		end
	end)

	t.test("the approved and review statuses follow the user's review", function()
		for _, id in { "ord_lancer", "chs_ravager", "ord_mason", "chs_scrapper", "ord_verdict", "chs_hellmouth", "ord_extractor", "ord_sovereign" } do
			t.equal(Registry.units[id].status, "approved", id)
		end
		t.equal(Registry.fx.shield_emitter.status, "approved")
	end)

	t.test("validate reports broken entries", function()
		local def = defById("ord_lancer")
		local ok = Registry.units.ord_lancer
		local function with(edit: (any) -> ()): string
			local copy = table.clone(ok) :: any
			copy.pieces = table.clone(ok.pieces)
			copy.maps = table.clone(ok.maps)
			copy.glow = table.clone(ok.glow)
			copy.teamPieces = table.clone(ok.teamPieces)
			edit(copy)
			return table.concat(Mesh.validate("ord_lancer", copy, def), "\n")
		end
		local function has(text: string, needle: string)
			t.expect(string.find(text, needle, 1, true) ~= nil, `expected "{needle}" in "{text}"`)
		end
		has(with(function(e)
			e.pieces.turret = nil
		end), "def piece turret has no mesh piece")
		has(with(function(e)
			e.attachments = {}
		end), "def piece muzzle must be an attachment")
		has(with(function(e)
			e.maps.EMI = nil
		end), "map EMI asset ID missing")
		has(with(function(e)
			e.pieces.hatch = { mesh = "rbxassetid://1", center = { 0, 0, 0 }, size = { 1, 1, 1 }, parent = "base", pivot = { 0, 0, 0 } }
		end), "piece hatch isn't in the def's pieces or the blockout's visualPieces")
		has(with(function(e)
			e.status = "draft"
		end), 'status draft must be "approved" or "review"')
		has(with(function(e)
			e.glow[1] = table.clone(e.glow[1])
			e.glow[1].channel = "disco"
		end), "unknown channel disco")
		has(with(function(e)
			table.insert(e.teamPieces, "nope")
		end), "team piece nope isn't a piece")
		local mesh = { mesh = "rbxassetid://1", center = { 0, 0, 0 }, size = { 1, 1, 1 } }
		local maps = { ALB = "rbxassetid://2", NOR = "rbxassetid://3", RGH = "rbxassetid://4", MTL = "rbxassetid://5" }
		has(with(function(e)
			e.wreck = { status = "review", model = "rbxassetid://6", maps = maps, pieces = { base = mesh, turret = mesh } }
		end), "wreck: piece barrel mesh missing")
		has(with(function(e)
			e.wreck = { status = "review", model = "rbxassetid://6", maps = { ALB = maps.ALB }, pieces = { base = mesh, turret = mesh, barrel = mesh } }
		end), "wreck: map NOR asset ID missing")
		has(with(function(e)
			e.wreck = { model = "rbxassetid://6", maps = maps, pieces = { base = mesh, turret = mesh, barrel = mesh } }
		end), 'wreck: status nil must be "approved" or "review"')
		t.equal(with(function(e)
			e.wreck = { status = "review", model = "rbxassetid://6", maps = maps, pieces = { base = mesh, turret = mesh, barrel = mesh } }
		end), "")
	end)
end
