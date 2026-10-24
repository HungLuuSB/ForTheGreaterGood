--!strict
-- Sensor effects (C-211; Core/SensorFx decides which and when): sonar
-- pings as thin cyan rings spreading over the water (pooled
-- CylinderHandleAdornments: a ring is a cylinder with an InnerRadius), and
-- jammer domes in Roblox's ForceField material, which shimmers by itself,
-- breathing slowly; a thin purple ring on the ground at the jam radius can
-- show the reach (JAM_RING, off for now). Hidden at strategic zoom with
-- the models.

local Core = require("../Core/SensorFx")
local World = require("../Core/World")

local SensorFx = {}

SensorFx.SONAR_COLOR = Color3.fromRGB(90, 200, 255)
SensorFx.JAM_COLOR = Color3.fromRGB(170, 120, 255)
SensorFx.RING_WIDTH = 3 -- studs, at least: a ring's band
SensorFx.JAM_TRANSPARENCY = 0 -- the dome at its strongest (ForceField is faint at any setting; its rim brighter)
SensorFx.JAM_BREATH = 0.35 -- how much the dome's transparency breathes
SensorFx.JAM_RING = false -- the ground ring at the jam radius: off (the user, 2026-10-24)
SensorFx.JAM_RING_TRANSPARENCY = 0.35 -- the ground ring, when on

export type State = { folder: Folder, rings: { CylinderHandleAdornment }, domes: { Part }, jamRings: { CylinderHandleAdornment } }

function SensorFx.new(): State
	local folder = Instance.new("Folder")
	folder.Name = "SensorFx"
	folder.Parent = workspace
	return { folder = folder, rings = {}, domes = {}, jamRings = {} }
end

local FLAT = CFrame.Angles(math.pi / 2, 0, 0) -- a handle cylinder's axis is its Z: turned to stand on Y

local function ring(s: State, pool: { CylinderHandleAdornment }, i: number, name: string, color: Color3): CylinderHandleAdornment
	local r = pool[i]
	if r == nil then
		local a = Instance.new("CylinderHandleAdornment")
		a.Name = name
		a.Adornee = workspace.Terrain
		a.AlwaysOnTop = false
		a.AdornCullingMode = Enum.AdornCullingMode.Never
		a.Color3 = color
		a.Height = 0.3
		a.Parent = s.folder
		pool[i] = a
		r = a
	end
	return r
end

local function dome(s: State, i: number): Part
	local d = s.domes[i]
	if d == nil then
		local p = Instance.new("Part")
		p.Name = "JammerDome"
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.ForceField
		p.Color = SensorFx.JAM_COLOR
		p.Parent = s.folder
		s.domes[i] = p
		d = p
	end
	return d
end

-- Per frame; `visible` false at strategic zoom.
function SensorFx.step(s: State, world: World.World, now: number, visible: boolean)
	local rings, domes, jamRings = 0, 0, 0
	if visible then
		for _, e in Core.emitters(world) do
			if e.kind == "sonar" then
				local p = Core.ping(e.id, now)
				if p then
					rings += 1
					local a = ring(s, s.rings, rings, "SonarPing", SensorFx.SONAR_COLOR)
					local radius = math.max(SensorFx.RING_WIDTH + 1, e.r * p)
					a.Radius = radius
					a.InnerRadius = radius - math.max(SensorFx.RING_WIDTH, e.r * 0.025)
					a.CFrame = CFrame.new(e.x, World.groundY(world, e.x, e.z, true) + 0.4, e.z) * FLAT
					a.Transparency = Core.pingTransparency(p)
					a.Visible = true
				end
			else
				domes += 1
				local d = dome(s, domes)
				d.Size = Vector3.one * (e.r * 2)
				d.CFrame = CFrame.new(e.x, World.groundY(world, e.x, e.z, true), e.z)
				local breath = Core.breath(e.id, now)
				d.Transparency = SensorFx.JAM_TRANSPARENCY + SensorFx.JAM_BREATH * breath
				if SensorFx.JAM_RING then
					jamRings += 1
					local g = ring(s, s.jamRings, jamRings, "JamRing", SensorFx.JAM_COLOR)
					g.Radius = e.r
					g.InnerRadius = e.r - math.max(2, e.r * 0.012)
					g.CFrame = CFrame.new(e.x, World.groundY(world, e.x, e.z, true) + 0.4, e.z) * FLAT
					g.Transparency = SensorFx.JAM_RING_TRANSPARENCY + 0.25 * breath
					g.Visible = true
				end
			end
		end
	end
	for i = rings + 1, #s.rings do
		if s.rings[i].Visible then
			s.rings[i].Visible = false
		end
	end
	for i = jamRings + 1, #s.jamRings do
		if s.jamRings[i].Visible then
			s.jamRings[i].Visible = false
		end
	end
	for i, d in s.domes do
		local parent = if i <= domes then s.folder else nil
		if d.Parent ~= parent then
			d.Parent = parent
		end
	end
end

return SensorFx
