--!strict
-- Breaker (Chaos coastal battery, T2, footprint 3; F18 redesign 2026-10-26,
-- the user's beta feedback: "turret should stand high, proud, tower above
-- others"): a lattice gun tower. A concrete slab with reactive blocks on its
-- sea face, four heavy legs with cross bracing round an ammo hoist trunk, a
-- railed deck at 17.6 studs with team plates and amber lamps, and on top a
-- rounded turret with one very long gun and a twin missile box (top ~24
-- studs). Chaos reads crude and brutal (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 22, 2, 18 }, at = { 0, 1, 1 }, color = "dark" },
	{ name = "trunk", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 15, 4.4 }, at = { 0, 9.5, 1 }, color = "hull" },
	{ name = "deck", parent = "base", shape = "box", size = { 14, 1.2, 14 }, at = { 0, 17.6, 1 }, color = "hull" },
	{ name = "deckTeamL", parent = "base", shape = "box", size = { 0.1, 0.8, 5 }, at = { -7.05, 17.6, 1 }, color = "team" },
	{ name = "deckTeamR", parent = "base", shape = "box", size = { 0.1, 0.8, 5 }, at = { 7.05, 17.6, 1 }, color = "team" },
	{ name = "railB", parent = "base", shape = "box", size = { 14, 0.3, 0.3 }, at = { 0, 19, 7.85 }, color = "dark" },
	{ name = "railL", parent = "base", shape = "box", size = { 0.3, 0.3, 14 }, at = { -6.85, 19, 1 }, color = "dark" },
	{ name = "railR", parent = "base", shape = "box", size = { 0.3, 0.3, 14 }, at = { 6.85, 19, 1 }, color = "dark" },
	{ name = "ladder", parent = "base", shape = "box", size = { 1, 15, 0.2 }, at = { 3, 9.5, 7.6 }, color = "metal" },
	{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { -7, 2.05, 6 }, color = "team" },
}
for i, x in { -6, 0, 6 } do -- reactive blocks on the sea face
	table.insert(parts, { name = `era{i}`, parent = "base", shape = "box", size = { 4, 1.6, 0.6 }, at = { x, 1.6, -8.2 }, color = "metal" })
end
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do -- legs, splayed a little
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `leg{tag}`, parent = "base", shape = "box", size = { 1.6, 15.8, 1.6 }, at = { sx * 5.6, 9.6, 1 + sz * 5.6 }, rot = { sz * 5, 0, -sx * 5 }, color = "metal" })
		table.insert(parts, { name = `lamp{tag}`, parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { sx * 6.6, 18.6, 1 + sz * 6.6 }, color = "glass" })
	end
	-- cross braces on the sides, the front and the back
	for tier, y in { 6.2, 13.2 } do -- two tiers of X bracing
		for _, d in { 1, -1 } do
			local tag = `{tier}{sx}{d}`
			table.insert(parts, { name = `braceSide{tag}`, parent = "base", shape = "box", size = { 0.5, 14.4, 0.5 }, at = { sx * 5.7, y, 1 }, rot = { 52 * d, 0, 0 }, color = "dark" })
			table.insert(parts, { name = `braceFB{tag}`, parent = "base", shape = "box", size = { 0.5, 14.4, 0.5 }, at = { 0, y, 1 + sx * 5.7 }, rot = { 0, 0, 52 * d }, color = "dark" })
		end
	end
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 8, 3.2, 8 }, at = { 0, 19.8, 1 }, pivot = { 0, 18.2, 1 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 4, 0.1, 3 }, at = { 0, 21.45, 2 }, color = "team" },
	{ name = "jacket", parent = "turret", shape = "cylinder", axis = "z", size = { 2.2, 2.2, 4 }, at = { 0, 20, -4.4 }, color = "dark" },
	{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 16 }, at = { 0, 20, -12 }, color = "metal" },
	{ name = "brake", parent = "turret", shape = "cylinder", axis = "z", size = { 2, 2, 1.2 }, at = { 0, 20, -19.6 }, color = "dark" },
	{ name = "missiles", parent = "turret", shape = "box", size = { 2.2, 1.8, 3.6 }, at = { 4.6, 20.6, 0 }, color = "dark" },
	{ name = "missileTubes", parent = "turret", shape = "box", size = { 1.6, 1.2, 0.1 }, at = { 4.6, 20.6, -1.85 }, color = "glass" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 1, 0.5, 0.1 }, at = { -2.4, 20.6, -2.1 }, color = "glass" },
	{ name = "lampMast", parent = "turret", shape = "box", size = { 0.3, 2, 0.3 }, at = { -2.4, 22.4, 3.4 }, color = "dark" },
	{ name = "lamp", parent = "turret", shape = "box", size = { 0.7, 0.5, 0.7 }, at = { -2.4, 23.5, 3.4 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_breaker",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 20, -20.3 } },
	},
}
