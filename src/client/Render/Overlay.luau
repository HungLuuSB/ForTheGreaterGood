--!strict
-- Order feedback in the world (guide 15.6): rings under selected units,
-- their order lines (from the client's waypoints) colored by kind, a
-- preview of a right-drag line move, and a short flash where an order
-- went. Pooled parts in workspace.Overlay; positions are set each frame.

local Schema = require("@shared/Net/Schema")
local Api = require("../Api")
local Targets = require("../Core/Targets")
local World = require("../Core/World")

local Overlay = {}

local CT = Schema.CmdType
local RING_COLOR = Color3.fromRGB(110, 235, 120)
local KIND_COLOR: { [number]: Color3 } = {
	[CT.MOVE] = Color3.fromRGB(110, 235, 120),
	[CT.FIGHT] = Color3.fromRGB(235, 150, 60),
	[CT.PATROL] = Color3.fromRGB(90, 180, 235),
	[CT.ATTACK] = Color3.fromRGB(235, 70, 60),
	[CT.ATTACK_GROUND] = Color3.fromRGB(235, 70, 60),
	[CT.GUARD] = Color3.fromRGB(90, 140, 235),
	[CT.REPAIR] = Color3.fromRGB(235, 220, 80),
	[CT.RECLAIM] = Color3.fromRGB(200, 120, 235),
	[CT.BUILD] = Color3.fromRGB(235, 220, 80),
	[CT.AREA] = Color3.fromRGB(200, 120, 235), -- Smart Reclaim's zone (S-183), the reclaim colour
}
local FLASH_SECONDS = 0.6
local LIFT = 0.15 -- studs above the ground

export type Overlay = {
	folder: Folder,
	pools: { [string]: { BasePart } },
	used: { [string]: number },
	flashes: { { x: number, z: number, color: Color3, born: number } },
}

local function newPart(kind: string): BasePart
	local p = Instance.new("Part")
	p.Name = kind
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "ring" or kind == "flash" or kind == "dot" then
		p.Shape = Enum.PartType.Cylinder
	end
	return p
end

function Overlay.new(): Overlay
	local folder = Instance.new("Folder")
	folder.Name = "Overlay"
	folder.Parent = workspace
	return { folder = folder, pools = {}, used = {}, flashes = {} }
end

local function take(o: Overlay, kind: string): BasePart
	local pool = o.pools[kind]
	if pool == nil then
		pool = {}
		o.pools[kind] = pool
	end
	local n = (o.used[kind] or 0) + 1
	o.used[kind] = n
	local p = pool[n]
	if p == nil then
		p = newPart(kind)
		pool[n] = p
	end
	p.Parent = o.folder
	return p
end

-- A flat disc of diameter `d` lying on the ground (cylinders run along X).
local function disc(p: BasePart, x: number, y: number, z: number, d: number, color: Color3, transparency: number)
	p.Size = Vector3.new(0.12, d, d)
	p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
	p.Color = color
	p.Transparency = transparency
end

local function segment(o: Overlay, a: Vector3, b: Vector3, color: Color3)
	local d = b - a
	local len = d.Magnitude
	if len < 0.5 then
		return
	end
	local p = take(o, "line")
	p.Size = Vector3.new(0.35, 0.08, len)
	p.CFrame = CFrame.lookAt(a + d / 2, b)
	p.Color = color
	p.Transparency = 0.25
end

-- Hooks the order flashes. Call once.
function Overlay.bind(o: Overlay, api: Api.Api, now: () -> number)
	api.changed.orders:Connect(function(intent)
		if intent.cmdType == CT.STOP or intent.value ~= nil then
			return
		end
		local x, z = intent.x, intent.z
		if intent.targetId then
			local t = api.world.units[intent.targetId]
			if t then
				x, z = t.rx or t.x, t.rz or t.z
			end
		end
		if x then
			table.insert(o.flashes, { x = x, z = z :: number, color = KIND_COLOR[intent.cmdType] or RING_COLOR, born = now() })
		end
	end)
end

-- Draws this frame's overlay. `line` = a right-drag preview { from, to }.
function Overlay.step(o: Overlay, api: Api.Api, now: number, lineFrom: Vector3?, lineTo: Vector3?)
	table.clear(o.used)
	local world = api.world
	local function groundY(x: number, z: number): number
		return World.groundY(world, x, z) + LIFT
	end
	-- where a unit's ring and lines go: at an aircraft's drawn height (its
	-- ground point can line up with another unit on screen, C-38), else
	-- on the ground
	local function drawnY(u: World.Unit, x: number, z: number): number
		if u.ry and u.alt > 0 then
			return u.ry + LIFT
		end
		return groundY(x, z)
	end

	for _, id in api.state.selection do
		local u = world.units[id]
		if u == nil then
			continue
		end
		local x, z = u.rx or u.x, u.rz or u.z
		local def = World.def(world, u)
		local d = ((def and def.footprint) or 1) * 8 * 0.95
		disc(take(o, "ring"), x, drawnY(u, x, z), z, d, RING_COLOR, 0.55)
		local list = api.waypoints.byUnit[id]
		if list then
			local from = Vector3.new(x, drawnY(u, x, z), z)
			for _, point in list do
				local to = Vector3.new(point.x, groundY(point.x, point.z), point.z)
				local color = KIND_COLOR[point.kind] or RING_COLOR
				segment(o, from, to, color)
				disc(take(o, "dot"), to.X, to.Y, to.Z, 1.4, color, 0.2)
				if point.radius then
					disc(take(o, "ring"), to.X, to.Y, to.Z, point.radius * 2, color, 0.85) -- Smart Reclaim's zone (S-183)
				end
				from = to
			end
		end
	end

	-- one unit selected: a red line to what it is shooting at (C-20)
	if #api.state.selection == 1 then
		local id = api.state.selection[1]
		local u = world.units[id]
		local target = Targets.of(world, id, api.waypoints.byUnit)
		local t = target and world.units[target]
		if u and t then
			local ux, uz, tx, tz = u.rx or u.x, u.rz or u.z, t.rx or t.x, t.rz or t.z
			local red = Color3.fromRGB(235, 60, 50)
			segment(o, Vector3.new(ux, drawnY(u, ux, uz) + 1.5, uz), Vector3.new(tx, drawnY(t, tx, tz) + 1.5, tz), red)
			local tdef = World.def(world, t)
			disc(take(o, "ring"), tx, drawnY(t, tx, tz), tz, ((tdef and tdef.footprint) or 1) * 8 * 1.1, red, 0.35)
		end
	end

	if lineFrom and lineTo then
		local a = Vector3.new(lineFrom.X, groundY(lineFrom.X, lineFrom.Z), lineFrom.Z)
		local b = Vector3.new(lineTo.X, groundY(lineTo.X, lineTo.Z), lineTo.Z)
		segment(o, a, b, KIND_COLOR[CT.MOVE])
	end

	for i = #o.flashes, 1, -1 do
		local f = o.flashes[i]
		local age = (now - f.born) / FLASH_SECONDS
		if age >= 1 then
			table.remove(o.flashes, i)
		else
			disc(take(o, "flash"), f.x, groundY(f.x, f.z), f.z, 2 + age * 6, f.color, 0.2 + age * 0.8)
		end
	end

	-- park what this frame didn't use
	for kind, pool in o.pools do
		for n = (o.used[kind] or 0) + 1, #pool do
			if pool[n].Parent ~= nil then
				pool[n].Parent = nil
			end
		end
	end
end

return Overlay
