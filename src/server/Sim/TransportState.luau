--!strict
-- Air transports' cargo (data only; logic in Transport.luau; S-219). Kept
-- apart so Types can describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local TransportState = {}

export type TransportState = {
	cargo: { [number]: { number } }, -- transport → the units on board, in loading order
	carrier: { [number]: number }, -- carried unit → its transport (0 once the transport is gone: it dies)
	loading: { [number]: number }, -- transport → ticks spent picking up / setting down the unit it is on now
	slow: { [number]: number }, -- loaded transport → its top speed's share (1 - SLOW_PER_SLOT × slots used)
	busy: { [number]: number }, -- transport → the unit it is picking up or setting down now (S-220)
	dropX: { [number]: number }, -- transport → where it sets that unit down (chosen at the start, S-220)
	dropZ: { [number]: number },
}

function TransportState.new(): TransportState
	return { cargo = {}, carrier = {}, loading = {}, slow = {}, busy = {}, dropX = {}, dropZ = {} }
end

-- Hash over transports in `ids` (ascending), so it's independent of table order.
function TransportState.hash(t: TransportState, ids: { number }, h: number): number
	for _, id in ids do
		local cargo = t.cargo[id]
		if cargo then
			h = Hash.u32(Hash.u32(h, id), #cargo)
			for _, u in cargo do
				h = Hash.u32(h, u)
			end
		end
		local loading = t.loading[id]
		if loading then
			h = Hash.u32(Hash.u32(h, loading), t.busy[id] or 0)
			local dx = t.dropX[id]
			if dx then
				h = Hash.number(Hash.number(h, dx), t.dropZ[id] :: number)
			end
		end
	end
	return h
end

return TransportState
