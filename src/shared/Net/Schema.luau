--!strict
-- Packet record layouts (guide 7.3). Every field is in wire units: integers
-- already quantized by the caller (health 0..255, heading 0..255 = 0..360°...).
--
-- Decoders accept only what this schema defines: unknown enum values, reserved
-- flag bits, unit ID 0 and out-of-range counts are rejected with a clear
-- "Schema: ..." error, and truncated input fails in Packer. Changing a layout
-- breaks replays and connected clients: update the guide and the specs together.

local Packer = require("./Packer")

type Writer = Packer.Writer
type Reader = Packer.Reader

local band = bit32.band

local Schema = {}

-- Bump on ANY change to a record layout, enum value or validation rule.
-- Checked on join (with the defs hash) and written into replay headers.
-- Schema.spec pins golden bytes to this number.
Schema.PROTOCOL_VERSION = 40 -- 2: Events channel records (ENTER, LEAVE, DEATH); 3: combat events (FIRE, SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK); 4: Projectiles channel (homing corrections); 5: strategic TRACKED flag; 6: join handshake (Snapshot channel) and Eco records; 7: REPEAT command and REPEAT state bit; 8: State TARGET field (own units' weapon targets); 9: Eco records carry their team; 10: WRECK / WRECK_GONE and SIGHT_ROWS / SIGHT_CELLS events; 11: DECOYED carries the decoy point and ticks; 12: CANCEL command; 13: DECOYED says which countermeasure won; 14: SHOT (a hidden shooter's hitscan shot); 15: State STOCK field (own units' missile stockpiles); 16: INTERCEPTOR, LAUNCH_WARNING, INTERCEPTED (strategic missiles); 17: STOCK carries the next missile's build progress; 18: SPAWN_STRATEGIC (a strategic missile with its goal); 19: strategic icon 8 bits, one per unit type; 20: State OWNER field (own units' factory queue, fire / move state, ammo); 21: OWNER CHARGES (own units' flares / chaff left); 22: unit state bits DEPLOYED, DEPLOYING; 23: ALERT events; 24: SHIELD, SHIELD_FIELD and SHIELD_HIT events (shield domes); 25: SHIELD_HIT flag ABSORBED; 26: SHIELD_HIT projId 0 (a hitscan shot); 27: CHEAT command and CHEAT_RESULT event (S-102), State owner field PRODUCING (allied factories); 28: SHOT carries its weapon (S-118); 29: DOME and DOME_GONE (domes regardless of vision, S-122); 30: WELCOME lists every team's ally team (S-129); 31: IDLE events (S-136) and command flag GROUP (S-137); 32: Eco records carry the team's radar accuracy (S-147); 33: PRIORITY command and LOW_PRIORITY state bit (S-156); 34: OWN_STATUS events (own units off camera, S-158); 35: RESURRECT command, WRECK carries its supply, WRECK_STATE events (S-168); 36: up to 16 teams (strategic records 7 bytes), the pre-game: START_POS and READY commands, PREGAME, COUNTDOWN and PREBUILD events (S-169); 37: FACTION and START commands, PREGAME flags CHAOS and HOST, PICK_CLOCK and START_BOXES events, a 3 s countdown (S-174); SHARE_UNITS, SHARE_RESOURCE and REQUEST commands, SHARE events (S-176); AREA command: Smart Reclaim / repair / resurrect (S-183); 38: positions on a fixed wire grid (Grid: 64-stud wire cells, quarter-stud offsets, ±8,192 studs whatever the map), strategic records carry 3-bit offsets (8 studs), ALERT a full position, SIGHT_CELLS u24 entries, SIGHT_ROWS firstRow u16, CAMERA u16 cells: maps up to 1,024 cells, aircraft past the edge (S-189); 39: SET_RETREAT, SELF_DESTRUCT and DGUN commands, the STATES byte's retreat bits, the owner fields SELF_DESTRUCT and WORK (kind and target) (S-194); 40: WRECK carries featureKind (map trees and rocks, S-197); ECO_LEVEL command and the Eco record's share / convert levels (S-198); command flag FRONT (S-199)

-- Which RemoteEvent carries what (guide 7.1).
Schema.Channel = table.freeze({
	Cmd = table.freeze({ name = "Cmd", reliable = true }), -- C→S commands
	Tactical = table.freeze({ name = "Tactical", reliable = false }), -- tactical records
	State = table.freeze({ name = "State", reliable = true }), -- state records
	Strategic = table.freeze({ name = "Strategic", reliable = false }), -- strategic records
	Events = table.freeze({ name = "Events", reliable = true }),
	Projectiles = table.freeze({ name = "Projectiles", reliable = false }), -- homing corrections (D102)
	Eco = table.freeze({ name = "Eco", reliable = true }),
	Snapshot = table.freeze({ name = "Snapshot", reliable = true }),
})

local function fail(r: Reader, message: string): never
	error(`Schema: {r.context or "record"}: {message}`, 0)
end

local function readId(r: Reader, what: string): number
	local id = r:readU16()
	if id == 0 then
		fail(r, `{what} 0 is reserved`)
	end
	return id
end

local function writeId(w: Writer, id: number, what: string)
	if id == 0 then
		error(`Schema: {what} 0 is reserved`, 3)
	end
	w:writeU16(id)
end

local function required<T>(value: T?, what: string): T
	if value == nil then
		error(`Schema: missing field {what}`, 3)
	end
	return value
end

--------------------------------------------------------------------------------
-- Message header (Tactical and Strategic messages, and anything else stamped
-- with a tick): tick u16 = the sim tick mod 2^16. Compare with Net/Tick.
--------------------------------------------------------------------------------

Schema.TICK_HEADER_BYTES = 2

function Schema.encodeTickHeader(w: Writer, wireTick: number)
	w:writeU16(wireTick)
end

function Schema.decodeTickHeader(r: Reader): number
	r.context = "message header"
	return r:readU16()
end

--------------------------------------------------------------------------------
-- Command (C → S, Cmd channel)
--   cmdType u8 | flags u8 | count u16 | unitIds u16 × count | params
--------------------------------------------------------------------------------

Schema.MAX_UNITS_PER_COMMAND = 200

Schema.CmdType = table.freeze({
	MOVE = 1,
	FIGHT = 2,
	ATTACK = 3,
	ATTACK_GROUND = 4,
	PATROL = 5,
	GUARD = 6,
	STOP = 7,
	BUILD = 8,
	REPAIR = 9,
	RECLAIM = 10,
	SET_FIRE_STATE = 11,
	SET_MOVE_STATE = 12,
	TOGGLE = 13,
	CAMERA = 14,
	REPEAT = 15, -- factories: repeat the build queue on / off (S-13)
	CANCEL = 16, -- unfinished frames: cancel them; factories: drop queue item `value` (0 = all), refunding what was spent (S-35)
	CHEAT = 17, -- a cheat / test command (S-102; protocol 27); applied only when the match allows cheats
	PRIORITY = 18, -- resource priority: value 1 high (the default), 0 low; sets the LOW_PRIORITY state bit (S-156; protocol 33)
	RESURRECT = 19, -- targetId = a wreck: workers that can resurrect refill it with supply, then bring its unit back for power (S-168; protocol 35)
	START_POS = 20, -- pre-game only (startMode "choose"): pos = where the sender's Commander will start (S-169; protocol 36)
	READY = 21, -- pre-game only: value 1 ready, 0 not (S-169)
	FACTION = 22, -- pre-game only, while not ready: value 0 Order, 1 Chaos; clears the sender's pre-game builds (S-174; protocol 37)
	START = 23, -- pre-game only, from the match's host: value 0 start (everyone ready), 1 force start (S-174)
	SHARE_UNITS = 24, -- the unit IDs (own, complete, not a Commander) go to ally player `value` (S-176; protocol 37)
	SHARE_RESOURCE = 25, -- share params: give `amount` of `resource` to ally player `toPlayer` (S-176)
	REQUEST = 26, -- value = Schema.ShareKind ASK_UNITS / ASK_SUPPLY / ASK_POWER: ask the allies for help (S-176)
	AREA = 27, -- area params: Smart Reclaim / repair / resurrect inside a circle, target after target (S-183; protocol 37)
	SET_RETREAT = 28, -- aircraft: value = Schema.RetreatAt, the health at which they fly back to a rearm pad to heal (S-194; protocol 39)
	SELF_DESTRUCT = 29, -- value 1 starts the unit's countdown (SELF_DESTRUCT_SECONDS), 0 stops it (S-194)
	DGUN = 30, -- pos: Commanders fire their D-Gun at the point (manual fire, S-194)
	ECO_LEVEL = 31, -- level params, no unit IDs: one of the sender's team's resource-bar sliders (Schema.EcoLevel) to `value` percent (S-198; protocol 40)
})
-- ECO_LEVEL's sliders (S-198): the share levels (stored above them goes to
-- the allies, fairly) and the converters' level (power stored above it may
-- be converted)
Schema.EcoLevel = table.freeze({ SUPPLY_SHARE = 1, POWER_SHARE = 2, CONVERT = 3 })
-- SET_RETREAT values (S-194): never, or below 30 / 40 / 50% health
Schema.RetreatAt = table.freeze({ NEVER = 0, AT_30 = 1, AT_40 = 2, AT_50 = 3 })
Schema.RETREAT_SHARE = table.freeze({ [0] = 0, 0.3, 0.4, 0.5 }) -- RetreatAt → share of max health
Schema.SELF_DESTRUCT_SECONDS = 6 -- the self-destruct countdown (S-194)
-- the WORK owner field's kind (S-194): what a builder's target is to it;
-- RECLAIM and RESURRECT targets are wreck IDs, the others unit IDs
Schema.WorkKind = table.freeze({ NONE = 0, BUILD = 1, REPAIR = 2, ASSIST = 3, RECLAIM = 4, RESURRECT = 5 })
Schema.AreaOp = table.freeze({ RECLAIM = 1, REPAIR = 2, RESURRECT = 3 }) -- AREA op (S-183)

-- CHEAT commands (S-102, net.md "Cheat commands"): what to do.
Schema.CheatOp = table.freeze({
	GIVE = 1, -- defIndex, amount = count, team, x, z: spawn finished units
	RES = 2, -- arg = CheatResource, amount (CHEAT_MAX = fill), team: set stores
	INCOME = 3, -- arg = CheatResource, amount per second (0 clears), team
	INSTABUILD = 4, -- arg 1 on / 0 off
	REVEAL = 5, -- arg 1 on / 0 off, team
	GOD = 6, -- arg 1 on / 0 off: the sender's units
	KILL = 7, -- arg = CheatKill; unit IDs (SELECTED), team (TEAM), x, z, radius (AREA)
	SPEED = 8, -- amount = speed × 100 (25..800)
	AI = 9, -- arg 1 pause / 0 resume, team
})
Schema.CheatResource = table.freeze({ SUPPLY = 1, POWER = 2, ALL = 3 })
Schema.CheatKill = table.freeze({ SELECTED = 1, TEAM = 2, AREA = 3 })
Schema.CHEAT_MAX = 0xFFFFFFFF -- RES amount: fill to storage
local CHEAT_OP_MAX = 9
local CHEAT_ARG_MAX: { [number]: number } = { [1] = 0, [2] = 3, [3] = 3, [4] = 1, [5] = 1, [6] = 1, [7] = 3, [8] = 0, [9] = 1 }

