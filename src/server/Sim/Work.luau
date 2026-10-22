--!strict
-- Deterministic work counters (S-99, next.md item 9): how much the hot
-- loops did, next to the noisy wall-clock timings in `lune run stress` and
-- `lune run profile_normandy`, so a change's effect shows without timing
-- noise. Process-wide (tools run one sim at a time), never hashed, and
-- nothing in the simulation reads them.
--   routeWork        Route.runSearch: heap pops and neighbour checks
--   flowWork         FlowField.run: cells settled and relaxed
--   sensorLookups    Sensors.level calls
--   knownLookups     Sensors.knownTarget calls

local Work = {}

Work.counts = {
	routeWork = 0,
	flowWork = 0,
	sensorLookups = 0,
	knownLookups = 0,
}

function Work.reset()
	for k in Work.counts do
		Work.counts[k] = 0
	end
end

-- A copy of the counts now.
function Work.snapshot(): { [string]: number }
	return table.clone(Work.counts)
end

return Work
