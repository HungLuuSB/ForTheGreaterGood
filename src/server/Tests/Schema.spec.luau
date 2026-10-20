--!strict
local Packer = require("@shared/Net/Packer")
local Prng = require("@shared/Util/Prng")
local Schema = require("@shared/Net/Schema")
local Tick = require("@shared/Net/Tick")
local RunAll = require("./RunAll")

type Command = Schema.Command
type Tactical = Schema.Tactical
type State = Schema.State
type Strategic = Schema.Strategic

local Writer = Packer.Writer
local Reader = Packer.Reader
local CT = Schema.CmdType
local LINE = Schema.CmdFlag.LINE
local QUEUE = Schema.CmdFlag.QUEUE

local SEED = 20261020
local RANDOM_COUNT = 1000

local function encodeOne<T>(encode: (Packer.Writer, T) -> (), record: T): buffer
	local w = Writer.new()
	encode(w, record)
	return w:finish()
end

local function bytesOf(buf: buffer): { number }
	local out = table.create(buffer.len(buf))
	for i = 0, buffer.len(buf) - 1 do
		out[i + 1] = buffer.readu8(buf, i)
	end
	return out
end

local function hex(buf: buffer): string
	local parts = table.create(buffer.len(buf))
	for i = 0, buffer.len(buf) - 1 do
		parts[i + 1] = string.format("%02x", buffer.readu8(buf, i))
	end
	return table.concat(parts, " ")
end

