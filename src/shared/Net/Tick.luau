--!strict
-- Wire ticks are u16: the sim tick mod 2^16. They wrap every 65,536 ticks
-- (~72.8 min at 15 Hz), so never compare them with < or >. These helpers use
-- the signed shortest distance, which is correct while the two ticks are less
-- than 32,768 ticks (~36 min) apart: always true for live packets.
-- Sim ticks themselves (replay log, World) are full integers and never wrap.

local Tick = {}

Tick.WRAP = 65536
local WRAP = 65536
local HALF = 32768

-- Sim tick (integer >= 0) → wire tick (0..65535).
function Tick.toWire(simTick: number): number
	assert(simTick >= 0 and simTick == math.floor(simTick), "Tick.toWire: sim tick must be an integer >= 0")
	return simTick % WRAP
end

-- Signed wire-tick distance a - b, in [-32768, 32767]. Exactly half a wrap
-- apart is ambiguous and reports -32768 (a counts as older).
function Tick.diff(a: number, b: number): number
	return (a - b + HALF) % WRAP - HALF
end

-- true if wire tick a is later than wire tick b.
function Tick.isNewer(a: number, b: number): boolean
	return Tick.diff(a, b) > 0
end

-- The full sim tick closest to referenceSimTick whose wire value is wireTick
-- (e.g. the client's latest known tick when stamping a snapshot).
function Tick.unwrap(wireTick: number, referenceSimTick: number): number
	return referenceSimTick + Tick.diff(wireTick, referenceSimTick % WRAP)
end

return table.freeze(Tick)
