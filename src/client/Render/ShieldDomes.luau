--!strict
-- Shield domes in the match (C-91): a Render/ShieldFx dome on every shield
-- generator the client has a SHIELD record for (protocol 24, S-79), round
-- its base, of its def's `shield.radius`. Strength is the server's charge
-- (0..1 of capacity), and the dome stands while the UP flag is set:
-- collapsing when it clears and deploying again when it returns. SHIELD_HIT
-- events (Core/Effects' `shieldHits`) light the dome they name, or the
-- nearest known dome round the point when the generator is hidden. Shells
-- in a field are stepped by Core/Effects with Shared/Combat/ShieldField.

local Schema = require("@shared/Net/Schema")
local Effects = require("../Core/Effects")
local World = require("../Core/World")
local ShieldFx = require("./ShieldFx")

local ShieldDomes = {}

local UP = Schema.ShieldFlag.UP

type Dome = { fx: ShieldFx.ShieldFx, up: boolean, x: number, y: number, z: number, radius: number }

export type State = { domes: { [number]: Dome } }

function ShieldDomes.new(): State
	return { domes = {} }
end

-- Each frame, after Effects.update.
function ShieldDomes.step(s: State, world: World.World, fx: Effects.Fx)
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
			if d == nil then
				local y = World.groundY(world, u.x, u.z)
				local f = ShieldFx.new(Vector3.new(u.x, y, u.z), radius)
				f:setStrength(sh.charge)
				if up then
					f:deploy(true) -- it was standing before it came into view
				end
				d = { fx = f, up = up, x = u.x, y = y, z = u.z, radius = radius }
				s.domes[id] = d
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
