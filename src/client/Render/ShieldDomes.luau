--!strict
-- Shield domes in the match (C-91): a Render/ShieldFx dome on every shield
-- generator the client has a SHIELD record for (protocol 24, S-79), round
-- its base, of its def's `shield.radius`. Strength is the server's charge
-- (0..1 of capacity), and the dome stands while the UP flag is set:
-- collapsing when it clears and deploying again when it returns. A shell
-- crossing the surface (Core/Effects' "enter" hits) lights the dome at once;
-- the server's turn (SHIELD_HIT, deep inside) doesn't light it again, a
-- breach does, and so does a light shell destroyed at the surface ("absorb"). Hits go to the dome they name, else the nearest one round
-- the point. Shells
-- in a field are stepped by Core/Effects with Shared/Combat/ShieldField.
-- The beam rises from the generator model's `beam` attachment (its blockout,
-- docs/contracts/fx.md) while the model is drawn; domes wait until
-- ShieldFx has C's meshes.
--
-- Shells in a field burn like a meteor entering the atmosphere (C-97, the
-- user's drawing): a glowing bow shock, C's dome mesh flattened into a cap,
-- curved round the shell's nose on the side the field pushes from, and a
-- burning trail behind it, both as strong as the force (Core/ShieldLook.
-- force: the field step's change of velocity over a tick). A fixed pool of
-- PLUMES, made once.

local Schema = require("@shared/Net/Schema")
local ShieldField = require("@shared/Combat/ShieldField")
local ShieldLook = require("../Core/ShieldLook")
local Effects = require("../Core/Effects")
local World = require("../Core/World")
local ShieldFx = require("./ShieldFx")
local UnitRenderer = require("./UnitRenderer")

local ShieldDomes = {}

local UP = Schema.ShieldFlag.UP
ShieldDomes.PLUMES = 32 -- force plumes at once (the fixed pool)

type Plume = { beam: Beam, at: Attachment, tip: Attachment, cap: MeshPart? }

ShieldDomes.SHOCK_COLOR = Color3.fromRGB(255, 226, 180) -- white-hot, a little orange
ShieldDomes.TRAIL_COLOR = ColorSequence.new(Color3.fromRGB(255, 240, 215), Color3.fromRGB(255, 130, 50))

type Dome = { fx: ShieldFx.ShieldFx, up: boolean, x: number, y: number, z: number, radius: number, model: Model? }

-- The generator model's beam attachment, if it is drawn.
local function beamOf(model: Model?): Attachment?
	local a = if model then model:FindFirstChild("beam", true) else nil
	return if a and a:IsA("Attachment") then a else nil
end

export type State = {
	domes: { [number]: Dome },
	-- SHIELD_HITs seen (debug): totals and the last few breaches { mass, x, y, z }
	stats: { hits: number, breaches: number, lastBreaches: { { number } }, enters: number, lit: number, lagSum: number, lagN: number, enteredAt: { [number]: number } },
	plumes: { Plume }, -- made on first use
	plumesShown: number,
	capFolder: Folder?,
}

function ShieldDomes.new(): State
	return { domes = {}, stats = { hits = 0, breaches = 0, lastBreaches = {}, enters = 0, lit = 0, lagSum = 0, lagN = 0, enteredAt = {} }, plumes = {}, plumesShown = 0, capFolder = nil }
end

local function makePlumes(s: State)
	local holder = workspace.Terrain
	local folder = Instance.new("Folder")
	folder.Name = "ShieldShocks"
	folder.Parent = workspace
	s.capFolder = folder
	for _ = 1, ShieldDomes.PLUMES do
		local at = Instance.new("Attachment")
		at.Name = "ShieldForce"
		at.Parent = holder
		local tip = Instance.new("Attachment")
		tip.Name = "ShieldForceTip"
		tip.Parent = holder
		local beam = Instance.new("Beam")
		beam.Attachment0 = at
		beam.Attachment1 = tip
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Brightness = 3
		beam.Color = ShieldDomes.TRAIL_COLOR
		beam.Texture = ShieldFx.ASSETS.beam
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 4
		beam.TextureSpeed = 3 -- streaming back off the shell
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) })
		beam.Width1 = 0.3
		beam.Segments = 2
		beam.Enabled = false
		beam.Parent = holder
		-- the bow shock: C's dome mesh as a flat cap (none until the meshes load)
		local cap = ShieldFx.cloneMesh("dome")
		if cap then
			cap.Name = "ShieldShock"
			cap.Anchored, cap.CanCollide, cap.CanQuery, cap.CanTouch, cap.CastShadow = true, false, false, false, false
			cap.Material = Enum.Material.Neon
			cap.Color = ShieldDomes.SHOCK_COLOR
			cap.Transparency = 1
			cap.Parent = s.capFolder
		end
		table.insert(s.plumes, { beam = beam, at = at, tip = tip, cap = cap })
	end
end

