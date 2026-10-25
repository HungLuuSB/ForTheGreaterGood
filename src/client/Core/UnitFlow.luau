--!strict
-- What one unit adds to or takes from its team's economy right now, per
-- second (the unit panel's "+5" / "−10", the user's request, C-125; made
-- and used apart, green and red, F9). The
-- wire has no per-unit flow, so this follows the sim's rules from the defs
-- and what the client knows:
--   production       generators, solar (def.production)
--   wind             the turbine's max × the team's current wind (Eco)
--   extractor        rate × every deposit value under its footprint
--   converter        while on: power in, supply out
--   upkeep           radar / jammer / tracking drain (while on, if switchable)
--   building         a factory with a queue, or a builder next to an own
--                    unfinished frame: the item's cost × its buildpower ÷
--                    the item's build time, slowed by the team's stall
-- Unfinished units yield nothing. Pure Luau (C-7).

local Layers = require("@shared/Grid/Layers")
local PlacementRules = require("@shared/Grid/PlacementRules")
local World = require("./World")

local UnitFlow = {}

UnitFlow.REACH = 16 -- studs past a builder's range at which a frame counts as its work (Waypoints' rule)

export type Context = {
	queue: { number }?, -- a factory's queue (def indices), Api.state.factoryQueues
	wind: number?, -- 0..1, Api.state.economy.wind
	ratio: number?, -- 0..1, the slower of the team's supply / power stall ratios
}

-- The own unfinished frame a builder `u` is working on (nearest within its
-- range), or nil.
function UnitFlow.buildTarget(world: World.World, u: World.Unit, def: any): World.Unit?
	local range = (def.buildRange or 0) + UnitFlow.REACH
	local best, bestD = nil, range * range
	for _, s in world.units do
		if s ~= u and s.team == u.team and s.build and s.build < 1 then
			local d = (s.x - u.x) ^ 2 + (s.z - u.z) ^ 2
			if d <= bestD then
				best, bestD = s, d
			end
		end
	end
	return best
end

-- The deposit values under `def`'s footprint at (x, z).
local function depositsUnder(world: World.World, def: any, x: number, z: number): number
	local layers = world.layers
	if layers == nil then
		return 0
	end
	local g = world.grid
	local x0, z0 = PlacementRules.snap(g, def.footprint, x, z)
	local sum = 0
	for cz = z0, z0 + def.footprint - 1 do
		for cx = x0, x0 + def.footprint - 1 do
			if g:inBounds(cx, cz) then
				sum += Layers.getSupply(layers, g:index(cx, cz))
			end
		end
	end
	return sum
end

export type Parts = { supplyIn: number, supplyOut: number, powerIn: number, powerOut: number }

-- What unit `u` of `def` makes and uses per second, each resource apart
-- (all ≥ 0): the panel shows "+make" green and "−use" red (F9, the user).
function UnitFlow.parts(world: World.World, u: World.Unit, def: any, ctx: Context): Parts
	local out: Parts = { supplyIn = 0, supplyOut = 0, powerIn = 0, powerOut = 0 }
	if (u.build or 1) < 1 then
		return out -- a frame: nothing until finished
	end
	local on = bit32.band(u.state or 0, 2) ~= 0 -- TOGGLED_ON
	local p = def.production
	if p then
		out.supplyIn += p.supply or 0
		out.powerIn += p.power or 0
	end
	if def.wind and def.wind.max then
		out.powerIn += def.wind.max * (ctx.wind or 0)
	end
	if def.extractor then
		out.supplyIn += def.extractor.rate * depositsUnder(world, def, u.x, u.z)
	end
	if def.converter and on then
		out.powerOut += def.converter.power or 0
		out.supplyIn += def.converter.supply or 0
	end
	local s = def.sensors or {}
	local upkeep = (s.trackDrain or 0) + (s.jamDrain or 0) + (s.radarDrain or 0)
	local switchable = def.toggle ~= nil or def.retract ~= nil
	if upkeep > 0 and (on or not switchable) then
		out.powerOut += upkeep
	end
	-- building: the item's cost at this unit's buildpower
	local bp = def.buildPower or 0
	if bp > 0 then
		local item = nil
		local q = ctx.queue
		if q and #q > 0 then
			item = world.defs.unitByIndex[q[1]]
		elseif def.domain ~= "structure" then
			local frame = UnitFlow.buildTarget(world, u, def)
			item = frame and World.def(world, frame)
		end
		local cost = item and item.cost
		if cost and (cost.buildTime or 0) > 0 then
			local rate = bp / cost.buildTime * (ctx.ratio or 1)
			out.supplyOut += (cost.supply or 0) * rate
			out.powerOut += (cost.power or 0) * rate
		end
	end
	return out
end

-- Supply and power per second for unit `u` of `def`, net (positive: income).
function UnitFlow.of(world: World.World, u: World.Unit, def: any, ctx: Context): (number, number)
	local f = UnitFlow.parts(world, u, def, ctx)
	return f.supplyIn - f.supplyOut, f.powerIn - f.powerOut
end

-- "+5", "−10", "0": a flow for the panel (whole numbers from 10 up).
function UnitFlow.text(v: number): string
	if math.abs(v) < 0.05 then
		return "0"
	end
	local a = math.abs(v)
	local body = if a >= 10 then string.format("%d", math.floor(a + 0.5)) else string.format("%.1f", a)
	return (if v > 0 then "+" else "−") .. body
end

UnitFlow.GAIN = "#5AD25A" -- green: made (the user: green positive, red negative)
UnitFlow.COST = "#E0574E" -- red: used
UnitFlow.NONE = "#8C929C" -- neither

-- One resource's line as RichText: `mark` (its coloured sign), then "+made"
-- green and "−used" red, each only when there is some; a dim "0" for none.
function UnitFlow.rich(mark: string, made: number, used: number): string
	local parts = { mark }
	if math.abs(made) >= 0.05 then
		table.insert(parts, `<font color="{UnitFlow.GAIN}">{UnitFlow.text(made)}</font>`)
	end
	if math.abs(used) >= 0.05 then
		table.insert(parts, `<font color="{UnitFlow.COST}">{UnitFlow.text(-used)}</font>`)
	end
	if #parts == 1 then
		table.insert(parts, `<font color="{UnitFlow.NONE}">0</font>`)
	end
	return table.concat(parts, " ")
end

return UnitFlow
