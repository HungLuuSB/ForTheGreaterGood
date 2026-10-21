--!strict
-- RTS camera (guide 15.5), BAR style: pan with the arrow keys, screen-edge
-- scroll (live games) and middle-drag (WASD stays free for hotkeys); zoom with the wheel; limited rotation with Q / E; clamped to
-- the map. The ground hits of the four screen corners give the camera
-- rectangle, sent as a CAMERA command when it changes, at most 5 per second:
-- the server's tactical tier follows it (net.md section 5).
--
-- Feel values are first guesses: listed under "Needs my review".

local UserInputService = game:GetService("UserInputService")

local Commands = require("./Core/Commands")
local World = require("./Core/World")

local Camera = {}

Camera.PITCH = math.rad(55) -- looking down
Camera.MIN_DISTANCE = 30
Camera.MAX_DISTANCE = 900
Camera.ZOOM_STEP = 1.15 -- per wheel notch
Camera.PAN_SPEED = 1.1 -- screen heights per second at any zoom
Camera.EDGE_PIXELS = 6
-- Studio's mouse often rests on the window edge (toolbars, Output), which
-- scrolls the view away; edge scroll is on in live games only.
Camera.EDGE_SCROLL = not game:GetService("RunService"):IsStudio()
Camera.MAX_YAW = math.rad(45) -- rotation limit either side of north-up
Camera.YAW_SPEED = math.rad(90) -- per second with Q / E
Camera.SEND_INTERVAL = 0.2 -- seconds between CAMERA commands (≤ 5 per second)

export type State = {
	x: number,
	z: number,
	distance: number,
	yaw: number,
	dragging: Vector2?,
	lastRect: { number }?,
	lastSent: number,
	rect: { number }, -- minX, minZ, maxX, maxZ cells of the last computed view
}

function Camera.new(x: number, z: number, distance: number): State
	return { x = x, z = z, distance = distance, yaw = 0, dragging = nil, lastRect = nil, lastSent = -math.huge, rect = { 0, 0, 0, 0 } }
end

local keys = {
	[Enum.KeyCode.Up] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, 1),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
}

-- Hooks the wheel and middle-drag. Call once.
function Camera.bind(state: State)
	UserInputService.InputChanged:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local notch = input.Position.Z
			state.distance = math.clamp(state.distance * Camera.ZOOM_STEP ^ -notch, Camera.MIN_DISTANCE, Camera.MAX_DISTANCE)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton3 then
			state.dragging = UserInputService:GetMouseLocation()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			state.dragging = nil
		end
	end)
end

-- Ground point (y = groundY) under a viewport pixel, or nil if the ray points up.
local function groundHit(cam: Camera, px: number, py: number, groundY: number): Vector3?
	local ray = cam:ViewportPointToRay(px, py)
	if ray.Direction.Y >= -1e-4 then
		return nil
	end
	local t = (groundY - ray.Origin.Y) / ray.Direction.Y
	return ray.Origin + ray.Direction * t
end

-- Moves the camera for this frame and returns a CAMERA payload to send, if any.
function Camera.update(state: State, world: World.World, cam: Camera, dt: number, now: number): buffer?
	local g = world.grid
	-- pan direction in screen space, turned into world space by the yaw
	local move = Vector2.zero
	if not UserInputService:GetFocusedTextBox() then
		for key, dir in keys do
			if UserInputService:IsKeyDown(key) then
				move += dir
			end
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			state.yaw = math.clamp(state.yaw + Camera.YAW_SPEED * dt, -Camera.MAX_YAW, Camera.MAX_YAW)
		elseif UserInputService:IsKeyDown(Enum.KeyCode.E) then
			state.yaw = math.clamp(state.yaw - Camera.YAW_SPEED * dt, -Camera.MAX_YAW, Camera.MAX_YAW)
		end
	end
	local mouse = UserInputService:GetMouseLocation()
	local view = cam.ViewportSize
	if Camera.EDGE_SCROLL and UserInputService.WindowFocused and view.X > 0 then
		if mouse.X <= Camera.EDGE_PIXELS then
			move += Vector2.new(-1, 0)
		elseif mouse.X >= view.X - Camera.EDGE_PIXELS then
			move += Vector2.new(1, 0)
		end
		if mouse.Y <= Camera.EDGE_PIXELS then
			move += Vector2.new(0, -1)
		elseif mouse.Y >= view.Y - Camera.EDGE_PIXELS then
			move += Vector2.new(0, 1)
		end
	end
	-- visible ground height ≈ distance; pan speed scales with zoom
	local speed = state.distance * Camera.PAN_SPEED
	local sin, cos = math.sin(state.yaw), math.cos(state.yaw)
	if move.Magnitude > 0 then
		move = move.Unit * speed * dt
	end
	if state.dragging then
		local delta = mouse - state.dragging
		state.dragging = mouse
		move -= delta * (state.distance / math.max(view.Y, 1)) * 1.6
	end
	-- screen right = (cos, sin) and screen up = (sin, -cos) in world X/Z;
	-- move.Y is positive downwards on screen
	state.x += move.X * cos - move.Y * sin
	state.z += move.X * sin + move.Y * cos
	local half = 0.5
	state.x = math.clamp(state.x, g.originX + half, g.originX + g.sizeX - half)
	state.z = math.clamp(state.z, g.originZ + half, g.originZ + g.sizeZ - half)

	local groundY = World.groundY(world, state.x, state.z)
	local focus = Vector3.new(state.x, groundY, state.z)
	-- camera sits south of the focus (looking north, -Z) at yaw 0
	local back = Vector3.new(-sin, 0, cos) * math.cos(Camera.PITCH) + Vector3.new(0, math.sin(Camera.PITCH), 0)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(focus + back * state.distance, focus)

	-- camera rectangle from the screen corners (sky corners clamp to far ground)
	local xs, zs = {}, {}
	for _, p in { Vector2.new(0, 0), Vector2.new(view.X, 0), Vector2.new(0, view.Y), view } do
		local hit = groundHit(cam, p.X, p.Y, groundY)
		if hit == nil then
			local far = focus - back * state.distance * 3
			hit = Vector3.new(far.X, groundY, far.Z)
		end
		table.insert(xs, hit.X)
		table.insert(zs, hit.Z)
	end
	local minX, minZ, maxX, maxZ = Commands.cameraRect(g, xs, zs)
	state.rect = { minX, minZ, maxX, maxZ }
	local last = state.lastRect
	local changed = last == nil or last[1] ~= minX or last[2] ~= minZ or last[3] ~= maxX or last[4] ~= maxZ
	if changed and now - state.lastSent >= Camera.SEND_INTERVAL then
		state.lastRect = state.rect
		state.lastSent = now
		return Commands.camera(minX, minZ, maxX, maxZ)
	end
	return nil
end

return Camera
