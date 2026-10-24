--!strict
-- The settings tree (C-202): a section's rows, search across sections,
-- Advanced rows, folds and Unfold all, dimmed children of an off parent,
-- sub-section headers, the active sub-section while scrolling.

local OptionTree = require("../../src/client/Core/OptionTree")

local function sample()
	return OptionTree.new({
		{ name = "Graphics", subs = {
			{ name = "Quality", options = {
				{ id = "quality", label = "Quality", help = "Effect caps", folded = true },
				{ id = "caps", label = "Explosions", parent = "quality" },
			} },
			{ name = "Lighting", options = {
				{ id = "fog", label = "Fog of war", help = "Shading over what you can't see" },
				{ id = "fogEdge", label = "Soft edge", parent = "fog" },
				{ id = "fogDeep", label = "Deeper", parent = "fogEdge" },
				{ id = "dev", label = "Debug lights", advanced = true },
				{ id = "devChild", label = "Light count", parent = "dev" },
			} },
		} },
		{ name = "Control", subs = {
			{ name = "Camera", options = {
				{ id = "pan", label = "Pan speed", keywords = "scroll" },
			} },
		} },
	})
end

return function(t: any)
	t.test("a section's rows; Advanced; folds and Unfold all", function()
		local tree = sample()
		local view = OptionTree.view("Graphics")
		local on = function(_: string): boolean
			return true
		end
		local s = OptionTree.shown(tree, view, on)
		t.expect(s.rows.quality.visible and s.rows.fog.visible, "the section's rows")
		t.expect(not s.rows.pan.visible, "not another section's")
		t.expect(not s.rows.caps.visible, "a folded parent hides its child")
		t.expect(s.rows.quality.foldable and not s.rows.quality.open, "the parent is foldable, folded")
		t.expect(s.rows.fogDeep.visible and s.rows.fogDeep.level == 2, "an open chain shows, two levels in")
		t.expect(not s.rows.dev.visible and not s.rows.devChild.visible, "advanced rows and their children hidden")
		view.advanced = true
		s = OptionTree.shown(tree, view, on)
		t.expect(s.rows.dev.visible and s.rows.devChild.visible, "shown with Advanced")
		view.unfoldAll = true
		s = OptionTree.shown(tree, view, on)
		t.expect(s.rows.caps.visible and s.rows.quality.open, "Unfold all opens every parent")
		view.unfoldAll = false
		view.folded.quality = false
		t.expect(OptionTree.shown(tree, view, on).rows.caps.visible, "the parent's own fold, opened")
		view.folded.fog = true
		s = OptionTree.shown(tree, view, on)
		t.expect(not s.rows.fogEdge.visible and not s.rows.fogDeep.visible, "folding hides the whole chain")
		t.equal(s.count, 5, "counted: quality, caps, fog, dev, devChild")
	end)

	t.test("dimmed under an off ancestor", function()
		local tree = sample()
		local view = OptionTree.view("Graphics")
		local s = OptionTree.shown(tree, view, function(id: string): boolean
			return id ~= "fog"
		end)
		t.expect(not s.rows.fog.dimmed, "the off parent itself isn't dimmed")
		t.expect(s.rows.fogEdge.dimmed and s.rows.fogDeep.dimmed, "its children and grandchildren are")
		t.expect(not s.rows.quality.dimmed and not s.rows.caps.dimmed, "others aren't")
	end)

	t.test("search: every section, all words, folds and Advanced ignored", function()
		local tree = sample()
		local view = OptionTree.view("Graphics")
		local on = function(_: string): boolean
			return true
		end
		view.query = "SCROLL"
		local s = OptionTree.shown(tree, view, on)
		t.expect(s.rows.pan.visible and s.count == 1, "keywords match, case-insensitive, from another section")
		view.query = "lighting fog"
		s = OptionTree.shown(tree, view, on)
		t.expect(s.rows.fog.visible and not s.rows.fogEdge.visible, "all words (one from the sub-section name)")
		view.query = "explosions"
		s = OptionTree.shown(tree, view, on)
		t.expect(s.rows.caps.visible, "a folded child is found")
		view.query = "light count"
		t.expect(OptionTree.shown(tree, view, on).rows.devChild.visible, "an advanced row is found")
		view.query = "   "
		t.expect(OptionTree.shown(tree, view, on).rows.quality.visible, "blank: back to the section")
	end)

	t.test("headers and the active sub-section", function()
		local tree = sample()
		local view = OptionTree.view("Graphics")
		view.query = "pan"
		local s = OptionTree.shown(tree, view, function(_: string): boolean
			return true
		end)
		t.expect(s.subs[OptionTree.subKey("Control", "Camera")] and not s.subs[OptionTree.subKey("Graphics", "Quality")], "only headers with a row")
		local heads = { { key = "a", y = 0 }, { key = "b", y = 200 }, { key = "c", y = 500 } }
		t.equal(OptionTree.activeSub(heads, 0), "a")
		t.equal(OptionTree.activeSub(heads, 199.5), "b", "within a pixel")
		t.equal(OptionTree.activeSub(heads, 900), "c")
		t.equal(OptionTree.activeSub({}, 0), nil)
	end)

	t.test("a parent must sit above its child in the same sub-section", function()
		local ok = pcall(OptionTree.new, { { name = "A", subs = { { name = "x", options = { { id = "c", label = "C", parent = "p" }, { id = "p", label = "P" } } } } } })
		t.expect(not ok, "a parent below is refused")
		ok = pcall(OptionTree.new, { { name = "A", subs = { { name = "x", options = { { id = "p", label = "P" }, { id = "p", label = "Q" } } } } } })
		t.expect(not ok, "an id twice is refused")
	end)
end
