--!strict
-- Range rings on the terrain (C-19): BAR-style merged outlines for the
-- selected own units and for the build ghost of a turret or SAM. Thin
-- pooled Neon segments; the outline is rebuilt only when the selection, the
-- ghost or a selected unit's position (2-stud steps) changes, at most 4
-- times a second. Between rebuilds every arc follows its unit's drawn
-- position each frame, laid on the terrain again (C-29), so rings glide
-- with moving units; the next rebuild fixes where merged outlines cross.
-- Colors: weapon red, anti-air pink, sight white, radar and tracking
-- green, jammer yellow. Toggled with V (on by default).

local Api = require("../Api")
local Ranges = require("../Core/Ranges")
local World = require("../Core/World")

local RangeOverlay = {}

RangeOverlay.TOGGLE_KEY = Enum.KeyCode.V
RangeOverlay.MIN_INTERVAL = 0.25 -- seconds between rebuilds
RangeOverlay.MOVE_STEP = 2 -- studs: position changes smaller than this don't rebuild
RangeOverlay.PREWARM = 256 -- segments made ahead, 16 per idle frame (creating parts is the slow part)
RangeOverlay.FOLLOW_EPS = 0.01 -- studs: an owner moving less than this since the last frame isn't redrawn

local COLOR: { [string]: Color3 } = {
	weapon = Color3.fromRGB(235, 60, 50),
	aa = Color3.fromRGB(240, 120, 220),
	sight = Color3.fromRGB(235, 235, 235),
	radar = Color3.fromRGB(90, 220, 110),
	track = Color3.fromRGB(60, 170, 80),
	jammer = Color3.fromRGB(240, 210, 60),
}
local SHOWN = 0.25 -- transparency of a drawn segment
local WIDTH: { [string]: number } = { weapon = 0.4, aa = 0.4, sight = 0.3, radar = 0.3, track = 0.3, jammer = 0.3 }

-- A drawn polyline: points (x, z) where its owner was at the rebuild;
-- segments first .. first + #xs - 2 of the pool.
type Line = { owner: number?, kind: string, xs: { number }, zs: { number }, first: number }

export type Overlay = {
	folder: Folder,
	pool: { BasePart },
	used: number,
	key: string,
	lastBuild: number,
	enabled: boolean,
	stats: { builds: number, lastMs: number, maxMs: number, segments: number, unionMs: number, follows: number, followMs: number, followMaxMs: number },
	arcs: { Ranges.Arc }, -- what the last rebuild drew (scene dumps)
	lines: { Line }, -- the last rebuild's lines
	base: { [number]: { number } }, -- owner → drawn {x, z} at the last rebuild
	shift: { [number]: { number } }, -- owner → {dx, dz} drawn last frame
}

function RangeOverlay.new(): Overlay
	local folder = Instance.new("Folder")
	folder.Name = "Ranges"
	folder.Parent = workspace
	return {
		folder = folder,
		pool = {},
		used = 0,
		key = "",
		lastBuild = -math.huge,
		enabled = true,
		stats = { builds = 0, lastMs = 0, maxMs = 0, segments = 0, unionMs = 0, follows = 0, followMs = 0, followMaxMs = 0 },
		arcs = {},
		lines = {},
		base = {},
		shift = {},
	}
end

local function segmentPart(o: Overlay, i: number): BasePart
	local p = o.pool[i]
	if p == nil then
		local part = Instance.new("Part")
		part.Name = "RangeSegment"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		-- parented once and hidden when unused: re-parenting hundreds of
		-- parts is the slow part of a rebuild
		part.Transparency = 1
		part.Parent = o.folder
		o.pool[i] = part
		p = part
	end
	return p :: BasePart
end

-- What the outline depends on: the selection, positions in MOVE_STEP
-- steps, the ghost.
local function signature(api: Api.Api): string
	local world = api.world
	local parts = {}
	for _, id in api.state.selection do
		local u = world.units[id]
		if u then
			local x, z = u.rx or u.x, u.rz or u.z
			table.insert(parts, `{id}:{math.floor(x / RangeOverlay.MOVE_STEP)}:{math.floor(z / RangeOverlay.MOVE_STEP)}`)
		end
	end
	local p = api.state.placement
	if p then
		table.insert(parts, `g:{p.defId}:{p.x}:{p.z}`)
	end
	return table.concat(parts, ",")
end

function RangeOverlay.setEnabled(o: Overlay, on: boolean)
	o.enabled = on
	o.key = "\0dirty" -- matches no real key: rebuild (or clear) on the next step
	o.lastBuild = -math.huge
end

