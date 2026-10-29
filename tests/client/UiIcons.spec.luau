--!strict
-- The UI icon atlas (C-259, 2D-E's resource and stat icons): the keys the
-- UI uses exist with a rect per size inside the atlas, and the helper draws
-- the smallest size at least as big as asked.

local UiIcons = require("../../src/client/UI/UiIcons")
local UiIcon = require("../../src/client/UI/UiIcon")

local CommandSet = require("../../src/client/Core/CommandSet")

local ATLAS_W, ATLAS_H = UiIcons.atlasSize[1], UiIcons.atlasSize[2] -- assets/2d/ui/ftgg-ui-icons.png

return function(t: any)
	t.test("every icon has a rect per size on the atlas, and the UI's keys exist", function()
		for key, icon in UiIcons.icons do
			for _, s in UiIcons.sizes do
				local r = icon.rect[s]
				t.expect(r ~= nil and #r == 4, `{key}: no {s}-px rect`)
				if r then
					t.expect(r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= ATLAS_W and r[2] + r[4] <= ATLAS_H, `{key}: {s}-px rect off the atlas`)
					t.equal(r[3], s, `{key}: {s}-px rect width`)
				end
			end
			t.equal(#icon.tint, 3, key)
		end
		for _, key in { "supply", "power", "health" } do
			t.expect(UiIcons.icons[key] ~= nil, `{key} is used by the UI`)
		end
		for _, name in CommandSet.ORDER do
			t.expect(UiIcons.icons[name] ~= nil, `command {name} has an icon (the command cursor, C-263)`)
		end
		t.expect(ATLAS_W <= 1024 and ATLAS_H <= 1024, "the atlas fits a Roblox image")
		t.expect(UiIcons.image == "" or string.match(UiIcons.image, "^rbxassetid://%d+$") ~= nil, `image {UiIcons.image}`)
	end)

	t.test("the helper scales down from the next size up, never up when it can", function()
		t.equal(UiIcon.pick(11), 16)
		t.equal(UiIcon.pick(16), 16)
		t.equal(UiIcon.pick(20), 24)
		t.equal(UiIcon.pick(24), 24)
		t.equal(UiIcon.pick(40), 32)
		t.equal(UiIcon.ready(), UiIcons.image ~= "")
	end)
end
