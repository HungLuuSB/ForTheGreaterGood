--!strict
-- Range rings on the terrain (C-19): BAR-style merged outlines for the
-- selected own units and for the build ghost of a turret or SAM. Thin
-- pooled Neon segments; rebuilt only when the selection, the ghost or a
-- selected unit's position (2-stud steps) changes, at most 4 times a
-- second. Colors: weapon red, anti-air pink, sight white, radar and
-- tracking green, jammer yellow. Toggled with V (on by default).

local Api = require("../Api")
local Ranges = require("../Core/Ranges")
local World = require("../Core/World")

local RangeOverlay = {}

RangeOverlay.TOGGLE_KEY = Enum.KeyCode.V
RangeOverlay.MIN_INTERVAL = 0.25 -- seconds between rebuilds
RangeOverlay.MOVE_STEP = 2 -- studs: position changes smaller than this don't rebuild
RangeOverlay.PREWARM = 256 -- segments made ahead, 16 per idle frame (creating parts is the slow part)

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

export type Overlay = {
	folder: Folder,
	pool: { BasePart },
	used: number,
	key: string,
	lastBuild: number,
	enabled: boolean,
	stats: { builds: number, lastMs: number, maxMs: number, segments: number, unionMs: number },
	arcs: { Ranges.Arc }, -- what the last rebuild drew (scene dumps)
}

function RangeOverlay.new(): Overlay
	local folder = Instance.new("Folder")
	folder.Name = "Ranges"
	folder.Parent = workspace
	return { folder = folder, pool = {}, used = 0, key = "", lastBuild = -math.huge, enabled = true, stats = { builds = 0, lastMs = 0, maxMs = 0, segments = 0, unionMs = 0 }, arcs = {} }
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

-- What the rings depend on: the selection, positions in MOVE_STEP steps,
-- the ghost.
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

function RangeOverlay.step(o: Overlay, api: Api.Api, now: number)
	local key = if o.enabled then signature(api) else ""
	if key == o.key or now - o.lastBuild < RangeOverlay.MIN_INTERVAL then
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
	local lines = Ranges.polylines(arcs, function(x, z)
		return World.groundY(world, x, z)
	end)
	o.stats.unionMs = (os.clock() - t0) * 1000
	local n = 0
	local parts, frames = {}, {}
	for _, line in lines do
		local color = COLOR[line.kind] or COLOR.weapon
		local width = WIDTH[line.kind] or 0.3
		local pts = line.points
		for k = 1, #pts - 1 do
			local a = Vector3.new(pts[k][1], pts[k][2], pts[k][3])
			local b = Vector3.new(pts[k + 1][1], pts[k + 1][2], pts[k + 1][3])
			local len = (b - a).Magnitude
			if len < 0.05 then
				continue
			end
			n += 1
			local part = segmentPart(o, n)
			local size = Vector3.new(width, 0.12, len + width + 0.3) -- overlap the joints (and hide the size tolerance below)
			if math.abs(part.Size.Z - size.Z) > 0.3 or part.Size.X ~= size.X then
				part.Size = size
			end
			if part.Color ~= color then
				part.Color = color
			end
			if part.Transparency ~= SHOWN then
				part.Transparency = SHOWN
			end
			parts[n] = part
			frames[n] = CFrame.lookAt((a + b) / 2, b)
		end
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
