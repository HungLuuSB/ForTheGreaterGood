--!strict
-- The pre-game's logic (net.md section 9b, S-169, S-171, S-174; C-218):
-- each side's spawn box (the server's START_BOXES; before they arrive, the
-- map's defaults from Shared/Match/StartAreas) and the map's start hints;
-- whether the viewer may pick a spot; each player's faction and the host;
-- the pick clock's text; where the camera opens; the START_POS, READY,
-- FACTION and START commands; the Commanders' landing. The state lives in
-- World.pregame (NetIn). Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local Schema = require("@shared/Net/Schema")
local StartAreas = require("@shared/Match/StartAreas")
local Commands = require("./Commands")
local World = require("./World")

local Pregame = {}

-- each faction's Commander (the server's Pregame.commanderDef)
Pregame.COMMANDER = table.freeze({ order = "ord_sovereign", chaos = "chs_warlord" })

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
	local sent = world.pregame.boxes
	local key = `{world.mapVersion}:{table.concat(allies, ",")}:{if sent then tostring(sent) else "map"}`
	if cache.world == world and cache.key == key then
		return cache.areas
	end
	cache.world, cache.key, cache.areas = world, key, nil
	if #allies == 0 or #allies > #layers.starts then
		return nil
	end
	local sides = StartAreas.sides(allies, #layers.starts, layers.sideSplits) -- the map's own splits (F40)
	local hints = {}
	for i, s in layers.starts do
		table.insert(hints, { x = s[1], z = s[2], ally = sides.sideOfStart[i] })
	end
	local areas: Areas = {
		sides = sides,
		boxes = sent or StartAreas.boxes(sides, layers.starts, StartAreas.bounds(layers.grid), layers.startBoxes),
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

-- The camera distance that shows the viewer's whole area (nil for a
-- spectator: the camera keeps its distance).
function Pregame.fitDistance(world: World.World, areas: Areas?): number?
	local box = areas and areas.boxes[world.me.allyTeam]
	if box == nil or world.me.player == 0 then
		return nil
	end
	return math.max(box[3] - box[1], box[4] - box[2]) * 1.1
end

function Pregame.isHost(world: World.World, player: number): boolean
	return flag(world, player, Schema.PregameFlag.HOST)
end

-- A player's faction: "order" or "chaos".
function Pregame.factionOf(world: World.World, player: number): string
	return if flag(world, player, Schema.PregameFlag.CHAOS) then "chaos" else "order"
end

-- Is every player ready (the host may start)?
function Pregame.allReady(world: World.World): boolean
	local clock = world.pregame.clock
	return clock ~= nil and bit32.band(clock.flags, Schema.PickClockFlag.ALL_READY) ~= 0
end

local function mmss(seconds: number): string
	return `{seconds // 60}:{string.format("%02d", seconds % 60)}`
end

-- The pick clock as a line: the pick time left, then (MAX_WAIT) the
-- forced start's; nil before the first PICK_CLOCK.
function Pregame.clockText(world: World.World): string?
	local clock = world.pregame.clock
	if clock == nil then
		return nil
	end
	if bit32.band(clock.flags, Schema.PickClockFlag.LOADING) ~= 0 then
		return "Waiting for players to load" -- the clocks start once everyone is in (S-174)
	elseif bit32.band(clock.flags, Schema.PickClockFlag.MAX_WAIT) ~= 0 then
		return `The match starts anyway in {mmss(clock.seconds)}`
	elseif clock.seconds > 0 then
		return `Pick time {mmss(clock.seconds)}`
	end
	return "Pick time is over: unplaced Commanders got a spot"
end

-- 0..1 through the Commanders' landing at `tick` (Schema.LANDING_TICKS
-- after COUNTDOWN 0), nil outside it.
function Pregame.landing(world: World.World, tick: number): number?
	local from = world.pregame.startedTick
	if from == nil or tick < from or tick >= from + Schema.LANDING_TICKS then
		return nil
	end
	return (tick - from) / Schema.LANDING_TICKS
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

-- FACTION: "order" or "chaos" (while not ready; it clears the queued builds).
function Pregame.faction(faction: string): buffer
	return Commands.encode({ cmdType = Schema.CmdType.FACTION, flags = 0, unitIds = {}, value = if faction == "chaos" then 1 else 0 })
end

-- START (the host): when everyone is ready, or `force` at any time (/forcestart).
function Pregame.start(force: boolean): buffer
	return Commands.encode({ cmdType = Schema.CmdType.START, flags = 0, unitIds = {}, value = if force then 1 else 0 })
end

return table.freeze(Pregame)
