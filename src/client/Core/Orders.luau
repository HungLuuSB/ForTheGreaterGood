--!strict
-- Turns player intent into Cmd payloads (guide 15.6, net.md section 9):
-- the smart right-click, line moves, stop, states. Every command is split
-- into chunks of at most Schema.MAX_UNITS_PER_COMMAND units. Pure Luau (C-7).

local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Orders = {}

local CT = Schema.CmdType

export type Intent = {
	cmdType: number,
	queue: boolean,
	targetId: number?, -- unit targets
	x: number?, -- point targets
	z: number?,
	x2: number?, -- line end (LINE flag)
	z2: number?,
	value: number?, -- state commands
	defIndex: number?, -- BUILD: what to build at (x, z)
	facing: number?, -- BUILD: 0..3
}

Orders.KIND = table.freeze({
	move = CT.MOVE,
	fight = CT.FIGHT,
	attack = CT.ATTACK,
	attackGround = CT.ATTACK_GROUND,
	patrol = CT.PATROL,
	guard = CT.GUARD,
	repair = CT.REPAIR,
	reclaim = CT.RECLAIM,
})

-- The right-click rule (guide 15.6): enemy → attack; own unfinished frame →
-- repair; own or allied unit → guard; ground → move. (Wrecks aren't on the
-- wire yet, so reclaim needs an explicit order.)
function Orders.smart(world: World.World, x: number, z: number, unitId: number?, queue: boolean?): Intent
	local u = if unitId then world.units[unitId] else nil
	if u then
		if u.team ~= world.me.team then
			-- other teams' alliances aren't on the wire: only own team counts as friendly
			return { cmdType = CT.ATTACK, queue = queue == true, targetId = u.id }
		elseif u.build and u.build < 1 then
			return { cmdType = CT.REPAIR, queue = queue == true, targetId = u.id }
		else
			return { cmdType = CT.GUARD, queue = queue == true, targetId = u.id }
		end
	end
	return { cmdType = CT.MOVE, queue = queue == true, x = x, z = z }
end

-- Payloads for `intent` given to `ids` (own units; the server ignores others).
function Orders.encode(world: World.World, intent: Intent, ids: { number }): { buffer }
	local out = {}
	local g = world.grid
	local limit = Schema.MAX_UNITS_PER_COMMAND
	local i = 1
	repeat
		local chunk = table.move(ids, i, math.min(i + limit - 1, #ids), 1, {})
		local cmd: Schema.Command = {
			cmdType = intent.cmdType,
			flags = if intent.queue then Schema.CmdFlag.QUEUE else 0,
			unitIds = chunk,
		}
		if intent.targetId then
			cmd.targetId = intent.targetId
		elseif intent.defIndex then
			cmd.defIndex = intent.defIndex
			cmd.cell, cmd.offX, cmd.offZ = g:encode(intent.x :: number, intent.z :: number)
			cmd.facing = intent.facing or 0
		elseif intent.x then
			cmd.cell, cmd.offX, cmd.offZ = g:encode(intent.x, intent.z :: number)
			if intent.x2 then
				cmd.flags += Schema.CmdFlag.LINE
				cmd.cell2, cmd.offX2, cmd.offZ2 = g:encode(intent.x2, intent.z2 :: number)
			end
		elseif intent.value then
			cmd.value = intent.value
		end
		local w = Packer.Writer.new(16 + 2 * #chunk)
		Schema.encodeCommand(w, cmd)
		table.insert(out, w:finish())
		i += limit
	until i > #ids
	return out
end

-- The server's formation constants (src/server/Sim/Nav.luau; copies until
-- they're shared, see "Requests for the sim session").
Orders.SLOT_SPACING = 1.3 -- unit diameters
Orders.RADIUS_PER_FOOTPRINT = 8 * 0.45

-- Goal point per unit of a line move from (x1, z1) to (x2, z2), for drawing
-- (C-11): the server's layout (rows of evenly spaced slots, extra rows
-- stepping back toward the group's centroid), deepest row first, each slot
-- taking the closest unassigned unit, ties to the lower ID (Nav.assignSlots).
-- It skips the server's open-ground filtering, so on blocked terrain the
-- drawn goals can differ.
function Orders.lineSlots(world: World.World, ids: { number }, x1: number, z1: number, x2: number, z2: number): { [number]: { number } }
	local members, maxFootprint, sumX, sumZ = {}, 1, 0, 0
	for _, id in ids do
		local u = world.units[id]
		if u then
			table.insert(members, id)
			local def = World.def(world, u)
			maxFootprint = math.max(maxFootprint, if def then def.footprint else 1)
			sumX += u.x
			sumZ += u.z
		end
	end
	local n = #members
	local out = {}
	if n == 0 then
		return out
	end
	local backX, backZ = sumX / n, sumZ / n
	local spacing = 2 * maxFootprint * Orders.RADIUS_PER_FOOTPRINT * Orders.SLOT_SPACING
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local perRow = math.max(1, math.min(n, math.floor(len / spacing) + 1))
	local rows = math.ceil(n / perRow)
	local ux, uz = if len > 0 then dx / len else 1, if len > 0 then dz / len else 0
	local px, pz = -uz, ux
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	if (backX - cx) * px + (backZ - cz) * pz < 0 then
		px, pz = -px, -pz
	end
	local slots: { { number } } = {}
	for row = 0, rows - 1 do
		for i = 0, perRow - 1 do
			if #slots >= n then
				break
			end
			local t = if perRow == 1 then 0.5 else i / (perRow - 1)
			table.insert(slots, { x1 + dx * t + px * spacing * row, z1 + dz * t + pz * spacing * row, #slots + 1 })
		end
	end
	-- far side first, along the approach from the centroid
	local ax, az = cx - backX, cz - backZ
	local alen = math.sqrt(ax * ax + az * az)
	if alen > 1e-9 then
		ax, az = ax / alen, az / alen
	end
	local function depth(s: { number }): number
		return math.floor(((s[1] - cx) * ax + (s[2] - cz) * az) / spacing + 0.5)
	end
	table.sort(slots, function(a, b)
		local da, db = depth(a), depth(b)
		if da ~= db then
			return da > db
		end
		return a[3] < b[3]
	end)
	local free = table.clone(members)
	for _, slot in slots do
		local best, bestD, bestK = 0, math.huge, 0
		for k, id in free do
			local u = world.units[id]
			local d = (u.x - slot[1]) ^ 2 + (u.z - slot[2]) ^ 2
			if d < bestD or (d == bestD and id < best) then
				best, bestD, bestK = id, d, k
			end
		end
		out[best] = { slot[1], slot[2] }
		free[bestK] = free[#free]
		free[#free] = nil
	end
	return out
end

return Orders
