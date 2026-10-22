--!strict
-- Drives the unit glow parts (C-103, docs/contracts/fx.md "Unit glow"):
-- each drawn model's glow parts (tag `Glow`, attributes GlowChannel and
-- GlowStrength) are found once when the model is drawn, and their
-- SurfaceAppearance.EmissiveStrength follows Core/Glow: power dims on an
-- energy stall, factories pulse while producing, weapons flash per shot,
-- unfinished units stay dark. Only changed values are written.
-- Headlights: a pool of shadowless SpotLights on the nearest on-screen
-- vehicles with `head` glow parts, at close zoom or under the night and
-- dusk atmospheres, capped by the graphics light budget. Client only.

local CollectionService = game:GetService("CollectionService")

local CoreGlow = require("../Core/Glow")
local Atmosphere = require("./Atmosphere")

local Glow = {}

Glow.MAX_HEADLIGHTS = 12 -- SettingsMenu: the quality's light budget
Glow.HEAD_NEAR = 220 -- camera distance within which headlights always show
Glow.HEAD_REFRESH = 0.25 -- seconds between choosing which vehicles get lights
Glow.HEAD_COLOR = Color3.fromRGB(255, 236, 205) -- the contract's head tint
Glow.HEAD_BRIGHTNESS = 2.5
Glow.HEAD_RANGE = 36
Glow.HEAD_ANGLE = 55
Glow.RATIO_OVERRIDE = nil :: number? -- debug (Invoke("glowratio", r)): pretend the team's power ratio is r

export type Part = { sa: SurfaceAppearance, channel: string, rest: number, shown: number }

-- The glow parts of a model and its headlight parts (nil when it has
-- none: blockouts).
function Glow.collect(model: Model): ({ Part }?, { BasePart }?)
	local out: { Part } = {}
	local heads: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (CollectionService:HasTag(d, "Glow") or d:GetAttribute("GlowChannel") ~= nil) then
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			local channel = d:GetAttribute("GlowChannel")
			if sa and type(channel) == "string" then
				local rest = d:GetAttribute("GlowStrength")
				local r = if type(rest) == "number" then rest else sa.EmissiveStrength
				table.insert(out, { sa = sa, channel = channel, rest = r, shown = sa.EmissiveStrength })
				if channel == "head" then
					table.insert(heads, d)
				end
			end
		end
	end
	return (if #out > 0 then out else nil), (if #heads > 0 then heads else nil)
end

-- Back to resting strength, headlight off (the model goes back to the pool).
function Glow.reset(parts: { Part }?, root: BasePart?)
	local headlight = root and root:FindFirstChild("FtggHeadlight")
	if headlight then
		headlight.Parent = nil -- chosen again (or not) at the next refresh
	end
	for _, p in parts or {} do
		if p.shown ~= p.rest then
			p.sa.EmissiveStrength = p.rest
			p.shown = p.rest
		end
	end
end

type Light = { attachment: Attachment, light: SpotLight, unit: number? }

export type State = {
	lastShot: { [number]: number }, -- unit id → time of its last shot
	lights: { Light },
	nextChoose: number,
	ctx: CoreGlow.Context,
	stats: { models: number, parts: number, writes: number, ms: number, headlights: number },
}

function Glow.new(): State
	return {
		lastShot = {},
		lights = {},
		nextChoose = 0,
		ctx = { built = true, ratio = 1, producing = false, sinceShot = math.huge, now = 0, phase = 0 },
		stats = { models = 0, parts = 0, writes = 0, ms = 0, headlights = 0 },
	}
end

-- This frame's shots (Effects' fx.shots: { unitId, slot }).
function Glow.shots(state: State, shots: { { number } }, now: number)
	for _, s in shots do
		state.lastShot[s[1]] = now
	end
end

