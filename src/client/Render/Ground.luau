--!strict
-- Draws a map's layers (heights, water) as anchored parts in workspace.Map,
-- for maps without baked place terrain (test maps, guide 5.4). Cells merge
-- into rectangles of equal height inside 8 × 8-cell blocks, so a flat map is
-- a checkerboard of 64-stud tiles: it shows scale and motion.

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")

local Ground = {}

local BLOCK = 8 -- cells per tile side
local THICKNESS = 4

local function landColor(h: number, checker: boolean): Color3
	local t = math.clamp((h + 10) / 40, 0, 1)
	local base = Color3.fromRGB(96, 122, 74):Lerp(Color3.fromRGB(150, 140, 110), t)
	return if checker then base:Lerp(Color3.new(0, 0, 0), 0.08) else base
end

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true -- the camera and input raycast the ground
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	return p
end

-- Builds the ground for `layers` and returns its folder (replacing an old one).
function Ground.build(layers: Layers.Layers): Folder
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	local g = layers.grid
	local cell = Grid.CELL_SIZE
	local function heightAt(cx: number, cz: number): (number, number)
		local i = g:index(cx, cz)
		return Layers.getHeight(layers, i), Layers.getWater(layers, i)
	end

	for bz = 0, g.cellsZ - 1, BLOCK do
		for bx = 0, g.cellsX - 1, BLOCK do
			local checker = ((bx // BLOCK) + (bz // BLOCK)) % 2 == 1
			local maxX, maxZ = math.min(bx + BLOCK, g.cellsX) - 1, math.min(bz + BLOCK, g.cellsZ) - 1
			local done: { [number]: boolean } = {}
			for cz = bz, maxZ do
				for cx = bx, maxX do
					if done[cz * g.cellsX + cx] then
						continue
					end
					local h, water = heightAt(cx, cz)
					-- grow right, then down, while cells match
					local ex = cx
					while ex + 1 <= maxX and not done[cz * g.cellsX + ex + 1] do
						local h2, w2 = heightAt(ex + 1, cz)
						if h2 ~= h or w2 ~= water then
							break
						end
						ex += 1
					end
					local ez = cz
					local grow = true
					while grow and ez + 1 <= maxZ do
						for x = cx, ex do
							local h2, w2 = heightAt(x, ez + 1)
							if done[(ez + 1) * g.cellsX + x] or h2 ~= h or w2 ~= water then
								grow = false
								break
							end
						end
						if grow then
							ez += 1
						end
					end
					for z = cz, ez do
						for x = cx, ex do
							done[z * g.cellsX + x] = true
						end
					end
					local x0, z0 = g.originX + cx * cell, g.originZ + cz * cell
					local sx, sz = (ex - cx + 1) * cell, (ez - cz + 1) * cell
					local center = Vector3.new(x0 + sx / 2, h - THICKNESS / 2, z0 + sz / 2)
					newPart("Land", Vector3.new(sx, THICKNESS, sz), CFrame.new(center), landColor(h, checker)).Parent = folder
					if water > 0 then
						local w = newPart("Water", Vector3.new(sx, water, sz), CFrame.new(center.X, h + water / 2, center.Z), Color3.fromRGB(52, 108, 168))
						w.Transparency = 0.35
						w.CanQuery = false
						w.Parent = folder
					end
				end
			end
		end
	end

	-- supply deposits: a gold plate on each deposit cell, where an extractor
	-- must stand (brighter for richer deposits)
	for cz = 0, g.cellsZ - 1 do
		for cx = 0, g.cellsX - 1 do
			local i = g:index(cx, cz)
			local supply = Layers.getSupply(layers, i)
			if supply > 0 then
				local h = Layers.getHeight(layers, i) + Layers.getWater(layers, i)
				local x0, z0 = g.originX + cx * cell, g.originZ + cz * cell
				local plate = newPart("Deposit", Vector3.new(cell - 1.2, 0.3, cell - 1.2), CFrame.new(x0 + cell / 2, h + 0.15, z0 + cell / 2), Color3.fromRGB(235, 190, 60):Lerp(Color3.fromRGB(255, 230, 120), math.clamp((supply - 3) / 4, 0, 1)))
				plate.Material = Enum.Material.Neon
				plate.Transparency = 0.15
				plate.CanQuery = false
				plate:SetAttribute("Supply", supply)
				plate.Parent = folder
			end
		end
	end
	folder.Parent = workspace
	return folder
end

return Ground
