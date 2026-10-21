--!strict
-- Mouse and keyboard for selection and orders (guide 15.6), through the
-- client API (Api.actions):
--   left click / drag        select one / box select (Shift adds, Ctrl toggles)
--   double click             all own units of that type on screen
--   right click              smart order (enemy attack, own guard / repair, ground move)
--   right drag               line move along the drag
--   Shift + right click      queue the order
--   Ctrl + 1..9 / 1..9       set / recall a control group (double tap: jump the camera)
--   S                        stop (BAR style; the camera pans with the arrow keys)
--   A / F / M / Z / G, then left click: attack (an enemy unit, or the ground:
--                            how a nuke silo fires, C-57) / fight / move / patrol to the
--                            point / guard a unit (C-68, Api.commandAt); Shift keeps the
--                            command; right click cancels
--   L / K                    cycle fire state / move state (C-68)
--   Y / U / X                factory repeat / on-off / cancel (a factory's last queued
--                            item, else an unfinished frame) (C-68)
--   J                        jump to the last alert (C-68)
--   V                        range rings on / off (Render/RangeOverlay)
--   T                        camera follow on / off (Core/Follow, C-43; handled in Main)
-- While placing a structure (build ghost, guide 15.6):
--   left click / drag        place / a row (Shift: queue it and keep placing)
--   R                        rotate
--   right click              cancel (Esc is Roblox's menu key: it never reaches the game)
--   B                        build menu (UI/BuildMenu, C-68): open / next tab; 1..0 pick
--                            while it is open (the menu takes those keys first)
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
Controls.STOP_KEY = Enum.KeyCode.S
Controls.ROTATE_KEY = Enum.KeyCode.R
-- command modes (C-68): the next left click gives the command
Controls.COMMAND_KEYS = {
	[Enum.KeyCode.A] = "attack",
	[Enum.KeyCode.F] = "fight",
	[Enum.KeyCode.M] = "move",
	[Enum.KeyCode.Z] = "patrol",
	[Enum.KeyCode.G] = "guard",
}
Controls.FIRE_STATE_KEY = Enum.KeyCode.L
Controls.MOVE_STATE_KEY = Enum.KeyCode.K
Controls.REPEAT_KEY = Enum.KeyCode.Y
Controls.TOGGLE_KEY = Enum.KeyCode.U
Controls.CANCEL_KEY = Enum.KeyCode.X
Controls.ALERT_KEY = Enum.KeyCode.J
-- a UI that takes keys first (the build menu while open): true = consumed
Controls.capture = nil :: ((InputObject) -> boolean)?
Controls.HINT = {
	attack = "ATTACK: left-click an enemy or the ground",
	fight = "FIGHT: left-click where to fight to",
	move = "MOVE: left-click where to go",
	patrol = "PATROL: left-click the far end of the patrol",
	guard = "GUARD: left-click a unit to guard",
}

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
	attacking: boolean, -- attack mode (A): the next left click attacks (C-57)
}

