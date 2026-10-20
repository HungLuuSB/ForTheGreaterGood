--!strict
-- Construction state per unit (data only; logic in Build.luau). Kept apart
-- so Types can describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local BuildState = {}

export type PendingBuild = { defIndex: number, x: number, z: number, facing: number }

export type BuildState = {
	order: { [number]: PendingBuild }, -- mobile builder → structure it is on its way to start
	target: { [number]: number }, -- builder → unit it is building / assisting (0 = none)
	assist: { [number]: boolean }, -- builder's target is a factory's production (not a frame)
	reclaim: { [number]: number }, -- builder → wreck it is reclaiming (0 = none)
	queue: { [number]: { number } }, -- factory → def indices waiting (head is in production)
	progress: { [number]: number }, -- factory → progress of the head item, 0..1
}

BuildState.MAX_QUEUE = 50

function BuildState.new(): BuildState
	return { order = {}, target = {}, assist = {}, reclaim = {}, queue = {}, progress = {} }
end

-- Forgets everything about one unit (it was removed from the world).
function BuildState.clearUnit(b: BuildState, id: number)
	b.order[id] = nil
	b.target[id] = nil
	b.assist[id] = nil
	b.reclaim[id] = nil
	b.queue[id] = nil
	b.progress[id] = nil
end

-- Clears a builder's work (MOVE / STOP / new task).
function BuildState.idle(b: BuildState, id: number)
	b.order[id] = nil
	b.target[id] = nil
	b.assist[id] = nil
	b.reclaim[id] = nil
end

-- Hash over units in `ids` (ascending), so it's independent of table order.
function BuildState.hash(b: BuildState, ids: { number }, h: number): number
	for _, id in ids do
		local o = b.order[id]
		if o then
			h = Hash.u32(Hash.u32(h, id), o.defIndex)
			h = Hash.number(Hash.number(h, o.x), o.z)
		end
		h = Hash.u32(h, b.target[id] or 0)
		h = Hash.u32(h, b.reclaim[id] or 0)
		local q = b.queue[id]
		if q then
			h = Hash.u32(h, #q)
			for _, d in q do
				h = Hash.u32(h, d)
			end
			h = Hash.number(h, b.progress[id] or 0)
		end
	end
	return h
end

return BuildState
