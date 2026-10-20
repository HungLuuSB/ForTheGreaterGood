--!strict
-- Profiler labels for the MicroProfiler, and the only sanctioned clock.
-- Gameplay logic must never read the clock (determinism); timings for
-- profiling, stress tests and logs go through Profiler.now().

local Env = require("./Env")

local Profiler = {}

local function noop(_label: string?) end

-- Roblox: debug.profilebegin/profileend. Elsewhere: no-ops, so sim systems can
-- keep their labels unconditionally.
Profiler.begin = if Env.isRoblox then (debug :: any).profilebegin :: (label: string) -> () else noop
Profiler.finish = if Env.isRoblox then (debug :: any).profileend :: () -> () else noop :: () -> ()

-- Seconds, high resolution, arbitrary origin. Profiling only.
Profiler.now = os.clock

return table.freeze(Profiler)
