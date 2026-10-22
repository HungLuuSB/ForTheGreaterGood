--!strict
-- Unit order queues (data only; logic in Orders.luau; S-4). Kept apart so
-- Types can describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local OrdersState = {}

export type Kind = "move" | "fight" | "patrol" | "attack" | "guard" | "repair" | "reclaim" | "build" | "attackGround"

export type Order = {
	kind: Kind,
	batch: number, -- the command it came from: units starting a move together go as a group
	x: number?, -- move / fight / patrol / build / attackGround: the point
	z: number?,
	lx: number?, -- line formation end (move-like orders)
	lz: number?,
	ox: number?, -- patrol: the other end (where the unit was when it started)
	oz: number?,
	target: number?, -- attack / guard / repair: unit ID; reclaim: wreck ID
	gen: number?, -- the target unit's generation (D109); for attack, a ghost's if remembered dead
	defIndex: number?, -- build
	facing: number?,
	started: boolean,
	held: boolean?, -- attack-move / patrol: its hold was checked at least once (S-107)
	nav: number, -- Nav order ID of the move this order issued (0 = none)
	gx: number?, -- chase moves (attack, guard): where the last move was aimed
	gz: number?,
	issued: number, -- tick of the last chase move
	auto: boolean?, -- given by the unit's move state, not a player (S-34): any command replaces it
}

-- One of a factory's orders for the units it produces (S-95).
export type RallyOrder = {
	kind: Kind, -- move, fight, patrol, guard, repair or attack
	x: number?,
	z: number?,
	lx: number?,
	lz: number?,
	target: number?,
	gen: number?,
}

export type OrdersState = {
	queue: { [number]: { Order } }, -- unit → its orders, head first
	hold: { [number]: boolean }, -- engaged while on a fight / patrol move: Movement brakes and keeps the order
	forced: { [number]: number }, -- unit → its attack order's target (Targeting prefers it)
	forcedGen: { [number]: number },
	manual: { [number]: number }, -- unit → its last attack order's target: preferred whenever in range, until STOP (S-115)
	manualGen: { [number]: number },
	rally: { [number]: { RallyOrder } }, -- factory → the orders each unit it produces takes, in order (S-95)
	repeatOn: { [number]: boolean }, -- factory → finished items go back to the end of the queue
	anchorX: { [number]: number }, -- idle units: the spot a Maneuver unit returns to (S-34)
	anchorZ: { [number]: number },
	nextBatch: number,
}

function OrdersState.new(): OrdersState
	return {
		queue = {},
		hold = {},
		forced = {},
		forcedGen = {},
		manual = {},
		manualGen = {},
		rally = {},
		repeatOn = {},
		anchorX = {},
		anchorZ = {},
		nextBatch = 1,
	}
end

function OrdersState.clearUnit(o: OrdersState, id: number)
	o.queue[id] = nil
	o.hold[id] = nil
	o.forced[id] = nil
	o.forcedGen[id] = nil
	o.manual[id] = nil
	o.manualGen[id] = nil
	o.rally[id] = nil
	o.repeatOn[id] = nil
	o.anchorX[id] = nil
	o.anchorZ[id] = nil
end

local KIND_CODE: { [string]: number } = { move = 1, fight = 2, patrol = 3, attack = 4, guard = 5, repair = 6, reclaim = 7, build = 8, attackGround = 9 }

-- Hash over units in `ids` (ascending).
function OrdersState.hash(o: OrdersState, ids: { number }, h: number): number
	for _, id in ids do
		local q = o.queue[id]
		if q then
			h = Hash.u32(Hash.u32(h, id), #q)
			for _, ord in q do
				h = Hash.u32(h, KIND_CODE[ord.kind])
				h = Hash.u32(h, ord.batch)
				h = Hash.number(Hash.number(h, ord.x or 0), ord.z or 0)
				h = Hash.number(Hash.number(h, ord.ox or 0), ord.oz or 0)
				h = Hash.u32(Hash.u32(h, ord.target or 0), ord.gen or 0)
				h = Hash.u32(h, ord.defIndex or 0)
				h = Hash.u32(Hash.u32(h, if ord.started then 1 else 0), ord.nav)
				h = Hash.u32(h, ord.issued)
				h = Hash.u32(h, if ord.auto then 1 else 0)
			end
		end
		h = Hash.u32(h, if o.hold[id] then 1 else 0)
		h = Hash.u32(Hash.u32(h, o.forced[id] or 0), o.forcedGen[id] or 0)
		h = Hash.u32(Hash.u32(h, o.manual[id] or 0), o.manualGen[id] or 0)
		local rally = o.rally[id]
		if rally then
			h = Hash.u32(h, #rally)
			for _, r in rally do
				h = Hash.u32(h, KIND_CODE[r.kind])
				h = Hash.number(Hash.number(h, r.x or 0), r.z or 0)
				h = Hash.number(Hash.number(h, r.lx or 0), r.lz or 0)
				h = Hash.u32(Hash.u32(h, r.target or 0), r.gen or 0)
			end
		end
		h = Hash.u32(h, if o.repeatOn[id] then 1 else 0)
		if o.anchorX[id] then
			h = Hash.number(Hash.number(h, o.anchorX[id]), o.anchorZ[id])
		end
	end
	return Hash.u32(h, o.nextBatch)
end

return OrdersState
