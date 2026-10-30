--!strict
-- Air transports on the client (S-219, protocol 43; C-272): who fits in
-- which transport, what each has on board, as `docs/design/transports.md`
-- and the server's Transport.canCarry. The server decides; this only picks
-- who a right click or a Load order goes to, and fills the unit panel.
-- Pure Luau (C-7).

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Transports = {}

local US = Schema.UnitState
local NO_LIFT = bit32.bor(US.DEPLOYED, US.DEPLOYING, US.SUBMERGED) -- a deployed Warden, a submerged unit

export type Spec = { slots: number, maxUnits: number, maxTier: number, maxFootprint: number }
export type Carried = { id: number, def: any? } -- def nil when the client never saw the unit

-- Its transport spec, or nil when `def` carries nothing.
function Transports.spec(def: any?): Spec?
	return if def then def.transport else nil
end

-- The slots a unit of `def` takes: footprint 1 takes 1, 2 takes 2, 3 takes 4.
function Transports.slotsOf(def: any): number
	local fp = def.footprint or 1
	return if fp <= 1 then 1 elseif fp == 2 then 2 else 4
end

-- What transport `t` has on board (its CARGO), in loading order.
function Transports.cargoOf(world: World.World, t: World.Unit): { Carried }
	local out = {}
	for i, id in t.cargo or {} do
		local index = t.cargoDefs and t.cargoDefs[i]
		table.insert(out, { id = id, def = if index then world.defs.unitByIndex[index] else nil })
	end
	return out
end

-- Slots in use on `t` (a unit the client never saw counts as one).
function Transports.used(world: World.World, t: World.Unit): number
	local n = 0
	for _, c in Transports.cargoOf(world, t) do
		n += if c.def then Transports.slotsOf(c.def) else 1
	end
	return n
end

-- Whether transport `t` can pick up unit `u` now, as the server's rule:
-- an allied finished ground unit, not a transport or a shield carrier, of
-- tier and footprint the transport takes, not deployed or submerged, with
-- room left.
function Transports.fits(world: World.World, t: World.Unit, u: World.Unit): boolean
	if t.id == u.id then
		return false
	end
	local spec = Transports.spec(World.def(world, t))
	local ud = World.def(world, u)
	if spec == nil or ud == nil or (t.build and t.build < 1) or (u.build and u.build < 1) then
		return false
	end
	local rel = World.relation(world, u)
	if (rel ~= "own" and rel ~= "ally") or World.relation(world, t) ~= "own" then
		return false
	end
	if ud.domain ~= "ground" or ud.transport ~= nil or ud.shield ~= nil then
		return false
	end
	if (ud.tier or 1) > spec.maxTier or (ud.footprint or 1) > spec.maxFootprint then
		return false
	end
	if bit32.band(u.state or 0, NO_LIFT) ~= 0 then
		return false
	end
	if #(t.cargo or {}) >= spec.maxUnits then
		return false
	end
	return Transports.used(world, t) + Transports.slotsOf(ud) <= spec.slots
end

-- The units of `ids` that are own transports.
function Transports.among(world: World.World, ids: { number }): { number }
	local out = {}
	for _, id in ids do
		local u = world.units[id]
		if u and u.team == world.me.team and Transports.spec(World.def(world, u)) then
			table.insert(out, id)
		end
	end
	return out
end

-- Whether every unit of `ids` is an own transport (the L / U keys then
-- mean Load / Unload: transports have no fire state or switch).
function Transports.only(world: World.World, ids: { number }): boolean
	return #ids > 0 and #Transports.among(world, ids) == #ids
end

-- The panel's line for transport `t`, or nil: "Cargo 2 / 4: Lancer, Commander".
function Transports.line(world: World.World, t: World.Unit): string?
	local spec = Transports.spec(World.def(world, t))
	if spec == nil then
		return nil
	end
	local names = {}
	for _, c in Transports.cargoOf(world, t) do
		table.insert(names, if c.def then c.def.name else "?")
	end
	local head = string.format("Cargo %d / %d", Transports.used(world, t), spec.slots)
	return if #names > 0 then head .. ": " .. table.concat(names, ", ") else head .. ": empty"
end

return Transports
