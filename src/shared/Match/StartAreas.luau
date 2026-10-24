--!strict
-- Start areas for "choose" start positions (S-169, the user: a map's starts
-- are suggestions; up to 16 players on any map). Shared by the sim, which
-- checks each pick, and the client, which draws the areas. Pure Luau.
--
--   * Sides: the match's ally teams, in ascending order, share out the map's
--     starts in contiguous blocks: with A sides and S starts, side k gets
--     starts floor((k-1)·S/A)+1 .. floor(k·S/A). So on a 2v2 map (starts
--     1-2 west, 3-4 east) two sides get one half each, and four sides one
--     start each. Never more sides than starts.
--   * A side's start area: every point nearer one of its starts than to any
--     other side's start (ties go to the lower start index).
--   * Suggestions: a side's k-th player (by player ID) is offered start
--     ((k-1) mod n)+1 of its n, then rings SPACING apart around it.
--   * Picks keep SPACING studs from every other player's pick.

local StartAreas = {}

StartAreas.SPACING = 48 -- studs between two players' starts

export type Sides = {
	allies: { number }, -- the sides (ally teams), ascending
	startsOf: { [number]: { number } }, -- ally team → its start indices (1-based, ascending)
	sideOfStart: { [number]: number }, -- start index → its ally team
}

-- Shares `startCount` starts among `allyTeams` (any order; duplicates ignored).
-- Errors when there are more sides than starts.
function StartAreas.sides(allyTeams: { number }, startCount: number): Sides
	local allies: { number } = {}
	for _, a in allyTeams do
		if table.find(allies, a) == nil then
			table.insert(allies, a)
		end
	end
	table.sort(allies)
	local n = #allies
	if n == 0 or n > startCount then
		error(`StartAreas.sides: {n} sides for {startCount} starts`, 2)
	end
	local startsOf: { [number]: { number } } = {}
	local sideOfStart: { [number]: number } = {}
	for k, a in allies do
		local first, last = (k - 1) * startCount // n + 1, k * startCount // n
		local list = {}
		for i = first, last do
			table.insert(list, i)
			sideOfStart[i] = a
		end
		startsOf[a] = list
	end
	return { allies = allies, startsOf = startsOf, sideOfStart = sideOfStart }
end

-- The side whose start area holds (x, z): the side of the nearest start.
-- `starts` are the map's { x, z } in start order (Layers.starts).
function StartAreas.sideAt(sides: Sides, starts: { { number } }, x: number, z: number): number?
	local best, bestD = nil :: number?, math.huge
	for i, s in starts do
		local side = sides.sideOfStart[i]
		if side ~= nil then
			local d = (s[1] - x) ^ 2 + (s[2] - z) ^ 2
			if d < bestD then
				best, bestD = side, d
			end
		end
	end
	return best
end

-- The suggested spot for the `k`-th player of side `ally` (1-based) on
-- `ring` 0, 1, 2...: ring 0 is the start itself; ring r offers 6r points
-- on a circle of r · SPACING (the first toward +x, counter-clockwise).
-- Returns the start's { x, z } and the points to try, in order.
function StartAreas.suggestions(sides: Sides, starts: { { number } }, ally: number, k: number, rings: number): { { number } }
	local own = sides.startsOf[ally]
	assert(own and #own > 0, "StartAreas.suggestions: unknown side")
	local start = starts[own[(k - 1) % #own + 1]]
	local out = { { start[1], start[2] } }
	for r = 1, rings do
		local n = 6 * r
		for j = 0, n - 1 do
			local a = j / n * 2 * math.pi
			table.insert(out, { start[1] + math.cos(a) * r * StartAreas.SPACING, start[2] + math.sin(a) * r * StartAreas.SPACING })
		end
	end
	return out
end

-- Does (x, z) keep SPACING from every pick in `picks` (player → { x, z }),
-- `self` aside?
function StartAreas.spaced(picks: { [number]: { number } }, self: number, x: number, z: number): boolean
	for pid, p in picks do
		if pid ~= self and (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < StartAreas.SPACING ^ 2 then
			return false
		end
	end
	return true
end

return table.freeze(StartAreas)
