--!strict
-- RTS camera (guide 15.5), BAR style: pan with the arrow keys, screen-edge
-- scroll (live games) and middle-drag (WASD stays free for hotkeys); zoom with the wheel; limited rotation with Q / E; clamped to
-- the map. The ground hits of the four screen corners give the camera
-- rectangle, sent as a CAMERA command when it changes, at most 5 per second:
-- the server's tactical tier follows it (net.md section 5). T follows a
-- unit or a missile (C-43, Core/Follow): Main sets the focus each frame
-- between `input` and `apply`; a manual pan stops it, zooming doesn't.
-- Alt + wheel tilts the camera between MIN_PITCH and MAX_PITCH (C-69); at a
-- low pitch the rectangle sent to the server stops RECT_CAP camera
-- distances from the focus, so the tactical tier never reaches the horizon.
--
-- Feel values are first guesses: listed under "Needs my review".

local UserInputService = game:GetService("UserInputService")

local Commands = require("./Core/Commands")
local Follow = require("./Core/Follow")
local World = require("./Core/World")

local Camera = {}

Camera.PITCH = math.rad(55) -- looking down: the starting pitch
Camera.MIN_PITCH = math.rad(35) -- Alt + wheel range (C-69)
Camera.MAX_PITCH = math.rad(80)
Camera.PITCH_STEP = math.rad(4) -- per wheel notch
-- the sent rectangle's corners stay within this many camera distances of the
-- focus (horizontally): about where the far edge is at 55°, so a low pitch
-- doesn't pull the tactical tier out to the horizon (C-69)
Camera.RECT_CAP = 1.8
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
Camera.LEAD_SECONDS = 0.8 -- the area sent to the server runs this far ahead of a moving camera (C-143)
Camera.LEAD_MAX = 400 -- studs, at most
Camera.FOLLOW_MARGIN = 400 -- studs: a follow may take the focus this far past the map's edge (missiles overshoot it, C-43)

export type State = {
	x: number,
	z: number,
	distance: number,
	yaw: number,
	pitch: number, -- radians above the horizontal (C-69)
	dragging: Vector2?,
	lastRect: { number }?,
	lastSent: number,
	lastFocus: { number }?, -- x, z, clock: the camera's speed for the lead
	rect: { number }, -- minX, minZ, maxX, maxZ cells of the last computed view
	corners: { number }?, -- the view's ground corners: x1, z1 .. x4, z4 round the edge (C-164)
	follow: Follow.Target?, -- what the camera follows (C-43)
	minDistance: number?, -- while following: the least distance that keeps the target in front (Follow.focus)
	outside: number, -- studs the focus may sit past the map's edge: FOLLOW_MARGIN while following, after that only back inwards
}

function Camera.new(x: number, z: number, distance: number): State
	return { x = x, z = z, distance = distance, yaw = 0, pitch = Camera.PITCH, dragging = nil, lastRect = nil, lastSent = -math.huge, rect = { 0, 0, 0, 0 }, outside = 0 }
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
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
				-- tilt (C-69): wheel up looks further ahead
				state.pitch = math.clamp(state.pitch - notch * Camera.PITCH_STEP, Camera.MIN_PITCH, Camera.MAX_PITCH)
			else
				state.distance = math.clamp(state.distance * Camera.ZOOM_STEP ^ -notch, Camera.MIN_DISTANCE, Camera.MAX_DISTANCE)
			end
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

