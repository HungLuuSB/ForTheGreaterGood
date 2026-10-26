--!strict
-- Supply deposits as the client shows them (the user's deposit brief,
-- C-123): one per deposit patch (2 x 2 cells since S-184, at its centre),
-- with its value, who holds it (a known structure standing on it: built
-- over, or a remembered ghost), the look variant and rotation (C's deposit
-- models, picked from its cell so every client draws the same), and the yield text for the BAR-style
-- overlay. Render/Deposits, the overlay and the minimap read this. Pure
-- Luau (C-7).

local Layers = require("@shared/Grid/Layers")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Deposits = {}

export type Deposit = {
	cell: number, -- grid index of the patch's min-corner cell
	cx: number,
	cz: number,
	x: number, -- the patch's centre (studs; a cell corner)
	z: number,
	supply: number, -- the patch's value (an extractor on it yields rate × this)
}

Deposits.PATCH = 2 -- cells per side (S-184)

-- A holder: the team whose structure stands on the deposit, and whether it
-- is only remembered (a ghost: drawn dim, the deposit not hidden).
export type Holder = { team: number, ghost: boolean, id: number }

-- Every deposit patch of the map (layers.deposits, S-184), in its order.
function Deposits.list(layers: Layers.Layers): { Deposit }
	local g = layers.grid
	local out = {}
	local half = Deposits.PATCH * 4 -- studs: half a patch
	for _, d in layers.deposits or {} do
		local cx, cz = g:cellAt(d[1] - half / 2, d[2] - half / 2)
		table.insert(out, { cell = g:index(cx, cz), cx = cx, cz = cz, x = d[1], z = d[2], supply = d[3] })
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
