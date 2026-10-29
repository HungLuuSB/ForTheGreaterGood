--!strict
-- Accumulator (Chaos energy storage, T1, footprint 2; S-209, BAR corestor):
-- a squat stepped octagonal dome, orange charge wedges on its diagonal
-- faces between dark buttresses, a glowing charge cap, eight team-faced
-- armor blocks round its foot. Model space, forward = -Z
-- (docs/contracts/rig.md).

local parts: { any } = {
	{ name = "base", shape = "box", size = { 15.6, 0.5, 15.6 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "lower", parent = "base", shape = "cylinder", axis = "y", size = { 9.6, 3.1, 9.6 }, at = { 0, 2.05, 0 }, color = "hull" },
	{ name = "upper", parent = "base", shape = "cylinder", axis = "y", size = { 6.4, 2.6, 6.4 }, at = { 0, 4.9, 0 }, color = "hull" },
	{ name = "cap", parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 0.5, 3.6 }, at = { 0, 6.45, 0 }, color = "glass" },
}
for k = 0, 7 do
	local a = math.pi / 4 * k
	local dx, dz = math.sin(a), -math.cos(a)
	if k % 2 == 1 then
		table.insert(parts, { name = `wedge{k}`, parent = "base", shape = "box", size = { 1.6, 3.6, 0.3 }, at = { dx * 4.0, 3.2, dz * 4.0 }, rot = { 0, -math.deg(a), 0 }, color = "glass" })
	else
		table.insert(parts, { name = `buttress{k}`, parent = "base", shape = "box", size = { 2.8, 4.2, 1.6 }, at = { dx * 4.45, 2.6, dz * 4.45 }, rot = { 0, -math.deg(a), 0 }, color = "dark" })
	end
	local b = a + math.pi / 8
	local bx, bz = math.sin(b), -math.cos(b)
	table.insert(parts, { name = `block{k}`, parent = "base", shape = "box", size = { 2.5, 1.8, 2.0 }, at = { bx * 6.0, 1.4, bz * 6.0 }, rot = { 0, -math.deg(b), 0 }, color = "hull" })
	table.insert(parts, { name = `blockTeam{k}`, parent = "base", shape = "box", size = { 2.1, 1.4, 0.1 }, at = { bx * 7.02, 1.4, bz * 7.02 }, rot = { 0, -math.deg(b), 0 }, color = "team" })
end

return {
	id = "chs_accumulator",
	parts = parts,
}
