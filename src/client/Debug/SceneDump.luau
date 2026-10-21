--!strict
-- Compact dump of what the client draws (Studio debugging, C-10), for
-- `lune run render_scene` to turn into a top-down PNG when Studio's own
-- screenshots can't show the 3D view. Read from the live Instances:
--   M originX originZ sizeX sizeZ                 map
--   U defId r,g,b x z heading yaw pitch           a unit model: team color, root, turret and barrel joints
--   D x z diameter r g b alpha                    a disc under the units (selection ring, order dot)
--   E x z diameter r g b alpha                    an effect disc over the units (shell, flash)
--   L x1 z1 x2 z2 width r g b                     a line (order path, tracer)
--   A x z r a0 a1 kind                            a range-ring arc (Render/RangeOverlay)

local function rgb(c: Color3): string
	return string.format("%d %d %d", c.R * 255, c.G * 255, c.B * 255)
end

local function jointAngles(model: Model, piece: string): (number, number)
	local part = model:FindFirstChild(piece)
	local motor = part and part:FindFirstChildOfClass("Motor6D")
	if motor == nil then
		return 0, 0
	end
	local rx, ry = motor.Transform:ToOrientation()
	return ry, rx
end

return function(grid: any, arcs: { any }?): string
	local out = { string.format("M %.0f %.0f %.0f %.0f", grid.originX, grid.originZ, grid.sizeX, grid.sizeZ) }
	local units = workspace:FindFirstChild("Units")
	for _, model in (if units then units:GetChildren() else {}) do
		if not model:IsA("Model") or model.PrimaryPart == nil then
			continue
		end
		local offset = model:GetAttribute("RootOffset") :: CFrame? or CFrame.identity
		local unit = (model.PrimaryPart :: BasePart).CFrame * offset:Inverse()
		-- placed with Angles(0, heading + π, 0): the look vector is (sin h, cos h)
		local look = unit.LookVector
		local heading = math.atan2(look.X, look.Z)
		local yaw = jointAngles(model, "turret")
		local _, pitch = jointAngles(model, "barrel")
		-- the team color as the model shows it (r,g,b)
		local teamColor = Color3.new(1, 1, 1)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:HasTag("TeamColor") then
				teamColor = d.Color
				break
			end
		end
		local color = (string.gsub(rgb(teamColor), " ", ","))
		table.insert(out, string.format("U %s %s %.1f %.1f %.2f %.2f %.2f", model:GetAttribute("DefId") or model.Name, color, unit.Position.X, unit.Position.Z, heading, yaw, pitch))
	end
	local parts = {}
	for _, folderName in { "Ranges", "Overlay", "Effects" } do
		local folder = workspace:FindFirstChild(folderName)
		for _, p in (if folder then folder:GetChildren() else {}) do
			if p:IsA("BasePart") and p.Transparency < 0.98 then
				table.insert(parts, { p, folderName == "Effects" })
			end
		end
	end
	for _, entry in parts do
		local p, effect = entry[1], entry[2]
		local pos = p.Position
		local trail = p:GetAttribute("TrailLength") :: number?
		if p.Name == "Projectile" and trail and trail > 0 then
			-- the shell's trail: a fading line behind it
			local back = pos - p.CFrame.LookVector * trail
			table.insert(out, string.format("T %.1f %.1f %.1f %.1f %.2f %s", back.X, back.Z, pos.X, pos.Z, p.Size.X, rgb(p.Color)))
		end
		if p.Name == "RangeSegment" and arcs then
			continue -- the arcs below describe them exactly, in far fewer lines
		end
		if p.Name == "line" or p.Name == "Tracer" or p.Name == "RangeSegment" then
			local half = p.CFrame.LookVector * p.Size.Z / 2
			local a, b = pos - half, pos + half
			table.insert(out, string.format("L %.1f %.1f %.1f %.1f %.2f %s", a.X, a.Z, b.X, b.Z, p.Size.X, rgb(p.Color)))
		else
			local d = if p.Name == "Projectile" then 1.4 else p.Size.Y
			table.insert(out, string.format("%s %.1f %.1f %.1f %s %.2f", if effect then "E" else "D", pos.X, pos.Z, d, rgb(p.Color), 1 - p.Transparency))
		end
	end
	for _, a in arcs or {} do
		table.insert(out, string.format("A %.1f %.1f %.1f %.4f %.4f %s", a.x, a.z, a.r, a.a0, a.a1, a.kind))
	end
	return table.concat(out, "\n")
end
