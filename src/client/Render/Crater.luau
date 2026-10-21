--!strict
-- Nuke craters (C-82, the user's idea: terrain deformation instead of a
-- dark circle): a ground burst digs a shallow bowl into the drawn Terrain,
-- with a scorched basalt floor, a ring of scorched ground around it and a
-- raised rim. Visual only: the sim's height map doesn't change, so the bowl
-- stays shallow (units still drive at the sim's height). Each crater's area
-- is copied first and pasted back by `clear` (a new match or map). Terrain
-- ground only (Ground.MODE "terrain"); nothing in "parts" mode.

local Crater = {}

Crater.RADIUS_SHARE = 0.45 -- the bowl's radius as a share of the blast radius
Crater.MIN_RADIUS = 18
Crater.MAX_RADIUS = 90
Crater.DEPTH_SHARE = 0.07 -- the bowl's depth as a share of its radius (60 → 4.2 studs)
Crater.MAX_DEPTH = 6
Crater.SCORCH_SHARE = 1.7 -- the scorched ring's radius as a share of the bowl's
Crater.RIM_BALLS = 28
Crater.MAX_SAVED = 8 -- craters remembered for clearing; older ones stay until the map is rebuilt

local VOXEL = 4

type Saved = { region: TerrainRegion, corner: Vector3int16 }
local saved: { Saved } = {}

local function terrain(): Terrain?
	return workspace:FindFirstChildOfClass("Terrain")
end

-- The bowl's radius and depth for a blast of `blastRadius` studs.
function Crater.size(blastRadius: number): (number, number)
	local r = math.clamp(blastRadius * Crater.RADIUS_SHARE, Crater.MIN_RADIUS, Crater.MAX_RADIUS)
	return r, math.min(r * Crater.DEPTH_SHARE, Crater.MAX_DEPTH)
end

-- Digs a crater at (x, z) on ground height `groundY`. Returns false when
-- there's no Terrain to dig.
function Crater.make(x: number, groundY: number, z: number, blastRadius: number): boolean
	local t = terrain()
	if t == nil then
		return false
	end
	local r, depth = Crater.size(blastRadius)
	local outer = r * Crater.SCORCH_SHARE
	-- remember the area, voxel-aligned, so `clear` can put it back
	if #saved < Crater.MAX_SAVED then
		local lo = Vector3int16.new(math.floor((x - outer - VOXEL) / VOXEL), math.floor((groundY - depth - 12) / VOXEL), math.floor((z - outer - VOXEL) / VOXEL))
		local hi = Vector3int16.new(math.ceil((x + outer + VOXEL) / VOXEL), math.ceil((groundY + r * 0.2 + 8) / VOXEL), math.ceil((z + outer + VOXEL) / VOXEL))
		local ok, region = pcall(function()
			return t:CopyRegion(Region3int16.new(lo, hi))
		end)
		if ok and region then
			table.insert(saved, { region = region, corner = lo })
		end
	end
	-- scorched ground around, then the basalt floor, thicker in the middle
	t:FillCylinder(CFrame.new(x, groundY - 1.5, z), 3, outer, Enum.Material.Mud)
	t:FillCylinder(CFrame.new(x, groundY - 2, z), 4, r * 1.05, Enum.Material.Basalt)
	t:FillCylinder(CFrame.new(x, groundY - depth - 1, z), depth * 2 + 2, r * 0.8, Enum.Material.Basalt)
	-- the bowl: a spherical cap `depth` deep and `r` wide
	local sphere = (r * r + depth * depth) / (2 * depth)
	t:FillBall(Vector3.new(x, groundY - depth + sphere, z), sphere, Enum.Material.Air)
	-- the rim: thrown-up earth just outside the bowl, uneven (sizes and
	-- spots vary with a fixed pattern, so every client digs the same)
	local rim = math.max(3, r * 0.1)
	for i = 1, Crater.RIM_BALLS do
		local k = math.sin(i * 12.9898 + x * 0.013 + z * 0.007) * 43758.5453
		local j = k - math.floor(k) -- 0..1
		local a = (i + (j - 0.5) * 0.6) / Crater.RIM_BALLS * 2 * math.pi
		local size = rim * (0.65 + 0.7 * j)
		local dist = r * (1.0 + 0.12 * j)
		t:FillBall(Vector3.new(x + math.cos(a) * dist, groundY - size * 0.5, z + math.sin(a) * dist), size, if j > 0.6 then Enum.Material.Mud else Enum.Material.Ground)
	end
	return true
end

-- Puts back the ground under every remembered crater (newest first).
function Crater.clear()
	local t = terrain()
	if t then
		for i = #saved, 1, -1 do
			local s = saved[i]
			pcall(function()
				t:PasteRegion(s.region, s.corner, true)
			end)
		end
	end
	table.clear(saved)
end

-- Craters to put back.
function Crater.count(): number
	return #saved
end

return Crater
