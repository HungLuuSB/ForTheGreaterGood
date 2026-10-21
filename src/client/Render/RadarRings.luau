--!strict
-- The team's radar facilities' rings (C-63), always shown: their radar
-- coverage as one merged green outline (Core/Ranges: radarFacilities,
-- union, polylines), drawn with always-on-top line adornments on the
-- Terrain (the user, C-64) so hills and hedgerows don't hide it and it
-- keeps its width in pixels at any zoom. Default ZIndex, culling off, like
-- the launch warning. Rebuilt at most every REBUILD seconds, and only when
-- a facility appears, goes or moves a MOVE_STEP.

local Ranges = require("../Core/Ranges")
local World = require("../Core/World")

local RadarRings = {}

RadarRings.REBUILD = 0.25 -- seconds between lookups
RadarRings.MOVE_STEP = 4 -- studs: a facility moving less than this keeps its rings
RadarRings.THICKNESS = 6 -- pixels
RadarRings.COLOR = Color3.fromRGB(70, 255, 100)
RadarRings.TRANSPARENCY = 0.1

export type State = {
	folder: Folder,
	lines: { LineHandleAdornment },
	used: number,
	key: string,
	at: number,
}

function RadarRings.new(): State
	local folder = Instance.new("Folder")
	folder.Name = "RadarRings"
	folder.Parent = workspace
	return { folder = folder, lines = {}, used = 0, key = "", at = -math.huge }
end

local function line(s: State, a: Vector3, b: Vector3)
	s.used += 1
	local l = s.lines[s.used]
	if l == nil then
		local inst = Instance.new("LineHandleAdornment")
		inst.Adornee = workspace.Terrain
		inst.AlwaysOnTop = true
		inst.AdornCullingMode = Enum.AdornCullingMode.Never
		inst.Color3 = RadarRings.COLOR
		inst.Thickness = RadarRings.THICKNESS
		inst.Transparency = RadarRings.TRANSPARENCY
		inst.Parent = s.folder
		s.lines[s.used] = inst
		l = inst
	end
	l.CFrame = CFrame.lookAt(a, b)
	l.Length = math.max((b - a).Magnitude, 0.01)
	l.Visible = true
end

function RadarRings.step(s: State, world: World.World, now: number)
	if now - s.at < RadarRings.REBUILD then
		return
	end
	s.at = now
	local circles = Ranges.radarFacilities(world)
	local keys = table.create(#circles)
	for i, c in circles do
		keys[i] = `{c.owner}:{math.floor(c.x / RadarRings.MOVE_STEP)}:{math.floor(c.z / RadarRings.MOVE_STEP)}:{c.r}`
	end
	local key = table.concat(keys, ",")
	if key == s.key then
		return
	end
	s.key = key
	s.used = 0
	local polylines = Ranges.polylines(Ranges.union(circles), function(x, z)
		return World.groundY(world, x, z)
	end)
	for _, pl in polylines do
		local prev: Vector3? = nil
		for _, pt in pl.points do
			local p = pt :: any
			local v = if typeof(p) == "Vector3" then p else Vector3.new(p[1], p[2], p[3])
			if prev then
				line(s, prev, v)
			end
			prev = v
		end
	end
	for i = s.used + 1, #s.lines do
		if s.lines[i].Visible then
			s.lines[i].Visible = false
		end
	end
end

return RadarRings
