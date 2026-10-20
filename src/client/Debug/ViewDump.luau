--!strict
-- Top-down dump of what the client draws (Studio debugging, C-10): every
-- BasePart under workspace.Units and workspace.Effects as an oriented
-- footprint, for `lune run render_view` to turn into a PNG when Studio's own
-- screenshots can't show the 3D view.
--
-- Format, one record per line:
--   M originX originZ sizeX sizeZ
--   P cx cz top ax az ha bx bz hb r g b    (axes a, b: unit XZ vectors; ha, hb: half extents)

local function axes(part: BasePart): (Vector3, number, Vector3, number, number)
	local cf, size = part.CFrame, part.Size
	local list = {
		{ cf.RightVector, size.X / 2 },
		{ cf.UpVector, size.Y / 2 },
		{ -cf.LookVector, size.Z / 2 },
	}
	-- the most vertical axis is the height; the other two span the footprint
	table.sort(list, function(p, q)
		return math.abs(p[1].Y) > math.abs(q[1].Y)
	end)
	local up = list[1]
	local top = cf.Position.Y + math.abs(up[1].Y) * up[2]
	return list[2][1], list[2][2], list[3][1], list[3][2], top
end

return function(grid: any): string
	local out = { string.format("M %.2f %.2f %.2f %.2f", grid.originX, grid.originZ, grid.sizeX, grid.sizeZ) }
	for _, folderName in { "Units", "Effects" } do
		local folder = workspace:FindFirstChild(folderName)
		if folder == nil then
			continue
		end
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				local a, ha, b, hb, top = axes(d)
				local la = Vector2.new(a.X, a.Z)
				local lb = Vector2.new(b.X, b.Z)
				-- tilted axes shrink when projected
				ha *= la.Magnitude
				hb *= lb.Magnitude
				la = if la.Magnitude > 1e-6 then la.Unit else Vector2.new(1, 0)
				lb = if lb.Magnitude > 1e-6 then lb.Unit else Vector2.new(0, 1)
				local c = d.Color
				table.insert(
					out,
					string.format(
						"P %.2f %.2f %.2f %.3f %.3f %.2f %.3f %.3f %.2f %d %d %d",
						d.Position.X,
						d.Position.Z,
						top,
						la.X,
						la.Y,
						ha,
						lb.X,
						lb.Y,
						hb,
						c.R * 255,
						c.G * 255,
						c.B * 255
					)
				)
			end
		end
	end
	return table.concat(out, "\n")
end