local function shift(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function ctrl(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

-- Ground point under a viewport pixel: a raycast against the drawn ground
-- (workspace.Map parts and the Terrain, its water surface included), else
-- the plane at the map's base height.
function Controls.groundAt(cam: Camera, px: number, py: number): Vector3?
	local ray = cam:ViewportPointToRay(px, py)
	local map = workspace:FindFirstChild("Map")
	if map then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { map, workspace.Terrain }
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

-- The unit whose model is under a viewport pixel, if any (set by Main:
-- raycasts the drawn unit models, C-38). Clicks try it first, then the
-- unit whose projected position is nearest (Selection.pick).
Controls.pickModel = nil :: ((number, number) -> number?)?

local function pickAt(world: any, project: any, x: number, y: number): number?
	local hit = if Controls.pickModel then Controls.pickModel(x, y) else nil
	return hit or Selection.pick(world, project, x, y)
end

-- The unit under the mouse, any team (the unit panel shows a hovered enemy, C-76).
function Controls.hoverUnit(world: any): number?
	local cam = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local inset = game:GetService("GuiService"):GetGuiInset()
	local gui = (game:GetService("Players").LocalPlayer :: any).PlayerGui
	for _, o in gui:GetGuiObjectsAtPosition(mouse.X, mouse.Y - inset.Y) do
		-- over a UI panel (the icon layer and see-through labels don't count)
		if not o:IsDescendantOf(gui.Icons) and o.BackgroundTransparency < 1 then
			return nil
		end
	end
	return pickAt(world, Controls.projector(cam), mouse.X, mouse.Y)
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
	-- attack mode's hint (A): the next left click attacks
	local hint = Instance.new("TextLabel")
	hint.Name = "AttackHint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0, 180)
	hint.Size = UDim2.fromOffset(520, 24)
	hint.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	hint.BackgroundTransparency = 0.25
	hint.BorderSizePixel = 0
	hint.Font = Enum.Font.Code
	hint.TextSize = 15
	hint.TextColor3 = Color3.fromRGB(255, 120, 100)
	hint.Text = ""
	hint.Visible = false
	hint.Parent = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local self: Controls = { boxFrame = box, placeFrom = nil, lineFrom = nil, lineTo = nil, attacking = false }
	local leftStart: Vector2? = nil
	local boxing = false
	local rightStart: Vector2? = nil
	local lastClick = { time = -math.huge, defIndex = -1 }
	local lastGroup = { n = 0, time = -math.huge }
	local world = api.world
	-- the command mode lives in the API (C-68); the hint follows it
	api.changed.commandMode:Connect(function(kind: string?)
		self.attacking = kind == "attack"
		hint.Visible = kind ~= nil
		if kind then
			hint.Text = `{Controls.HINT[kind] or kind} (Shift keeps it, right click cancels)`
		end
	end)

	-- what the selected units are (for the toggles)
	local function selectedStates(): (boolean, boolean, { number })
		local anyOn, anyRepeat, factories = false, false, {}
		for _, id in api.state.selection do
			local u = world.units[id]
			if u then
				local st = u.state or 0
				anyOn = anyOn or bit32.band(st, 2) ~= 0 -- TOGGLED_ON
				anyRepeat = anyRepeat or bit32.band(st, 16) ~= 0 -- REPEAT
				local def = World.def(world, u)
				if def and def.domain == "structure" and def.buildOptions and #def.buildOptions > 0 then
					table.insert(factories, id)
				end
			end
		end
		return anyOn, anyRepeat, factories
	end
	Controls.selectedStates = selectedStates

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
		elseif placing and input.UserInputType == Enum.UserInputType.MouseButton2 then
			api.actions.cancelPlacement()
			return
		elseif placing and input.KeyCode == Controls.ROTATE_KEY then
			api.actions.rotatePlacement()
			return
		end
		local capture = Controls.capture
		if capture and capture(input) then
			return -- a UI took it (the build menu's keys)
		end
		-- command modes (C-68): the next left click gives the command
		local mode = api.state.commandMode
		local commandKey = Controls.COMMAND_KEYS[input.KeyCode]
		if commandKey and not ctrl() then
			api.actions.setCommandMode(commandKey)
			return
		elseif mode and input.UserInputType == Enum.UserInputType.MouseButton2 then
			api.actions.setCommandMode(nil)
			return
		elseif mode and input.UserInputType == Enum.UserInputType.MouseButton1 then
			local id = pickAt(world, Controls.projector(cam()), mouse.X, mouse.Y)
			local ground = Controls.groundAt(cam(), mouse.X, mouse.Y)
			local u = if id then world.units[id] else nil
			local x = if ground then ground.X elseif u then u.x else nil
			local z = if ground then ground.Z elseif u then u.z else nil
			if x and z then
				api.actions.commandAt(x, z, id, shift(), shift())
			end
			return
		end
		if input.KeyCode == Controls.FIRE_STATE_KEY then
			api.actions.setFireState(((api.state.fireState or 1) + 1) % 3)
			return
		elseif input.KeyCode == Controls.MOVE_STATE_KEY then
			api.actions.setMoveState(((api.state.moveState or 1) + 1) % 3)
			return
		elseif input.KeyCode == Controls.TOGGLE_KEY then
			local anyOn = selectedStates()
			api.actions.toggle(not anyOn)
			return
		elseif input.KeyCode == Controls.REPEAT_KEY then
			local _, anyRepeat = selectedStates()
			api.actions.setRepeat(not anyRepeat)
			return
		elseif input.KeyCode == Controls.CANCEL_KEY then
			-- a factory's last queued item, else an unfinished frame
			local _, _, factories = selectedStates()
			local q = factories[1] and api.state.factoryQueues[factories[1]]
			api.actions.cancel(if q and #q > 0 then #q else 0)
			return
		elseif input.KeyCode == Controls.ALERT_KEY then
			local list = api.state.alerts
			for i = #list, 1, -1 do
				if list[i].kind ~= "stall" then
					api.actions.focusCamera(list[i].x, list[i].z)
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
				local id = pickAt(world, project, mouse.X, mouse.Y)
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
				local id = pickAt(world, Controls.projector(cam()), mouse.X, mouse.Y)
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
