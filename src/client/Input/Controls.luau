--!strict
-- Mouse and keyboard for selection and orders (guide 15.6), through the
-- client API (Api.actions):
--   left click / drag        select one / box select (Shift adds, Ctrl toggles)
--   double click             all own units of that type on screen
--   right click              smart order (enemy attack, own guard / repair, ground move)
--   right drag               line move along the drag
--   Shift + right click      queue the order
--   Ctrl + 1..9 / 1..9       set / recall a control group (double tap: jump the camera)
--   X                        stop
-- While placing a structure (build ghost, guide 15.6):
--   left click / drag        place / a row (Shift: queue it and keep placing)
--   R                        rotate
--   right click, Esc         cancel
--   B                        placeholder build menu: the selected builder's next build option
-- Bindings are first guesses: listed under "Needs my review".

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Api = require("../Api")
local Selection = require("../Core/Selection")
local World = require("../Core/World")

local Controls = {}

Controls.DRAG_PIXELS = 5 -- left drag beyond this is a box
Controls.LINE_PIXELS = 12 -- right drag beyond this is a line move
Controls.DOUBLE_CLICK = 0.35 -- seconds
Controls.STOP_KEY = Enum.KeyCode.X
Controls.ROTATE_KEY = Enum.KeyCode.R
Controls.BUILD_KEY = Enum.KeyCode.B -- placeholder until the build menu (UI)

local DIGITS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

export type Controls = {
	boxFrame: Frame,
	placeFrom: Vector3?, -- left-drag start on the ground while placing (row preview)
	lineFrom: Vector3?, -- right-drag start on the ground, while dragging
	lineTo: Vector3?,
}

