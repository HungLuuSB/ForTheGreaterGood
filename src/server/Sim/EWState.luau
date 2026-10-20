--!strict
-- Countermeasure state per unit (data only; logic in EW.luau). Kept apart so
-- Types can describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local EWState = {}

export type EWState = {
	flares: { [number]: number }, -- charges left (units whose def has flares)
	chaff: { [number]: number }, -- charges left (units whose def has chaff)
	dircmCooldown: { [number]: number }, -- seconds until DIRCM can engage again (0 = ready)
}

function EWState.new(): EWState
	return { flares = {}, chaff = {}, dircmCooldown = {} }
end

function EWState.clearUnit(e: EWState, id: number)
	e.flares[id] = nil
	e.chaff[id] = nil
	e.dircmCooldown[id] = nil
end

-- Hash over units in `ids` (ascending).
function EWState.hash(e: EWState, ids: { number }, h: number): number
	for _, id in ids do
		local flares, chaff, cooldown = e.flares[id], e.chaff[id], e.dircmCooldown[id]
		if flares or chaff or cooldown then
			h = Hash.u32(h, id)
			h = Hash.u32(h, flares or 0xFFFF)
			h = Hash.u32(h, chaff or 0xFFFF)
			h = Hash.number(h, cooldown or -1)
		end
	end
	return h
end

return EWState
