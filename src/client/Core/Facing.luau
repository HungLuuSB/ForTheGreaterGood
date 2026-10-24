--!strict
-- A structure's facing (C-206; BUILD `facing`, 0..3): the frame's heading
-- is facing × 90° (S-133), so its exit, build pad and drive-out point along
-- (sin h, cos h): 0 → +Z, 1 → +X, 2 → -Z, 3 → -X. Named as the player sees
-- the map: the camera looks toward -Z at yaw 0, so up (-Z) is North and
-- right (+X) is East, and facing 0 (Schema's NORTH, the default) exits
-- South, toward the camera. Pure Luau (C-7).

local Facing = {}

local NAMES = { [0] = "South", [1] = "East", [2] = "North", [3] = "West" }

-- The sim heading of a facing (radians).
function Facing.heading(f: number): number
	return (f % 4) * math.pi / 2
end

-- The exit direction (unit x, z) of a facing.
function Facing.exit(f: number): (number, number)
	local h = Facing.heading(f)
	local x, z = math.sin(h), math.cos(h)
	-- exact quarter turns
	return math.floor(x + 0.5), math.floor(z + 0.5)
end

-- "East" and so on, as seen on the map.
function Facing.name(f: number): string
	return NAMES[f % 4]
end

-- The message when the player turns the placement: BAR's wording.
function Facing.message(f: number): string
	return `Buildings set to face {Facing.name(f)}`
end

return Facing
