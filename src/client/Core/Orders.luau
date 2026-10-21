--!strict
-- Turns player intent into Cmd payloads (guide 15.6, net.md section 9):
-- the smart right-click, line moves, stop, states. Every command is split
-- into chunks of at most Schema.MAX_UNITS_PER_COMMAND units. Pure Luau (C-7).

local Formation = require("@shared/Grid/Formation")
local Packer = require("@shared/Net/Packer")
local PlacementRules = require("@shared/Grid/PlacementRules")
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

-- Goal point per unit of a line move from (x1, z1) to (x2, z2), for drawing
-- (C-11): the server's own formation functions (Shared/Grid/Formation,
-- S-12): rows of slots along the line, deepest row first, each slot taking
-- the closest unassigned unit. Without the server's open-ground callback,
-- so on blocked terrain the drawn goals can differ.
function Orders.lineSlots(world: World.World, ids: { number }, x1: number, z1: number, x2: number, z2: number): { [number]: { number } }
	local members, maxFootprint, sumX, sumZ = {}, 1, 0, 0
	local posX, posZ = {}, {}
	for _, id in ids do
		local u = world.units[id]
		if u then
			table.insert(members, id)
			local def = World.def(world, u)
			maxFootprint = math.max(maxFootprint, if def then def.footprint else 1)
			sumX += u.x
			sumZ += u.z
			posX[id], posZ[id] = u.x, u.z
		end
	end
	local out = {}
	local n = #members
	if n == 0 then
		return out
	end
	local backX, backZ = sumX / n, sumZ / n
	local spacing = Formation.spacing(maxFootprint * PlacementRules.RADIUS_PER_FOOTPRINT)
	local slots = Formation.layout(n, spacing, x1, z1, x2, z2, backX, backZ)
	Formation.deepestFirst(slots, (x1 + x2) / 2, (z1 + z2) / 2, backX, backZ, spacing)
	local pick = Formation.assign(posX, posZ, members, slots)
	for i, slot in slots do
		if pick[i] ~= 0 then
			out[pick[i]] = { slot[1], slot[2] }
		end
	end
	return out
end

return Orders