local function shift(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function ctrl(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

-- Ground point under a viewport pixel: a raycast against workspace.Map,
-- else the plane at the map's base height.
function Controls.groundAt(cam: Camera, px: number, py: number): Vector3?
	local ray = cam:ViewportPointToRay(px, py)
	local map = workspace:FindFirstChild("Map")
	if map then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { map }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
		if hit then
			return hit.Position
		end
	end
	if ray.Direction.Y < -1e-4 then
		local t = (10 - ray.Origin.Y) / ray.Direction.Y
		return ray.Origin + ray.Direction * t
	end
	return nil
end

-- Ground point under the mouse (for the build ghost), or nil.
function Controls.hover(): Vector3?
	local mouse = UserInputService:GetMouseLocation()
	return Controls.groundAt(workspace.CurrentCamera, mouse.X, mouse.Y)
end

function Controls.projector(cam: Camera): Selection.Projector
	return function(x: number, y: number, z: number)
		local v, onScreen = cam:WorldToViewportPoint(Vector3.new(x, y, z))
		return v.X, v.Y, onScreen and v.Z > 0
	end
end

function Controls.bind(api: Api.Api): Controls
	local gui = Instance.new("ScreenGui")
	gui.Name = "SelectionBox"
	gui.IgnoreGuiInset = true -- same pixel space as the viewport and the mouse
	gui.ResetOnSpawn = false
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.BackgroundColor3 = Color3.fromRGB(120, 230, 120)
	box.BackgroundTransparency = 0.85
	box.BorderSizePixel = 0
	box.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 230, 120)
	stroke.Thickness = 1
	stroke.Parent = box
	box.Parent = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local self: Controls = { boxFrame = box, placeFrom = nil, lineFrom = nil, lineTo = nil }
	local leftStart: Vector2? = nil
	local boxing = false
	local rightStart: Vector2? = nil
	local lastClick = { time = -math.huge, defIndex = -1 }
	local lastGroup = { n = 0, time = -math.huge }
	local world = api.world

	local function cam(): Camera
		return workspace.CurrentCamera
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not world.joined then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local placing = api.state.placement ~= nil
		if placing and input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.placeFrom = Controls.groundAt(cam(), mouse.X, mouse.Y)
			leftStart, boxing = mouse, false
			return
		elseif placing and (input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape) then
			api.actions.cancelPlacement()
			return
		elseif placing and input.KeyCode == Controls.ROTATE_KEY then
			api.actions.rotatePlacement()
			return
		end
		if input.KeyCode == Controls.BUILD_KEY then
			-- next build option of the first selected builder (placeholder)
			for _, id in api.state.selection do
				local u = world.units[id]
				local def = u and World.def(world, u)
				local options = def and def.buildOptions
				if options and #options > 0 then
					local current = if api.state.placement then table.find(options, api.state.placement.defId) else nil
					for k = 1, #options do
						local pick = options[((current or 0) + k - 1) % #options + 1]
						if api.actions.beginPlacement(pick) then
							break
						end
					end
					break
				end
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			leftStart, boxing = mouse, false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightStart = mouse
			self.lineFrom = Controls.groundAt(cam(), mouse.X, mouse.Y)
			self.lineTo = nil
		elseif input.KeyCode == Controls.STOP_KEY then
			api.actions.stop()
		elseif DIGITS[input.KeyCode] then
			local n = DIGITS[input.KeyCode]
			if ctrl() then
				api.actions.setGroup(n)
			else
				api.actions.recallGroup(n, shift())
				local now = os.clock()
				if lastGroup.n == n and now - lastGroup.time <= Controls.DOUBLE_CLICK then
					local x, z = Selection.center(world, api.state.selection)
					if x then
						api.actions.focusCamera(x, z :: number)
					end
				end
				lastGroup.n, lastGroup.time = n, now
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		if self.placeFrom then
			return -- placing: no selection box
		end
		if leftStart and (boxing or (mouse - leftStart).Magnitude > Controls.DRAG_PIXELS) then
			boxing = true
			local a, b = leftStart :: Vector2, mouse
			box.Position = UDim2.fromOffset(math.min(a.X, b.X), math.min(a.Y, b.Y))
			box.Size = UDim2.fromOffset(math.abs(a.X - b.X), math.abs(a.Y - b.Y))
			box.Visible = true
		end
		if rightStart and (mouse - rightStart).Magnitude > Controls.LINE_PIXELS then
			self.lineTo = Controls.groundAt(cam(), mouse.X, mouse.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local mouse = UserInputService:GetMouseLocation()
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.placeFrom then
			local from = self.placeFrom :: Vector3
			local to = Controls.groundAt(cam(), mouse.X, mouse.Y)
			local dragged = leftStart and (mouse - leftStart).Magnitude > Controls.DRAG_PIXELS
			if to and dragged then
				api.actions.placeRow(from.X, from.Z, to.X, to.Z, shift(), shift())
			elseif to then
				api.actions.place(to.X, to.Z, shift(), shift())
			end
			self.placeFrom, leftStart = nil, nil
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and leftStart then
			local project = Controls.projector(cam())
			local mode = if shift() then "add" elseif ctrl() then "toggle" else "replace"
			if boxing then
				local a = leftStart :: Vector2
				api.actions.select(Selection.inBox(world, project, a.X, a.Y, mouse.X, mouse.Y), mode)
			else
				local id = Selection.pick(world, project, mouse.X, mouse.Y)
				local u = if id then world.units[id] else nil
				if u and u.team == world.me.team then
					local now = os.clock()
					if u.defIndex and u.defIndex == lastClick.defIndex and now - lastClick.time <= Controls.DOUBLE_CLICK then
						local view = cam().ViewportSize
						api.actions.select(Selection.sameTypeOnScreen(world, project, u.defIndex, view.X, view.Y), mode)
					else
						api.actions.select({ id :: number }, mode)
					end
					lastClick.time, lastClick.defIndex = now, u.defIndex or -1
				elseif mode == "replace" then
					api.actions.select({})
				end
			end
			leftStart, boxing = nil, false
			box.Visible = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and rightStart then
			local from, to = self.lineFrom, self.lineTo
			if from and to then
				api.actions.lineMove(from.X, from.Z, to.X, to.Z, shift())
			else
				local ground = Controls.groundAt(cam(), mouse.X, mouse.Y)
				local id = Selection.pick(world, Controls.projector(cam()), mouse.X, mouse.Y)
				if ground or id then
					local p = ground or Vector3.zero
					api.actions.smartOrder(p.X, p.Z, id, shift())
				end
			end
			rightStart, self.lineFrom, self.lineTo = nil, nil, nil
		end
	end)

	return self
end

return Controls
