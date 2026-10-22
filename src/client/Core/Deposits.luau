--!strict
-- Supply deposits as the client shows them (the user's deposit brief,
-- C-123): one per deposit cell, with its value, who holds it (a known
-- structure standing on its cell: built over, or a remembered ghost), the
-- look variant and rotation (C's deposit models, picked from the cell so
-- every client draws the same), and the yield text for the BAR-style
-- overlay. Render/Deposits, the overlay and the minimap read this. Pure
-- Luau (C-7).

local Layers = require("@shared/Grid/Layers")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Deposits = {}

export type Deposit = {
	cell: number, -- grid index
	cx: number,
	cz: number,
	x: number, -- the cell's center (studs)
	z: number,
	supply: number, -- the layer's value (an extractor yields rate × this)
}

-- A holder: the team whose structure stands on the deposit, and whether it
-- is only remembered (a ghost: drawn dim, the deposit not hidden).
export type Holder = { team: number, ghost: boolean, id: number }

-- Every deposit of the map, in cell order.
function Deposits.list(layers: Layers.Layers): { Deposit }
	local g = layers.grid
	local out = {}
	for cz = 0, g.cellsZ - 1 do
		for cx = 0, g.cellsX - 1 do
			local i = g:index(cx, cz)
			local supply = Layers.getSupply(layers, i)
			if supply > 0 then
				local x, z = g:cellCenter(cx, cz)
				table.insert(out, { cell = i, cx = cx, cz = cz, x = x, z = z, supply = supply })
			end
		end
	end
	return out
end

-- Who holds each deposit (by its index in `list`; free ones absent): known
-- structures cover their footprint, a ghost without a known type its cell.
-- A live structure wins over a ghost on the same cell.
function Deposits.holders(world: World.World, list: { Deposit }): { [number]: Holder }
	local g = world.grid
	local byCell: { [number]: Holder } = {}
	for id, u in world.units do
		local def = World.def(world, u)
		local ghost = bit32.band(u.flags or 0, Schema.StrategicFlag.GHOST) ~= 0
		if def and def.domain == "structure" then
			local x0, z0 = PlacementRules.snap(g, def.footprint, u.x, u.z)
			for cz = z0, z0 + def.footprint - 1 do
				for cx = x0, x0 + def.footprint - 1 do
					if g:inBounds(cx, cz) then
						local i = g:index(cx, cz)
						local was = byCell[i]
						if was == nil or (was.ghost and not ghost) then
							byCell[i] = { team = u.team, ghost = ghost, id = id }
						end
					end
				end
			end
		elseif def == nil and ghost then
			local cx, cz = g:cellAt(u.x, u.z)
			if g:inBounds(cx, cz) then
				local i = g:index(cx, cz)
				byCell[i] = byCell[i] or { team = u.team, ghost = true, id = id }
			end
		end
	end
	local out: { [number]: Holder } = {}
	for k, d in list do
		local h = byCell[d.cell]
		if h then
			out[k] = h
		end
	end
	return out
end

-- The look of deposit `d` among `variants` models: a variant (1..variants)
-- and a rotation in degrees, both from the cell, so every client agrees.
function Deposits.look(d: Deposit, variants: number): (number, number)
	local h = (d.cx * 73856093 + d.cz * 19349663) % 1000003
	return (h % math.max(variants, 1)) + 1, (h // 7) % 360
end

-- The overlay's text: what an extractor of `rate` takes from `d` per
-- second, or the deposit's value when no extractor is in hand.
function Deposits.yieldText(d: Deposit, rate: number?): string
	if rate then
		local v = rate * d.supply
		return if v >= 10 then string.format("+%d", math.floor(v + 0.5)) else string.format("+%.1f", v)
	end
	return string.format("%g", d.supply)
end

return Deposits
