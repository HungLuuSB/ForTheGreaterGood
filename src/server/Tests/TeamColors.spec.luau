--!strict
-- Player colours by side (S-172): to each viewer, its side cold, enemies warm.
local TeamColors = require("@shared/Match/TeamColors")
local RunAll = require("./RunAll")

local COLD_HUES = { Blue = true, Cyan = true, Green = true, Navy = true, Teal = true, Sky = true, Mint = true, Forest = true }

return function(t: RunAll.Context)
	local function eightVsEight()
		local list = {}
		for i = 1, 16 do
			table.insert(list, { id = i, allyTeam = if i <= 8 then 1 else 2 })
		end
		return list
	end

	t.test("8v8: the viewer blue, its allies the other cold shades, all eight enemies warm, all distinct", function()
		local players = eightVsEight()
		for _, viewer in { 1, 5, 12 } do
			local colors = TeamColors.forViewer(viewer, players)
			t.equal(colors[viewer].name, "Blue", `the viewer ({viewer}) is blue`)
			local seen = {}
			local mySide = if viewer <= 8 then 1 else 2
			for _, p in players do
				local col = colors[p.id]
				t.expect(col ~= nil, `player {p.id} has a colour`)
				t.expect(not seen[col.name], `{col.name} used once`)
				seen[col.name] = true
				t.equal(COLD_HUES[col.name] == true, p.allyTeam == mySide, `player {p.id}: cold if an ally, warm if an enemy`)
			end
		end
	end)

	t.test("a 16-player FFA: the viewer cold, fifteen warm enemies, all distinct; spectators see side 1 cold", function()
		local players = {}
		for i = 1, 16 do
			table.insert(players, { id = i, allyTeam = i })
		end
		local colors = TeamColors.forViewer(7, players)
		local seen, warm = {}, 0
		for _, p in players do
			local col = colors[p.id]
			t.expect(not seen[col.name], `{col.name} once`)
			seen[col.name] = true
			if not COLD_HUES[col.name] then
				warm += 1
			end
		end
		t.equal(warm, 15)
		local spectator = TeamColors.forViewer(0, eightVsEight())
		t.expect(COLD_HUES[spectator[1].name] and not COLD_HUES[spectator[9].name], "a spectator: side 1 cold, side 2 warm")
	end)

	t.test("players keep the same colour to a viewer whatever order they're listed in", function()
		local a = eightVsEight()
		local b = table.clone(a)
		table.sort(b, function(x, y)
			return x.id > y.id
		end)
		local ca, cb = TeamColors.forViewer(3, a), TeamColors.forViewer(3, b)
		for i = 1, 16 do
			t.equal(ca[i].name, cb[i].name)
		end
	end)
end
