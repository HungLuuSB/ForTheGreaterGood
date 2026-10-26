--!strict
-- Blockout data (C-6): hand-made ones and the generic fallback are valid for
-- every unit def, and the checks catch broken ones.

local Blockout = require("@shared/Defs/Blockouts/Blockout")
local Registry = require("@shared/Defs/Blockouts/Registry")
local Defs = require("@shared/Defs/Defs")

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
	t.test("every hand-made blockout matches a def and is valid", function()
		local n = 0
		for id, bp in Registry :: any do
			n += 1
			local def = defById(id)
			t.expect(def ~= nil, `{id}: no unit def`)
			t.deepEqual(Blockout.validate(bp, def), {}, id)
		end
		t.expect(n >= 2, "Lancer and Ravager are registered")
		t.expect((Registry :: any).ord_lancer ~= nil and (Registry :: any).chs_ravager ~= nil)
	end)

	t.test("every unit def gets a valid blockout (generic when not hand-made)", function()
		local generic = 0
		for _, def in defs.unitByIndex do
			local bp, handMade = Blockout.forDef(def)
			if not handMade then
				generic += 1
			end
			t.deepEqual(Blockout.validate(bp, def), {}, def.id)
		end
		local handMade = 0
		for _ in Registry :: any do
			handMade += 1
		end
		t.expect(generic == #defs.unitByIndex - handMade, "all but the hand-made ones are generic")
	end)

	t.test("muzzles are attachments, other pieces are parts", function()
		t.expect(Blockout.isAttachmentPiece("muzzle"))
		t.expect(Blockout.isAttachmentPiece("muzzle3"))
		t.expect(Blockout.isAttachmentPiece("laser_muzzle2"))
		t.expect(Blockout.isAttachmentPiece("laser_l_muzzle")) -- the Dragon's (S-181)
		t.expect(not Blockout.isAttachmentPiece("arm_l"))
		t.expect(not Blockout.isAttachmentPiece("muzzleBrake"))
		t.expect(not Blockout.isAttachmentPiece("laser_drum"))
		t.expect(not Blockout.isAttachmentPiece("turret"))
	end)

	t.test("the hand-made tanks keep the turret above the hull and the muzzle in front", function()
		for _, id in { "ord_lancer", "chs_ravager" } do
			local bp = (Registry :: any)[id]
			local at: { [string]: { number } } = {}
			for _, p in bp.parts do
				at[p.name] = p.at
			end
			t.expect(at.turret[2] > at.base[2], `{id}: turret above the hull`)
			local muzzle = bp.attachments[1]
			t.equal(muzzle.name, "muzzle")
			t.expect(muzzle.at[3] < at.turret[3] - 3, `{id}: muzzle well in front of the turret (forward = -Z)`)
		end
	end)

	t.test("validate reports broken blockouts", function()
		local def = defById("ord_lancer")
		local function problems(bp: any): string
			return table.concat(Blockout.validate(bp, def), "\n")
		end
		local ok = (Registry :: any).ord_lancer
		local function with(edit: (any) -> ()): any
			local copy = { id = ok.id, parts = {}, attachments = {} }
			for i, p in ok.parts do
				copy.parts[i] = table.clone(p)
			end
			for i, a in ok.attachments do
				copy.attachments[i] = table.clone(a)
			end
			edit(copy)
			return copy
		end
		t.expect(string.find(problems(with(function(bp)
			table.remove(bp.attachments, 1)
		end)), "def piece muzzle must be an attachment", 1, true))
		t.expect(string.find(problems(with(function(bp)
			bp.parts[2].parent = "nope"
		end)), "parent nope must be an earlier part", 1, true))
		t.expect(string.find(problems(with(function(bp)
			bp.parts[1].size = { 1, 0, 1 }
		end)), "size must be three positive numbers", 1, true))
		t.expect(string.find(problems(with(function(bp)
			bp.parts[2].color = "pink"
		end)), "unknown color pink", 1, true))
		t.expect(string.find(problems(with(function(bp)
			bp.parts[3].parent = "glacis"
		end)), "is a decoration, not a piece", 1, true))
		t.expect(string.find(problems(with(function(bp)
			bp.parts[2].pivot = { 0, 0, 0 }
		end)), "only pieces have a pivot", 1, true))
		t.expect(string.find(problems(with(function(bp)
			bp.id = "chs_ravager"
		end)), "id doesn't match", 1, true))
	end)
end
