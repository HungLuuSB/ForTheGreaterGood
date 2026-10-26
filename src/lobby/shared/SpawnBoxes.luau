--!strict
-- Spawn boxes in the room (F26, L-20): each team's box on the map, which
-- the host can move and resize. Boxes are fractions of the map,
-- { x0, z0, x1, z1 } in 0..1 with x0 < x1 and z0 < z1 (0 is the map's low
-- X / low Z edge: west and north in the map preview). Defaults are the
-- match's own boxes (`@shared/Match/StartAreas`) for the room's sides, so
-- an untouched room shows what the match would use. Pure Luau.

local StartAreas = require("@shared/Match/StartAreas")

local SpawnBoxes = {}

SpawnBoxes.SNAP = 0.03 -- a side this close to the map's edge snaps to it
SpawnBoxes.MIN = 0.04 -- a box's smallest width and depth
SpawnBoxes.STEP = 1000 -- boxes are kept in thousandths

export type Box = { number } -- { x0, z0, x1, z1 }, fractions of the map
-- A map's shape in studs, for the defaults: its bounds, start hints, its
-- own boxes per start (optional) and its side splits (optional, S-186), as
-- the server reads them from the layers. The splits travel as a list
-- ({ n = side count, sides = each side's start indices }): a table keyed by
-- side counts has gaps, which a remote can drop.
export type Split = { n: number, sides: { { number } } }
export type Geometry = { bounds: { number }, starts: { { number } }, startBoxes: { { number } }?, splits: { Split }? }

-- `Layers.sideSplits` as a list for Geometry.splits.
function SpawnBoxes.splitList(sideSplits: { [number]: { { number } } }?): { Split }?
	if sideSplits == nil then
		return nil
	end
	local out: { Split } = {}
	for n, sides in sideSplits do
		table.insert(out, { n = n, sides = sides })
	end
	table.sort(out, function(a, b)
		return a.n < b.n
	end)
	return out
end

local function round(v: number): number
	return math.floor(v * SpawnBoxes.STEP + 0.5) / SpawnBoxes.STEP
end

-- Snaps a side to 0 or 1 when it's within SNAP of it.
function SpawnBoxes.snap(v: number): number
	if v <= SpawnBoxes.SNAP then
		return 0
	elseif v >= 1 - SpawnBoxes.SNAP then
		return 1
	end
	return v
end

-- A box from a request, cleaned: four numbers, sides snapped to the map's
-- edges, inside 0..1, at least MIN wide and deep. nil and why when it isn't
-- a box.
function SpawnBoxes.clean(box: any): (Box?, string?)
	if type(box) ~= "table" or #box ~= 4 then
		return nil, "Bad box"
	end
	for i = 1, 4 do
		local v = box[i]
		if type(v) ~= "number" or v ~= v or v < -0.5 or v > 1.5 then
			return nil, "Bad box"
		end
	end
	local x0, z0, x1, z1 = SpawnBoxes.snap(math.clamp(box[1], 0, 1)), SpawnBoxes.snap(math.clamp(box[2], 0, 1)), SpawnBoxes.snap(math.clamp(box[3], 0, 1)), SpawnBoxes.snap(math.clamp(box[4], 0, 1))
	if x1 - x0 < SpawnBoxes.MIN or z1 - z0 < SpawnBoxes.MIN then
		return nil, "That box is too small"
	end
	return { round(x0), round(z0), round(x1), round(z1) }, nil
end

-- The match's default boxes for `count` sides (ally teams 1..count), as
-- fractions. Empty when the map has fewer starts than sides.
function SpawnBoxes.defaults(geo: Geometry, count: number): { [number]: Box }
	if count < 1 or count > #geo.starts then
		return {}
	end
	local allies = {}
	for a = 1, count do
		table.insert(allies, a)
	end
	local splits: { [number]: { { number } } }? = nil
	if geo.splits then
		local byCount: { [number]: { { number } } } = {}
		for _, s in geo.splits do
			byCount[s.n] = s.sides
		end
		splits = byCount
	end
	local b = geo.bounds
	local w, d = b[3] - b[1], b[4] - b[2]
	local out: { [number]: Box } = {}
	for a, box in StartAreas.boxes(StartAreas.sides(allies, #geo.starts, splits), geo.starts, b, geo.startBoxes) do
		out[a] = { round((box[1] - b[1]) / w), round((box[2] - b[2]) / d), round((box[3] - b[1]) / w), round((box[4] - b[2]) / d) }
	end
	return out
end

-- The room's sides in order: its teams with a seat, ascending (Teams), the
-- same numbering as the match config's ally teams.
function SpawnBoxes.teams(slots: { { team: number } }): { number }
	local teams = {}
	for _, s in slots do
		if table.find(teams, s.team) == nil then
			table.insert(teams, s.team)
		end
	end
	table.sort(teams)
	return teams
end

-- Every side's box by room team: the host's edits (`edits`, keyed by the
-- team as a string) over the defaults.
function SpawnBoxes.forTeams(geo: Geometry?, teams: { number }, edits: { [string]: Box }?): { [number]: Box }
	local defaults = if geo then SpawnBoxes.defaults(geo, #teams) else {}
	local out: { [number]: Box } = {}
	for ally, team in teams do
		local edit = edits and edits[tostring(team)]
		out[team] = edit or defaults[ally]
	end
	return out
end

-- Did the host move or resize a box of a team that's seated?
function SpawnBoxes.touched(teams: { number }, edits: { [string]: Box }?): boolean
	if edits == nil then
		return false
	end
	for _, team in teams do
		if edits[tostring(team)] then
			return true
		end
	end
	return false
end

return SpawnBoxes