local function fromBytes(bytes: { number }): buffer
	local buf = buffer.create(#bytes)
	for i, b in bytes do
		buffer.writeu8(buf, i - 1, b)
	end
	return buf
end

-- Encodes all records into one buffer, decodes it back, compares.
local function roundTrip<T>(t: RunAll.Context, records: { T }, encode: (Packer.Writer, T) -> (), decode: (Packer.Reader) -> T)
	local w = Writer.new()
	for _, rec in records do
		encode(w, rec)
	end
	local decoded = Packer.readAll(w:finish(), decode)
	t.equal(#decoded, #records, "record count")
	t.deepEqual(decoded, records)
end

-- Every proper prefix of an encoded record must fail with a "truncated" error.
local function expectTruncated<T>(t: RunAll.Context, label: string, decode: (Packer.Reader) -> T, buf: buffer)
	for n = 0, buffer.len(buf) - 1 do
		local ok, err = pcall(decode, Reader.new(buf, 0, n))
		t.expect(not ok, `{label}: {n}-byte prefix decoded without error`)
		local message = tostring(err)
		t.expect(
			string.find(message, label .. ": truncated", 1, true) ~= nil,
			`{label}: {n}-byte prefix gave an unclear error: {message}`
		)
	end
end

local function expectRejected<T>(t: RunAll.Context, decode: (Packer.Reader) -> T, bytes: { number }, pattern: string)
	local ok, err = pcall(decode, Reader.new(fromBytes(bytes)))
	t.expect(not ok, `malformed input decoded without error (wanted "{pattern}")`)
	t.expect(string.find(tostring(err), pattern) ~= nil, `expected an error matching "{pattern}", got: {err}`)
end

local function ids(n: number, id: number): { number }
	local out = table.create(n, id)
	return out
end

--------------------------------------------------------------------------------
-- Random record generators (valid records only)
--------------------------------------------------------------------------------

local POS_TYPES = { CT.MOVE, CT.FIGHT, CT.ATTACK_GROUND, CT.PATROL }
local TARGET_TYPES = { CT.ATTACK, CT.GUARD, CT.REPAIR, CT.RECLAIM }
local VALUE_TYPES = { { CT.SET_FIRE_STATE, 2 }, { CT.SET_MOVE_STATE, 2 }, { CT.TOGGLE, 1 } }

local function randomCommand(rng: Prng.Prng): Command
	local kind = rng:nextInteger(1, 6)
	if kind == 6 then
		local minX, minZ = rng:nextInteger(0, 255), rng:nextInteger(0, 255)
		return {
			cmdType = CT.CAMERA,
			flags = 0,
			unitIds = {},
			minX = minX,
			minZ = minZ,
			maxX = rng:nextInteger(minX, 255),
			maxZ = rng:nextInteger(minZ, 255),
		}
	end
	local unitIds = {}
	for i = 1, rng:nextInteger(1, Schema.MAX_UNITS_PER_COMMAND) do
		unitIds[i] = rng:nextInteger(1, 65535)
	end
	local flags = if rng:chance(0.5) then QUEUE else 0
	if kind == 1 then
		local cmd: Command = {
			cmdType = POS_TYPES[rng:nextInteger(1, #POS_TYPES)],
			flags = flags,
			unitIds = unitIds,
			cell = rng:nextInteger(0, 65535),
			offX = rng:nextInteger(0, 255),
			offZ = rng:nextInteger(0, 255),
		}
		if rng:chance(0.5) then
			cmd.flags += LINE
			cmd.cell2 = rng:nextInteger(0, 65535)
			cmd.offX2 = rng:nextInteger(0, 255)
			cmd.offZ2 = rng:nextInteger(0, 255)
		end
		return cmd
	elseif kind == 2 then
		return {
			cmdType = TARGET_TYPES[rng:nextInteger(1, #TARGET_TYPES)],
			flags = flags,
			unitIds = unitIds,
			targetId = rng:nextInteger(1, 65535),
		}
	elseif kind == 3 then
		return {
			cmdType = CT.BUILD,
			flags = flags,
			unitIds = unitIds,
			defIndex = rng:nextInteger(1, 65535),
			cell = rng:nextInteger(0, 65535),
			offX = rng:nextInteger(0, 255),
			offZ = rng:nextInteger(0, 255),
			facing = rng:nextInteger(0, 3),
		}
	elseif kind == 4 then
		local entry = VALUE_TYPES[rng:nextInteger(1, #VALUE_TYPES)]
		return { cmdType = entry[1], flags = flags, unitIds = unitIds, value = rng:nextInteger(0, entry[2]) }
	else
		return { cmdType = CT.STOP, flags = flags, unitIds = unitIds }
	end
end

local function randomTactical(rng: Prng.Prng): Tactical
	return {
		unitId = rng:nextInteger(1, 65535),
		cell = rng:nextInteger(0, 65535),
		offX = rng:nextInteger(0, 255),
		offZ = rng:nextInteger(0, 255),
		heading = rng:nextInteger(0, 255),
		alt = if rng:chance(0.5) then rng:nextInteger(0, 255) else nil,
	}
end

local function randomState(rng: Prng.Prng): State
	local rec: State = { unitId = rng:nextInteger(1, 65535) }
	repeat
		if rng:chance(0.5) then
			rec.health = rng:nextInteger(0, 255)
		end
		if rng:chance(0.5) then
			rec.state = rng:nextInteger(0, 65535)
		end
		if rng:chance(0.5) then
			local aim = {}
			for slot = 1, Schema.MAX_WEAPONS do
				if rng:chance(0.5) then
					table.insert(aim, { slot = slot, yaw = rng:nextInteger(0, 255), pitch = rng:nextInteger(0, 255) })
				end
			end
			if #aim > 0 then
				rec.aim = aim
			end
		end
		if rng:chance(0.5) then
			rec.weapon = rng:nextInteger(0, 65535)
		end
		if rng:chance(0.5) then
			rec.build = rng:nextInteger(0, 255)
		end
	until rec.health or rec.state or rec.aim or rec.weapon or rec.build
	return rec
end

local function randomStrategic(rng: Prng.Prng): Strategic
	return {
		unitId = rng:nextInteger(1, 65535),
		cell = rng:nextInteger(0, 65535),
		icon = rng:nextInteger(0, 63),
		team = rng:nextInteger(1, Schema.MAX_TEAMS),
		flags = rng:nextInteger(0, 15),
	}
end

local function many<T>(seed: number, gen: (Prng.Prng) -> T): { T }
	local rng = Prng.new(seed)
	local out = table.create(RANDOM_COUNT)
	for i = 1, RANDOM_COUNT do
		out[i] = gen(rng)
	end
	return out
end

-- Largest record of each type, used for the truncation sweeps.
local BIG_COMMAND: Command = {
	cmdType = CT.MOVE,
	flags = QUEUE + LINE,
	unitIds = ids(Schema.MAX_UNITS_PER_COMMAND, 65535),
	cell = 65535,
	offX = 255,
	offZ = 255,
	cell2 = 65535,
	offX2 = 255,
	offZ2 = 255,
}
local FULL_STATE: State = {
	unitId = 65535,
	health = 255,
	state = 65535,
	aim = {
		{ slot = 1, yaw = 255, pitch = 0 },
		{ slot = 2, yaw = 0, pitch = 255 },
		{ slot = 3, yaw = 255, pitch = 255 },
		{ slot = 4, yaw = 1, pitch = 2 },
		{ slot = 5, yaw = 3, pitch = 4 },
		{ slot = 6, yaw = 5, pitch = 6 },
		{ slot = 7, yaw = 7, pitch = 8 },
		{ slot = 8, yaw = 0, pitch = 0 },
	},
	weapon = 65535,
	build = 255,
}

return function(t: RunAll.Context)
	t.test("exact byte sizes", function()
		local base: Tactical = { unitId = 1, cell = 0, offX = 0, offZ = 0, heading = 0 }
		t.equal(buffer.len(encodeOne(Schema.encodeTactical, base)), Schema.TACTICAL_BYTES)
		t.equal(Schema.TACTICAL_BYTES, 8)
		base.alt = 0
		t.equal(buffer.len(encodeOne(Schema.encodeTactical, base)), Schema.TACTICAL_ALT_BYTES)
		t.equal(Schema.TACTICAL_ALT_BYTES, 9)

		local strategic: Strategic = { unitId = 1, cell = 0, icon = 0, team = 1, flags = 0 }
		t.equal(buffer.len(encodeOne(Schema.encodeStrategic, strategic)), Schema.STRATEGIC_BYTES)
		t.equal(Schema.STRATEGIC_BYTES, 6)

		-- command: 4-byte header + 2 per unit + params
		t.equal(buffer.len(encodeOne(Schema.encodeCommand, { cmdType = CT.STOP, flags = 0, unitIds = { 1 } })), 6)
		t.equal(buffer.len(encodeOne(Schema.encodeCommand, BIG_COMMAND)), 4 + 400 + 8)
		local camera: Command = { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 0, maxZ = 0 }
		t.equal(buffer.len(encodeOne(Schema.encodeCommand, camera)), 8)
		local build: Command = { cmdType = CT.BUILD, flags = 0, unitIds = { 1 }, defIndex = 1, cell = 0, offX = 0, offZ = 0, facing = 0 }
		t.equal(buffer.len(encodeOne(Schema.encodeCommand, build)), 4 + 2 + 2 + 4 + 1)

		-- state: 3-byte header + fields; aim = slot mask + 2 per weapon; weapon = u16
		t.equal(buffer.len(encodeOne(Schema.encodeState, { unitId = 1, health = 0 })), 4)
		t.equal(buffer.len(encodeOne(Schema.encodeState, { unitId = 1, weapon = 0 })), 5)
		t.equal(buffer.len(encodeOne(Schema.encodeState, FULL_STATE)), 3 + 1 + 2 + (1 + 16) + 2 + 1)

		t.equal(buffer.len(encodeOne(Schema.encodeTickHeader, 0)), Schema.TICK_HEADER_BYTES)
	end)

	t.test("strategic bit layout: icon bits 0-5, team 6-8, flags 9-15", function()
		local rec: Strategic = { unitId = 0x0102, cell = 0x0304, icon = 1, team = 2, flags = 1 }
		-- 1 + (2 - 1) * 2^6 + 1 * 2^9 = 0x0241; the team field straddles the byte boundary
		t.deepEqual(bytesOf(encodeOne(Schema.encodeStrategic, rec)), { 0x02, 0x01, 0x04, 0x03, 0x41, 0x02 })
		local top: Strategic = { unitId = 1, cell = 0, icon = 63, team = 8, flags = 15 }
		t.deepEqual(bytesOf(encodeOne(Schema.encodeStrategic, top)), { 0x01, 0x00, 0x00, 0x00, 0xFF, 0x1F })
	end)

	-- Hand-computed bytes. If this test fails you changed the wire format:
	-- bump Schema.PROTOCOL_VERSION and update these bytes in the same change.
	t.test("golden bytes are pinned to PROTOCOL_VERSION", function()
		t.equal(Schema.PROTOCOL_VERSION, 2, "protocol version changed: update the golden bytes below")
		local build: Command = {
			cmdType = CT.BUILD,
			flags = QUEUE,
			unitIds = { 0x0102, 0x0304 },
			defIndex = 0x0506,
			cell = 0x0708,
			offX = 9,
			offZ = 10,
			facing = Schema.Facing.WEST,
		}
		t.equal(hex(encodeOne(Schema.encodeCommand, build)), "08 01 02 00 02 01 04 03 06 05 08 07 09 0a 03")
		local line: Command = {
			cmdType = CT.MOVE,
			flags = QUEUE + LINE,
			unitIds = { 1 },
			cell = 0x1234,
			offX = 1,
			offZ = 2,
			cell2 = 0x5678,
			offX2 = 3,
			offZ2 = 4,
		}
		t.equal(hex(encodeOne(Schema.encodeCommand, line)), "01 03 01 00 01 00 34 12 01 02 78 56 03 04")
		local camera: Command = { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 1, minZ = 2, maxX = 3, maxZ = 4 }
		t.equal(hex(encodeOne(Schema.encodeCommand, camera)), "0e 00 00 00 01 02 03 04")
		local tactical: Tactical = { unitId = 0x0201, cell = 0x0403, offX = 5, offZ = 6, heading = 7, alt = 9 }
		t.equal(hex(encodeOne(Schema.encodeTactical, tactical)), "01 02 03 04 05 06 07 01 09")
		local state: State = {
			unitId = 0x0102,
			health = 3,
			state = 0x0405,
			aim = { { slot = 1, yaw = 6, pitch = 7 }, { slot = 8, yaw = 8, pitch = 9 } },
			weapon = Schema.packWeaponStates({ 1, 0, 0, 0, 0, 0, 0, 3 }), -- 0xC001
			build = 10,
		}
		t.equal(hex(encodeOne(Schema.encodeState, state)), "02 01 1f 03 05 04 81 06 07 08 09 01 c0 0a")
		local strategic: Strategic = { unitId = 0x0102, cell = 0x0304, icon = 1, team = 2, flags = 1 }
		t.equal(hex(encodeOne(Schema.encodeStrategic, strategic)), "02 01 04 03 41 02")
		t.equal(hex(encodeOne(Schema.encodeTickHeader, 0xABCD)), "cd ab")
		-- version 2: events
		local enter: Schema.Event = {
			kind = Schema.EventKind.ENTER,
			unitId = 0x0102,
			defIndex = 0x0304,
			team = 2,
			cell = 0x0506,
			offX = 7,
			offZ = 8,
			heading = 9,
			alt = 10,
			health = 11,
			build = 12,
			state = 0x0D0E,
		}
		t.equal(hex(encodeOne(Schema.encodeEvent, enter)), "01 02 01 04 03 02 06 05 07 08 09 0a 0b 0c 0e 0d")
		t.equal(hex(encodeOne(Schema.encodeEvent, { kind = Schema.EventKind.LEAVE, unitId = 0x0102 })), "02 02 01")
		t.equal(hex(encodeOne(Schema.encodeEvent, { kind = Schema.EventKind.DEATH, unitId = 0x0102, severity = 200, wreckId = 0x0304 })), "03 02 01 c8 04 03")
	end)

	t.test("events round-trip, reject bad input, and every prefix is truncated", function()
		local events: { Schema.Event } = {
			{ kind = Schema.EventKind.ENTER, unitId = 65535, defIndex = 1, team = 8, cell = 65535, offX = 255, offZ = 0, heading = 255, alt = 0, health = 255, build = 0, state = 65535 },
			{ kind = Schema.EventKind.LEAVE, unitId = 1 },
			{ kind = Schema.EventKind.DEATH, unitId = 7, severity = 0, wreckId = 0 },
		}
		roundTrip(t, events, Schema.encodeEvent, Schema.decodeEvent)
		t.equal(buffer.len(encodeOne(Schema.encodeEvent, events[1])), Schema.ENTER_BYTES)
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, events[1]))
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, events[3]))
		expectRejected(t, Schema.decodeEvent, { 9, 1, 0 }, "unknown event kind 9")
		expectRejected(t, Schema.decodeEvent, { 2, 0, 0 }, "unitId 0 is reserved")
		expectRejected(t, Schema.decodeEvent, { 1, 1, 0, 1, 0, 9 }, "team 9 outside")
	end)

	t.test("tactical layout is byte exact", function()
		local rec: Tactical = { unitId = 0x0201, cell = 0x0403, offX = 5, offZ = 6, heading = 7, alt = 9 }
		t.deepEqual(bytesOf(encodeOne(Schema.encodeTactical, rec)), { 0x01, 0x02, 0x03, 0x04, 5, 6, 7, 1, 9 })
	end)

	t.test("edge values round-trip for every record type", function()
		roundTrip(t, {
			BIG_COMMAND,
			{ cmdType = CT.STOP, flags = 0, unitIds = { 1 } },
			{ cmdType = CT.ATTACK, flags = 0, unitIds = { 1 }, targetId = 65535 },
			{ cmdType = CT.ATTACK, flags = QUEUE, unitIds = { 65535 }, targetId = 1 },
			{ cmdType = CT.BUILD, flags = 0, unitIds = { 1 }, defIndex = 65535, cell = 0, offX = 0, offZ = 0, facing = 0 },
			{ cmdType = CT.BUILD, flags = 0, unitIds = { 2 }, defIndex = 1, cell = 65535, offX = 255, offZ = 255, facing = 3 },
			{ cmdType = CT.MOVE, flags = 0, unitIds = { 1 }, cell = 0, offX = 0, offZ = 0 },
			{ cmdType = CT.SET_FIRE_STATE, flags = 0, unitIds = { 1 }, value = 0 },
			{ cmdType = CT.SET_MOVE_STATE, flags = 0, unitIds = { 1 }, value = 2 },
			{ cmdType = CT.TOGGLE, flags = 0, unitIds = { 1 }, value = 1 },
			{ cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 255, maxZ = 255 },
		}, Schema.encodeCommand, Schema.decodeCommand)

		roundTrip(t, {
			{ unitId = 1, cell = 0, offX = 0, offZ = 0, heading = 0 },
			{ unitId = 65535, cell = 65535, offX = 255, offZ = 255, heading = 255 },
			{ unitId = 1, cell = 0, offX = 0, offZ = 0, heading = 0, alt = 0 },
			{ unitId = 65535, cell = 65535, offX = 255, offZ = 255, heading = 255, alt = 255 },
		}, Schema.encodeTactical, Schema.decodeTactical)

		roundTrip(t, {
			FULL_STATE,
			{ unitId = 1, health = 0 },
			{ unitId = 1, state = 0 },
			{ unitId = 1, state = 65535 },
			{ unitId = 1, aim = { { slot = 8, yaw = 0, pitch = 0 } } },
			{ unitId = 1, aim = { { slot = 1, yaw = 255, pitch = 255 } } },
			{ unitId = 1, weapon = 0 },
			{ unitId = 1, weapon = Schema.packWeaponStates({ 3, 2, 1, 0, 3, 2, 1, 0 }) },
			{ unitId = 1, build = 0 },
		}, Schema.encodeState, Schema.decodeState)

		roundTrip(t, {
			{ unitId = 1, cell = 0, icon = 0, team = 1, flags = 0 },
			{ unitId = 65535, cell = 65535, icon = 63, team = 8, flags = 15 },
			{ unitId = 2, cell = 1, icon = 62, team = 7, flags = Schema.StrategicFlag.GHOST },
		}, Schema.encodeStrategic, Schema.decodeStrategic)
	end)

	t.test("weapon state helpers", function()
		local states = { 3, 2, 1, 0, 0, 1, 2, 3 }
		local field = Schema.packWeaponStates(states)
		t.equal(field, 0xE41B)
		for slot, state in states do
			t.equal(Schema.weaponStateAt(field, slot), state, `slot {slot}`)
		end
		t.equal(Schema.packWeaponStates({ 3, 3, 3, 3, 3, 3, 3, 3 }), 0xFFFF)
		t.throws(function()
			Schema.packWeaponStates({ 0, 0, 0, 0, 0, 0, 0, 0, 0 })
		end, "more than MAX_WEAPONS")
	end)

	t.test("truncated buffers give a clear error for every record type", function()
		expectTruncated(t, "command record", Schema.decodeCommand, encodeOne(Schema.encodeCommand, BIG_COMMAND))
		local build: Command = { cmdType = CT.BUILD, flags = 0, unitIds = { 1 }, defIndex = 1, cell = 2, offX = 3, offZ = 4, facing = 2 }
		expectTruncated(t, "command record", Schema.decodeCommand, encodeOne(Schema.encodeCommand, build))
		local camera: Command = { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 1, minZ = 1, maxX = 2, maxZ = 2 }
		expectTruncated(t, "command record", Schema.decodeCommand, encodeOne(Schema.encodeCommand, camera))
		local alt: Tactical = { unitId = 1, cell = 2, offX = 3, offZ = 4, heading = 5, alt = 6 }
		expectTruncated(t, "tactical record", Schema.decodeTactical, encodeOne(Schema.encodeTactical, alt))
		expectTruncated(t, "state record", Schema.decodeState, encodeOne(Schema.encodeState, FULL_STATE))
		local strategic: Strategic = { unitId = 1, cell = 2, icon = 63, team = 8, flags = 15 }
		expectTruncated(t, "strategic record", Schema.decodeStrategic, encodeOne(Schema.encodeStrategic, strategic))
		expectTruncated(t, "message header", Schema.decodeTickHeader, encodeOne(Schema.encodeTickHeader, 65535))
	end)

	t.test("malformed records are rejected", function()
		local cmd = Schema.decodeCommand
		expectRejected(t, cmd, { 0, 0, 1, 0, 1, 0 }, "unknown cmdType 0")
		expectRejected(t, cmd, { 15, 0, 1, 0, 1, 0 }, "unknown cmdType 15")
		expectRejected(t, cmd, { CT.STOP, 4, 1, 0, 1, 0 }, "reserved bits")
		expectRejected(t, cmd, { CT.STOP, LINE, 1, 0, 1, 0 }, "LINE flag")
		expectRejected(t, cmd, { CT.STOP, 0, 0, 0 }, "unit count 0")
		expectRejected(t, cmd, { CT.STOP, 0, 201, 0 }, "unit count 201")
		expectRejected(t, cmd, { CT.STOP, 0, 0xFF, 0xFF }, "unit count 65535")
		expectRejected(t, cmd, { CT.STOP, 0, 1, 0, 0, 0 }, "unitId 0 is reserved")
		expectRejected(t, cmd, { CT.ATTACK, 0, 1, 0, 1, 0, 0, 0 }, "targetId 0 is reserved")
		expectRejected(t, cmd, { CT.TOGGLE, 0, 1, 0, 1, 0, 2 }, "value 2 out of range")
		expectRejected(t, cmd, { CT.CAMERA, 0, 1, 0, 1, 0 }, "CAMERA with 1 unit IDs")
		expectRejected(t, cmd, { CT.CAMERA, 0, 0, 0, 5, 0, 4, 0 }, "min > max")
		expectRejected(t, cmd, { CT.BUILD, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 4 }, "facing 4 outside 0..3")
		expectRejected(t, cmd, { CT.BUILD, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0x80 }, "facing 128")

		expectRejected(t, Schema.decodeTactical, { 0, 0, 0, 0, 0, 0, 0, 0 }, "unitId 0 is reserved")
		expectRejected(t, Schema.decodeTactical, { 1, 0, 0, 0, 0, 0, 0, 2 }, "reserved bits")

		expectRejected(t, Schema.decodeState, { 1, 0, 0 }, "mask is empty")
		expectRejected(t, Schema.decodeState, { 1, 0, 32 }, "reserved bits")
		expectRejected(t, Schema.decodeState, { 1, 0, Schema.StateField.AIM, 0 }, "aim slot mask is empty")

		expectRejected(t, Schema.decodeStrategic, { 1, 0, 0, 0, 0x00, 0x20 }, "reserved bits")
		expectRejected(t, Schema.decodeStrategic, { 0, 0, 0, 0, 0, 0 }, "unitId 0 is reserved")
	end)

	t.test("encoders reject invalid records", function()
		local function enc<T>(encode: (Packer.Writer, T) -> (), rec: T)
			return function()
				encode(Writer.new(), rec)
			end
		end
		t.throws(enc(Schema.encodeTactical, { unitId = 0, cell = 0, offX = 0, offZ = 0, heading = 0 }), "unitId 0")
		t.throws(enc(Schema.encodeTactical, { unitId = 1, cell = 0, offX = 256, offZ = 0, heading = 0 }), "u8 out of range")
		t.throws(enc(Schema.encodeStrategic, { unitId = 1, cell = 0, icon = 0, team = 0, flags = 0 }), "team 0")
		t.throws(enc(Schema.encodeStrategic, { unitId = 1, cell = 0, icon = 0, team = 9, flags = 0 }), "team 9")
		t.throws(enc(Schema.encodeStrategic, { unitId = 1, cell = 0, icon = 64, team = 1, flags = 0 }), "6%-bit value")
		t.throws(enc(Schema.encodeStrategic, { unitId = 1, cell = 0, icon = 0, team = 1, flags = 16 }), "reserved bits")
		t.throws(enc(Schema.encodeState, { unitId = 1 }), "no fields")
		t.throws(enc(Schema.encodeState, { unitId = 1, aim = {} }), "aim list is empty")
		t.throws(enc(Schema.encodeState, { unitId = 1, aim = { { slot = 2, yaw = 0, pitch = 0 }, { slot = 1, yaw = 0, pitch = 0 } } }), "ascending")
		t.throws(enc(Schema.encodeState, { unitId = 1, aim = { { slot = 9, yaw = 0, pitch = 0 } } }), "ascending")
		t.throws(enc(Schema.encodeState, { unitId = 1, weapon = 65536 }), "u16 out of range")
		local badFacing: Command = { cmdType = CT.BUILD, flags = 0, unitIds = { 1 }, defIndex = 1, cell = 0, offX = 0, offZ = 0, facing = 4 }
		t.throws(enc(Schema.encodeCommand, badFacing), "facing 4")
		local noFacing: Command = { cmdType = CT.BUILD, flags = 0, unitIds = { 1 }, defIndex = 1, cell = 0, offX = 0, offZ = 0 }
		t.throws(enc(Schema.encodeCommand, noFacing), "missing field facing")
		t.throws(enc(Schema.encodeCommand, { cmdType = CT.STOP, flags = 0, unitIds = ids(201, 1) }), "1..200")
		t.throws(enc(Schema.encodeCommand, { cmdType = CT.STOP, flags = 0, unitIds = {} }), "1..200")
		t.throws(enc(Schema.encodeCommand, { cmdType = CT.MOVE, flags = 0, unitIds = { 1 } }), "missing field cell")
		t.throws(enc(Schema.encodeCommand, { cmdType = CT.STOP, flags = LINE, unitIds = { 1 } }), "LINE flag")
		t.throws(enc(Schema.encodeCommand, { cmdType = 99, flags = 0, unitIds = { 1 } }), "unknown cmdType")
	end)

	t.test("chunking: messages stay within 900 bytes and records come back in order", function()
		local tactical = many(SEED, randomTactical)
		local wireTick = Tick.toWire(70000) -- past the first wrap
		local function writeTick(w: Packer.Writer)
			Schema.encodeTickHeader(w, wireTick)
		end
		local messages = Packer.chunk(tactical, Schema.encodeTactical, Packer.MAX_MESSAGE_BYTES, writeTick)
		t.expect(#messages > 1, "1,000 tactical records should need several messages")
		local recovered = {}
		for _, m in messages do
			t.expect(buffer.len(m) <= 900, `message of {buffer.len(m)} bytes`)
			local records, tick = Packer.readAll(m, Schema.decodeTactical, Schema.decodeTickHeader)
			t.equal(tick, 70000 - 65536)
			for _, rec in records do
				table.insert(recovered, rec)
			end
		end
		t.deepEqual(recovered, tactical)

		-- 150 strategic records fill a 900-byte message exactly
		local strategic = many(SEED + 1, randomStrategic)
		messages = Packer.chunk(strategic, Schema.encodeStrategic)
		t.equal(#messages, math.ceil(RANDOM_COUNT / 150))
		t.equal(buffer.len(messages[1]), 900)
		recovered = {}
		for _, m in messages do
			for _, rec in (Packer.readAll(m, Schema.decodeStrategic)) do
				table.insert(recovered, rec)
			end
		end
		t.deepEqual(recovered, strategic)
	end)

	t.test("randomized round-trip: 1,000 records per type (fixed seed)", function()
		roundTrip(t, many(SEED, randomCommand), Schema.encodeCommand, Schema.decodeCommand)
		roundTrip(t, many(SEED, randomTactical), Schema.encodeTactical, Schema.decodeTactical)
		roundTrip(t, many(SEED, randomState), Schema.encodeState, Schema.decodeState)
		roundTrip(t, many(SEED, randomStrategic), Schema.encodeStrategic, Schema.decodeStrategic)
	end)
end
