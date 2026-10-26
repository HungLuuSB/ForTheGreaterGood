--!strict
-- Spawn boxes on the room's map (F26, L-20): one box per team in that
-- team's colour (as you see it), labelled with the team. The host drags a
-- side to resize a box or its inside to move it; sides snap to the map's
-- edge (SpawnBoxes.SNAP). The box is sent when the drag ends; while it's
-- held, views from the server don't move it.

local UserInputService = game:GetService("UserInputService")

local SpawnBoxes = require("../shared/SpawnBoxes")
local Ui = require("./Ui")

local Kit = Ui.Kit

local BoxEditor = {}

local EDGE = 10 -- px: a side's grab strip

export type Team = { team: number, box: { number }, color: Color3 }
export type BoxEditor = {
	set: (teams: { Team }, editable: boolean) -> (),
	dragging: () -> boolean,
}

-- `image` is the map's ImageLabel (fractions of it are fractions of the
-- map); `commit(team, box)` sends a finished drag.
function BoxEditor.new(image: GuiObject, commit: (team: number, box: { number }) -> ()): BoxEditor
	local layer = Instance.new("Frame")
	layer.Name = "SpawnBoxes"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 5
	layer.Parent = image

	-- the drag in progress: which team, which part, where it started
	local held: { team: number, part: string, start: { number }, from: Vector2, frame: Frame }? = nil

	local function place(frame: Frame, b: { number })
		frame.Position = UDim2.fromScale(b[1], b[2])
		frame.Size = UDim2.fromScale(b[3] - b[1], b[4] - b[2])
	end

	-- the box under the drag: `part` "move" or a side ("x0", "z0", "x1", "z1")
	local function dragged(start: { number }, part: string, du: number, dv: number): { number }
		local b = table.clone(start)
		local min = SpawnBoxes.MIN
		if part == "move" then
			local w, d = b[3] - b[1], b[4] - b[2]
			local x0 = SpawnBoxes.snap(math.clamp(b[1] + du, 0, 1 - w))
			local z0 = SpawnBoxes.snap(math.clamp(b[2] + dv, 0, 1 - d))
			-- the far side snaps too: whichever side is near an edge wins
			if SpawnBoxes.snap(x0 + w) == 1 then
				x0 = 1 - w
			end
			if SpawnBoxes.snap(z0 + d) == 1 then
				z0 = 1 - d
			end
			return { x0, z0, x0 + w, z0 + d }
		elseif part == "x0" then
			b[1] = SpawnBoxes.snap(math.clamp(b[1] + du, 0, b[3] - min))
		elseif part == "x1" then
			b[3] = SpawnBoxes.snap(math.clamp(b[3] + du, b[1] + min, 1))
		elseif part == "z0" then
			b[2] = SpawnBoxes.snap(math.clamp(b[2] + dv, 0, b[4] - min))
		elseif part == "z1" then
			b[4] = SpawnBoxes.snap(math.clamp(b[4] + dv, b[2] + min, 1))
		end
		return b
	end

	local function grab(frame: Frame, team: number, box: { number }, part: string, hit: GuiObject)
		hit.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			held = { team = team, part = part, start = box, from = Vector2.new(input.Position.X, input.Position.Y), frame = frame }
		end)
	end

	UserInputService.InputChanged:Connect(function(input: InputObject)
		local h = held
		if h == nil or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end
		local size = image.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - h.from
		place(h.frame, dragged(h.start, h.part, delta.X / size.X, delta.Y / size.Y))
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		local h = held
		if h == nil or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end
		held = nil
		local p, s = h.frame.Position, h.frame.Size
		local b = { p.X.Scale, p.Y.Scale, p.X.Scale + s.X.Scale, p.Y.Scale + s.Y.Scale }
		local changed = false
		for i = 1, 4 do
			if math.abs(b[i] - h.start[i]) > 1e-4 then
				changed = true
			end
		end
		if changed then
			commit(h.team, b)
		end
	end)

	local function strip(frame: Frame, name: string, pos: UDim2, size: UDim2): TextButton
		local s = Instance.new("TextButton")
		s.Name = name
		s.Text = ""
		s.AutoButtonColor = false
		s.BackgroundTransparency = 1
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = pos
		s.Size = size
		s.ZIndex = 8
		s.Parent = frame
		return s
	end

	return {
		dragging = function(): boolean
			return held ~= nil
		end,
		set = function(teams: { Team }, editable: boolean)
			if held then
				return -- a drag is in progress: the next view redraws
			end
			Ui.clear(layer)
			for _, t in teams do
				local f = Instance.new("Frame")
				f.Name = `Team{t.team}`
				f.BackgroundColor3 = t.color
				f.BackgroundTransparency = 0.72
				f.BorderSizePixel = 0
				f.ZIndex = 6
				f.Parent = layer
				place(f, t.box)
				Ui.stroke(f, 0.1, t.color)
				local st = f:FindFirstChildOfClass("UIStroke")
				if st then
					st.Thickness = 2
				end
				local label = Kit.text(f, tostring(t.team), "small", Color3.new(1, 1, 1))
				label.Size = UDim2.fromOffset(18, 16)
				label.Position = UDim2.fromOffset(3, 1)
				label.FontFace = Kit.font(Enum.FontWeight.Bold)
				label.ZIndex = 7
				if editable then
					local body = Instance.new("TextButton")
					body.Name = "Move"
					body.Text = ""
					body.AutoButtonColor = false
					body.BackgroundTransparency = 1
					body.Size = UDim2.fromScale(1, 1)
					body.ZIndex = 7
					body.Parent = f
					grab(f, t.team, t.box, "move", body)
					grab(f, t.team, t.box, "x0", strip(f, "West", UDim2.fromScale(0, 0.5), UDim2.new(0, EDGE, 1, 0)))
					grab(f, t.team, t.box, "x1", strip(f, "East", UDim2.fromScale(1, 0.5), UDim2.new(0, EDGE, 1, 0)))
					grab(f, t.team, t.box, "z0", strip(f, "North", UDim2.fromScale(0.5, 0), UDim2.new(1, 0, 0, EDGE)))
					grab(f, t.team, t.box, "z1", strip(f, "South", UDim2.fromScale(0.5, 1), UDim2.new(1, 0, 0, EDGE)))
				end
			end
		end,
	}
end

return BoxEditor