-- Turn keys (Settings > Keys, C-159; E was also BAR's reclaim, so right is C)
Camera.ROTATE_LEFT = Enum.KeyCode.Q
Camera.ROTATE_RIGHT = Enum.KeyCode.C
-- a UI that holds a turn key for now (the build menu's tab keys, C-203)
Camera.keyTaken = nil :: ((Enum.KeyCode) -> boolean)?

local function turnKey(key: Enum.KeyCode): boolean
	local taken = Camera.keyTaken
	return UserInputService:IsKeyDown(key) and not (taken and taken(key))
end

-- Applies this frame's pan, rotation and middle-drag to the focus; returns
-- true when the player panned (which stops a follow, C-43).
function Camera.input(state: State, cam: Camera, dt: number): boolean
	-- pan direction in screen space, turned into world space by the yaw
	local move = Vector2.zero
	if not UserInputService:GetFocusedTextBox() then
		for key, dir in keys do
			if UserInputService:IsKeyDown(key) then
				move += dir
			end
		end
		if turnKey(Camera.ROTATE_LEFT) then
			state.yaw = math.clamp(state.yaw + Camera.YAW_SPEED * dt, -Camera.MAX_YAW, Camera.MAX_YAW)
		elseif turnKey(Camera.ROTATE_RIGHT) then
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
	return move.Magnitude > 0
end

-- Places the camera on its focus (clamped to the map) for this frame and
-- returns a CAMERA payload to send, if any. A follow may take the focus up
-- to FOLLOW_MARGIN past the map's edge; once it ends, the camera stays where
-- it stopped and can only move back towards the map.
function Camera.apply(state: State, world: World.World, cam: Camera, now: number): buffer?
	local g = world.grid
	local view = cam.ViewportSize
	local sin, cos = math.sin(state.yaw), math.cos(state.yaw)
	local margin = if state.follow then Camera.FOLLOW_MARGIN else state.outside
	local half = 0.5
	local x0, z0 = g.originX + half, g.originZ + half
	local x1, z1 = g.originX + g.sizeX - half, g.originZ + g.sizeZ - half
	state.x = math.clamp(state.x, x0 - margin, x1 + margin)
	state.z = math.clamp(state.z, z0 - margin, z1 + margin)
	state.outside = math.max(0, x0 - state.x, state.x - x1, z0 - state.z, state.z - z1)

	local groundY = World.groundY(world, state.x, state.z)
	local focus = Vector3.new(state.x, groundY, state.z)
	-- camera sits south of the focus (looking north, -Z) at yaw 0
	local back = Vector3.new(-sin, 0, cos) * math.cos(state.pitch) + Vector3.new(0, math.sin(state.pitch), 0)
	local distance = math.max(state.distance, state.minDistance or 0)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(focus + back * distance, focus)
	-- the engine refines terrain detail and lighting around Camera.Focus
	-- first; the point looked at, not just ahead of the lens, so after a
	-- jump the ground in view sharpens first (C-162)
	cam.Focus = CFrame.new(focus)

	-- camera rectangle from the screen corners, each at most RECT_CAP camera
	-- distances from the focus (sky corners: straight ahead at the cap, C-69)
	local xs, zs = {}, {}
	local cap = distance * Camera.RECT_CAP
	for _, p in { Vector2.new(0, 0), Vector2.new(view.X, 0), Vector2.new(0, view.Y), view } do
		local ray = cam:ViewportPointToRay(p.X, p.Y)
		local hit = groundHit(cam, p.X, p.Y, groundY)
		local dx, dz
		if hit then
			dx, dz = hit.X - focus.X, hit.Z - focus.Z
		else
			dx, dz = ray.Direction.X, ray.Direction.Z
			local len = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / math.max(len, 1e-6) * cap, dz / math.max(len, 1e-6) * cap
		end
		local len = math.sqrt(dx * dx + dz * dz)
		if len > cap then
			dx, dz = dx / len * cap, dz / len * cap
		end
		table.insert(xs, focus.X + dx)
		table.insert(zs, focus.Z + dz)
	end
	-- run the area ahead of a moving camera, so units there arrive (tactical,
	-- full models) before they scroll into view (the user: models popping in
	-- when panning fast, C-143)
	local lf = state.lastFocus
	local vx, vz = 0, 0
	if lf and now > lf[3] then
		vx, vz = (state.x - lf[1]) / (now - lf[3]), (state.z - lf[2]) / (now - lf[3])
	end
	state.lastFocus = { state.x, state.z, now }
	local lx, lz = vx * Camera.LEAD_SECONDS, vz * Camera.LEAD_SECONDS
	local ll = math.sqrt(lx * lx + lz * lz)
	if ll > Camera.LEAD_MAX then
		lx, lz = lx / ll * Camera.LEAD_MAX, lz / ll * Camera.LEAD_MAX
	end
	state.rect = { Commands.cameraRect(g, xs, zs) } -- what is on screen (its cells)
	-- the ground the screen shows, corner by corner round the edge (top
	-- left, top right, bottom right, bottom left): the minimap's trapezoid (C-164)
	state.corners = { xs[1], zs[1], xs[2], zs[2], xs[4], zs[4], xs[3], zs[3] }
	if ll > 1 then
		for i = 1, 4 do
			table.insert(xs, xs[i] + lx)
			table.insert(zs, zs[i] + lz)
		end
	end
	local minX, minZ, maxX, maxZ = Commands.cameraRect(g, xs, zs) -- what the server sends: with the lead
	local last = state.lastRect
	local changed = last == nil or last[1] ~= minX or last[2] ~= minZ or last[3] ~= maxX or last[4] ~= maxZ
	if changed and now - state.lastSent >= Camera.SEND_INTERVAL then
		state.lastRect = { minX, minZ, maxX, maxZ }
		state.lastSent = now
		return Commands.camera(minX, minZ, maxX, maxZ)
	end
	return nil
end

return Camera
