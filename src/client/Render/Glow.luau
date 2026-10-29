--!strict
-- Drives the unit glow parts (C-103, docs/contracts/fx.md "Unit glow"):
-- each drawn model's glow parts (tag `Glow`, attributes GlowChannel and
-- GlowStrength) are found once when the model is drawn, and their
-- SurfaceAppearance.EmissiveStrength follows Core/Glow: power dims on an
-- energy stall, factories pulse while producing, a `pulse` piece's glow
-- (GlowPiece, Core/PieceMotion) breathes, weapons flash per shot,
-- unfinished units stay dark. Only changed values are written.
-- A `pulse` piece also swells and shrinks with its breath (C-257): the
-- piece and every part welded to it are resized about the piece's pivot
-- (sizes and joint offsets times Core/Glow.scale), near the camera only.
-- Headlights: a pool of shadowless SpotLights on the nearest on-screen
-- vehicles with `head` glow parts, at close zoom or under the night and
-- dusk atmospheres, capped by the graphics light budget. Client only.

local CollectionService = game:GetService("CollectionService")

local CoreGlow = require("../Core/Glow")
local PieceMotion = require("../Core/PieceMotion")
local Atmosphere = require("./Atmosphere")

local Glow = {}

Glow.MAX_HEADLIGHTS = 12 -- SettingsMenu: the quality's light budget
Glow.LEVEL = "high" -- SettingsMenu: "off" | "low" | "high" (Core/Glow)
Glow.HEADLIGHTS = true -- SettingsMenu: the Headlights setting
Glow.HEAD_NEAR = 220 -- camera distance within which headlights always show
Glow.HEAD_REFRESH = 0.25 -- seconds between choosing which vehicles get lights
Glow.HEAD_COLOR = Color3.fromRGB(255, 236, 205) -- the contract's head tint
Glow.HEAD_BRIGHTNESS = 2.5
Glow.HEAD_RANGE = 36
Glow.HEAD_ANGLE = 55
Glow.RATIO_OVERRIDE = nil :: number? -- debug (Invoke("glowratio", r)): pretend the team's power ratio is r
Glow.PULSE_NEAR = 450 -- studs from the camera within which pulse pieces change size
Glow.PULSE_STEP = 0.003 -- smaller size changes aren't written

export type Part = { sa: SurfaceAppearance, channel: string, rest: number, shown: number, pulsing: boolean }
-- One resized part of a pulse piece: its resting size, and the joint that
-- holds it with that joint's resting offset (Motor6D C1 for the piece
-- itself, Weld C0 for what's welded on).
type Scaled = { part: BasePart, size: Vector3, joint: JointInstance?, rest: CFrame, c1: boolean }
export type Pulse = { parts: { Scaled }, attachments: { { at: Attachment, rest: Vector3 } }, shown: number }

-- The `pulse` pieces of `def`, by name (nil: none).
local function pulsePieces(def: any?): { [string]: boolean }?
	if def == nil then
		return nil
	end
	local out: { [string]: boolean }? = nil
	for _, m in PieceMotion.forDef(def) do
		if m.motion == "pulse" then
			out = out or {}
			(out :: any)[m.piece] = true
		end
	end
	return out
end

