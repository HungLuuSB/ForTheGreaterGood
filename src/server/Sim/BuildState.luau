--!strict
-- Construction state per unit (data only; logic in Build.luau). Kept apart
-- so Types can describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local BuildState = {}

export type PendingBuild = { defIndex: number, x: number, z: number, facing: number }

export type BuildState = {
	order: { [number]: PendingBuild }, -- mobile builder → structure it is on its way to start
	target: { [number]: number }, -- builder → unit it is building / assisting (0 = none)
	targetGen: { [number]: number }, -- its generation (D109)
	assist: { [number]: boolean }, -- builder's target is a factory's production (not a frame)
	repair: { [number]: boolean }, -- builder's target is a finished, damaged unit to heal (S-4)
	reclaim: { [number]: number }, -- builder → wreck it is reclaiming (0 = none)
	queue: { [number]: { number } }, -- factory → def indices waiting (head is in production)
	progress: { [number]: number }, -- factory → progress of the head item, 0..1
	upgrading: { [number]: number }, -- frame → the structure it upgrades in place (S-108)
	upgradingGen: { [number]: number }, -- its generation (D109)
	-- produced unit → { factory x, z, half size, exit x, z, factory } while it
	-- drives out through its factory's footprint from the build pad; the
	-- factory waits until its pad is clear (S-133)
	exiting: { [number]: { number } },
}

BuildState.MAX_QUEUE = 50

function BuildState.new(): BuildState
	return { order = {}, target = {}, targetGen = {}, assist = {}, repair = {}, reclaim = {}, queue = {}, progress = {}, upgrading = {}, upgradingGen = {}, exiting = {} }
end

-- Forgets everything about one unit (it was removed from the world).
function BuildState.clearUnit(b: BuildState, id: number)
	b.order[id] = nil
	b.target[id] = nil
	b.targetGen[id] = nil
	b.assist[id] = nil
	b.repair[id] = nil
	b.reclaim[id] = nil
	b.queue[id] = nil
	b.progress[id] = nil
	b.upgrading[id] = nil
	b.upgradingGen[id] = nil
	b.exiting[id] = nil
end

-- Clears a builder's work (MOVE / STOP / new task).
function BuildState.idle(b: BuildState, id: number)
	b.order[id] = nil
	b.target[id] = nil
	b.targetGen[id] = nil
	b.assist[id] = nil
	b.repair[id] = nil
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
		h = Hash.u32(Hash.u32(h, b.target[id] or 0), b.targetGen[id] or 0)
		h = Hash.u32(h, b.reclaim[id] or 0)
		h = Hash.u32(h, if b.repair[id] then 1 else 0)
		local q = b.queue[id]
		if q then
			h = Hash.u32(h, #q)
			for _, d in q do
				h = Hash.u32(h, d)
			end
			h = Hash.number(h, b.progress[id] or 0)
		end
		local up = b.upgrading[id]
		if up then
			h = Hash.u32(Hash.u32(h, up), b.upgradingGen[id] or 0) -- (S-108)
		end
		local e = b.exiting[id]
		if e then
			for _, v in e do
				h = Hash.number(h, v) -- (S-133)
			end
		end
	end
	return h
end

return BuildState
