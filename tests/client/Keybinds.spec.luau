--!strict
-- Rebindable keys (C-159): defaults are distinct and bindable, reserved keys
-- are refused, a shared key shows as a conflict on both actions, and saving
-- keeps only what changed and reads back the same bindings.

local Keybinds = require("../../src/client/Core/Keybinds")

return function(t: any)
	t.test("defaults: one key each, none reserved, no conflicts", function()
		local b = Keybinds.defaults()
		local seen = {}
		for _, a in Keybinds.ACTIONS do
			t.expect(not Keybinds.RESERVED[a.default], `{a.id}: {a.default} isn't reserved`)
			t.expect(seen[a.default] == nil, `{a.id}: {a.default} also {seen[a.default]}`)
			seen[a.default] = a.id
		end
		t.expect(next(Keybinds.conflicts(b)) == nil, "no conflicts by default")
		t.equal(b.reclaim, "E")
		t.equal(b.rotateRight, "C", "the camera no longer shares E with reclaim")
	end)

	t.test("rebinding: reserved keys refused, shared keys flagged on both", function()
		local b = Keybinds.defaults()
		t.expect(not Keybinds.set(b, "stop", "One"), "digits are the groups'")
		t.expect(not Keybinds.set(b, "stop", "LeftShift"), "modifiers can't be bound")
		t.expect(not Keybinds.set(b, "nonsense", "H"), "unknown action")
		t.equal(b.stop, "S")
		t.expect(Keybinds.set(b, "stop", "A"))
		local c = Keybinds.conflicts(b)
		t.equal(c.stop and c.stop[1], "attack")
		t.equal(c.attack and c.attack[1], "stop")
		t.expect(Keybinds.set(b, "stop", "H"))
		t.expect(next(Keybinds.conflicts(b)) == nil, "resolved")
	end)

	t.test("saving keeps only changes and reads back the same", function()
		local b = Keybinds.defaults()
		t.equal(Keybinds.encode(b), "", "nothing changed, nothing saved")
		Keybinds.set(b, "stop", "H")
		Keybinds.set(b, "idle", "F6")
		local text = Keybinds.encode(b)
		t.equal(text, "stop=H;idle=F6")
		local back = Keybinds.decode(text)
		for _, a in Keybinds.ACTIONS do
			t.equal(back[a.id], b[a.id], a.id)
		end
		local junk = Keybinds.decode("stop=One;bogus=K;move=W;;x")
		t.equal(junk.stop, "S", "a reserved key in a save is skipped")
		t.equal(junk.move, "W")
	end)
end