-- Each frame after Effects.visible: the force plumes on shells in a field
-- (`drawn`: { proj, x, y, z } entries).
function ShieldDomes.forces(s: State, drawn: { { any } })
	if #s.plumes == 0 and not ShieldFx.ready() then
		return -- the pool waits for C's dome mesh (the bow shock)
	end
	local used = 0
	local caps: { BasePart } = {}
	local capFrames: { CFrame } = {}
	for _, e in drawn do
		local p = e[1]
		local n = p.nextState
		if p.field and n and used < ShieldDomes.PLUMES then
			local w = p.weapon
			local dx, dy, dz, size = ShieldLook.force(p.vx, p.vy, p.vz, n[4], n[5], n[6], w.gravity or 0)
			if size > 0 then
				if #s.plumes == 0 then
					makePlumes(s)
				end
				used += 1
				local plume = s.plumes[used]
				local at = Vector3.new(e[2], e[3], e[4])
				local push = Vector3.new(dx, dy, dz) -- the field's force: out of the dome, against the shot
				local mass = math.min(ShieldField.mass(w), 4)
				local heat = math.clamp(ShieldLook.plume(size) / ShieldLook.PLUME_MAX, 0.25, 1)
				-- the burning trail streams back from the shell, along the force
				plume.at.WorldPosition = at
				plume.tip.WorldPosition = at + push * ShieldLook.plume(size)
				plume.beam.Width0 = 1.2 + 0.5 * mass
				plume.beam.Enabled = true
				-- the bow shock: a cap curved round the nose, its pole into the push
				local cap = plume.cap
				if cap then
					local r = (1.3 + 0.5 * mass) * (0.7 + 0.3 * heat)
					cap.Size = Vector3.new(2 * r, 0.7 * r, 2 * r)
					local up = -push
					local right = if math.abs(up.Y) < 0.95 then up:Cross(Vector3.yAxis).Unit else up:Cross(Vector3.xAxis).Unit
					-- its rim sits just behind the nose, its pole a little ahead
					table.insert(caps, cap)
					table.insert(capFrames, CFrame.fromMatrix(at + up * (0.15 * r), right, up))
					cap.Transparency = 1 - 0.75 * heat
				end
			end
		end
	end
	if #caps > 0 then
		workspace:BulkMoveTo(caps, capFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for i = used + 1, s.plumesShown do
		local plume = s.plumes[i]
		plume.beam.Enabled = false
		if plume.cap then
			plume.cap.Transparency = 1
		end
	end
	s.plumesShown = used
end

-- Each frame, after Effects.update.
function ShieldDomes.step(s: State, world: World.World, fx: Effects.Fx, renderer: UnitRenderer.Renderer)
	if not ShieldFx.ready() then
		table.clear(fx.shieldHits)
		return
	end
	-- every dome to draw: generators the player has (SHIELD), and the others'
	-- domes the server sends whatever the team sees (DOME, S-122, C-145)
	local sources: { [number]: { x: number, z: number, y: number?, radius: number, charge: number, flags: number } } = {}
	for id, rd in world.remoteDomes do
		sources[id] = rd
	end
	for id, sh in world.shields do
		local u = world.units[id]
		local def = if u and u.tier == "tactical" then World.def(world, u) else nil
		local radius = def and def.shield and def.shield.radius
		if u and radius then
			sources[id] = { x = u.x, z = u.z, radius = radius, charge = sh.charge, flags = sh.flags }
		end
	end
	for id, d in s.domes do
		if sources[id] == nil then
			d.fx:destroy()
			s.domes[id] = nil
		end
	end
	for id, sh in sources do
		do
			local radius = sh.radius
			local up = bit32.band(sh.flags, UP) ~= 0
			local d = s.domes[id]
			local model = UnitRenderer.modelOf(renderer, id)
			if d == nil then
				local y = sh.y or World.groundY(world, sh.x, sh.z)
				local base = Vector3.new(sh.x, y, sh.z)
				local f = ShieldFx.new(beamOf(model) or base, radius, nil, base)
				f:setStrength(sh.charge)
				if up then
					f:deploy(true) -- it was standing before it came into view
				end
				d = { fx = f, up = up, x = sh.x, y = y, z = sh.z, radius = radius, model = model }
				s.domes[id] = d
			elseif model ~= d.model then
				-- the generator's model came into view, went, or was swapped
				d.model = model
				d.fx:setEmitter(beamOf(model))
			end
			d.fx:setStrength(sh.charge)
			if up ~= d.up then
				d.up = up
				if up then
					d.fx:deploy()
				else
					d.fx:collapse()
				end
			end
		end
	end
	for _, h in fx.shieldHits do
		local st = s.stats
		if h.kind == "enter" then
			st.enters += 1
			st.enteredAt[h.projId] = h.tick
		else
			st.hits += 1
			local at = st.enteredAt[h.projId]
			if at then
				-- ticks from the shell's entry to its turn (debug)
				st.lagSum += h.tick - at
				st.lagN += 1
			end
		end
		if h.breach then
			s.stats.breaches += 1
			table.insert(s.stats.lastBreaches, { h.mass, h.x, h.y, h.z })
			if #s.stats.lastBreaches > 10 then
				table.remove(s.stats.lastBreaches, 1)
			end
		end
		local d = s.domes[h.unitId]
		if d == nil then
			-- a generator the client doesn't have: the nearest dome round the point
			local best = math.huge
			for _, o in s.domes do
				local dist = math.sqrt((h.x - o.x) ^ 2 + (h.y - o.y) ^ 2 + (h.z - o.z) ^ 2) - o.radius
				if math.abs(dist) < 8 and math.abs(dist) < best then
					best, d = math.abs(dist), o
				end
			end
		end
		-- a turn lights the dome only for a shell that never showed entering
		-- (destroyed on contact, or one whose SHIELD_FIELD the client missed)
		local entered = h.kind == "turn" and st.enteredAt[h.projId] ~= nil
		if h.kind ~= "enter" then
			st.enteredAt[h.projId] = nil -- done with this shell
		end
		if d and not entered then
			d.fx:hit(Vector3.new(h.x, h.y, h.z), if h.breach then h.mass * 1.5 else h.mass)
			st.lit += 1
		end
	end
	table.clear(fx.shieldHits)
end

return ShieldDomes