-- Lays `line`'s segments on the terrain, shifted by (dx, dz); appends them
-- to the BulkMoveTo lists.
local function layLine(o: Overlay, world: World.World, line: Line, dx: number, dz: number, parts: { BasePart }, frames: { CFrame })
	local width = WIDTH[line.kind] or 0.3
	local xs, zs = line.xs, line.zs
	local ax, az = xs[1] + dx, zs[1] + dz
	local a = Vector3.new(ax, World.groundY(world, ax, az) + Ranges.LIFT, az)
	for k = 2, #xs do
		local bx, bz = xs[k] + dx, zs[k] + dz
		local b = Vector3.new(bx, World.groundY(world, bx, bz) + Ranges.LIFT, bz)
		local part = o.pool[line.first + k - 2]
		local sizeZ = (b - a).Magnitude + width + 0.3 -- overlap the joints (and hide the size tolerance below)
		if math.abs(part.Size.Z - sizeZ) > 0.3 or part.Size.X ~= width then
			part.Size = Vector3.new(width, 0.12, sizeZ)
		end
		table.insert(parts, part)
		table.insert(frames, CFrame.lookAt((a + b) / 2, b))
		a = b
	end
end

-- Between rebuilds: move the lines whose unit moved since the last frame.
local function follow(o: Overlay, world: World.World)
	if o.used == 0 then
		return
	end
	local t0 = os.clock()
	local moved: { [number]: boolean } = {}
	local any = false
	for owner, last in o.shift do
		local base, u = o.base[owner], world.units[owner]
		if base and u then
			local dx, dz = (u.rx or u.x) - base[1], (u.rz or u.z) - base[2]
			if math.abs(dx - last[1]) > RangeOverlay.FOLLOW_EPS or math.abs(dz - last[2]) > RangeOverlay.FOLLOW_EPS then
				last[1], last[2] = dx, dz
				moved[owner] = true
				any = true
			end
		end
	end
	if not any then
		return
	end
	local parts, frames = {}, {}
	for _, line in o.lines do
		local owner = line.owner
		if owner and moved[owner] then
			local sh = o.shift[owner]
			layLine(o, world, line, sh[1], sh[2], parts, frames)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	local ms = (os.clock() - t0) * 1000
	o.stats.follows += 1
	o.stats.followMs = ms
	o.stats.followMaxMs = math.max(o.stats.followMaxMs, ms)
end

function RangeOverlay.step(o: Overlay, api: Api.Api, now: number)
	local key = if o.enabled then signature(api) else ""
	if key == o.key or now - o.lastBuild < RangeOverlay.MIN_INTERVAL then
		follow(o, api.world)
		-- idle frame: grow the pool a little so the first rings don't stall
		local have = #o.pool
		if have < RangeOverlay.PREWARM then
			for i = have + 1, math.min(have + 16, RangeOverlay.PREWARM) do
				segmentPart(o, i)
			end
		end
		return
	end
	o.key, o.lastBuild = key, now
	local t0 = os.clock()
	local world = api.world
	local circles = if o.enabled then Ranges.circles(world, api.state.selection) else {}
	local p = api.state.placement
	if o.enabled and p then
		Ranges.circlesOfDef(world.defs.unitByIndex[p.defIndex], world.defs, p.x, p.z, circles)
	end
	local arcs = Ranges.union(circles)
	o.arcs = arcs
	local polylines = Ranges.polylines(arcs, function(x, z)
		return World.groundY(world, x, z)
	end)
	o.stats.unionMs = (os.clock() - t0) * 1000
	-- each owner's drawn position now: the lines' origin until the next rebuild
	table.clear(o.base)
	table.clear(o.shift)
	for _, c in circles do
		local owner = c.owner
		if owner and o.base[owner] == nil then
			o.base[owner] = { c.x, c.z }
			o.shift[owner] = { 0, 0 }
		end
	end
	local n = 0
	local lines: { Line } = {}
	for _, pl in polylines do
		-- drop points within 0.05 stud of the previous one: every pair is a segment
		local xs, zs = {}, {}
		for _, pt in pl.points do
			local x, z = (pt :: any)[1], (pt :: any)[3]
			local m = #xs
			if m == 0 or (x - xs[m]) ^ 2 + (z - zs[m]) ^ 2 >= 0.05 * 0.05 then
				table.insert(xs, x)
				table.insert(zs, z)
			end
		end
		if #xs < 2 then
			continue
		end
		local color = COLOR[pl.kind] or COLOR.weapon
		for k = 1, #xs - 1 do
			local part = segmentPart(o, n + k)
			if part.Color ~= color then
				part.Color = color
			end
			if part.Transparency ~= SHOWN then
				part.Transparency = SHOWN
			end
		end
		table.insert(lines, { owner = pl.owner, kind = pl.kind, xs = xs, zs = zs, first = n + 1 })
		n += #xs - 1
	end
	o.lines = lines
	local parts, frames = {}, {}
	for _, line in lines do
		layLine(o, world, line, 0, 0, parts, frames)
	end
	if n > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for i = n + 1, o.used do
		o.pool[i].Transparency = 1
	end
	o.used = n
	local ms = (os.clock() - t0) * 1000
	o.stats.builds += 1
	o.stats.lastMs = ms
	o.stats.maxMs = math.max(o.stats.maxMs, ms)
	o.stats.segments = n
end

return RangeOverlay
