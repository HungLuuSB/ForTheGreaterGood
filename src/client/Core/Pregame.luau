--!strict
-- The pre-game's logic (net.md section 9b, S-169, S-171; C-218): each
-- side's spawn box and the map's start hints, from the same module the
-- server checks picks with (Shared/Match/StartAreas); whether the viewer
-- may pick a spot; where the camera opens; the START_POS and READY
-- commands. The picks and the countdown live in World.pregame (NetIn).
-- Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local Schema = require("@shared/Net/Schema")
local StartAreas = require("@shared/Match/StartAreas")
local Commands = require("./Commands")
local World = require("./World")

local Pregame = {}

-- ticks from the match's boot (tick 0) until everyone counts as ready: the
-- server's Pregame.TIMEOUT (a spec checks they agree)
Pregame.TIMEOUT = 90 * 15

export type Hint = { x: number, z: number, ally: number }
export type Areas = {
	sides: StartAreas.Sides,
	boxes: { [number]: StartAreas.Box }, -- ally team → its spawn box
	hints: { Hint }, -- the map's starts, with the side each belongs to
	key: string, -- what they were made from (the views rebuild on a change)
}

local cache: { world: World.World?, key: string?, areas: Areas? } = { world = nil, key = nil, areas = nil }

-- The match's spawn boxes and hints, nil before the WELCOME or on a map
-- without enough starts.
function Pregame.areas(world: World.World): Areas?
	local layers = world.layers
	if layers == nil or not world.joined then
		return nil
	end
	local allies: { number } = {}
	for _, a in world.teamAllies do
		if a ~= 0 and table.find(allies, a) == nil then
			table.insert(allies, a)
		end
	end
	table.sort(allies)
	local key = `{world.mapVersion}:{table.concat(allies, ",")}`
	if cache.world == world and cache.key == key then
		return cache.areas
	end
	cache.world, cache.key, cache.areas = world, key, nil
	if #allies == 0 or #allies > #layers.starts then
		return nil
	end
	local sides = StartAreas.sides(allies, #layers.starts)
	local hints = {}
	for i, s in layers.starts do
		table.insert(hints, { x = s[1], z = s[2], ally = sides.sideOfStart[i] })
	end
	local areas: Areas = {
		sides = sides,
		boxes = StartAreas.boxes(sides, layers.starts, StartAreas.bounds(layers.grid), layers.startBoxes),
		hints = hints,
		key = key,
	}
	cache.areas = areas
	return areas
end

-- Every pick so far: player → { x, z }.
function Pregame.picks(world: World.World): { [number]: { number } }
	local out = {}
	for pid, p in world.pregame.picks do
		if p.x and p.z then
			out[pid] = { p.x, p.z }
		end
	end
	return out
end

-- Can the viewer start at (x, z): a player, in its side's box, SPACING from
-- every other pick? (The server also checks the Commander can stand there.)
function Pregame.canPick(world: World.World, areas: Areas, x: number, z: number): boolean
	if world.me.player == 0 or not world.pregame.active then
		return false
	end
	local box = areas.boxes[world.me.allyTeam]
	if box == nil or not StartAreas.inBox(box, x, z) then
		return false
	end
	return StartAreas.spaced(Pregame.picks(world), world.me.player, x, z)
end

local function flag(world: World.World, player: number, bit: number): boolean
	local p = world.pregame.picks[player]
	return p ~= nil and bit32.band(p.flags, bit) ~= 0
end

function Pregame.isReady(world: World.World, player: number): boolean
	return flag(world, player, Schema.PregameFlag.READY)
end

function Pregame.isAI(world: World.World, player: number): boolean
	return flag(world, player, Schema.PregameFlag.AI)
end

-- Where the camera opens: the viewer's pick, else the middle of its side's
-- box, else (a spectator) the middle of the map.
function Pregame.focus(world: World.World, areas: Areas?): (number, number)
	local own = world.pregame.picks[world.me.player]
	if own and own.x and own.z then
		return own.x, own.z
	end
	local box = areas and areas.boxes[world.me.allyTeam]
	if box and world.me.player ~= 0 then
		return (box[1] + box[3]) / 2, (box[2] + box[4]) / 2
	end
	local g = world.grid
	return g.originX + g.cellsX * 4, g.originZ + g.cellsZ * 4
end

-- Seconds until everyone counts as ready (the countdown then runs).
function Pregame.timeLeft(world: World.World): number
	return math.max(0, (Pregame.TIMEOUT - math.max(world.latestTick, 0)) / 15)
end

-- START_POS: the viewer's Commander starts at (x, z).
function Pregame.startPos(grid: Grid.Grid, x: number, z: number): buffer
	local cell, offX, offZ = grid:encode(x, z)
	return Commands.encode({ cmdType = Schema.CmdType.START_POS, flags = 0, unitIds = {}, cell = cell, offX = offX, offZ = offZ })
end

-- READY (on) or not.
function Pregame.ready(on: boolean): buffer
	return Commands.encode({ cmdType = Schema.CmdType.READY, flags = 0, unitIds = {}, value = if on then 1 else 0 })
end

return table.freeze(Pregame)
