--!strict
-- Thorn (Chaos IR SAM site, T1, footprint 1): a light base and post with a
-- launcher of six bare canister tubes on an open frame (three either side
-- of an orange sensor), team plate on the launcher. The def turns
-- `launcher`, on the post's axis (M-3). Model space, forward = -Z
-- (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 5.4, 0.8, 5.4 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 2.2, 1.2 }, at = { 0, 1.9, 0 }, color = "hull" },
	{ name = "launcher", parent = "base", shape = "box", size = { 1.2, 1, 1.4 }, at = { 0, 3.5, 0 }, pivot = { 0, 3.0, 0 }, color = "hull" },
	{ name = "sensor", parent = "launcher", shape = "box", size = { 0.7, 0.4, 0.1 }, at = { 0, 3.6, -0.75 }, color = "glass" },
	{ name = "frame", parent = "launcher", shape = "box", size = { 4.6, 0.2, 0.2 }, at = { 0, 3.5, 0.4 }, color = "dark" },
	{ name = "team", parent = "launcher", shape = "box", size = { 1, 0.08, 1.2 }, at = { 0, 4.04, 0 }, color = "team" },
}
for i, x in { -2.2, -1.7, -1.2, 1.2, 1.7, 2.2 } do
	local y = if i % 2 == 0 then 3.75 else 3.3
	table.insert(parts, { name = `tube{i}`, parent = "launcher", shape = "cylinder", axis = "z", size = { 0.42, 0.42, 3 }, at = { x, y, -0.2 }, color = "metal" })
end

return {
	id = "chs_thorn",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -2.2, 3.3, -1.75 } },
	},
}
