--!strict
-- Shield domes in the match (C-91): a Render/ShieldFx dome on every shield
-- generator the client has a SHIELD record for (protocol 24, S-79), round
-- its base, of its def's `shield.radius`. Strength is the server's charge
-- (0..1 of capacity), and the dome stands while the UP flag is set:
-- collapsing when it clears and deploying again when it returns. SHIELD_HIT
-- events (Core/Effects' `shieldHits`) light the dome they name, or the
-- nearest known dome round the point when the generator is hidden. Shells
-- in a field are stepped by Core/Effects with Shared/Combat/ShieldField.
-- The beam rises from the generator model's `beam` attachment (its blockout,
-- docs/contracts/fx.md) while the model is drawn; domes wait until
-- ShieldFx has C's meshes.

local Schema = require("@shared/Net/Schema")
local Effects = require("../Core/Effects")
local World = require("../Core/World")
local ShieldFx = require("./ShieldFx")
local UnitRenderer = require("./UnitRenderer")

local ShieldDomes = {}

local UP = Schema.ShieldFlag.UP

type Dome = { fx: ShieldFx.ShieldFx, up: boolean, x: number, y: number, z: number, radius: number, model: Model? }

-- The generator model's beam attachment, if it is drawn.
local function beamOf(model: Model?): Attachment?
	local a = if model then model:FindFirstChild("beam", true) else nil
	return if a and a:IsA("Attachment") then a else nil
end

export type State = {
	domes: { [number]: Dome },
	-- SHIELD_HITs seen (debug): totals and the last few breaches { mass, x, y, z }
	stats: { hits: number, breaches: number, lastBreaches: { { number } } },
}

function ShieldDomes.new(): State
	return { domes = {}, stats = { hits = 0, breaches = 0, lastBreaches = {} } }
end

-- Each frame, after Effects.update.
function ShieldDomes.step(s: State, world: World.World, fx: Effects.Fx, renderer: UnitRenderer.Renderer)
	if not ShieldFx.ready() then
		table.clear(fx.shieldHits)
		return
	end
	for id, d in s.domes do
		local u = world.units[id]
		if world.shields[id] == nil or u == nil or u.tier ~= "tactical" then
			d.fx:destroy()
			s.domes[id] = nil
		end
	end
	for id, sh in world.shields do
		local u = world.units[id]
		local def = if u and u.tier == "tactical" then World.def(world, u) else nil
		local radius = def and def.shield and def.shield.radius
		if u and radius then
			local up = bit32.band(sh.flags, UP) ~= 0
			local d = s.domes[id]
			local model = UnitRenderer.modelOf(renderer, id)
			if d == nil then
				local y = World.groundY(world, u.x, u.z)
				local base = Vector3.new(u.x, y, u.z)
				local f = ShieldFx.new(beamOf(model) or base, radius, nil, base)
				f:setStrength(sh.charge)
				if up then
					f:deploy(true) -- it was standing before it came into view
				end
				d = { fx = f, up = up, x = u.x, y = y, z = u.z, radius = radius, model = model }
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
		s.stats.hits += 1
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
		if d then
			d.fx:hit(Vector3.new(h.x, h.y, h.z), if h.breach then h.mass * 1.5 else h.mass)
		end
	end
	table.clear(fx.shieldHits)
end

return ShieldDomes
