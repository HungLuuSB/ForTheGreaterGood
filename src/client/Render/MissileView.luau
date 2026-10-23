--!strict
-- Draws the missile sensor view (Core/MissileView, C-39), toggled with N
-- (off by default). Always-on-top handle adornments on the Terrain, so
-- nothing hides them: per missile a dot where it is drawn, its predicted
-- path (green when the prediction fuses, orange when it misses, grey
-- without a lock), a yellow line to the point it steers at, the target's
-- centre in red, the fuse envelope (the hull grown by the weapon's aoe)
-- and the predicted closest approach (magenta) joined to the centre, and the
-- seeker cone as a wireframe out to the lock range (C-42: cyan while the
-- target's centre is inside it, red when outside). Corrections,
-- decoys and lost locks (Effects' marks) show as a line from where the
-- missile was drawn to where the server had it, fading out. The team's
-- radar accuracy (Core/RadarAccuracy, C-181): a circle round each radar
-- blip, the radius radar-fired shots miss by (amber; green and smaller on
-- tracked contacts), and a readout line at the top. Labels are
-- screen-space TextLabels. Pools never shrink; unused adornments are hidden.

local Effects = require("../Core/Effects")
local MissileView = require("../Core/MissileView")
local RadarAccuracy = require("../Core/RadarAccuracy")
local Terrain = require("../Core/Terrain")
local World = require("../Core/World")

local RenderMissileView = {}

RenderMissileView.TOGGLE_KEY = Enum.KeyCode.N
RenderMissileView.DOT_DISTANCE = 120 -- studs: farther from the camera, dots grow with the distance (a constant size on screen)

local COLOR: { [string]: Color3 } = {
	missile = Color3.fromRGB(120, 230, 255),
	hit = Color3.fromRGB(90, 230, 110),
	miss = Color3.fromRGB(255, 160, 50),
	unguided = Color3.fromRGB(170, 170, 170),
	aim = Color3.fromRGB(255, 230, 70),
	target = Color3.fromRGB(255, 70, 60),
	closest = Color3.fromRGB(255, 90, 230),
	correction = Color3.fromRGB(240, 240, 240),
	decoy = Color3.fromRGB(170, 210, 255),
	lost = Color3.fromRGB(150, 150, 150),
	seekerIn = Color3.fromRGB(110, 220, 255),
	seekerOut = Color3.fromRGB(255, 60, 60),
	track = Color3.fromRGB(120, 255, 170), -- radar tracks on strategic missiles (C-58)
	enemyTrack = Color3.fromRGB(255, 90, 90), -- enemy radars tracking your missile
	radarRing = Color3.fromRGB(255, 190, 70), -- radar accuracy round a blip (C-181)
	trackRing = Color3.fromRGB(120, 255, 170), -- the same, tracked by fire-control radar
}

RenderMissileView.MAX_RINGS = 80 -- radar accuracy circles drawn at most (the first by unit ID)

local CONE_SEGMENTS = 24 -- rim segments of the seeker cone
local CONE_EDGES = 8 -- lines from the apex to the rim
local CONE_MAX_ANGLE = 85 -- degrees: a wider cone is drawn at this (its rim would run off to infinity)

export type View = {
	enabled: boolean,
	folder: Folder,
	gui: ScreenGui,
	lines: { LineHandleAdornment },
	spheres: { SphereHandleAdornment },
	cylinders: { CylinderHandleAdornment },
	rings: { CylinderHandleAdornment }, -- radar accuracy: an outline and a faint fill per blip (C-181)
	labels: { TextLabel },
	readout: TextLabel, -- the radar accuracy line (C-181)
	used: { lines: number, spheres: number, cylinders: number, rings: number, labels: number },
	entries: { MissileView.Entry }, -- the last frame's (debug query)
	stats: { frames: number, lastMs: number, maxMs: number, maxShown: number },
	eye: Vector3, -- the camera this frame
}

function RenderMissileView.new(): View
	local folder = Instance.new("Folder")
	folder.Name = "MissileView"
	folder.Parent = workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "MissileView"
	gui.IgnoreGuiInset = true -- labels are placed in viewport coordinates
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = (game:GetService("Players").LocalPlayer :: Player):WaitForChild("PlayerGui")
	local readout = Instance.new("TextLabel")
	readout.Name = "RadarAccuracy"
	readout.AnchorPoint = Vector2.new(0.5, 0)
	readout.Position = UDim2.new(0.5, 0, 0, 72)
	readout.AutomaticSize = Enum.AutomaticSize.XY
	readout.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	readout.BackgroundTransparency = 0.35
	readout.BorderSizePixel = 0
	readout.Font = Enum.Font.Code
	readout.TextSize = 14
	readout.TextColor3 = COLOR.radarRing
	readout.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
	pad.Parent = readout
	readout.Parent = gui
	return {
		enabled = false,
		folder = folder,
		gui = gui,
		lines = {},
		spheres = {},
		cylinders = {},
		rings = {},
		labels = {},
		readout = readout,
		used = { lines = 0, spheres = 0, cylinders = 0, rings = 0, labels = 0 },
		entries = {},
		stats = { frames = 0, lastMs = 0, maxMs = 0, maxShown = 0 },
		eye = Vector3.zero,
	}
end

local function adorn<T>(v: View, pool: { T }, key: string, class: string): T
	local i = (v.used :: any)[key] + 1;
	(v.used :: any)[key] = i
	local a = pool[i]
	if a == nil then
		local inst = Instance.new(class) :: any
		inst.Adornee = workspace.Terrain
		inst.AlwaysOnTop = true
		inst.AdornCullingMode = Enum.AdornCullingMode.Never -- Automatic culls small adornments at RTS camera distances
		inst.Parent = v.folder
		pool[i] = inst
		a = inst
	end
	(a :: any).Visible = true
	return a
end

local function line(v: View, a: Vector3, b: Vector3, color: Color3, thickness: number, transparency: number)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return
	end
	local l = adorn(v, v.lines, "lines", "LineHandleAdornment")
	l.CFrame = CFrame.lookAt(a, b)
	l.Length = len
	l.Thickness = thickness
	l.Color3 = color
	l.Transparency = transparency
end

-- The seeker cone of entry `e` (C-42): apex at the missile, axis along its
-- flight direction, slant length = the seeker range.
local rim: { Vector3 } = table.create(CONE_SEGMENTS)
local function cone(v: View, e: MissileView.Entry, at: Vector3)
	local a = math.rad(math.min(e.seekerAngle :: number, CONE_MAX_ANGLE))
	local f = Vector3.new(e.fx, e.fy, e.fz)
	local centre = at + f * (e.seekerRange * math.cos(a))
	local radius = e.seekerRange * math.sin(a)
	-- two axes across the flight direction
	local side = f:Cross(if math.abs(f.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
	local up = side:Cross(f)
	local color = if e.inSeeker then COLOR.seekerIn else COLOR.seekerOut
	for k = 1, CONE_SEGMENTS do
		local t = (k - 1) / CONE_SEGMENTS * 2 * math.pi
		rim[k] = centre + (side * math.cos(t) + up * math.sin(t)) * radius
	end
	for k = 1, CONE_SEGMENTS do
		line(v, rim[k], rim[k % CONE_SEGMENTS + 1], color, 2, 0.35)
	end
	local step = CONE_SEGMENTS // CONE_EDGES
	for k = 1, CONE_SEGMENTS, step do
		line(v, at, rim[k], color, 2, 0.35)
	end
end

local function sphere(v: View, p: Vector3, radius: number, color: Color3, transparency: number)
	local s = adorn(v, v.spheres, "spheres", "SphereHandleAdornment")
	s.CFrame = CFrame.new(p)
	s.Radius = radius * math.max(1, (p - v.eye).Magnitude / RenderMissileView.DOT_DISTANCE)
	s.Color3 = color
	s.Transparency = transparency
end

local VERTICAL = CFrame.Angles(math.pi / 2, 0, 0) -- a cylinder adornment's axis is its Z

local function cylinder(v: View, p: Vector3, radius: number, height: number, color: Color3, transparency: number)
	local c = adorn(v, v.cylinders, "cylinders", "CylinderHandleAdornment")
	c.CFrame = CFrame.new(p) * VERTICAL
	c.Radius = radius
	c.Height = height
	c.Color3 = color
	c.Transparency = transparency
end

-- A flat circle on the ground: an outline `width` studs wide, or a filled
-- disc (width nil).
local function ring(v: View, p: Vector3, radius: number, width: number?, color: Color3, transparency: number)
	local c = adorn(v, v.rings, "rings", "CylinderHandleAdornment")
	c.CFrame = CFrame.new(p) * VERTICAL
	c.Radius = radius
	c.InnerRadius = if width then math.max(0, radius - width) else 0
	c.Height = 0.15
	c.Color3 = color
	c.Transparency = transparency
end

local function label(v: View, text: string, x: number, y: number, color: Color3)
	local i = v.used.labels + 1
	v.used.labels = i
	local t = v.labels[i]
	if t == nil then
		t = Instance.new("TextLabel")
		t.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		t.BackgroundTransparency = 0.35
		t.BorderSizePixel = 0
		t.Font = Enum.Font.Code
		t.TextSize = 13
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextStrokeTransparency = 0.6
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.AnchorPoint = Vector2.new(0, 1)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 2), UDim.new(0, 2)
		pad.Parent = t
		t.Parent = v.gui
		v.labels[i] = t
	end
	t.Visible = true
	t.Text = text
	t.TextColor3 = color
	t.Position = UDim2.fromOffset(x + 10, y - 10)
end

local function hideFrom(pool: { any }, from: number)
	for i = from, #pool do
		if pool[i].Visible then
			pool[i].Visible = false
		end
	end
end

local function finish(v: View)
	hideFrom(v.lines, v.used.lines + 1)
	hideFrom(v.spheres, v.used.spheres + 1)
	hideFrom(v.cylinders, v.used.cylinders + 1)
	hideFrom(v.rings, v.used.rings + 1)
	hideFrom(v.labels, v.used.labels + 1)
end

function RenderMissileView.setEnabled(v: View, on: boolean)
	v.enabled = on
	if not on then
		v.used.lines, v.used.spheres, v.used.cylinders, v.used.rings, v.used.labels = 0, 0, 0, 0, 0
		table.clear(v.entries)
		finish(v)
	end
	v.readout.Visible = on
end

-- The team's radar accuracy (C-181): a circle round each radar blip, and
-- the readout.
local function radarAccuracy(v: View, world: World.World)
	local acc = RadarAccuracy.of(world.economy)
	v.readout.Text = RadarAccuracy.readout(acc)
	local layers = world.layers
	for i, r in RadarAccuracy.rings(world, acc) do
		if i > RenderMissileView.MAX_RINGS then
			break
		end
		local y = (if layers then Terrain.surfaceY(layers, r.x, r.z) else World.groundY(world, r.x, r.z)) + 0.6
		local at = Vector3.new(r.x, y, r.z)
		local color = if r.tracked then COLOR.trackRing else COLOR.radarRing
		-- the outline stays visible from the RTS camera: a tenth of the radius, at least 0.3
		ring(v, at, r.radius, math.max(0.3, r.radius * 0.1), color, 0.15)
		ring(v, at, r.radius, nil, color, 0.85)
	end
end

-- `visible`: Effects.visible's list this frame (RenderEffects.step returns it).
function RenderMissileView.step(v: View, fx: Effects.Fx, world: World.World, renderTick: number, now: number, visible: { { any } }, cam: Camera)
	if not v.enabled then
		return
	end
	local t0 = os.clock()
	v.used.lines, v.used.spheres, v.used.cylinders, v.used.rings, v.used.labels = 0, 0, 0, 0, 0
	v.eye = cam.CFrame.Position
	radarAccuracy(v, world)
	local entries = MissileView.build(fx, world, renderTick, visible)
	v.entries = entries
	for _, e in entries do
		local at = Vector3.new(e.x, e.y, e.z)
		local color = if not e.locked then COLOR.unguided elseif e.hit then COLOR.hit else COLOR.miss
		sphere(v, at, 0.9, COLOR.missile, 0)
		if e.seekerAngle and e.seekerRange > 0 then
			cone(v, e, at)
		end
		local path = e.path
		for k = 4, #path - 2, 3 do
			line(v, Vector3.new(path[k - 3], path[k - 2], path[k - 1]), Vector3.new(path[k], path[k + 1], path[k + 2]), color, 3, 0.1)
		end
		if e.cx and e.lx then
			local centre = Vector3.new(e.cx, e.cy :: number, e.cz :: number)
			local lead = Vector3.new(e.lx, e.ly :: number, e.lz :: number)
			line(v, at, lead, COLOR.aim, 2, 0.3)
			sphere(v, lead, 0.7, COLOR.aim, 0.1)
			sphere(v, centre, 0.8, COLOR.target, 0)
			cylinder(v, centre, (e.hullRadius :: number) + e.fuse, (e.hullHeight :: number) + 2 * e.fuse, color, 0.7)
			if e.px then
				local close = Vector3.new(e.px, e.py :: number, e.pz :: number)
				sphere(v, close, 0.8, COLOR.closest, 0)
				line(v, close, centre, COLOR.closest, 2, 0.2)
			end
		elseif e.cx then
			-- an interceptor: the line to its strategic missile
			line(v, at, Vector3.new(e.cx, e.cy :: number, e.cz :: number), COLOR.aim, 2, 0.3)
		end
		local screen, onScreen = cam:WorldToViewportPoint(at)
		if onScreen then
			label(v, e.label, screen.X, screen.Y, color)
		end
	end
	-- radar tracks on strategic missiles (C-58): a line from every site
	-- holding one, and the track's label
	for _, tr in MissileView.tracks(fx, world, visible) do
		local at = Vector3.new(tr.x, tr.y, tr.z)
		local color = if tr.own then COLOR.enemyTrack else COLOR.track
		sphere(v, at, 3, color, 0.2)
		for _, s in tr.sites do
			local site = Vector3.new(s[1], s[2], s[3])
			line(v, site, at, color, 2, 0.35)
			sphere(v, site, 1.5, color, 0.2)
		end
		local screen, onScreen = cam:WorldToViewportPoint(at)
		if onScreen then
			label(v, tr.label, screen.X, screen.Y, color)
		end
	end
	for _, m in fx.marks do
		local fade = math.clamp((now - m.born) / Effects.MARK_SECONDS, 0, 1)
		local color = COLOR[m.kind] or COLOR.correction
		local a, b = Vector3.new(m.x0, m.y0, m.z0), Vector3.new(m.x1, m.y1, m.z1)
		line(v, a, b, color, 2, 0.1 + 0.85 * fade)
		sphere(v, b, if m.kind == "correction" then 0.35 else 1.2, color, 0.1 + 0.85 * fade)
	end
	finish(v)
	local ms = (os.clock() - t0) * 1000
	v.stats.frames += 1
	v.stats.lastMs = ms
	v.stats.maxMs = math.max(v.stats.maxMs, ms)
	v.stats.maxShown = math.max(v.stats.maxShown, #entries)
end

return RenderMissileView