local function light(state: State, i: number): Light
	local l = state.lights[i]
	if l == nil then
		local attachment = Instance.new("Attachment")
		attachment.Name = "FtggHeadlight"
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Shadows = false
		spot.Color = Glow.HEAD_COLOR
		spot.Brightness = Glow.HEAD_BRIGHTNESS
		spot.Range = Glow.HEAD_RANGE
		spot.Angle = Glow.HEAD_ANGLE
		spot.Parent = attachment
		l = { attachment = attachment, light = spot, unit = nil }
		state.lights[i] = l
	end
	return l
end

-- Puts the headlights on the nearest on-screen vehicles with head glow.
local function chooseHeadlights(state: State, renderer: any, world: any, camera: Camera, focusX: number, focusZ: number, on: boolean)
	local picks: { { id: number, d2: number } } = {}
	if on and Glow.MAX_HEADLIGHTS > 0 then
		for id, d in renderer.drawn do
			if d.heads and d.root.Parent then
				local u = world.units[id]
				if u and (u.build or 1) >= 1 then
					local p = d.root.Position
					local _, visible = camera:WorldToViewportPoint(p)
					if visible then
						local dx, dz = p.X - focusX, p.Z - focusZ
						table.insert(picks, { id = id, d2 = dx * dx + dz * dz })
					end
				end
			end
		end
		table.sort(picks, function(a, b)
			return a.d2 < b.d2
		end)
	end
	local n = math.min(#picks, Glow.MAX_HEADLIGHTS)
	for i = 1, n do
		local id = picks[i].id
		local d = renderer.drawn[id]
		local u = world.units[id]
		local l = light(state, i)
		local at = Vector3.zero
		for _, part in d.heads do
			at += part.Position
		end
		at /= #d.heads
		local forward = Vector3.new(math.sin(u.heading), -0.25, math.cos(u.heading))
		l.attachment.Parent = d.root
		l.attachment.WorldCFrame = CFrame.lookAt(at, at + forward)
		l.light.Enabled = true
		l.unit = id
	end
	for i = n + 1, #state.lights do
		local l = state.lights[i]
		if l.unit then
			l.light.Enabled = false
			l.attachment.Parent = nil
			l.unit = nil
		end
	end
	state.stats.headlights = n
end

-- Once a frame while models are shown (not at strategic zoom).
function Glow.step(state: State, renderer: any, world: any, now: number, camera: Camera, focusX: number, focusZ: number, distance: number)
	local t0 = os.clock()
	local eco = world.economy
	local ratio = Glow.RATIO_OVERRIDE or (if eco then eco.power.ratio / 255 else 1)
	local myTeam = world.me.team
	local c = state.ctx
	c.now = now
	local models, parts, writes = 0, 0, 0
	for id, d in renderer.drawn do
		local glows = d.glows
		local u = world.units[id]
		if glows and u then
			models += 1
			c.built = (u.build or 1) >= 1
			c.ratio = if u.team == myTeam then ratio else 1
			c.producing = u.queue ~= nil and #u.queue > 0
			local shot = state.lastShot[id]
			c.sinceShot = if shot then now - shot else math.huge
			c.phase = (id * 0.618) % 1
			for _, p in glows do
				parts += 1
				local target = CoreGlow.strength(p.channel, p.rest, c)
				if CoreGlow.changed(p.shown, target) then
					p.sa.EmissiveStrength = target
					p.shown = target
					writes += 1
				end
			end
			if shot and now - shot > CoreGlow.FLASH_SECONDS then
				state.lastShot[id] = nil
			end
		end
	end
	if now >= state.nextChoose then
		state.nextChoose = now + Glow.HEAD_REFRESH
		local name = Atmosphere.active
		chooseHeadlights(state, renderer, world, camera, focusX, focusZ, distance < Glow.HEAD_NEAR or name == "night" or name == "dusk")
	end
	local s = state.stats
	s.models, s.parts, s.writes, s.ms = models, parts, writes, (os.clock() - t0) * 1000
end

-- Strategic zoom hides the models: lights off.
function Glow.hide(state: State)
	for _, l in state.lights do
		if l.unit then
			l.light.Enabled = false
			l.attachment.Parent = nil
			l.unit = nil
		end
	end
	state.nextChoose = 0
end

return Glow