Schema.CmdFlag = table.freeze({
	QUEUE = 1, -- shift: append to the order queue
	LINE = 2, -- line formation: a second position (the line's end) follows
	GROUP = 4, -- MOVE / FIGHT / PATROL: the selection keeps together at its slowest unit's speed (ctrl; protocol 31, S-137)
	FRONT = 8, -- orders: in at the head of the queue; the order under way resumes after it (space; protocol 40, S-199). Wins over QUEUE
})
local CMD_FLAGS_MASK = 15

-- Structure facing for BUILD: footprints rotate with it (guide 9.3).
Schema.Facing = table.freeze({ NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }) -- 0/90/180/270°
local MAX_FACING = 3

Schema.FireState = table.freeze({ HOLD_FIRE = 0, RETURN_FIRE = 1, FIRE_AT_WILL = 2 })
Schema.MoveState = table.freeze({ HOLD_POSITION = 0, MANEUVER = 1, ROAM = 2 })

-- Params layout per command type:
--   pos     cell u16, offX u8, offZ u8            (+ cell2, offX2, offZ2 with LINE)
--           (every position: wire cell + quarter-stud offsets, Grid.encode;
--           protocol 38, S-189)
--   target  targetId u16                          (unit, or wreck for RECLAIM / RESURRECT)
--   build   defIndex u16, cell u16, offX u8, offZ u8, facing u8 (0..3; bits 2..7 reserved)
--   value   value u8                              (0..VALUE_MAX[cmdType])
--   camera  minX u16, minZ u16, maxX u16, maxZ u16 (map-cell rectangle, unit count 0; u8 before protocol 38)
--   cheat   op u8, arg u8, team u8 (0 = the sender's), defIndex u16 (0 = none),
--           amount u32, x i16, z i16 (world studs), radius u16 (studs)
--           (unit count 0..MAX: KILL SELECTED's units; S-102)
--   share   toPlayer u8, resource u8 (ShareKind.SUPPLY / POWER), amount u32
--           (unit count 0; S-176)
--   area    op u8 (AreaOp), cell u16, offX u8, offZ u8 (the circle's centre),
--           radius u16 (studs, 1..AREA_MAX_RADIUS) (S-183)
--   none
type ParamKind = "pos" | "target" | "build" | "value" | "camera" | "cheat" | "share" | "area" | "none"

local CT = Schema.CmdType
local PARAMS: { [number]: ParamKind } = {
	[CT.MOVE] = "pos",
	[CT.FIGHT] = "pos",
	[CT.ATTACK] = "target",
	[CT.ATTACK_GROUND] = "pos",
	[CT.PATROL] = "pos",
	[CT.GUARD] = "target",
	[CT.STOP] = "none",
	[CT.BUILD] = "build",
	[CT.REPAIR] = "target",
	[CT.RECLAIM] = "target",
	[CT.SET_FIRE_STATE] = "value",
	[CT.SET_MOVE_STATE] = "value",
	[CT.TOGGLE] = "value",
	[CT.CAMERA] = "camera",
	[CT.REPEAT] = "value",
	[CT.CANCEL] = "value",
	[CT.CHEAT] = "cheat",
	[CT.PRIORITY] = "value",
	[CT.RESURRECT] = "target",
	[CT.START_POS] = "pos",
	[CT.READY] = "value",
	[CT.FACTION] = "value",
	[CT.START] = "value",
	[CT.SHARE_UNITS] = "value",
	[CT.SHARE_RESOURCE] = "share",
	[CT.REQUEST] = "value",
	[CT.AREA] = "area",
	[CT.SET_RETREAT] = "value",
	[CT.SELF_DESTRUCT] = "value",
	[CT.DGUN] = "pos",
	[CT.ECO_LEVEL] = "level",
}
Schema.AREA_MAX_RADIUS = 1024 -- studs
-- commands that may carry no unit IDs besides CAMERA and CHEAT (S-169): the
-- pre-game's START_POS and READY, and BUILD / STOP for the Commander that
-- doesn't exist yet (its pre-game build queue)
local NO_UNITS_OK: { [number]: boolean } = { [CT.START_POS] = true, [CT.READY] = true, [CT.FACTION] = true, [CT.START] = true, [CT.BUILD] = true, [CT.STOP] = true, [CT.REQUEST] = true }
local VALUE_MAX: { [number]: number } = {
	[CT.SET_FIRE_STATE] = 2,
	[CT.SET_MOVE_STATE] = 2,
	[CT.TOGGLE] = 1,
	[CT.REPEAT] = 1,
	[CT.PRIORITY] = 1,
	[CT.READY] = 1,
	[CT.FACTION] = 1,
	[CT.START] = 1,
	[CT.SHARE_UNITS] = 255, -- a player ID
	[CT.REQUEST] = 6, -- Schema.ShareKind (ASK_* only: Share checks)
	[CT.CANCEL] = 50, -- a factory queue holds at most 50 items (D62)
	[CT.SET_RETREAT] = 3,
	[CT.SELF_DESTRUCT] = 1,
}

export type Command = {
	cmdType: number,
	flags: number,
	unitIds: { number },
	-- pos / build
	cell: number?,
	offX: number?,
	offZ: number?,
	-- line end (LINE flag)
	cell2: number?,
	offX2: number?,
	offZ2: number?,
	-- target
	targetId: number?,
	-- build
	defIndex: number?,
	facing: number?, -- 0..3 = 0/90/180/270°
	-- value
	value: number?,
	-- camera
	minX: number?,
	minZ: number?,
	maxX: number?,
	maxZ: number?,
	-- cheat (S-102; defIndex as build)
	cheatOp: number?, -- Schema.CheatOp
	cheatArg: number?, -- on / off, CheatResource, CheatKill
	cheatTeam: number?, -- 0 = the sender's
	amount: number?, -- u32
	x: number?, -- world studs (i16)
	z: number?,
	radius: number?, -- studs (u16)
	-- share (S-176; amount as cheat)
	toPlayer: number?,
	resource: number?, -- Schema.ShareKind.SUPPLY / POWER
	ecoLevel: number?, -- ECO_LEVEL: Schema.EcoLevel (with `value`, 0..100 percent; S-198)
	-- area (S-183; cell / offX / offZ as pos)
	areaOp: number?, -- Schema.AreaOp (radius as cheat's)
}

function Schema.encodeCommand(w: Writer, cmd: Command)
	local kind = PARAMS[cmd.cmdType]
	if kind == nil then
		error(`Schema: unknown cmdType {cmd.cmdType}`, 2)
	end
	if band(cmd.flags, CMD_FLAGS_MASK) ~= cmd.flags then
		error(`Schema: command flags has reserved bits: {cmd.flags}`, 2)
	end
	if band(cmd.flags, Schema.CmdFlag.LINE) ~= 0 and kind ~= "pos" then
		error("Schema: LINE flag only applies to position commands", 2)
	end
	local count = #cmd.unitIds
	if kind == "camera" or kind == "share" or kind == "level" then
		if count ~= 0 then
			error("Schema: CAMERA and SHARE_RESOURCE commands carry no unit IDs", 2)
		end
	elseif kind == "cheat" or NO_UNITS_OK[cmd.cmdType] then
		if count > Schema.MAX_UNITS_PER_COMMAND then
			error(`Schema: command with {count} unit IDs`, 2)
		end
	elseif count < 1 or count > Schema.MAX_UNITS_PER_COMMAND then
		error(`Schema: command needs 1..{Schema.MAX_UNITS_PER_COMMAND} unit IDs, got {count}`, 2)
	end

	w:writeU8(cmd.cmdType)
	w:writeU8(cmd.flags)
	w:writeU16(count)
	for _, id in cmd.unitIds do
		writeId(w, id, "unitId")
	end

	if kind == "pos" or kind == "build" then
		if kind == "build" then
			writeId(w, required(cmd.defIndex, "defIndex"), "defIndex")
		end
		w:writeU16(required(cmd.cell, "cell"))
		w:writeU8(required(cmd.offX, "offX"))
		w:writeU8(required(cmd.offZ, "offZ"))
		if kind == "build" then
			local facing = required(cmd.facing, "facing")
			if facing > MAX_FACING then
				error(`Schema: facing {facing} outside 0..{MAX_FACING}`, 2)
			end
			w:writeU8(facing)
		end
		if band(cmd.flags, Schema.CmdFlag.LINE) ~= 0 then
			w:writeU16(required(cmd.cell2, "cell2"))
			w:writeU8(required(cmd.offX2, "offX2"))
			w:writeU8(required(cmd.offZ2, "offZ2"))
		end
	elseif kind == "target" then
		writeId(w, required(cmd.targetId, "targetId"), "targetId")
	elseif kind == "value" then
		local value = required(cmd.value, "value")
		if value > VALUE_MAX[cmd.cmdType] then
			error(`Schema: value {value} out of range for cmdType {cmd.cmdType}`, 2)
		end
		w:writeU8(value)
	elseif kind == "camera" then
		local minX, minZ = required(cmd.minX, "minX"), required(cmd.minZ, "minZ")
		local maxX, maxZ = required(cmd.maxX, "maxX"), required(cmd.maxZ, "maxZ")
		if minX > maxX or minZ > maxZ then
			error("Schema: camera rectangle has min > max", 2)
		end
		w:writeU16(minX)
		w:writeU16(minZ)
		w:writeU16(maxX)
		w:writeU16(maxZ)
	elseif kind == "area" then
		local op = required(cmd.areaOp, "areaOp")
		local radius = required(cmd.radius, "radius")
		if op < 1 or op > 3 or radius < 1 or radius > Schema.AREA_MAX_RADIUS then
			error(`Schema: area op {op} radius {radius}`, 2)
		end
		w:writeU8(op)
		w:writeU16(required(cmd.cell, "cell"))
		w:writeU8(required(cmd.offX, "offX"))
		w:writeU8(required(cmd.offZ, "offZ"))
		w:writeU16(radius)
	elseif kind == "share" then
		local resource = required(cmd.resource, "resource")
		if resource ~= Schema.ShareKind.SUPPLY and resource ~= Schema.ShareKind.POWER then
			error(`Schema: share resource {resource}`, 2)
		end
		w:writeU8(required(cmd.toPlayer, "toPlayer"))
		w:writeU8(resource)
		w:writeU32(required(cmd.amount, "amount"))
	elseif kind == "level" then
		local which, value = required(cmd.ecoLevel, "ecoLevel"), required(cmd.value, "value")
		if which < 1 or which > 3 or value < 0 or value > 100 or value ~= math.floor(value) then
			error(`Schema: eco level {which} at {value}%`, 2)
		end
		w:writeU8(which)
		w:writeU8(value)
	elseif kind == "cheat" then
		local op, arg = required(cmd.cheatOp, "cheatOp"), cmd.cheatArg or 0
		if op < 1 or op > CHEAT_OP_MAX or arg > CHEAT_ARG_MAX[op] then
			error(`Schema: cheat op {op} arg {arg}`, 2)
		end
		w:writeU8(op)
		w:writeU8(arg)
		w:writeU8(cmd.cheatTeam or 0)
		w:writeU16(cmd.defIndex or 0)
		w:writeU32(cmd.amount or 0)
		w:writeI16(cmd.x or 0)
		w:writeI16(cmd.z or 0)
		w:writeU16(cmd.radius or 0)
	end
end

function Schema.decodeCommand(r: Reader): Command
	r.context = "command record"
	local cmdType = r:readU8()
	local kind = PARAMS[cmdType]
	if kind == nil then
		fail(r, `unknown cmdType {cmdType}`)
	end
	local flags = r:readU8()
	if band(flags, CMD_FLAGS_MASK) ~= flags then
		fail(r, `flags has reserved bits: {flags}`)
	end
	local line = band(flags, Schema.CmdFlag.LINE) ~= 0
	if line and kind ~= "pos" then
		fail(r, `LINE flag on cmdType {cmdType}`)
	end

	local count = r:readU16()
	if kind == "camera" or kind == "share" or kind == "level" then
		if count ~= 0 then
			fail(r, `{if kind == "camera" then "CAMERA" else "SHARE_RESOURCE"} with {count} unit IDs`)
		end
	elseif kind == "cheat" or NO_UNITS_OK[cmdType] then
		if count > Schema.MAX_UNITS_PER_COMMAND then
			fail(r, `command with {count} unit IDs`)
		end
	elseif count < 1 or count > Schema.MAX_UNITS_PER_COMMAND then
		fail(r, `unit count {count} outside 1..{Schema.MAX_UNITS_PER_COMMAND}`)
	end
	-- Check the whole ID list fits before allocating for it.
	if r:remaining() < count * 2 then
		fail(r, `truncated: {count} unit IDs need {count * 2} bytes, only {r:remaining()} left`)
	end
	local unitIds = table.create(count)
	for i = 1, count do
		unitIds[i] = readId(r, "unitId")
	end

	local cmd: Command = { cmdType = cmdType, flags = flags, unitIds = unitIds }
	if kind == "pos" or kind == "build" then
		if kind == "build" then
			cmd.defIndex = readId(r, "defIndex")
		end
		cmd.cell = r:readU16()
		cmd.offX = r:readU8()
		cmd.offZ = r:readU8()
		if kind == "build" then
			local facing = r:readU8()
			if facing > MAX_FACING then
				fail(r, `facing {facing} outside 0..{MAX_FACING}`)
			end
			cmd.facing = facing
		end
		if line then
			cmd.cell2 = r:readU16()
			cmd.offX2 = r:readU8()
			cmd.offZ2 = r:readU8()
		end
	elseif kind == "target" then
		cmd.targetId = readId(r, "targetId")
	elseif kind == "value" then
		local value = r:readU8()
		if value > VALUE_MAX[cmdType] then
			fail(r, `value {value} out of range for cmdType {cmdType}`)
		end
		cmd.value = value
	elseif kind == "camera" then
		local minX, minZ, maxX, maxZ = r:readU16(), r:readU16(), r:readU16(), r:readU16()
		if minX > maxX or minZ > maxZ then
			fail(r, "camera rectangle has min > max")
		end
		cmd.minX, cmd.minZ, cmd.maxX, cmd.maxZ = minX, minZ, maxX, maxZ
	elseif kind == "area" then
		local op = r:readU8()
		cmd.cell = r:readU16()
		cmd.offX = r:readU8()
		cmd.offZ = r:readU8()
		local radius = r:readU16()
		if op < 1 or op > 3 or radius < 1 or radius > Schema.AREA_MAX_RADIUS then
			fail(r, `area op {op} radius {radius}`)
		end
		cmd.areaOp, cmd.radius = op, radius
	elseif kind == "share" then
		cmd.toPlayer = r:readU8()
		local resource = r:readU8()
		if resource ~= Schema.ShareKind.SUPPLY and resource ~= Schema.ShareKind.POWER then
			fail(r, `share resource {resource}`)
		end
		cmd.resource = resource
		cmd.amount = r:readU32()
	elseif kind == "level" then
		local which, value = r:readU8(), r:readU8()
		if which < 1 or which > 3 or value > 100 then
			fail(r, `eco level {which} at {value}%`)
		end
		cmd.ecoLevel, cmd.value = which, value
	elseif kind == "cheat" then
		local op, arg = r:readU8(), r:readU8()
		if op < 1 or op > CHEAT_OP_MAX or arg > CHEAT_ARG_MAX[op] then
			fail(r, `cheat op {op} arg {arg}`)
		end
		cmd.cheatOp, cmd.cheatArg = op, arg
		cmd.cheatTeam = r:readU8()
		cmd.defIndex = r:readU16()
		cmd.amount = r:readU32()
		cmd.x = r:readI16()
		cmd.z = r:readI16()
		cmd.radius = r:readU16()
	end
	return cmd
end

--------------------------------------------------------------------------------
-- Tactical (S → C, unreliable): units in camera area that moved this tick
--   unitId u16 | cell u16 | offX u8 | offZ u8 | heading u8 | flags u8 | [alt u8]
--   = 8 bytes, 9 with altitude
--------------------------------------------------------------------------------

Schema.TACTICAL_BYTES = 8
Schema.TACTICAL_ALT_BYTES = 9

local TACTICAL_HAS_ALT = 1
local TACTICAL_FLAGS_MASK = 1

export type Tactical = {
	unitId: number,
	cell: number,
	offX: number,
	offZ: number,
	heading: number, -- 0..255 → 0..360°
	alt: number?, -- air units only: studs above ground, 0..255
}

function Schema.encodeTactical(w: Writer, rec: Tactical)
	writeId(w, rec.unitId, "unitId")
	w:writeU16(rec.cell)
	w:writeU8(rec.offX)
	w:writeU8(rec.offZ)
	w:writeU8(rec.heading)
	if rec.alt ~= nil then
		w:writeU8(TACTICAL_HAS_ALT)
		w:writeU8(rec.alt)
	else
		w:writeU8(0)
	end
end

function Schema.decodeTactical(r: Reader): Tactical
	r.context = "tactical record"
	local rec: Tactical = {
		unitId = readId(r, "unitId"),
		cell = r:readU16(),
		offX = r:readU8(),
		offZ = r:readU8(),
		heading = r:readU8(),
	}
	local flags = r:readU8()
	if band(flags, TACTICAL_FLAGS_MASK) ~= flags then
		fail(r, `flags has reserved bits: {flags}`)
	end
	if flags == TACTICAL_HAS_ALT then
		rec.alt = r:readU8()
	end
	return rec
end

--------------------------------------------------------------------------------
-- State (S → C, reliable): only the fields that changed
--   unitId u16 | mask u8 | [health u8] | [state u16] | [aim] | [weapon u16] | [build u8] | [targets] | [stock]
--   aim = slotMask u8 (bit i-1 = weapon slot i, 1..8) + yaw u8, pitch u8 per set bit
--   targets = slotMask u8 + targetId u16 per set bit (0 = none); sent only to
--             the unit's owner (protocol 8, S-16)
--   stock   = slotMask u8 + (count u8, progress u8) per set bit: missiles in
--             stock of the weapon slots with a stockpile, and the next
--             missile's build progress (0..255 of 1; protocol 17, S-49); sent
--             only to the unit's owner (protocol 15, S-47)
--   owner   = ownerMask u8, then the fields it sets (protocol 20, S-61; only
--             to the unit's owner):
--               QUEUE 1   count u8 (0..50) | progress u8 (the head item,
--                         0..255 of 1) | defIndex u16 × count
--               STATES 2  u8: fire state bits 0–1, move state bits 2–3
--               AMMO 4    rounds u8 | max u8
--               CHARGES 8 flares u8 | chaff u8: countermeasure charges
--                         left, 0 for a kind the def lacks (protocol 21,
--                         S-63)
--               PRODUCING 16 defIndex u16 (0 = idle) | progress u8: an
--                         allied player's factory's current item and its
--                         progress (0..255 of 1); sent to allies, not the
--                         owner, who has QUEUE (protocol 27, S-103, client
--                         request 45). The only owner field allies get.
--------------------------------------------------------------------------------

Schema.MAX_WEAPONS = 8 -- aim slot mask is one byte; weapon field is 2 bits per slot in a u16

-- Unit state bits: the u16 `state` of ENTER and State records. The sim's
-- World.State is this table (one source; S-6, client request).
Schema.UnitState = table.freeze({
	MOVING = 1,
	TOGGLED_ON = 2, -- radar / jammer switched on
	SUBMERGED = 4, -- submarines (sonar-only detection)
	LANDED = 8, -- aircraft on the ground / on a pad
	REPEAT = 16, -- factory: finished items go back to the end of the queue (S-13)
	DEPLOYED = 32, -- a deployable unit (the Warden) unpacked: fires, can't move (S-64, protocol 22)
	DEPLOYING = 64, -- unpacking or packing: neither moves nor fires (S-64, protocol 22)
	LOW_PRIORITY = 128, -- resource priority low: served after every high consumer in a stall (S-156, protocol 33)
})

Schema.StateField = table.freeze({
	HEALTH = 1,
	STATE = 2,
	AIM = 4,
	WEAPON = 8,
	BUILD = 16,
	TARGET = 32, -- own units only: each weapon's target (protocol 8, S-16)
	STOCK = 64, -- own units only: missiles in stock per stockpile slot (protocol 15, S-47)
	OWNER = 128, -- own units only: factory queue, fire / move state, ammo (protocol 20, S-61)
})
local STATE_MASK_ALL = 255
Schema.OwnerField = table.freeze({ QUEUE = 1, STATES = 2, AMMO = 4, CHARGES = 8, PRODUCING = 16, SELF_DESTRUCT = 32, WORK = 64 })
local OWNER_MASK_ALL = 127
Schema.MAX_QUEUE = 50 -- items a factory queue can hold (BuildState.MAX_QUEUE)
local SF = Schema.StateField

Schema.WeaponState = table.freeze({ IDLE = 0, AIMING = 1, READY = 2, RESTORING = 3 })

export type Aim = { slot: number, yaw: number, pitch: number }
export type Target = { slot: number, targetId: number } -- targetId 0 = no target
export type Stock = { slot: number, count: number, progress: number } -- missiles in stock (0..255); next one's progress 0..255 (S-49)

export type State = {
	unitId: number,
	health: number?, -- 0..255 fraction of max health
	state: number?, -- u16 state bit flags
	aim: { Aim }?, -- changed weapons only, ascending slot order
	weapon: number?, -- u16, 2 bits per slot; see packWeaponStates / weaponStateAt
	build: number?, -- 0..255 build progress
	targets: { Target }?, -- own units only (S-16): ascending slot order; targetId 0 = none
	stock: { Stock }?, -- own units only (S-47): stockpile slots, ascending slot order
	-- own units only (S-61, protocol 20): each optional
	queue: { number }?, -- factory queue: unit def indices, the head in production
	queueProgress: number?, -- 0..255: the head item's progress (with `queue`)
	fireState: number?, -- Schema.FireState (with `moveState`: the STATES field)
	moveState: number?, -- Schema.MoveState
	retreat: number?, -- Schema.RetreatAt (aircraft; in the STATES field, protocol 39; nil = NEVER)
	selfDestruct: number?, -- seconds left of a self-destruct countdown, 1..255; 0 = stopped (the SELF_DESTRUCT field, protocol 39)
	-- builders (the WORK field, protocol 39, S-194): what its nano spray is on
	-- now, as the server builds: Schema.WorkKind and the unit (BUILD, REPAIR,
	-- ASSIST) or wreck (RECLAIM, RESURRECT) ID; NONE with 0 when idle
	workKind: number?,
	workTarget: number?,
	ammo: number?, -- rounds left (with `maxAmmo`: the AMMO field)
	maxAmmo: number?,
	flares: number?, -- countermeasure charges left (with `chaff`: the CHARGES field, protocol 21)
	chaff: number?,
	-- allied factories (S-103, protocol 27): the PRODUCING field
	producing: number?, -- def index of the item in production; 0 = idle
	producingProgress: number?, -- 0..255
}

-- {slot1, slot2, ...} WeaponState values → the u16 weapon field.
function Schema.packWeaponStates(states: { number }): number
	assert(#states <= Schema.MAX_WEAPONS, "Schema.packWeaponStates: more than MAX_WEAPONS slots")
	local field = 0
	for i, s in states do
		assert(s >= 0 and s <= 3 and s == math.floor(s), "Schema.packWeaponStates: state must be 0..3")
		field += s * 4 ^ (i - 1)
	end
	return field
end

function Schema.weaponStateAt(field: number, slot: number): number
	return bit32.extract(field, (slot - 1) * 2, 2)
end

function Schema.encodeState(w: Writer, rec: State)
	local mask = 0
	if rec.health ~= nil then
		mask += SF.HEALTH
	end
	if rec.state ~= nil then
		mask += SF.STATE
	end
	if rec.aim ~= nil then
		mask += SF.AIM
	end
	if rec.weapon ~= nil then
		mask += SF.WEAPON
	end
	if rec.build ~= nil then
		mask += SF.BUILD
	end
	if rec.targets ~= nil then
		mask += SF.TARGET
	end
	if rec.stock ~= nil then
		mask += SF.STOCK
	end
	local owner = 0
	if rec.queue ~= nil then
		owner += Schema.OwnerField.QUEUE
	end
	if rec.fireState ~= nil or rec.moveState ~= nil then
		owner += Schema.OwnerField.STATES
	end
	if rec.ammo ~= nil then
		owner += Schema.OwnerField.AMMO
	end
	if rec.flares ~= nil or rec.chaff ~= nil then
		owner += Schema.OwnerField.CHARGES
	end
	if rec.producing ~= nil then
		owner += Schema.OwnerField.PRODUCING
	end
	if rec.selfDestruct ~= nil then
		owner += Schema.OwnerField.SELF_DESTRUCT
	end
	if rec.workKind ~= nil then
		owner += Schema.OwnerField.WORK
	end
	if owner ~= 0 then
		mask += SF.OWNER
	end
	if mask == 0 then
		error("Schema: state record has no fields", 2)
	end

	writeId(w, rec.unitId, "unitId")
	w:writeU8(mask)
	if rec.health ~= nil then
		w:writeU8(rec.health)
	end
	if rec.state ~= nil then
		w:writeU16(rec.state)
	end
	if rec.aim ~= nil then
		local slotMask = 0
		local lastSlot = 0
		for _, a in rec.aim do
			if a.slot ~= math.floor(a.slot) or a.slot <= lastSlot or a.slot > Schema.MAX_WEAPONS then
				error("Schema: aim slots must be ascending within 1..MAX_WEAPONS", 2)
			end
			slotMask += 2 ^ (a.slot - 1)
			lastSlot = a.slot
		end
		if slotMask == 0 then
			error("Schema: aim list is empty", 2)
		end
		w:writeU8(slotMask)
		for _, a in rec.aim do
			w:writeU8(a.yaw)
			w:writeU8(a.pitch)
		end
	end
	if rec.weapon ~= nil then
		w:writeU16(rec.weapon)
	end
	if rec.build ~= nil then
		w:writeU8(rec.build)
	end
	if rec.targets ~= nil then
		local slotMask = 0
		local lastSlot = 0
		for _, tg in rec.targets do
			if tg.slot ~= math.floor(tg.slot) or tg.slot <= lastSlot or tg.slot > Schema.MAX_WEAPONS then
				error("Schema: target slots must be ascending within 1..MAX_WEAPONS", 2)
			end
			slotMask += 2 ^ (tg.slot - 1)
			lastSlot = tg.slot
		end
		if slotMask == 0 then
			error("Schema: target list is empty", 2)
		end
		w:writeU8(slotMask)
		for _, tg in rec.targets do
			w:writeU16(tg.targetId) -- 0 = none
		end
	end
	if rec.stock ~= nil then
		local slotMask = 0
		local lastSlot = 0
		for _, st in rec.stock do
			if st.slot ~= math.floor(st.slot) or st.slot <= lastSlot or st.slot > Schema.MAX_WEAPONS then
				error("Schema: stock slots must be ascending within 1..MAX_WEAPONS", 2)
			end
			slotMask += 2 ^ (st.slot - 1)
			lastSlot = st.slot
		end
		if slotMask == 0 then
			error("Schema: stock list is empty", 2)
		end
		w:writeU8(slotMask)
		for _, st in rec.stock do
			w:writeU8(st.count)
			w:writeU8(st.progress)
		end
	end
	if owner ~= 0 then
		w:writeU8(owner)
		if rec.queue ~= nil then
			local q = rec.queue
			if #q > Schema.MAX_QUEUE then
				error(`Schema: queue of {#q} items (at most {Schema.MAX_QUEUE})`, 2)
			end
			w:writeU8(#q)
			w:writeU8(rec.queueProgress or 0)
			for _, defIndex in q do
				writeId(w, defIndex, "defIndex")
			end
		end
		if band(owner, Schema.OwnerField.STATES) ~= 0 then
			local fs, ms = required(rec.fireState, "fireState"), required(rec.moveState, "moveState")
			local rt = rec.retreat or 0
			if fs > 3 or ms > 3 or rt > 3 then
				error(`Schema: fire / move / retreat state {fs} / {ms} / {rt} outside 0..3`, 2)
			end
			w:writeU8(fs + ms * 4 + rt * 16) -- retreat in bits 4-5 (protocol 39)
		end
		if rec.ammo ~= nil then
			w:writeU8(rec.ammo)
			w:writeU8(required(rec.maxAmmo, "maxAmmo"))
		end
		if band(owner, Schema.OwnerField.CHARGES) ~= 0 then
			w:writeU8(rec.flares or 0)
			w:writeU8(rec.chaff or 0)
		end
		if rec.producing ~= nil then
			w:writeU16(rec.producing)
			w:writeU8(rec.producingProgress or 0)
		end
		if rec.selfDestruct ~= nil then
			local sd = rec.selfDestruct
			if sd < 0 or sd > 255 or sd ~= math.floor(sd) then
				error(`Schema: self-destruct seconds {sd} outside 0..255`, 2)
			end
			w:writeU8(sd)
		end
		if rec.workKind ~= nil then
			if rec.workKind < 0 or rec.workKind > 5 then
				error(`Schema: work kind {rec.workKind} outside 0..5`, 2)
			end
			w:writeU8(rec.workKind)
			w:writeU16(rec.workTarget or 0)
		end
	end
end

function Schema.decodeState(r: Reader): State
	r.context = "state record"
	local rec: State = { unitId = readId(r, "unitId") }
	local mask = r:readU8()
	if mask == 0 then
		fail(r, "mask is empty")
	end
	if band(mask, STATE_MASK_ALL) ~= mask then
		fail(r, `mask has reserved bits: {mask}`)
	end
	if band(mask, SF.HEALTH) ~= 0 then
		rec.health = r:readU8()
	end
	if band(mask, SF.STATE) ~= 0 then
		rec.state = r:readU16()
	end
	if band(mask, SF.AIM) ~= 0 then
		local slotMask = r:readU8()
		if slotMask == 0 then
			fail(r, "aim slot mask is empty")
		end
		local aim: { Aim } = {}
		for slot = 1, Schema.MAX_WEAPONS do
			if band(slotMask, 2 ^ (slot - 1)) ~= 0 then
				table.insert(aim, { slot = slot, yaw = r:readU8(), pitch = r:readU8() })
			end
		end
		rec.aim = aim
	end
	if band(mask, SF.WEAPON) ~= 0 then
		rec.weapon = r:readU16()
	end
	if band(mask, SF.BUILD) ~= 0 then
		rec.build = r:readU8()
	end
	if band(mask, SF.TARGET) ~= 0 then
		local slotMask = r:readU8()
		if slotMask == 0 then
			fail(r, "target slot mask is empty")
		end
		local targets: { Target } = {}
		for slot = 1, Schema.MAX_WEAPONS do
			if band(slotMask, 2 ^ (slot - 1)) ~= 0 then
				table.insert(targets, { slot = slot, targetId = r:readU16() })
			end
		end
		rec.targets = targets
	end
	if band(mask, SF.STOCK) ~= 0 then
		local slotMask = r:readU8()
		if slotMask == 0 then
			fail(r, "stock slot mask is empty")
		end
		local stock: { Stock } = {}
		for slot = 1, Schema.MAX_WEAPONS do
			if band(slotMask, 2 ^ (slot - 1)) ~= 0 then
				local count = r:readU8()
				table.insert(stock, { slot = slot, count = count, progress = r:readU8() })
			end
		end
		rec.stock = stock
	end
	if band(mask, SF.OWNER) ~= 0 then
		local owner = r:readU8()
		if owner == 0 then
			fail(r, "owner field mask is empty")
		end
		if band(owner, OWNER_MASK_ALL) ~= owner then
			fail(r, `owner field mask has reserved bits: {owner}`)
		end
		if band(owner, Schema.OwnerField.QUEUE) ~= 0 then
			local count = r:readU8()
			if count > Schema.MAX_QUEUE then
				fail(r, `queue of {count} items`)
			end
			rec.queueProgress = r:readU8()
			local q = table.create(count)
			for i = 1, count do
				q[i] = readId(r, "defIndex")
			end
			rec.queue = q
		end
		if band(owner, Schema.OwnerField.STATES) ~= 0 then
			local b = r:readU8()
			if b > 63 then
				fail(r, `states byte has reserved bits: {b}`)
			end
			rec.fireState, rec.moveState = b % 4, (b // 4) % 4
			if b >= 16 then
				rec.retreat = b // 16
			end
		end
		if band(owner, Schema.OwnerField.AMMO) ~= 0 then
			rec.ammo = r:readU8()
			rec.maxAmmo = r:readU8()
		end
		if band(owner, Schema.OwnerField.CHARGES) ~= 0 then
			rec.flares = r:readU8()
			rec.chaff = r:readU8()
		end
		if band(owner, Schema.OwnerField.PRODUCING) ~= 0 then
			rec.producing = r:readU16()
			rec.producingProgress = r:readU8()
		end
		if band(owner, Schema.OwnerField.SELF_DESTRUCT) ~= 0 then
			rec.selfDestruct = r:readU8()
		end
		if band(owner, Schema.OwnerField.WORK) ~= 0 then
			rec.workKind = r:readU8()
			if rec.workKind > 5 then
				fail(r, `work kind {rec.workKind}`)
			end
			rec.workTarget = r:readU16()
		end
	end
	return rec
end

--------------------------------------------------------------------------------
-- Strategic (S → C, unreliable, 2–4 Hz): every known unit, minimap level
--   unitId u16 | cell u16 | icon 8 bits | team 4 bits | flags 5 bits
--   | offX 3 bits | offZ 3 bits | 1 reserved bit (0)                 = 7 bytes
--   Bits are packed LSB-first: icon = bits 0–7, team = 8–11, flags = 12–16,
--   offX 17–19, offZ 20–22. The position is a wire cell (Grid.encode) and
--   its offsets' top 3 bits: 8 studs (protocol 38, S-189; a map cell index
--   before); decoded to the 8-stud square's centre.
--   (protocol 19, S-58: the icon is the unit's def index, Shared/Net/Icons).
--   Team travels as team - 1 (teams are 1..16; 3 bits and 1..8 before
--   protocol 36, S-169).
--------------------------------------------------------------------------------

Schema.STRATEGIC_BYTES = 7
Schema.MAX_TEAMS = 16 -- (protocol 36, S-169: 16 players)

Schema.StrategicFlag = table.freeze({
	RADAR_ONLY = 1, -- radar blip: icon is 0 (unknown) unless identified earlier
	SONAR_ONLY = 2,
	UNDER_ATTACK = 4,
	GHOST = 8, -- structure seen earlier, now out of sight
	TRACKED = 16, -- radar blip under fire-control radar: wobbles less, and the icon is the real one (D104)
})
local STRATEGIC_FLAGS_MASK = 31 -- all 5 flag bits are in use

export type Strategic = {
	unitId: number,
	cell: number,
	offX: number?, -- 0..255 as Grid.encode gives it; travels as its top 3 bits (S-189)
	offZ: number?,
	icon: number, -- 0..255: the unit's def index (Icons), 0 = unknown blip
	team: number, -- 1..16
	flags: number,
}

function Schema.encodeStrategic(w: Writer, rec: Strategic)
	if rec.team < 1 or rec.team > Schema.MAX_TEAMS then
		error(`Schema: team {rec.team} outside 1..{Schema.MAX_TEAMS}`, 2)
	end
	if band(rec.flags, STRATEGIC_FLAGS_MASK) ~= rec.flags then
		error(`Schema: strategic flags has reserved bits: {rec.flags}`, 2)
	end
	writeId(w, rec.unitId, "unitId")
	w:writeU16(rec.cell)
	w:writeBits(rec.icon, 8)
	w:writeBits(rec.team - 1, 4)
	w:writeBits(rec.flags, 5)
	w:writeBits((rec.offX or 0) // 32, 3)
	w:writeBits((rec.offZ or 0) // 32, 3)
	w:writeBits(0, 1)
	w:flushBits()
end

function Schema.decodeStrategic(r: Reader): Strategic
	r.context = "strategic record"
	local unitId = readId(r, "unitId")
	local cell = r:readU16()
	local icon = r:readBits(8)
	local team = r:readBits(4) + 1
	local flags = r:readBits(5)
	local offX, offZ = r:readBits(3) * 32 + 16, r:readBits(3) * 32 + 16
	if r:readBits(1) ~= 0 then
		fail(r, "reserved bits set")
	end
	r:alignBits()
	if band(flags, STRATEGIC_FLAGS_MASK) ~= flags then
		fail(r, `flags has reserved bits: {flags}`)
	end
	return { unitId = unitId, cell = cell, offX = offX, offZ = offZ, icon = icon, team = team, flags = flags }
end

--------------------------------------------------------------------------------
-- Events (S → C, reliable): tactical tier changes, deaths and combat (guide
-- 7.2, 7.3). All of a tick's events go in one record list under the tick
-- header (chunked at 900 bytes).
--   kind u8, then
--   ENTER       unitId u16 | defIndex u16 | team u8 | cell u16 | offX u8 | offZ u8
--               | heading u8 | alt u8 | health u8 | build u8 | state u16      = 16 bytes
--   LEAVE       unitId u16                                                    =  3 bytes
--   DEATH       unitId u16 | severity u8 | wreckId u16 (0 = none)             =  6 bytes
--   FIRE        shooterId u16 | slot u8 (bits 0–3 slot 1..8, bit 4 hit;
--               bits 5–7 reserved) | end pos                                  = 10 bytes
--   SPAWN_PROJ  projId u16 | weaponDefIndex u16 | pos | vel
--               | targetId u16 (0 = none or not shown)                        = 19 bytes
--   IMPACT      projId u16 | pos                                              =  9 bytes
--   DECOYED     projId u16 | pos | vel | decoy pos (the point it follows)
--               | decoyTicks u8 (ticks it still follows it; protocol 11)
--               | countermeasure u8 (Schema.Countermeasure; protocol 13)     = 23 bytes
--   LOST_LOCK   projId u16 | pos | vel (the missile flies on unguided)       = 15 bytes
--   WRECK       wreckId u16 | defIndex u16 | cell u16 | offX u8 | offZ u8
--               | heading u8 | supply u16 (left in it) | fullSupply u16 (what
--               it held at first; protocol 35, S-168) | featureKind u8 (0 = a
--               unit's wreck; Defs/Features: 1 tree, 2 rock, whose defIndex
--               is 0 and whose supply / fullSupply count its resource, a
--               tree's power; protocol 40, S-197)                            = 15 bytes
--   WRECK_GONE  wreckId u16                                                   =  3 bytes
--   SIGHT_ROWS  firstRow u16 (u8 before protocol 38) | rowCount u8 (1..) | rowBytes u8 (1..)
--               | rowCount × rowBytes bytes: one bit per sensor cell, row by
--               row, bit (x % 8) of byte x // 8; 1 = in the ally team's sight
--                                                          = 5 + rows × rowBytes
--   SHOT        hit u8 (0 / 1) | start pos | end pos | weaponDefIndex u16
--               (protocol 28, S-118; 0 = unknown): a hitscan / beam shot
--               whose shooter the player doesn't have (protocol 14)        = 16 bytes
--   INTERCEPTOR projId u16 | weaponDefIndex u16 | pos | vel | targetProjId u16:
--               SPAWN_PROJ of a missile fired at a strategic missile; the
--               target is a projectile (0 = one the client doesn't have;
--               protocol 16)                                                  = 19 bytes
--   LAUNCH_WARNING projId u16 | pos: a strategic missile launched from pos;
--               every player gets it, wherever it is (protocol 16)            =  9 bytes
--   INTERCEPTED projId u16 | pos: a strategic missile destroyed in flight; it
--               doesn't detonate (protocol 16)                                =  9 bytes
--   SPAWN_STRATEGIC as SPAWN_PROJ (targetId 0) | goal pos: a strategic missile
--               and the spot it flies to (Shared/Combat/Lofted; protocol 18) = 25 bytes
--   ALERT       alert u8 (Schema.AlertKind) | cell u16 | offX u8 | offZ u8
--               (offsets: protocol 38) | defIndex u16 (0 = none):
--               something the player should know, rate-limited by the sim
--               (Sim/Alerts; protocol 23)                                     =  8 bytes
--   SHIELD      unitId u16 | charge u8 (0..255 of capacity) | flags u8
--               (Schema.ShieldFlag): a shield dome generator's state, after
--               its ENTER and when it changes (Sim/Shield; protocol 24)      =  5 bytes
--   SHIELD_FIELD projId u16 | pos (the dome's centre) | radius u16 (studs) |
--               force u8 (0..255 of full) | phase u8 (ShieldField.BRAKING
--               or REPELLED): a projectile the client has is in a dome's
--               field from now on; the client steps it with
--               Shared/Combat/ShieldField until it is done (protocol 24)    = 13 bytes
--   SHIELD_HIT  unitId u16 (the generator; 0 = one the client doesn't have) |
--               projId u16 (0 = a hitscan shot, protocol 26) | pos (the point on
--               the dome) | mass u8 (SHIELD_MASS_SCALE per shell mass) |
--               flags u8 (SHIELD_BREACH, SHIELD_ABSORBED): a shell turned
--               back by the dome's field, through it, or (protocol 25)
--               destroyed at its surface (protocol 24)                      = 13 bytes
--   DOME        unitId u16 (the generator) | pos (the dome's centre) | radius
--               u16 (studs) | charge u8 (0..255) | flags u8 (Schema.ShieldFlag):
--               a shield dome whose circle touches the camera area, whatever
--               the team sees, when the player doesn't have its generator
--               (as BAR draws shields); when it enters the area and when its
--               charge or flags change (protocol 29, S-122)              = 13 bytes
--   DOME_GONE   unitId u16: that dome left the area, its generator died, or
--               the player now has the generator (ENTER / SHIELD cover it) =  3 bytes
--   IDLE        unitId u16 | idle u8 (0 / 1): one of the player's own
--               builders or factories became idle or busy, on camera or
--               not; owner only. A builder is idle with no order of its own
--               and no build / assist / repair / reclaim work; a factory
--               with an empty queue. Units not reported are busy; on join,
--               every idle one is sent (protocol 31, S-136, request 62)  =  4 bytes
--   OWN_STATUS  unitId u16 | health u8 | build u8 | queueHead u16 (unit def
--               index; 0 = no queue or empty) | queueProgress u8 (0..255, the
--               head's) | queueCount u8: one of the player's own units outside
--               its tactical tier, when one of these changed (the progress by
--               sixteenths) since the client last had it; owner only, capped
--               per tick (NetOut.OWN_STATUS_MAX). Tactical units carry the
--               same in ENTER / State (protocol 34, S-158)                 =  9 bytes
--   CHEAT_RESULT op u8 (Schema.CheatOp) | result u8 (Schema.CheatResult) |
--               count u16 | total u16: the answer to the player's CHEAT
--               command, for the chat (GIVE: units placed of asked; KILL:
--               units killed; RES / INCOME: the amount set; SPEED: speed × 100);
--               owner only (protocol 27, S-102)                             =  7 bytes
--   WRECK_STATE wreckId u16 | supply u16 | rez u8 (resurrect progress,
--               0..255): a wreck the client has, in the team's sight, whose
--               supply or resurrect progress changed (protocol 35, S-168)   =  6 bytes
--   PREGAME     player u8 | flags u8 (PregameFlag: PICKED 1, READY 2, AI 4,
--               CHAOS 8 (its faction; else Order), HOST 16 (starts the
--               match; protocol 37)) | cell u16 | offX u8 | offZ u8 (the
--               pick; 0 when not picked): one player's pre-game state, to
--               everyone, when it changes and after a join (protocol 36,
--               S-169)                                                    =  7 bytes
--   COUNTDOWN   seconds u8: 3..1 counting down (protocol 37; 5..1 in 36);
--               0 the match starts this tick (the Commanders' ENTERs come
--               with it; they land for Schema.LANDING_TICKS); 255 cancelled
--               (someone isn't ready any more); to everyone            =  2 bytes
--   PICK_CLOCK  seconds u8 (pick time left; 0 once over: unpicked players
--               got a spot; with MAX_WAIT, the seconds to the forced start)
--               | flags u8 (PickClockFlag: ALL_READY 1 (the host may
--               start), MAX_WAIT 2, LOADING 4 (humans still loading: the
--               clock hasn't started)): to everyone, when it changes
--               (protocol 37, S-174)                                    =  3 bytes
--   SHARE       from u8 | to u8 (0 for a request) | what u8 (ShareKind) |
--               amount u32 (units given, or resource given; 0 for a request):
--               a gift or a request for help between allies, to the
--               sender's ally team and spectators (protocol 37, S-176)  =  8 bytes
--   START_BOXES count u8 | count × (allyTeam u8 | x0 i16 | z0 i16 | x1 i16 |
--               z1 i16, world studs): every side's spawn box, to everyone,
--               once after a join during the pre-game (protocol 37)  = 2 + 9 × count
--   PREBUILD    player u8 | count u8 (0..PREBUILD_MAX) | count × (defIndex
--               u16 | cell u16 | offX u8 | offZ u8 | facing u8): the
--               player's pre-game build queue for its Commander, to the
--               player and its allies, when it changes and after a join
--                                                              = 3 + 7 × count
--   SIGHT_CELLS count u8 (1..255) | count × u24 (low u16, high u8; u16
--               before protocol 38): sensor cell index (z × sensorX + x) |
--               SIGHT_SEEN (bit 23) when now in sight             = 2 + 3 × count
-- pos = cell u16 | offX u8 | offZ u8 | y i16 (eighth studs)                     6 bytes
--       (cell, offX, offZ: a wire position, Grid.encode; protocol 38, S-189)
-- vel = vx i16 | vy i16 | vz i16 (eighth studs per second)                     6 bytes
--------------------------------------------------------------------------------

Schema.EventKind = table.freeze({
	ENTER = 1,
	LEAVE = 2,
	DEATH = 3,
	FIRE = 4,
	SPAWN_PROJ = 5,
	IMPACT = 6,
	DECOYED = 7,
	LOST_LOCK = 8,
	WRECK = 9, -- protocol 10 (S-26)
	WRECK_GONE = 10,
	SIGHT_ROWS = 11,
	SIGHT_CELLS = 12,
	SHOT = 13, -- protocol 14 (S-43)
	INTERCEPTOR = 14, -- protocol 16 (S-48)
	LAUNCH_WARNING = 15,
	INTERCEPTED = 16,
	SPAWN_STRATEGIC = 17, -- protocol 18 (S-51)
	ALERT = 18, -- protocol 23 (S-68)
	SHIELD = 19, -- protocol 24 (S-79)
	SHIELD_HIT = 20,
	SHIELD_FIELD = 21,
	CHEAT_RESULT = 22, -- protocol 27 (S-102)
	DOME = 23, -- protocol 29 (S-122)
	DOME_GONE = 24,
	IDLE = 25, -- protocol 31 (S-136)
	OWN_STATUS = 26, -- protocol 34 (S-158)
	WRECK_STATE = 27, -- protocol 35 (S-168)
	PREGAME = 28, -- protocol 36 (S-169)
	COUNTDOWN = 29,
	PREBUILD = 30, -- variable size (Schema.eventBytes)
	PICK_CLOCK = 31, -- protocol 37 (S-174)
	START_BOXES = 32, -- variable size
	SHARE = 33, -- protocol 37 (S-176)
})
-- CHEAT_RESULT result codes (S-102)
Schema.CheatResult = table.freeze({
	OK = 0,
	CHEATS_OFF = 1, -- the match doesn't allow cheats
	BAD_ARGS = 2, -- an unknown unit type, a count or amount out of range
	NO_TEAM = 3, -- no player on that team
	NO_ROOM = 4, -- GIVE: no valid spot in the formation
	NOT_OFFLINE = 5, -- SPEED: only offline / in Studio
	NO_AI = 6, -- AI: no AI player on that team
	NO_MAP = 7, -- GIVE: the match has no map
})
local CHEAT_RESULT_MAX = 7
Schema.AlertKind = table.freeze({
	UNIT_ATTACKED = 1,
	STRUCTURE_ATTACKED = 2,
	UNIT_LOST = 3,
	STRUCTURE_LOST = 4,
	BUILD_DONE = 5,
	STALL_SUPPLY = 6,
	STALL_POWER = 7,
	NUKE_LAUNCH = 8,
	COMMANDER_ATTACKED = 9,
})
local ALERT_MAX = 9
local EK = Schema.EventKind
Schema.ENTER_BYTES = 16
-- fixed sizes; SIGHT_ROWS and SIGHT_CELLS are variable (Schema.eventBytes)
Schema.EVENT_BYTES = table.freeze({ [1] = 16, [2] = 3, [3] = 6, [4] = 10, [5] = 19, [6] = 9, [7] = 23, [8] = 15, [9] = 15, [10] = 3, [13] = 16, [14] = 19, [15] = 9, [16] = 9, [17] = 25, [18] = 8, [19] = 5, [20] = 13, [21] = 13, [22] = 7, [23] = 13, [24] = 3, [25] = 4, [26] = 9, [27] = 6, [28] = 7, [29] = 2, [31] = 3, [33] = 8 })
Schema.ShareKind = table.freeze({ UNITS = 1, SUPPLY = 2, POWER = 3, ASK_UNITS = 4, ASK_SUPPLY = 5, ASK_POWER = 6 }) -- SHARE what; REQUEST value (ASK_*); SHARE_RESOURCE resource (SUPPLY, POWER) (S-176)
Schema.PregameFlag = table.freeze({ PICKED = 1, READY = 2, AI = 4, CHAOS = 8, HOST = 16 }) -- PREGAME flags (S-169; CHAOS, HOST protocol 37)
local PREGAME_FLAGS_MAX = 31
Schema.PickClockFlag = table.freeze({ ALL_READY = 1, MAX_WAIT = 2, LOADING = 4 }) -- PICK_CLOCK flags (S-174): LOADING = humans still loading, the clock waits
Schema.LANDING_TICKS = 23 -- the Commanders land (1.5 s) after COUNTDOWN 0 and take no orders until then (S-174)
Schema.START_BOXES_MAX = 16
Schema.COUNTDOWN_STARTED = 0 -- COUNTDOWN seconds: the match starts
Schema.COUNTDOWN_CANCELLED = 255
Schema.PREBUILD_MAX = 30 -- PREBUILD entries (a player's pre-game queue)
Schema.ShieldFlag = table.freeze({ UP = 1, RECHARGING = 2 }) -- SHIELD flags: the dome stands; it is recharging (protocol 24)
Schema.SHIELD_BREACH = 1 -- SHIELD_HIT flags: the shell broke through (else it turned back)
Schema.SHIELD_ABSORBED = 2 -- SHIELD_HIT flags: a light shell destroyed at the surface; drop it, no burst (protocol 25, S-85)
Schema.SHIELD_MASS_SCALE = 31 -- SHIELD_HIT mass units per shell mass (8 masses fit a u8)
Schema.SIGHT_SEEN = 0x800000 -- SIGHT_CELLS: bit 23 of a cell entry (bit 15 before protocol 38)
Schema.Countermeasure = table.freeze({ FLARES = 1, CHAFF = 2, DIRCM = 3 }) -- DECOYED: what defeated the missile (protocol 13)
Schema.SIGHT_MAX_CELLS = 255 -- per SIGHT_CELLS record
Schema.SIGHT_MAX_ROW_BYTES = 640 -- per SIGHT_ROWS record (rowCount × rowBytes)
Schema.FIRE_HIT = 16 -- FIRE slot byte: bit 4
Schema.Y_SCALE = 8 -- pos.y and vel units per stud

export type Event = {
	kind: number,
	unitId: number?, -- ENTER, LEAVE, DEATH; FIRE: the shooter
	projId: number?, -- SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK
	-- ENTER
	defIndex: number?,
	team: number?, -- 1..8
	cell: number?, -- ENTER, and pos of FIRE (end point), SPAWN_PROJ, IMPACT, DECOYED
	offX: number?,
	offZ: number?,
	heading: number?,
	alt: number?,
	health: number?,
	build: number?,
	state: number?,
	alert: number?, -- ALERT: Schema.AlertKind (with cell / offX / offZ, defIndex)
	idle: boolean?, -- IDLE (S-136)
	queueHead: number?, -- OWN_STATUS: unit def index in production (0 = none; S-158)
	queueProgress: number?, -- OWN_STATUS: 0..255
	queueCount: number?, -- OWN_STATUS: items in the queue
	supply: number?, -- WRECK, WRECK_STATE: supply left in the wreck (whole units; S-168)
	fullSupply: number?, -- WRECK: what it held when the unit died
	featureKind: number?, -- WRECK: 0 a unit's wreck, else a map feature (Defs/Features: 1 tree, 2 rock; protocol 40, S-197)
	rez: number?, -- WRECK_STATE: resurrect progress 0..255
	player: number?, -- PREGAME, PREBUILD: the player (S-169)
	pregameFlags: number?, -- PREGAME: Schema.PregameFlag bits
	seconds: number?, -- COUNTDOWN, PICK_CLOCK
	clockFlags: number?, -- PICK_CLOCK: Schema.PickClockFlag bits
	toPlayer: number?, -- SHARE: the receiver (0 for a request; `player` the sender)
	shareKind: number?, -- SHARE: Schema.ShareKind
	amount: number?, -- SHARE: units or resource given
	boxes: { { allyTeam: number, x0: number, z0: number, x1: number, z1: number } }?, -- START_BOXES (world studs)
	builds: { { defIndex: number, cell: number, offX: number, offZ: number, facing: number } }?, -- PREBUILD
	charge: number?, -- SHIELD: 0..255 of capacity
	shieldFlags: number?, -- SHIELD: Schema.ShieldFlag bits
	mass: number?, -- SHIELD_HIT: the shell's mass × SHIELD_MASS_SCALE (u8)
	breach: boolean?, -- SHIELD_HIT: it broke through
	absorbed: boolean?, -- SHIELD_HIT: destroyed at the surface (protocol 25)
	radius: number?, -- SHIELD_FIELD: the dome's radius (studs; with its centre in cell / offX / offZ / y)
	force: number?, -- SHIELD_FIELD: 0..255 of full force
	phase: number?, -- SHIELD_FIELD: ShieldField.BRAKING (1) or REPELLED (2)
	cheatOp: number?, -- CHEAT_RESULT: Schema.CheatOp
	cheatResult: number?, -- CHEAT_RESULT: Schema.CheatResult
	count: number?, -- CHEAT_RESULT
	total: number?, -- CHEAT_RESULT
	-- DEATH
	severity: number?,
	wreckId: number?,
	-- FIRE
	slot: number?, -- 1..8
	hit: boolean?,
	-- pos (FIRE, SPAWN_PROJ, IMPACT, DECOYED)
	y: number?, -- eighth studs (i16)
	-- vel (SPAWN_PROJ, DECOYED)
	vx: number?,
	vy: number?,
	vz: number?,
	-- SPAWN_PROJ
	weaponIndex: number?,
	targetId: number?, -- 0 = none; INTERCEPTOR: the target projectile's ID
	-- DECOYED: the decoy point (a pos) and the ticks the missile still follows it
	decoyCell: number?,
	decoyOffX: number?,
	decoyOffZ: number?,
	decoyY: number?,
	decoyTicks: number?,
	countermeasure: number?, -- DECOYED: Schema.Countermeasure
	-- WRECK, WRECK_GONE: wreckId; WRECK: defIndex, cell, offX, offZ, heading
	-- SIGHT_ROWS
	firstRow: number?, -- 0-based sensor row
	rowCount: number?,
	rowBytes: number?,
	bits: buffer?, -- rowCount × rowBytes
	-- SIGHT_CELLS: cell index, + SIGHT_SEEN when the cell is now in sight
	cells: { number }?,
	-- SPAWN_STRATEGIC: the goal (a pos)
	goalCell: number?,
	goalOffX: number?,
	goalOffZ: number?,
	goalY: number?,
	-- SHOT: the start pos (end pos in cell / offX / offZ / y; hit as FIRE)
	fromCell: number?,
	fromOffX: number?,
	fromOffZ: number?,
	fromY: number?,
}

local function isProjEvent(kind: number): boolean
	return (kind >= EK.SPAWN_PROJ and kind <= EK.LOST_LOCK) or (kind >= EK.INTERCEPTOR and kind <= EK.SPAWN_STRATEGIC)
end

-- Encoded size of an event record.
function Schema.eventBytes(e: Event): number
	if e.kind == EK.SIGHT_ROWS then
		return 5 + (e.rowCount :: number) * (e.rowBytes :: number)
	elseif e.kind == EK.SIGHT_CELLS then
		return 2 + 3 * #(e.cells :: { number })
	elseif e.kind == EK.PREBUILD then
		return 3 + 7 * #(e.builds :: { any })
	elseif e.kind == EK.START_BOXES then
		return 2 + 9 * #(e.boxes :: { any })
	end
	return Schema.EVENT_BYTES[e.kind]
end

local function writePos(w: Writer, e: Event)
	w:writeU16(required(e.cell, "cell"))
	w:writeU8(required(e.offX, "offX"))
	w:writeU8(required(e.offZ, "offZ"))
	w:writeI16(required(e.y, "y"))
end

local function readPos(r: Reader, e: Event)
	e.cell = r:readU16()
	e.offX = r:readU8()
	e.offZ = r:readU8()
	e.y = r:readI16()
end

local function writeVel(w: Writer, e: Event)
	w:writeI16(required(e.vx, "vx"))
	w:writeI16(required(e.vy, "vy"))
	w:writeI16(required(e.vz, "vz"))
end

local function readVel(r: Reader, e: Event)
	e.vx = r:readI16()
	e.vy = r:readI16()
	e.vz = r:readI16()
end

-- Studs (or studs per second) → the i16 wire unit, clamped.
function Schema.toI16(v: number): number
	return math.clamp(math.floor(v * Schema.Y_SCALE + 0.5), -32768, 32767)
end

function Schema.encodeEvent(w: Writer, e: Event)
	local kind = e.kind
	if Schema.EVENT_BYTES[kind] == nil and kind ~= EK.SIGHT_ROWS and kind ~= EK.SIGHT_CELLS and kind ~= EK.PREBUILD and kind ~= EK.START_BOXES then
		error(`Schema: unknown event kind {kind}`, 2)
	end
	w:writeU8(kind)
	if kind == EK.SIGHT_ROWS then
		local rows, rowBytes = required(e.rowCount, "rowCount"), required(e.rowBytes, "rowBytes")
		local bits = required(e.bits, "bits")
		if rows < 1 or rows > 255 or rowBytes < 1 or rows * rowBytes > Schema.SIGHT_MAX_ROW_BYTES or buffer.len(bits) ~= rows * rowBytes then
			error(`Schema: SIGHT_ROWS of {rows} rows × {rowBytes} bytes ({buffer.len(bits)} given)`, 2)
		end
		w:writeU16(required(e.firstRow, "firstRow"))
		w:writeU8(rows)
		w:writeU8(rowBytes)
		w:writeBytes(bits)
		return
	elseif kind == EK.SIGHT_CELLS then
		local cells = required(e.cells, "cells")
		if #cells < 1 or #cells > Schema.SIGHT_MAX_CELLS then
			error(`Schema: SIGHT_CELLS needs 1..{Schema.SIGHT_MAX_CELLS} cells, got {#cells}`, 2)
		end
		w:writeU8(#cells)
		for _, c in cells do
			w:writeU16(c % 65536)
			w:writeU8(c // 65536)
		end
		return
	elseif kind == EK.SHOT then
		w:writeU8(if e.hit then 1 else 0)
		w:writeU16(required(e.fromCell, "fromCell"))
		w:writeU8(required(e.fromOffX, "fromOffX"))
		w:writeU8(required(e.fromOffZ, "fromOffZ"))
		w:writeI16(required(e.fromY, "fromY"))
		writePos(w, e)
		w:writeU16(e.weaponIndex or 0) -- (protocol 28, S-118)
		return
	elseif kind == EK.ALERT then
		local a = required(e.alert, "alert")
		if a < 1 or a > ALERT_MAX then
			error(`Schema: alert kind {a} outside 1..{ALERT_MAX}`, 2)
		end
		w:writeU8(a)
		w:writeU16(required(e.cell, "cell"))
		w:writeU8(e.offX or 0)
		w:writeU8(e.offZ or 0)
		w:writeU16(e.defIndex or 0)
		return
	elseif kind == EK.CHEAT_RESULT then
		local op, res = required(e.cheatOp, "cheatOp"), required(e.cheatResult, "cheatResult")
		if op < 1 or op > CHEAT_OP_MAX or res > CHEAT_RESULT_MAX then
			error(`Schema: cheat result op {op} result {res}`, 2)
		end
		w:writeU8(op)
		w:writeU8(res)
		w:writeU16(math.clamp(e.count or 0, 0, 65535))
		w:writeU16(math.clamp(e.total or 0, 0, 65535))
		return
	elseif kind == EK.SHIELD then
		local flags = required(e.shieldFlags, "shieldFlags")
		if flags > 3 then
			error(`Schema: shield flags {flags} have reserved bits`, 2)
		end
		writeId(w, required(e.unitId, "unitId"), "unitId")
		w:writeU8(required(e.charge, "charge"))
		w:writeU8(flags)
		return
	elseif kind == EK.DOME then
		local flags = required(e.shieldFlags, "shieldFlags")
		if flags > 3 then
			error(`Schema: dome flags {flags} have reserved bits`, 2)
		end
		writeId(w, required(e.unitId, "unitId"), "unitId")
		writePos(w, e)
		w:writeU16(math.clamp(math.floor(required(e.radius, "radius") + 0.5), 0, 65535))
		w:writeU8(required(e.charge, "charge"))
		w:writeU8(flags)
		return
	elseif kind == EK.DOME_GONE then
		writeId(w, required(e.unitId, "unitId"), "unitId")
		return
	elseif kind == EK.IDLE then
		writeId(w, required(e.unitId, "unitId"), "unitId")
		w:writeU8(if required(e.idle, "idle") then 1 else 0)
		return
	elseif kind == EK.PREGAME then
		local flags = required(e.pregameFlags, "pregameFlags")
		if flags > PREGAME_FLAGS_MAX then
			error(`Schema: pregame flags {flags} have reserved bits`, 2)
		end
		w:writeU8(required(e.player, "player"))
		w:writeU8(flags)
		w:writeU16(e.cell or 0)
		w:writeU8(e.offX or 0)
		w:writeU8(e.offZ or 0)
		return
	elseif kind == EK.COUNTDOWN then
		w:writeU8(required(e.seconds, "seconds"))
		return
	elseif kind == EK.SHARE then
		local what = required(e.shareKind, "shareKind")
		if what < 1 or what > 6 then
			error(`Schema: share kind {what}`, 2)
		end
		w:writeU8(required(e.player, "player"))
		w:writeU8(e.toPlayer or 0)
		w:writeU8(what)
		w:writeU32(e.amount or 0)
		return
	elseif kind == EK.PICK_CLOCK then
		w:writeU8(required(e.seconds, "seconds"))
		local flags = required(e.clockFlags, "clockFlags")
		if flags > 7 then
			error(`Schema: pick clock flags {flags} have reserved bits`, 2)
		end
		w:writeU8(flags)
		return
	elseif kind == EK.START_BOXES then
		local boxes = required(e.boxes, "boxes")
		if #boxes > Schema.START_BOXES_MAX then
			error(`Schema: START_BOXES of {#boxes} (at most {Schema.START_BOXES_MAX})`, 2)
		end
		w:writeU8(#boxes)
		for _, b in boxes do
			w:writeU8(b.allyTeam)
			w:writeI16(b.x0)
			w:writeI16(b.z0)
			w:writeI16(b.x1)
			w:writeI16(b.z1)
		end
		return
	elseif kind == EK.PREBUILD then
		local builds = required(e.builds, "builds")
		if #builds > Schema.PREBUILD_MAX then
			error(`Schema: PREBUILD of {#builds} (at most {Schema.PREBUILD_MAX})`, 2)
		end
		w:writeU8(required(e.player, "player"))
		w:writeU8(#builds)
		for _, b in builds do
			writeId(w, b.defIndex, "defIndex")
			w:writeU16(b.cell)
			w:writeU8(b.offX)
			w:writeU8(b.offZ)
			if b.facing > MAX_FACING then
				error(`Schema: facing {b.facing} outside 0..{MAX_FACING}`, 2)
			end
			w:writeU8(b.facing)
		end
		return
	elseif kind == EK.OWN_STATUS then
		writeId(w, required(e.unitId, "unitId"), "unitId")
		w:writeU8(required(e.health, "health"))
		w:writeU8(required(e.build, "build"))
		w:writeU16(e.queueHead or 0)
		w:writeU8(e.queueProgress or 0)
		w:writeU8(math.clamp(e.queueCount or 0, 0, 255))
		return
	elseif kind == EK.SHIELD_FIELD then
		local phase = required(e.phase, "phase")
		if phase ~= 1 and phase ~= 2 then
			error(`Schema: shield field phase {phase} (1 or 2)`, 2)
		end
		writeId(w, required(e.projId, "projId"), "projId")
		writePos(w, e)
		w:writeU16(required(e.radius, "radius"))
		w:writeU8(required(e.force, "force"))
		w:writeU8(phase)
		return
	elseif kind == EK.SHIELD_HIT then
		w:writeU16(e.unitId or 0) -- 0: a generator the client doesn't have
		w:writeU16(e.projId or 0) -- 0: a hitscan shot (protocol 26)
		writePos(w, e)
		w:writeU8(required(e.mass, "mass"))
		if e.breach and e.absorbed then
			error("Schema: a shield hit is a breach or absorbed, not both", 2)
		end
		w:writeU8(if e.breach then Schema.SHIELD_BREACH elseif e.absorbed then Schema.SHIELD_ABSORBED else 0)
		return
	elseif kind == EK.WRECK or kind == EK.WRECK_GONE then
		writeId(w, required(e.wreckId, "wreckId"), "wreckId")
		if kind == EK.WRECK then
			local feature = e.featureKind or 0
			if feature == 0 then
				writeId(w, required(e.defIndex, "defIndex"), "defIndex")
			else
				w:writeU16(0) -- a map feature has no unit def (S-197)
			end
			w:writeU16(required(e.cell, "cell"))
			w:writeU8(required(e.offX, "offX"))
			w:writeU8(required(e.offZ, "offZ"))
			w:writeU8(required(e.heading, "heading"))
			w:writeU16(math.clamp(e.supply or 0, 0, 65535)) -- (protocol 35, S-168)
			w:writeU16(math.clamp(e.fullSupply or 0, 0, 65535))
			w:writeU8(feature) -- (protocol 40)
		end
		return
	elseif kind == EK.WRECK_STATE then
		writeId(w, required(e.wreckId, "wreckId"), "wreckId")
		w:writeU16(math.clamp(required(e.supply, "supply"), 0, 65535))
		w:writeU8(required(e.rez, "rez"))
		return
	end
	if isProjEvent(kind) then
		writeId(w, required(e.projId, "projId"), "projId")
	else
		writeId(w, required(e.unitId, "unitId"), "unitId")
	end
	if kind == EK.ENTER then
		local team = required(e.team, "team")
		if team < 1 or team > Schema.MAX_TEAMS then
			error(`Schema: team {team} outside 1..{Schema.MAX_TEAMS}`, 2)
		end
		writeId(w, required(e.defIndex, "defIndex"), "defIndex")
		w:writeU8(team)
		w:writeU16(required(e.cell, "cell"))
		w:writeU8(required(e.offX, "offX"))
		w:writeU8(required(e.offZ, "offZ"))
		w:writeU8(required(e.heading, "heading"))
		w:writeU8(required(e.alt, "alt"))
		w:writeU8(required(e.health, "health"))
		w:writeU8(required(e.build, "build"))
		w:writeU16(required(e.state, "state"))
	elseif kind == EK.DEATH then
		w:writeU8(required(e.severity, "severity"))
		w:writeU16(required(e.wreckId, "wreckId"))
	elseif kind == EK.FIRE then
		local slot = required(e.slot, "slot")
		if slot < 1 or slot > Schema.MAX_WEAPONS then
			error(`Schema: weapon slot {slot} outside 1..{Schema.MAX_WEAPONS}`, 2)
		end
		w:writeU8(slot + (if e.hit then Schema.FIRE_HIT else 0))
		writePos(w, e)
	elseif kind == EK.SPAWN_PROJ or kind == EK.INTERCEPTOR or kind == EK.SPAWN_STRATEGIC then
		writeId(w, required(e.weaponIndex, "weaponIndex"), "weaponIndex")
		writePos(w, e)
		writeVel(w, e)
		w:writeU16(e.targetId or 0)
		if kind == EK.SPAWN_STRATEGIC then
			w:writeU16(required(e.goalCell, "goalCell"))
			w:writeU8(required(e.goalOffX, "goalOffX"))
			w:writeU8(required(e.goalOffZ, "goalOffZ"))
			w:writeI16(required(e.goalY, "goalY"))
		end
	elseif kind == EK.IMPACT or kind == EK.LAUNCH_WARNING or kind == EK.INTERCEPTED then
		writePos(w, e)
	elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
		writePos(w, e)
		writeVel(w, e)
		if kind == EK.DECOYED then
			w:writeU16(required(e.decoyCell, "decoyCell"))
			w:writeU8(required(e.decoyOffX, "decoyOffX"))
			w:writeU8(required(e.decoyOffZ, "decoyOffZ"))
			w:writeI16(required(e.decoyY, "decoyY"))
			w:writeU8(required(e.decoyTicks, "decoyTicks"))
			local cm = required(e.countermeasure, "countermeasure")
			if cm < 1 or cm > 3 then
				error(`Schema: countermeasure {cm} outside 1..3`, 2)
			end
			w:writeU8(cm)
		end
	end
end

function Schema.decodeEvent(r: Reader): Event
	r.context = "event record"
	local kind = r:readU8()
	if Schema.EVENT_BYTES[kind] == nil and kind ~= EK.SIGHT_ROWS and kind ~= EK.SIGHT_CELLS and kind ~= EK.PREBUILD and kind ~= EK.START_BOXES then
		fail(r, `unknown event kind {kind}`)
	end
	local e: Event = { kind = kind }
	if kind == EK.SIGHT_ROWS then
		e.firstRow = r:readU16()
		local rows, rowBytes = r:readU8(), r:readU8()
		if rows < 1 or rowBytes < 1 or rows * rowBytes > Schema.SIGHT_MAX_ROW_BYTES then
			fail(r, `SIGHT_ROWS of {rows} rows × {rowBytes} bytes`)
		end
		e.rowCount, e.rowBytes = rows, rowBytes
		e.bits = r:readBuffer(rows * rowBytes)
		return e
	elseif kind == EK.SIGHT_CELLS then
		local count = r:readU8()
		if count < 1 then
			fail(r, "SIGHT_CELLS with no cells")
		end
		local cells = table.create(count)
		for i = 1, count do
			local low = r:readU16()
			cells[i] = r:readU8() * 65536 + low
		end
		e.cells = cells
		return e
	elseif kind == EK.SHOT then
		local hit = r:readU8()
		if hit > 1 then
			fail(r, `SHOT hit byte {hit}`)
		end
		e.hit = hit == 1
		e.fromCell = r:readU16()
		e.fromOffX = r:readU8()
		e.fromOffZ = r:readU8()
		e.fromY = r:readI16()
		readPos(r, e)
		e.weaponIndex = r:readU16() -- (protocol 28, S-118)
		return e
	elseif kind == EK.ALERT then
		local a = r:readU8()
		if a < 1 or a > ALERT_MAX then
			fail(r, `alert kind {a}`)
		end
		e.alert = a
		e.cell = r:readU16()
		e.offX = r:readU8()
		e.offZ = r:readU8()
		e.defIndex = r:readU16()
		return e
	elseif kind == EK.CHEAT_RESULT then
		local op, res = r:readU8(), r:readU8()
		if op < 1 or op > CHEAT_OP_MAX or res > CHEAT_RESULT_MAX then
			fail(r, `cheat result op {op} result {res}`)
		end
		e.cheatOp, e.cheatResult = op, res
		e.count = r:readU16()
		e.total = r:readU16()
		return e
	elseif kind == EK.SHIELD then
		e.unitId = readId(r, "unitId")
		e.charge = r:readU8()
		local flags = r:readU8()
		if flags > 3 then
			fail(r, `shield flags {flags}`)
		end
		e.shieldFlags = flags
		return e
	elseif kind == EK.DOME then
		e.unitId = readId(r, "unitId")
		readPos(r, e)
		e.radius = r:readU16()
		e.charge = r:readU8()
		local flags = r:readU8()
		if flags > 3 then
			fail(r, `dome flags {flags}`)
		end
		e.shieldFlags = flags
		return e
	elseif kind == EK.DOME_GONE then
		e.unitId = readId(r, "unitId")
		return e
	elseif kind == EK.IDLE then
		e.unitId = readId(r, "unitId")
		local v = r:readU8()
		if v > 1 then
			fail(r, `idle {v} (0 or 1)`)
		end
		e.idle = v == 1
		return e
	elseif kind == EK.PREGAME then
		e.player = r:readU8()
		local flags = r:readU8()
		if flags > PREGAME_FLAGS_MAX then
			fail(r, `pregame flags {flags}`)
		end
		e.pregameFlags = flags
		e.cell = r:readU16()
		e.offX = r:readU8()
		e.offZ = r:readU8()
		return e
	elseif kind == EK.COUNTDOWN then
		e.seconds = r:readU8()
		return e
	elseif kind == EK.SHARE then
		e.player = r:readU8()
		e.toPlayer = r:readU8()
		local what = r:readU8()
		if what < 1 or what > 6 then
			fail(r, `share kind {what}`)
		end
		e.shareKind = what
		e.amount = r:readU32()
		return e
	elseif kind == EK.PICK_CLOCK then
		e.seconds = r:readU8()
		local flags = r:readU8()
		if flags > 7 then
			fail(r, `pick clock flags {flags}`)
		end
		e.clockFlags = flags
		return e
	elseif kind == EK.START_BOXES then
		local count = r:readU8()
		if count > Schema.START_BOXES_MAX then
			fail(r, `START_BOXES of {count}`)
		end
		local boxes = table.create(count)
		for i = 1, count do
			boxes[i] = { allyTeam = r:readU8(), x0 = r:readI16(), z0 = r:readI16(), x1 = r:readI16(), z1 = r:readI16() }
		end
		e.boxes = boxes
		return e
	elseif kind == EK.PREBUILD then
		e.player = r:readU8()
		local count = r:readU8()
		if count > Schema.PREBUILD_MAX then
			fail(r, `PREBUILD of {count}`)
		end
		local builds = table.create(count)
		for i = 1, count do
			local defIndex = readId(r, "defIndex")
			local cell = r:readU16()
			local offX, offZ = r:readU8(), r:readU8()
			local facing = r:readU8()
			if facing > MAX_FACING then
				fail(r, `facing {facing}`)
			end
			builds[i] = { defIndex = defIndex, cell = cell, offX = offX, offZ = offZ, facing = facing }
		end
		e.builds = builds
		return e
	elseif kind == EK.OWN_STATUS then
		e.unitId = readId(r, "unitId")
		e.health = r:readU8()
		e.build = r:readU8()
		e.queueHead = r:readU16()
		e.queueProgress = r:readU8()
		e.queueCount = r:readU8()
		return e
	elseif kind == EK.SHIELD_FIELD then
		e.projId = readId(r, "projId")
		readPos(r, e)
		e.radius = r:readU16()
		e.force = r:readU8()
		local phase = r:readU8()
		if phase ~= 1 and phase ~= 2 then
			fail(r, `shield field phase {phase}`)
		end
		e.phase = phase
		return e
	elseif kind == EK.SHIELD_HIT then
		e.unitId = r:readU16()
		e.projId = r:readU16()
		readPos(r, e)
		e.mass = r:readU8()
		local flags = r:readU8()
		if flags > 2 then
			fail(r, `shield hit flags {flags}`)
		end
		e.breach = flags == Schema.SHIELD_BREACH
		e.absorbed = flags == Schema.SHIELD_ABSORBED
		return e
	elseif kind == EK.WRECK or kind == EK.WRECK_GONE then
		e.wreckId = readId(r, "wreckId")
		if kind == EK.WRECK then
			e.defIndex = r:readU16() -- (0 for a map feature)
			e.cell = r:readU16()
			e.offX = r:readU8()
			e.offZ = r:readU8()
			e.heading = r:readU8()
			e.supply = r:readU16()
			e.fullSupply = r:readU16()
			e.featureKind = r:readU8()
			if e.featureKind > 2 then
				fail(r, `feature kind {e.featureKind}`)
			elseif e.featureKind == 0 and e.defIndex == 0 then
				fail(r, "a wreck with defIndex 0")
			end
		end
		return e
	elseif kind == EK.WRECK_STATE then
		e.wreckId = readId(r, "wreckId")
		e.supply = r:readU16()
		e.rez = r:readU8()
		return e
	end
	if isProjEvent(kind) then
		e.projId = readId(r, "projId")
	else
		e.unitId = readId(r, "unitId")
	end
	if kind == EK.ENTER then
		e.defIndex = readId(r, "defIndex")
		local team = r:readU8()
		if team < 1 or team > Schema.MAX_TEAMS then
			fail(r, `team {team} outside 1..{Schema.MAX_TEAMS}`)
		end
		e.team = team
		e.cell = r:readU16()
		e.offX = r:readU8()
		e.offZ = r:readU8()
		e.heading = r:readU8()
		e.alt = r:readU8()
		e.health = r:readU8()
		e.build = r:readU8()
		e.state = r:readU16()
	elseif kind == EK.DEATH then
		e.severity = r:readU8()
		e.wreckId = r:readU16()
	elseif kind == EK.FIRE then
		local b = r:readU8()
		local slot = band(b, 15)
		if band(b, 0xE0) ~= 0 then
			fail(r, `slot byte has reserved bits: {b}`)
		end
		if slot < 1 or slot > Schema.MAX_WEAPONS then
			fail(r, `weapon slot {slot} outside 1..{Schema.MAX_WEAPONS}`)
		end
		e.slot = slot
		e.hit = band(b, Schema.FIRE_HIT) ~= 0
		readPos(r, e)
	elseif kind == EK.SPAWN_PROJ or kind == EK.INTERCEPTOR or kind == EK.SPAWN_STRATEGIC then
		e.weaponIndex = readId(r, "weaponIndex")
		readPos(r, e)
		readVel(r, e)
		e.targetId = r:readU16()
		if kind == EK.SPAWN_STRATEGIC then
			e.goalCell = r:readU16()
			e.goalOffX = r:readU8()
			e.goalOffZ = r:readU8()
			e.goalY = r:readI16()
		end
	elseif kind == EK.IMPACT or kind == EK.LAUNCH_WARNING or kind == EK.INTERCEPTED then
		readPos(r, e)
	elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
		readPos(r, e)
		readVel(r, e)
		if kind == EK.DECOYED then
			e.decoyCell = r:readU16()
			e.decoyOffX = r:readU8()
			e.decoyOffZ = r:readU8()
			e.decoyY = r:readI16()
			e.decoyTicks = r:readU8()
			local cm = r:readU8()
			if cm < 1 or cm > 3 then
				fail(r, `countermeasure {cm} outside 1..3`)
			end
			e.countermeasure = cm
		end
	end
	return e
end

--------------------------------------------------------------------------------
-- Join handshake (Snapshot channel, both directions; S-2, docs/contracts/net.md 10)
--   kind u8, then
--   HELLO    C → S  protocol u16 | defsHash u32                              =  7 bytes
--   REJECT   S → C  protocol u16 | defsHash u32 | reason u8 (1 protocol, 2 defs) = 8 bytes
--   WELCOME  S → C  tick u32 | player u8 | team u8 | allyTeam u8 | mapIdLength u8 | mapId
--                   | teamCount u8 | allyTeam u8 × teamCount (team 1 first; 0 = no such
--                   team; protocol 30, S-129)
--------------------------------------------------------------------------------

Schema.SnapshotKind = table.freeze({ HELLO = 1, REJECT = 2, WELCOME = 3 })
Schema.RejectReason = table.freeze({ PROTOCOL = 1, DEFS = 2 })
local SK = Schema.SnapshotKind

export type SnapshotRecord = {
	kind: number,
	protocol: number?, -- HELLO, REJECT
	defsHash: number?, -- HELLO, REJECT (u32)
	reason: number?, -- REJECT
	tick: number?, -- WELCOME: the full sim tick (u32)
	player: number?, -- WELCOME
	team: number?,
	allyTeam: number?,
	mapId: string?,
	teamAllies: { number }?, -- WELCOME: the ally team of teams 1..n, 0 for a team not in the match (protocol 30)
}

function Schema.encodeSnapshot(w: Writer, rec: SnapshotRecord)
	local kind = rec.kind
	if kind ~= SK.HELLO and kind ~= SK.REJECT and kind ~= SK.WELCOME then
		error(`Schema: unknown snapshot kind {kind}`, 2)
	end
	w:writeU8(kind)
	if kind == SK.WELCOME then
		w:writeU32(required(rec.tick, "tick"))
		w:writeU8(required(rec.player, "player"))
		w:writeU8(required(rec.team, "team"))
		w:writeU8(required(rec.allyTeam, "allyTeam"))
		local mapId = required(rec.mapId, "mapId")
		if #mapId > 255 then
			error("Schema: mapId longer than 255 bytes", 2)
		end
		w:writeU8(#mapId)
		w:writeString(mapId)
		local allies = rec.teamAllies or {}
		if #allies > Schema.MAX_TEAMS then
			error(`Schema: {#allies} teams (at most {Schema.MAX_TEAMS})`, 2)
		end
		w:writeU8(#allies)
		for _, a in allies do
			w:writeU8(a)
		end
	else
		w:writeU16(required(rec.protocol, "protocol"))
		w:writeU32(required(rec.defsHash, "defsHash"))
		if kind == SK.REJECT then
			local reason = required(rec.reason, "reason")
			if reason ~= Schema.RejectReason.PROTOCOL and reason ~= Schema.RejectReason.DEFS then
				error(`Schema: unknown reject reason {reason}`, 2)
			end
			w:writeU8(reason)
		end
	end
end

function Schema.decodeSnapshot(r: Reader): SnapshotRecord
	r.context = "snapshot record"
	local kind = r:readU8()
	if kind ~= SK.HELLO and kind ~= SK.REJECT and kind ~= SK.WELCOME then
		fail(r, `unknown snapshot kind {kind}`)
	end
	local rec: SnapshotRecord = { kind = kind }
	if kind == SK.WELCOME then
		rec.tick = r:readU32()
		rec.player = r:readU8()
		rec.team = r:readU8()
		rec.allyTeam = r:readU8()
		rec.mapId = r:readString(r:readU8())
		local n = r:readU8()
		if n > Schema.MAX_TEAMS then
			fail(r, `{n} teams`)
		end
		local allies = table.create(n)
		for i = 1, n do
			allies[i] = r:readU8()
		end
		rec.teamAllies = allies
	else
		rec.protocol = r:readU16()
		rec.defsHash = r:readU32()
		if kind == SK.REJECT then
			local reason = r:readU8()
			if reason ~= Schema.RejectReason.PROTOCOL and reason ~= Schema.RejectReason.DEFS then
				fail(r, `unknown reject reason {reason}`)
			end
			rec.reason = reason
		end
	end
	return rec
end

--------------------------------------------------------------------------------
-- Economy (Eco channel, S → C, reliable; S-2): after the tick header, one
-- record per team: a player gets its own team's, a spectator every team's
-- (protocol 9, S-21).
--   team u8 (1..8)
--   per resource (supply, then power):
--     stored u32 (whole) | storage u32 (whole) | income u32 (tenths per second)
--     | demand u32 (tenths per second) | ratio u8 (stall ratio × 255)
--   wind u8 (× 255)
--   radarError u16 (tenths of a stud; 0 = no radar) | trackError u16 (tenths;
--   0 = no fire-control radar) | precision u8 (Pinpointers, × 255): the
--   team's radar accuracy, what radar-fired weapons miss by: the hidden aim
--   point circles a contact at radarError, a tracked one at trackError,
--   both already scaled by the precision (guide 11.4; protocol 32, S-147) = 41 bytes
--------------------------------------------------------------------------------

export type EcoResource = { stored: number, storage: number, income: number, demand: number, ratio: number }
export type Eco = { team: number, supply: EcoResource, power: EcoResource, wind: number, radarError: number?, trackError: number?, precision: number?, supplyShare: number?, powerShare: number?, convertAt: number? }

Schema.ECO_BYTES = 44 -- (41 before protocol 40: the three levels, S-198)

local function writeResource(w: Writer, r: EcoResource)
	w:writeU32(r.stored)
	w:writeU32(r.storage)
	w:writeU32(r.income)
	w:writeU32(r.demand)
	w:writeU8(r.ratio)
end

local function readResource(r: Reader): EcoResource
	return { stored = r:readU32(), storage = r:readU32(), income = r:readU32(), demand = r:readU32(), ratio = r:readU8() }
end

function Schema.encodeEco(w: Writer, rec: Eco)
	if rec.team ~= math.floor(rec.team) or rec.team < 1 or rec.team > Schema.MAX_TEAMS then
		error(`Schema: eco team must be 1..{Schema.MAX_TEAMS}, got {rec.team}`, 2)
	end
	w:writeU8(rec.team)
	writeResource(w, rec.supply)
	writeResource(w, rec.power)
	w:writeU8(rec.wind)
	w:writeU16(rec.radarError or 0)
	w:writeU16(rec.trackError or 0)
	w:writeU8(rec.precision or 0)
	-- the team's sliders, percent (S-198; protocol 40): share levels, convert level
	w:writeU8(rec.supplyShare or 100)
	w:writeU8(rec.powerShare or 100)
	w:writeU8(rec.convertAt or 50)
end

function Schema.decodeEco(r: Reader): Eco
	r.context = "eco record"
	local team = r:readU8()
	if team < 1 or team > Schema.MAX_TEAMS then
		fail(r, `team {team} outside 1..{Schema.MAX_TEAMS}`)
	end
	local supply = readResource(r)
	local power = readResource(r)
	local rec: Eco = { team = team, supply = supply, power = power, wind = r:readU8(), radarError = r:readU16(), trackError = r:readU16(), precision = r:readU8() }
	rec.supplyShare, rec.powerShare, rec.convertAt = r:readU8(), r:readU8(), r:readU8()
	return rec
end

--------------------------------------------------------------------------------
-- Projectile corrections (S → C, unreliable; D102): the server's position
-- and velocity of a homing projectile the client already has, ~3 Hz.
--   projId u16 | pos | vel                                             = 14 bytes
--------------------------------------------------------------------------------

export type ProjSync = { projId: number, cell: number, offX: number, offZ: number, y: number, vx: number, vy: number, vz: number }

Schema.PROJ_SYNC_BYTES = 14

function Schema.encodeProjSync(w: Writer, rec: ProjSync)
	writeId(w, rec.projId, "projId")
	writePos(w, rec :: any)
	writeVel(w, rec :: any)
end

function Schema.decodeProjSync(r: Reader): ProjSync
	r.context = "projectile correction"
	local rec: any = { projId = readId(r, "projId") }
	readPos(r, rec)
	readVel(r, rec)
	return rec :: ProjSync
end

return Schema