-- The glow parts of a model of `def` and its headlight parts (nil when it
-- has none: blockouts).
function Glow.collect(model: Model, def: any?): ({ Part }?, { BasePart }?)
	local out: { Part } = {}
	local heads: { BasePart } = {}
	local pulses = pulsePieces(def)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (CollectionService:HasTag(d, "Glow") or d:GetAttribute("GlowChannel") ~= nil) then
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			local channel = d:GetAttribute("GlowChannel")
			if sa and type(channel) == "string" then
				local rest = d:GetAttribute("GlowStrength")
				local r = if type(rest) == "number" then rest else sa.EmissiveStrength
				local piece = d:GetAttribute("GlowPiece")
				local pulsing = pulses ~= nil and type(piece) == "string" and pulses[piece] == true
				table.insert(out, { sa = sa, channel = channel, rest = r, shown = sa.EmissiveStrength, pulsing = pulsing })
				if channel == "head" then
					table.insert(heads, d)
				end
			end
		end
	end
	return (if #out > 0 then out else nil), (if #heads > 0 then heads else nil)
end

-- The pulse pieces of a model of `def`, each with every part welded to it
-- (nil: none).
function Glow.collectPulses(model: Model, def: any?): { Pulse }?
	local pulses = pulsePieces(def)
	if pulses == nil then
		return nil
	end
	local welded: { [BasePart]: { Weld } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Part0 and d.Part1 then
			local list = welded[d.Part0] or {}
			table.insert(list, d)
			welded[d.Part0] = list
		end
	end
	local out: { Pulse } = {}
	for name in pulses do
		local piece = model:FindFirstChild(name, true)
		if piece == nil or not piece:IsA("BasePart") then
			continue
		end
		local motor = piece:FindFirstChildOfClass("Motor6D")
		local pulse: Pulse = { parts = {}, attachments = {}, shown = 1 }
		table.insert(pulse.parts, { part = piece, size = piece.Size, joint = motor, rest = if motor then motor.C1 else CFrame.identity, c1 = true })
		local queue = { piece }
		while #queue > 0 do
			local part = table.remove(queue) :: BasePart
			for _, a in part:GetChildren() do
				if a:IsA("Attachment") then
					table.insert(pulse.attachments, { at = a, rest = a.Position })
				end
			end
			for _, w in welded[part] or {} do
				local p1 = w.Part1 :: BasePart
				table.insert(pulse.parts, { part = p1, size = p1.Size, joint = w, rest = w.C0, c1 = false })
				table.insert(queue, p1)
			end
		end
		table.insert(out, pulse)
	end
	return if #out > 0 then out else nil
end

-- Resizes a pulse piece to `k` × its rest about its pivot.
local function scalePulse(pulse: Pulse, k: number)
	for _, s in pulse.parts do
		s.part.Size = s.size * k
		local joint = s.joint
		if joint then
			local offset = CFrame.new(s.rest.Position * k) * s.rest.Rotation
			if s.c1 then
				(joint :: Motor6D).C1 = offset
			else
				(joint :: Weld).C0 = offset
			end
		end
	end
	for _, a in pulse.attachments do
		a.at.Position = a.rest * k
	end
	pulse.shown = k
end

-- Back to resting strength and size, headlight off (the model goes back to
-- the pool).
function Glow.reset(parts: { Part }?, root: BasePart?, pulses: { Pulse }?)
	for _, pulse in pulses or {} do
		if pulse.shown ~= 1 then
			scalePulse(pulse, 1)
		end
	end
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
	c.level = Glow.LEVEL
	local models, parts, writes = 0, 0, 0
	local eye = camera.CFrame.Position
	for id, d in renderer.drawn do
		local glows, pulses = d.glows, d.pulses
		local u = world.units[id]
		if (glows or pulses) and u then
			models += 1
			c.built = (u.build or 1) >= 1
			c.ratio = if u.team == myTeam then ratio else 1
			c.producing = u.queue ~= nil and #u.queue > 0
			c.retracted = d.def.retract ~= nil and bit32.band(u.state or 0, 2) == 0 -- TOGGLED_ON clear (S-96)
			local shot = state.lastShot[id]
			c.sinceShot = if shot then now - shot else math.huge
			c.phase = (id * 0.618) % 1
			if pulses then
				local k = if (d.root.Position - eye).Magnitude < Glow.PULSE_NEAR then CoreGlow.scale(c) else 1
				for _, pulse in pulses do
					if math.abs(pulse.shown - k) >= Glow.PULSE_STEP or (k == 1 and pulse.shown ~= 1) then
						scalePulse(pulse, k)
						writes += 1
					end
				end
			end
			for _, p in glows or {} do
				parts += 1
				local target = CoreGlow.strength(p.channel, p.rest, c, p.pulsing)
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
		chooseHeadlights(state, renderer, world, camera, focusX, focusZ, Glow.HEADLIGHTS and (distance < Glow.HEAD_NEAR or name == "night" or name == "dusk"))
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
