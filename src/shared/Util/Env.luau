--!strict
-- Detects which runtime is hosting the code. This and the other Util adapters
-- (Profiler, Log) are the only modules allowed to branch on the runtime.

export type Runtime = "roblox" | "lune" | "luau"

-- Lune reports "Lune <version>+<luau version>"; Roblox and the plain Luau CLI
-- both report "Luau". debug.profilebegin is a Roblox-only extension, which tells
-- those two apart without touching Roblox globals.
local isLune = string.find(_VERSION, "^Lune") ~= nil
local isRoblox = not isLune and (debug :: any).profilebegin ~= nil

local runtime: Runtime = if isRoblox then "roblox" elseif isLune then "lune" else "luau"

return table.freeze({
	runtime = runtime,
	isRoblox = isRoblox,
	isLune = isLune,
})
