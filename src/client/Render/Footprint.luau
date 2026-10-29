--!strict
-- A planned structure's footprint as its build cells (H3): the 8-stud grid
-- cells under it as thin lines on the ground, the outline thicker, one
-- segment per cell edge so the lines follow hills. Used for the queued
-- builds (QueuedBuilds) and a dragged row's ghosts (PlacementGhost). Pooled
-- line parts; each frame of drawing is begin, lay per structure, finish.

local World = require("../Core/World")

local Footprint = {}

local CELL = 8
local LIFT = 0.14 -- studs above the ground
local OUTLINE = 0.32 -- line widths (studs)
local INNER = 0.12

export type Pool = {
	parent: Instance,
	parts: { BasePart },
	used: number,
}

function Footprint.new(parent: Instance): Pool
	return { parent = parent, parts = {}, used = 0 }
end

function Footprint.begin(pool: Pool)
	pool.used = 0
end

local function line(pool: Pool, a: Vector3, b: Vector3, width: number, color: Color3, transparency: number)
	pool.used += 1
	local p = pool.parts[pool.used]
	if p == nil then
		local made = Instance.new("Part")
		made.Name = "FootprintLine"
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
		made.Material = Enum.Material.Neon
		pool.parts[pool.used] = made
		p = made
	end
	local part = p :: BasePart
	part.Size = Vector3.new(width, 0.05, (b - a).Magnitude + width)
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	part.Color = color
	part.Transparency = transparency
	if part.Parent ~= pool.parent then
		part.Parent = pool.parent
	end
end

-- The cells of a `footprint`-cell structure centred on (cx, cz).
-- `floats`: on the water for a water structure (World.groundY).
function Footprint.lay(pool: Pool, world: World.World, cx: number, cz: number, footprint: number, color: Color3, transparency: number, floats: boolean?)
	local half = footprint * CELL / 2
	local x0, z0 = cx - half, cz - half
	local heights: { [number]: { [number]: number } } = {}
	for i = 0, footprint do
		heights[i] = {}
		for j = 0, footprint do
			heights[i][j] = World.groundY(world, x0 + i * CELL, z0 + j * CELL, floats) + LIFT
		end
	end
	local function at(i: number, j: number): Vector3
		return Vector3.new(x0 + i * CELL, heights[i][j], z0 + j * CELL)
	end
	for i = 0, footprint do
		local width = if i == 0 or i == footprint then OUTLINE else INNER
		for j = 0, footprint - 1 do
			line(pool, at(i, j), at(i, j + 1), width, color, transparency) -- along z
			line(pool, at(j, i), at(j + 1, i), width, color, transparency) -- along x
		end
	end
end

-- Parks the lines this frame didn't use.
function Footprint.finish(pool: Pool)
	for i = pool.used + 1, #pool.parts do
		local p = pool.parts[i]
		if p.Parent ~= nil then
			p.Parent = nil
		end
	end
end

return Footprint
