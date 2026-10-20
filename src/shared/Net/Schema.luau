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
Schema.PROTOCOL_VERSION = 5 -- 2: Events channel records (ENTER, LEAVE, DEATH); 3: combat events (FIRE, SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK); 4: Projectiles channel (homing corrections); 5: strategic TRACKED flag

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
})

Schema.CmdFlag = table.freeze({
	QUEUE = 1, -- shift: append to the order queue
	LINE = 2, -- line formation: a second position (the line's end) follows
})
local CMD_FLAGS_MASK = 3

-- Structure facing for BUILD: footprints rotate with it (guide 9.3).
Schema.Facing = table.freeze({ NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }) -- 0/90/180/270°
local MAX_FACING = 3

Schema.FireState = table.freeze({ HOLD_FIRE = 0, RETURN_FIRE = 1, FIRE_AT_WILL = 2 })
Schema.MoveState = table.freeze({ HOLD_POSITION = 0, MANEUVER = 1, ROAM = 2 })

-- Params layout per command type:
--   pos     cell u16, offX u8, offZ u8            (+ cell2, offX2, offZ2 with LINE)
--   target  targetId u16                          (unit, or wreck for RECLAIM)
--   build   defIndex u16, cell u16, offX u8, offZ u8, facing u8 (0..3; bits 2..7 reserved)
--   value   value u8                              (0..VALUE_MAX[cmdType])
--   camera  minX u8, minZ u8, maxX u8, maxZ u8    (cell rectangle, unit count 0)
--   none
type ParamKind = "pos" | "target" | "build" | "value" | "camera" | "none"

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
}
local VALUE_MAX: { [number]: number } = {
	[CT.SET_FIRE_STATE] = 2,
	[CT.SET_MOVE_STATE] = 2,
	[CT.TOGGLE] = 1,
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
	if kind == "camera" then
		if count ~= 0 then
			error("Schema: CAMERA commands carry no unit IDs", 2)
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
		w:writeU8(minX)
		w:writeU8(minZ)
		w:writeU8(maxX)
		w:writeU8(maxZ)
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
	if kind == "camera" then
		if count ~= 0 then
			fail(r, `CAMERA with {count} unit IDs`)
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
		local minX, minZ, maxX, maxZ = r:readU8(), r:readU8(), r:readU8(), r:readU8()
		if minX > maxX or minZ > maxZ then
			fail(r, "camera rectangle has min > max")
		end
		cmd.minX, cmd.minZ, cmd.maxX, cmd.maxZ = minX, minZ, maxX, maxZ
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
--   unitId u16 | mask u8 | [health u8] | [state u16] | [aim] | [weapon u16] | [build u8]
--   aim = slotMask u8 (bit i-1 = weapon slot i, 1..8) + yaw u8, pitch u8 per set bit
--------------------------------------------------------------------------------

Schema.MAX_WEAPONS = 8 -- aim slot mask is one byte; weapon field is 2 bits per slot in a u16

Schema.StateField = table.freeze({
	HEALTH = 1,
	STATE = 2,
	AIM = 4,
	WEAPON = 8,
	BUILD = 16,
})
local STATE_MASK_ALL = 31
local SF = Schema.StateField

Schema.WeaponState = table.freeze({ IDLE = 0, AIMING = 1, READY = 2, RESTORING = 3 })

export type Aim = { slot: number, yaw: number, pitch: number }

export type State = {
	unitId: number,
	health: number?, -- 0..255 fraction of max health
	state: number?, -- u16 state bit flags
	aim: { Aim }?, -- changed weapons only, ascending slot order
	weapon: number?, -- u16, 2 bits per slot; see packWeaponStates / weaponStateAt
	build: number?, -- 0..255 build progress
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
	return rec
end

--------------------------------------------------------------------------------
-- Strategic (S → C, unreliable, 2–4 Hz): every known unit, minimap level
--   unitId u16 | cell u16 | icon 6 bits | team 3 bits | flags 7 bits  = 6 bytes
--   Bits are packed LSB-first: icon = bits 0–5, team = 6–8, flags = 9–15.
--   Team travels as team - 1 (teams are 1..8).
--------------------------------------------------------------------------------

Schema.STRATEGIC_BYTES = 6
Schema.MAX_TEAMS = 8

Schema.StrategicFlag = table.freeze({
	RADAR_ONLY = 1, -- radar blip: icon is 0 (unknown) unless identified earlier
	SONAR_ONLY = 2,
	UNDER_ATTACK = 4,
	GHOST = 8, -- structure seen earlier, now out of sight
	TRACKED = 16, -- radar blip under fire-control radar: wobbles less, and the icon is the real one (D104)
})
local STRATEGIC_FLAGS_MASK = 31 -- bits 5..6 reserved

export type Strategic = {
	unitId: number,
	cell: number,
	icon: number, -- 0..63, 0 = unknown blip
	team: number, -- 1..8
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
	w:writeBits(rec.icon, 6)
	w:writeBits(rec.team - 1, 3)
	w:writeBits(rec.flags, 7)
	w:flushBits()
end

function Schema.decodeStrategic(r: Reader): Strategic
	r.context = "strategic record"
	local unitId = readId(r, "unitId")
	local cell = r:readU16()
	local icon = r:readBits(6)
	local team = r:readBits(3) + 1
	local flags = r:readBits(7)
	r:alignBits()
	if band(flags, STRATEGIC_FLAGS_MASK) ~= flags then
		fail(r, `flags has reserved bits: {flags}`)
	end
	return { unitId = unitId, cell = cell, icon = icon, team = team, flags = flags }
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
--   DECOYED     projId u16 | pos | vel (after the decoy turn)                 = 15 bytes
--   LOST_LOCK   projId u16 | pos | vel (the missile flies on unguided)       = 15 bytes
-- pos = cell u16 | offX u8 | offZ u8 | y i16 (eighth studs)                     6 bytes
-- vel = vx i16 | vy i16 | vz i16 (eighth studs per second)                     6 bytes
--------------------------------------------------------------------------------

Schema.EventKind = table.freeze({ ENTER = 1, LEAVE = 2, DEATH = 3, FIRE = 4, SPAWN_PROJ = 5, IMPACT = 6, DECOYED = 7, LOST_LOCK = 8 })
local EK = Schema.EventKind
Schema.ENTER_BYTES = 16
Schema.EVENT_BYTES = table.freeze({ [1] = 16, [2] = 3, [3] = 6, [4] = 10, [5] = 19, [6] = 9, [7] = 15, [8] = 15 })
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
	targetId: number?, -- 0 = none
}

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
	if Schema.EVENT_BYTES[kind] == nil then
		error(`Schema: unknown event kind {kind}`, 2)
	end
	w:writeU8(kind)
	if kind >= EK.SPAWN_PROJ then
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
	elseif kind == EK.SPAWN_PROJ then
		writeId(w, required(e.weaponIndex, "weaponIndex"), "weaponIndex")
		writePos(w, e)
		writeVel(w, e)
		w:writeU16(e.targetId or 0)
	elseif kind == EK.IMPACT then
		writePos(w, e)
	elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
		writePos(w, e)
		writeVel(w, e)
	end
end

function Schema.decodeEvent(r: Reader): Event
	r.context = "event record"
	local kind = r:readU8()
	if Schema.EVENT_BYTES[kind] == nil then
		fail(r, `unknown event kind {kind}`)
	end
	local e: Event = { kind = kind }
	if kind >= EK.SPAWN_PROJ then
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
	elseif kind == EK.SPAWN_PROJ then
		e.weaponIndex = readId(r, "weaponIndex")
		readPos(r, e)
		readVel(r, e)
		e.targetId = r:readU16()
	elseif kind == EK.IMPACT then
		readPos(r, e)
	elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
		readPos(r, e)
		readVel(r, e)
	end
	return e
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
