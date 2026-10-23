--!strict
-- The world round the battle (C-102), client only:
--   skirt    dark ground beyond the map's edge (Core/Environment's tiles),
--            so the battlefield ends on dim land fading into the haze
--   ambient  near the camera, at close zoom: dust motes drifting in the
--            moonlight and a faint low mist (built-in smoke texture, no
--            asset); off at Low quality

local CoreEnvironment = require("../Core/Environment")
local MapLook = require("../Core/MapLook")
local Layers = require("@shared/Grid/Layers")

local Environment = {}

Environment.AMBIENT = true -- SettingsMenu: off at Low quality
Environment.AMBIENT_WITHIN = 320 -- camera distance (studs) the particles run within
local BOX = Vector3.new(220, 30, 220) -- the volume the particles appear in, round the focus
local LIFT = 15 -- the box's centre above the ground
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

export type State = {
	folder: Folder,
	skirt: { BasePart },
	carrier: Part,
	dust: ParticleEmitter,
	mist: ParticleEmitter,
	on: boolean,
}

local function fade(peak: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, peak),
		NumberSequenceKeypoint.new(0.7, peak),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function inert(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- clicks go through to the map
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
end

function Environment.new(): State
	local folder = Instance.new("Folder")
	folder.Name = "FtggEnvironment"
	local carrier = Instance.new("Part")
	carrier.Name = "Ambient"
	carrier.Size = BOX
	carrier.Transparency = 1
	inert(carrier)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = SMOKE
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Rate = 40
	dust.Lifetime = NumberRange.new(6, 10)
	dust.Speed = NumberRange.new(0.5, 1.5)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Acceleration = Vector3.new(1.5, 0.1, 0.6) -- a light breeze
	dust.RotSpeed = NumberRange.new(-20, 20)
	dust.Size = NumberSequence.new(0.6)
	dust.LightEmission = 0.3
	dust.LightInfluence = 0.6
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 210, 230))
	dust.Transparency = fade(0.55)
	dust.Enabled = false
	dust.Parent = carrier
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = SMOKE
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mist.Rate = 3
	mist.Lifetime = NumberRange.new(16, 24)
	mist.Speed = NumberRange.new(0.5, 1.2)
	mist.SpreadAngle = Vector2.new(180, 0)
	mist.Acceleration = Vector3.new(0.8, 0, 0.3)
	mist.RotSpeed = NumberRange.new(-4, 4)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 55) })
	mist.LightEmission = 0
	mist.LightInfluence = 1
	mist.Color = ColorSequence.new(Color3.fromRGB(150, 160, 180))
	mist.Transparency = fade(0.92)
	mist.Enabled = false
	mist.Parent = carrier
	carrier.Parent = folder
	folder.Parent = workspace
	return { folder = folder, skirt = {}, carrier = carrier, dust = dust, mist = mist, on = false }
end

-- Lays the skirt round `layers`' map (replacing an earlier map's) and
-- gives the skirt and the particles the map's look (Core/MapLook, C-155).
function Environment.setMap(state: State, layers: Layers.Layers, look: MapLook.Look?)
	local l = look or MapLook.DEFAULT
	local function rgb(c: { number }): Color3
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	local function v3(v: { number }): Vector3
		return Vector3.new(v[1], v[2], v[3])
	end
	state.dust.Color = ColorSequence.new(rgb(l.dust.color))
	state.dust.Acceleration = v3(l.dust.wind)
	state.mist.Color = ColorSequence.new(rgb(l.mist.color))
	state.mist.Acceleration = v3(l.mist.wind)
	local skirt = rgb(l.skirt)
	for _, p in state.skirt do
		p:Destroy()
	end
	table.clear(state.skirt)
	local g = layers.grid
	local top = CoreEnvironment.edgeY(layers)
	local thick = 4
	for _, r in CoreEnvironment.skirt(g.originX, g.originZ, g.originX + g.sizeX, g.originZ + g.sizeZ) do
		local p = Instance.new("Part")
		p.Name = "Skirt"
		p.Material = Enum.Material.Ground
		p.Color = skirt
		p.Size = Vector3.new(r.x1 - r.x0, thick, r.z1 - r.z0)
		p.Position = Vector3.new((r.x0 + r.x1) / 2, top - thick / 2, (r.z0 + r.z1) / 2)
		inert(p)
		p.Parent = state.folder
		table.insert(state.skirt, p)
	end
end

-- Once a frame: the particles follow the camera's focus at close zoom.
function Environment.update(state: State, x: number, z: number, distance: number, groundY: number)
	local on = Environment.AMBIENT and distance < Environment.AMBIENT_WITHIN
	if on then
		state.carrier.CFrame = CFrame.new(x, groundY + LIFT, z)
	end
	if on ~= state.on then
		state.on = on
		state.dust.Enabled = on
		state.mist.Enabled = on
	end
end

return Environment
