--!strict
-- Compact dump of what the client draws (Studio debugging, C-10), for
-- `lune run render_scene` to turn into a top-down PNG when Studio's own
-- screenshots can't show the 3D view. Read from the live Instances:
--   M originX originZ sizeX sizeZ                 map
--   U defId r,g,b x z heading yaw pitch           a unit model: team color, root, turret and barrel joints
--   D x z diameter r g b alpha                    a disc (selection ring, order dot, flash, effect)
--   L x1 z1 x2 z2 width r g b                     a line (order path, tracer)

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

return function(grid: any): string
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
	local overlay = workspace:FindFirstChild("Overlay")
	for _, p in (if overlay then overlay:GetChildren() else {}) do
		if not p:IsA("BasePart") then
			continue
		end
		local pos = p.Position
		if p.Name == "line" then
			local half = p.CFrame.LookVector * p.Size.Z / 2
			local a, b = pos - half, pos + half
			table.insert(out, string.format("L %.1f %.1f %.1f %.1f %.2f %s", a.X, a.Z, b.X, b.Z, p.Size.X, rgb(p.Color)))
		else
			table.insert(out, string.format("D %.1f %.1f %.1f %s %.2f", pos.X, pos.Z, p.Size.Y, rgb(p.Color), 1 - p.Transparency))
		end
	end
	return table.concat(out, "\n")
end
