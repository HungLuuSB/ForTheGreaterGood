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
}

function TransportState.new(): TransportState
	return { cargo = {}, carrier = {}, loading = {}, slow = {} }
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
			h = Hash.u32(h, loading)
		end
	end
	return h
end

return TransportState
