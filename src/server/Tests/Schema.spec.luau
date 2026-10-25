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
local VALUE_TYPES = { { CT.SET_FIRE_STATE, 2 }, { CT.SET_MOVE_STATE, 2 }, { CT.TOGGLE, 1 }, { CT.REPEAT, 1 }, { CT.CANCEL, 50 } }

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
		if rng:chance(0.5) then
			local targets = {}
			for slot = 1, Schema.MAX_WEAPONS do
				if rng:chance(0.5) then
					table.insert(targets, { slot = slot, targetId = rng:nextInteger(0, 65535) })
				end
			end
			if #targets > 0 then
				rec.targets = targets
			end
		end
	until rec.health or rec.state or rec.aim or rec.weapon or rec.build or rec.targets
	return rec
end

local function randomStrategic(rng: Prng.Prng): Strategic
	return {
		unitId = rng:nextInteger(1, 65535),
		cell = rng:nextInteger(0, 65535),
		icon = rng:nextInteger(0, 255),
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
	targets = {
		{ slot = 1, targetId = 65535 },
		{ slot = 2, targetId = 0 },
		{ slot = 3, targetId = 1 },
		{ slot = 4, targetId = 2 },
		{ slot = 5, targetId = 3 },
		{ slot = 6, targetId = 4 },
		{ slot = 7, targetId = 5 },
		{ slot = 8, targetId = 6 },
	},
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
		t.equal(Schema.STRATEGIC_BYTES, 7) -- 4-bit team since protocol 36 (S-169)

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
		t.equal(buffer.len(encodeOne(Schema.encodeState, FULL_STATE)), 3 + 1 + 2 + (1 + 16) + 2 + 1 + (1 + 16))

		t.equal(buffer.len(encodeOne(Schema.encodeTickHeader, 0)), Schema.TICK_HEADER_BYTES)
	end)

	t.test("strategic bit layout: icon bits 0-7, team 8-11, flags 12-16, 7 reserved (protocol 36)", function()
		local rec: Strategic = { unitId = 0x0102, cell = 0x0304, icon = 1, team = 2, flags = 1 }
		-- 1 + (2 - 1) * 2^8 + 1 * 2^12 = 0x1101
		t.deepEqual(bytesOf(encodeOne(Schema.encodeStrategic, rec)), { 0x02, 0x01, 0x04, 0x03, 0x01, 0x11, 0x00 })
		local top: Strategic = { unitId = 1, cell = 0, icon = 255, team = 16, flags = 31 }
		t.deepEqual(bytesOf(encodeOne(Schema.encodeStrategic, top)), { 0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x01 })
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeStrategic, top), Schema.decodeStrategic)[1], top)
		expectRejected(t, Schema.decodeStrategic, { 1, 0, 0, 0, 0, 0, 0x02 }, "reserved bits")
	end)

	-- Hand-computed bytes. If this test fails you changed the wire format:
	-- bump Schema.PROTOCOL_VERSION and update these bytes in the same change.
	t.test("golden bytes are pinned to PROTOCOL_VERSION", function()
		t.equal(Schema.PROTOCOL_VERSION, 37, "protocol version changed: update the golden bytes below")
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
		-- version 7: REPEAT (S-13)
		local repeatOn: Command = { cmdType = CT.REPEAT, flags = 0, unitIds = { 0x0102 }, value = 1 }
		t.equal(hex(encodeOne(Schema.encodeCommand, repeatOn)), "0f 00 01 00 02 01 01")
		-- version 8: State TARGET field (S-16)
		local aimed: State = { unitId = 0x0102, targets = { { slot = 1, targetId = 0x0304 }, { slot = 3, targetId = 0 } } }
		t.equal(hex(encodeOne(Schema.encodeState, aimed)), "02 01 20 05 04 03 00 00")
		-- version 15: State STOCK field (S-47)
		-- version 17: each stock entry also carries the next missile's progress (S-49)
		local stocked: State = { unitId = 0x0102, stock = { { slot = 1, count = 8, progress = 0 }, { slot = 3, count = 0, progress = 0x7f } } }
		t.equal(hex(encodeOne(Schema.encodeState, stocked)), "02 01 40 05 08 00 00 7f")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeState, stocked), Schema.decodeState)[1], stocked)
		local both: State = { unitId = 1, targets = { { slot = 2, targetId = 7 } }, stock = { { slot = 2, count = 255, progress = 1 } } }
		t.equal(hex(encodeOne(Schema.encodeState, both)), "01 00 60 02 07 00 02 ff 01")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeState, both), Schema.decodeState)[1], both)
		expectTruncated(t, "state record", Schema.decodeState, encodeOne(Schema.encodeState, both))
		-- version 20: the OWNER field (S-61): queue, fire / move state, ammo
		local own: State = { unitId = 0x0102, queue = { 0x0304, 5 }, queueProgress = 0x80, fireState = 2, moveState = 1, ammo = 3, maxAmmo = 4 }
		t.equal(hex(encodeOne(Schema.encodeState, own)), "02 01 80 07 02 80 04 03 05 00 06 03 04")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeState, own), Schema.decodeState)[1], own)
		expectTruncated(t, "state record", Schema.decodeState, encodeOne(Schema.encodeState, own))
		local onlyStates: State = { unitId = 1, fireState = 0, moveState = 2 }
		t.equal(hex(encodeOne(Schema.encodeState, onlyStates)), "01 00 80 02 08")
		-- version 24: shield domes (S-79): SHIELD state, SHIELD_HIT (generator 0 =
		-- unknown), SHIELD_FIELD (the dome's centre, radius, force, phase)
		local shield: Schema.Event = { kind = Schema.EventKind.SHIELD, unitId = 0x0102, charge = 0x80, shieldFlags = 3 }
		t.equal(hex(encodeOne(Schema.encodeEvent, shield)), "13 02 01 80 03")
		local hit: Schema.Event = { kind = Schema.EventKind.SHIELD_HIT, unitId = 0, projId = 0x0304, cell = 0x0506, offX = 7, offZ = 8, y = 9, mass = 31, breach = true, absorbed = false }
		t.equal(hex(encodeOne(Schema.encodeEvent, hit)), "14 00 00 04 03 06 05 07 08 09 00 1f 01")
		-- version 25: SHIELD_HIT flag ABSORBED (S-85), a light shell destroyed at the surface
		local absorbed: Schema.Event = { kind = Schema.EventKind.SHIELD_HIT, unitId = 0x0102, projId = 0x0304, cell = 0x0506, offX = 7, offZ = 8, y = 9, mass = 7, breach = false, absorbed = true }
		t.equal(hex(encodeOne(Schema.encodeEvent, absorbed)), "14 02 01 04 03 06 05 07 08 09 00 07 02")
		t.throws(function()
			encodeOne(Schema.encodeEvent, { kind = Schema.EventKind.SHIELD_HIT, unitId = 1, projId = 1, cell = 0, offX = 0, offZ = 0, y = 0, mass = 1, breach = true, absorbed = true })
		end, "a breach or absorbed")
		local field: Schema.Event = { kind = Schema.EventKind.SHIELD_FIELD, projId = 0x0102, cell = 0x0304, offX = 5, offZ = 6, y = -8, radius = 120, force = 255, phase = 2 }
		t.equal(hex(encodeOne(Schema.encodeEvent, field)), "15 02 01 04 03 05 06 f8 ff 78 00 ff 02")
		-- version 26: projId 0, a hitscan shot stopped at the surface (S-89)
		local scan: Schema.Event = { kind = Schema.EventKind.SHIELD_HIT, unitId = 0x0102, projId = 0, cell = 0x0506, offX = 7, offZ = 8, y = 9, mass = 31, breach = false, absorbed = true }
		t.equal(hex(encodeOne(Schema.encodeEvent, scan)), "14 02 01 00 00 06 05 07 08 09 00 1f 02")
		for _, e in { shield, hit, absorbed, scan, field } do
			local bytes = encodeOne(Schema.encodeEvent, e)
			t.deepEqual(Packer.readAll(bytes, Schema.decodeEvent)[1], e)
			t.equal(buffer.len(bytes), Schema.eventBytes(e), "size table")
			expectTruncated(t, "event record", Schema.decodeEvent, bytes)
		end
		expectRejected(t, Schema.decodeEvent, { 19, 1, 0, 0, 4 }, "shield flags 4")
		expectRejected(t, Schema.decodeEvent, { 20, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 3 }, "shield hit flags 3")
		expectRejected(t, Schema.decodeEvent, { 21, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 3 }, "shield field phase 3")
		-- version 23: ALERT (S-68): alert kind, cell, defIndex
		local alert: Schema.Event = { kind = Schema.EventKind.ALERT, alert = Schema.AlertKind.UNIT_LOST, cell = 0x0102, defIndex = 0x0304 }
		t.equal(hex(encodeOne(Schema.encodeEvent, alert)), "12 03 02 01 04 03")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, alert), Schema.decodeEvent)[1], alert)
		-- version 21: OWNER CHARGES (S-63): flares, chaff left
		local charges: State = { unitId = 1, flares = 5, chaff = 0 }
		t.equal(hex(encodeOne(Schema.encodeState, charges)), "01 00 80 08 05 00")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeState, charges), Schema.decodeState)[1], charges)
		local emptyQueue: State = { unitId = 1, queue = {}, queueProgress = 0 }
		-- version 27: OWNER PRODUCING (S-103): an allied factory's item and progress
		local producing: State = { unitId = 1, producing = 0x0304, producingProgress = 0x80 }
		t.equal(hex(encodeOne(Schema.encodeState, producing)), "01 00 80 10 04 03 80")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeState, producing), Schema.decodeState)[1], producing)
		-- version 29: DOME, DOME_GONE (S-122): domes regardless of vision
		local dome: Schema.Event = { kind = Schema.EventKind.DOME, unitId = 0x0102, cell = 0x0304, offX = 5, offZ = 6, y = 7, radius = 80, charge = 200, shieldFlags = 1 }
		t.equal(hex(encodeOne(Schema.encodeEvent, dome)), "17 02 01 04 03 05 06 07 00 50 00 c8 01")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, dome), Schema.decodeEvent)[1], dome)
		local gone: Schema.Event = { kind = Schema.EventKind.DOME_GONE, unitId = 0x0102 }
		t.equal(hex(encodeOne(Schema.encodeEvent, gone)), "18 02 01")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, gone), Schema.decodeEvent)[1], gone)
		-- version 31: command flag GROUP (S-137): a ctrl move
		local groupMove: Command = { cmdType = CT.MOVE, flags = Schema.CmdFlag.GROUP + QUEUE, unitIds = { 1 }, cell = 0x0203, offX = 4, offZ = 5 }
		t.equal(hex(encodeOne(Schema.encodeCommand, groupMove)), "01 05 01 00 01 00 03 02 04 05")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeCommand, groupMove), Schema.decodeCommand)[1], groupMove)
		-- version 31: IDLE (S-136): an own builder or factory idle / busy
		local idle: Schema.Event = { kind = Schema.EventKind.IDLE, unitId = 0x0102, idle = true }
		t.equal(hex(encodeOne(Schema.encodeEvent, idle)), "19 02 01 01")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, idle), Schema.decodeEvent)[1], idle)
		local busy: Schema.Event = { kind = Schema.EventKind.IDLE, unitId = 0x0102, idle = false }
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, busy), Schema.decodeEvent)[1], busy)
		-- version 36: the pre-game (S-169)
		local EKp = Schema.EventKind
		local pregame: Schema.Event = { kind = EKp.PREGAME, player = 3, pregameFlags = Schema.PregameFlag.PICKED + Schema.PregameFlag.READY, cell = 0x0405, offX = 6, offZ = 7 }
		t.equal(hex(encodeOne(Schema.encodeEvent, pregame)), "1c 03 03 05 04 06 07")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, pregame), Schema.decodeEvent)[1], pregame)
		local countdown: Schema.Event = { kind = EKp.COUNTDOWN, seconds = 5 }
		t.equal(hex(encodeOne(Schema.encodeEvent, countdown)), "1d 05")
		local prebuild: Schema.Event = { kind = EKp.PREBUILD, player = 2, builds = { { defIndex = 0x0102, cell = 0x0304, offX = 5, offZ = 6, facing = 1 } } }
		t.equal(hex(encodeOne(Schema.encodeEvent, prebuild)), "1e 02 01 02 01 04 03 05 06 01")
		t.equal(Schema.eventBytes(prebuild), 10)
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, prebuild), Schema.decodeEvent)[1], prebuild)
		local none: Schema.Event = { kind = EKp.PREBUILD, player = 2, builds = {} }
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, none), Schema.decodeEvent)[1], none)
		expectRejected(t, Schema.decodeEvent, { 28, 1, 32, 0, 0, 0, 0 }, "pregame flags 32")
		-- version 37: factions, the host, the pick clock and the spawn boxes (S-174)
		local chaosHost: Schema.Event = { kind = EKp.PREGAME, player = 4, pregameFlags = Schema.PregameFlag.CHAOS + Schema.PregameFlag.HOST, cell = 0, offX = 0, offZ = 0 }
		t.equal(hex(encodeOne(Schema.encodeEvent, chaosHost)), "1c 04 18 00 00 00 00")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, chaosHost), Schema.decodeEvent)[1], chaosHost)
		local clock: Schema.Event = { kind = EKp.PICK_CLOCK, seconds = 150, clockFlags = Schema.PickClockFlag.ALL_READY }
		t.equal(hex(encodeOne(Schema.encodeEvent, clock)), "1f 96 01")
		t.equal(Schema.eventBytes(clock), 3)
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, clock), Schema.decodeEvent)[1], clock)
		expectRejected(t, Schema.decodeEvent, { 31, 10, 8 }, "pick clock flags 8")
		local boxes: Schema.Event = { kind = EKp.START_BOXES, boxes = { { allyTeam = 2, x0 = -1024, z0 = -300, x1 = -600, z1 = 300 } } }
		t.equal(hex(encodeOne(Schema.encodeEvent, boxes)), "20 01 02 00 fc d4 fe a8 fd 2c 01")
		t.equal(Schema.eventBytes(boxes), 11)
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, boxes), Schema.decodeEvent)[1], boxes)
		expectRejected(t, Schema.decodeEvent, { 32, 17 }, "START_BOXES of 17")
		local switch: Command = { cmdType = CT.FACTION, flags = 0, unitIds = {}, value = 1 }
		t.equal(hex(encodeOne(Schema.encodeCommand, switch)), "16 00 00 00 01")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeCommand, switch), Schema.decodeCommand)[1], switch)
		local force: Command = { cmdType = CT.START, flags = 0, unitIds = {}, value = 1 }
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeCommand, force), Schema.decodeCommand)[1], force)
		expectRejected(t, Schema.decodeEvent, { 30, 1, 31 }, "PREBUILD of 31")
		local pick: Command = { cmdType = CT.START_POS, flags = 0, unitIds = {}, cell = 0x0203, offX = 4, offZ = 5 }
		t.equal(hex(encodeOne(Schema.encodeCommand, pick)), "14 00 00 00 03 02 04 05")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeCommand, pick), Schema.decodeCommand)[1], pick)
		local ready: Command = { cmdType = CT.READY, flags = 0, unitIds = {}, value = 1 }
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeCommand, ready), Schema.decodeCommand)[1], ready)
		-- version 34: OWN_STATUS (S-158): an own unit off camera
		local status: Schema.Event = { kind = Schema.EventKind.OWN_STATUS, unitId = 0x0102, health = 200, build = 255, queueHead = 0x0304, queueProgress = 128, queueCount = 5 }
		t.equal(hex(encodeOne(Schema.encodeEvent, status)), "1a 02 01 c8 ff 04 03 80 05")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, status), Schema.decodeEvent)[1], status)
		t.equal(Schema.eventBytes(status), 9)
		local bare: Schema.Event = { kind = Schema.EventKind.OWN_STATUS, unitId = 7, health = 0, build = 0, queueHead = 0, queueProgress = 0, queueCount = 0 }
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, bare), Schema.decodeEvent)[1], bare)
		-- version 27: CHEAT_RESULT (S-102)
		local answer: Schema.Event = { kind = Schema.EventKind.CHEAT_RESULT, cheatOp = Schema.CheatOp.GIVE, cheatResult = Schema.CheatResult.OK, count = 3, total = 0x0105 }
		t.equal(hex(encodeOne(Schema.encodeEvent, answer)), "16 01 00 03 00 05 01")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, answer), Schema.decodeEvent)[1], answer)
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeState, emptyQueue), Schema.decodeState)[1], emptyQueue)
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
		t.equal(hex(encodeOne(Schema.encodeStrategic, strategic)), "02 01 04 03 01 11 00") -- version 36 layout
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
		-- version 3: combat events; slot byte 3 + hit bit 16 = 0x13, y = -2 is fe ff
		local fire: Schema.Event = { kind = Schema.EventKind.FIRE, unitId = 0x0102, slot = 3, hit = true, cell = 0x0304, offX = 5, offZ = 6, y = -2 }
		t.equal(hex(encodeOne(Schema.encodeEvent, fire)), "04 02 01 13 04 03 05 06 fe ff")
		local spawn: Schema.Event = {
			kind = Schema.EventKind.SPAWN_PROJ,
			projId = 0x0102,
			weaponIndex = 0x0304,
			cell = 0x0506,
			offX = 7,
			offZ = 8,
			y = 0x0109,
			vx = -1,
			vy = 0x0200,
			vz = 3,
			targetId = 0x0a0b,
		}
		t.equal(hex(encodeOne(Schema.encodeEvent, spawn)), "05 02 01 04 03 06 05 07 08 09 01 ff ff 00 02 03 00 0b 0a")
		local impact: Schema.Event = { kind = Schema.EventKind.IMPACT, projId = 1, cell = 2, offX = 3, offZ = 4, y = 5 }
		t.equal(hex(encodeOne(Schema.encodeEvent, impact)), "06 01 00 02 00 03 04 05 00")
		local decoyed: Schema.Event = { kind = Schema.EventKind.DECOYED, projId = 1, cell = 2, offX = 3, offZ = 4, y = 5, vx = 6, vy = -7, vz = 8, decoyCell = 0x0109, decoyOffX = 10, decoyOffZ = 11, decoyY = -12, decoyTicks = 13, countermeasure = 3 }
		t.equal(hex(encodeOne(Schema.encodeEvent, decoyed)), "07 01 00 02 00 03 04 05 00 06 00 f9 ff 08 00 09 01 0a 0b f4 ff 0d 03") -- decoy point and ticks since protocol 11, countermeasure since 13
		decoyed.kind = Schema.EventKind.LOST_LOCK
		decoyed.decoyCell, decoyed.decoyOffX, decoyed.decoyOffZ, decoyed.decoyY, decoyed.decoyTicks, decoyed.countermeasure = nil, nil, nil, nil, nil, nil
		t.equal(hex(encodeOne(Schema.encodeEvent, decoyed)), "08 01 00 02 00 03 04 05 00 06 00 f9 ff 08 00")
		-- version 4: homing corrections on the Projectiles channel
		local sync: Schema.ProjSync = { projId = 0x0102, cell = 0x0304, offX = 5, offZ = 6, y = -2, vx = 1, vy = -1, vz = 0x0203 }
		t.equal(hex(encodeOne(Schema.encodeProjSync, sync)), "02 01 04 03 05 06 fe ff 01 00 ff ff 03 02")
		-- version 5: TRACKED strategic flag (16 = flag bit 4 = bit 13 overall)
		local tracked: Strategic = { unitId = 0x0102, cell = 0x0304, icon = 1, team = 2, flags = Schema.StrategicFlag.RADAR_ONLY + Schema.StrategicFlag.TRACKED }
		-- 1 + (2 - 1) * 2^8 + 17 * 2^12 = 0x11101 (version 36 layout)
		t.equal(hex(encodeOne(Schema.encodeStrategic, tracked)), "02 01 04 03 01 11 01")
		-- version 6: join handshake and economy
		local SK = Schema.SnapshotKind
		t.equal(hex(encodeOne(Schema.encodeSnapshot, { kind = SK.HELLO, protocol = 0x0102, defsHash = 0x03040506 })), "01 02 01 06 05 04 03")
		t.equal(hex(encodeOne(Schema.encodeSnapshot, { kind = SK.REJECT, protocol = 6, defsHash = 0x0A0B0C0D, reason = 2 })), "02 06 00 0d 0c 0b 0a 02")
		t.equal(hex(encodeOne(Schema.encodeSnapshot, { kind = SK.WELCOME, tick = 0x01020304, player = 1, team = 2, allyTeam = 1, mapId = "ab", teamAllies = { 1, 1, 2 } })), "03 04 03 02 01 01 02 01 02 61 62 03 01 01 02") -- (teams' ally teams since protocol 30, S-129)
		local eco: Schema.Eco = {
			team = 3,
			supply = { stored = 1, storage = 2, income = 3, demand = 4, ratio = 5 },
			power = { stored = 6, storage = 7, income = 8, demand = 9, ratio = 10 },
			wind = 11,
			radarError = 0x0102,
			trackError = 0x0304,
			precision = 0x80,
		}
		t.equal(hex(encodeOne(Schema.encodeEco, eco)), "03 01 00 00 00 02 00 00 00 03 00 00 00 04 00 00 00 05 06 00 00 00 07 00 00 00 08 00 00 00 09 00 00 00 0a 0b 02 01 04 03 80") -- team first since protocol 9; radar accuracy since 32
	end)

	t.test("wreck and sight events (protocol 10): golden bytes, round-trip, bad input, truncation", function()
		local EK = Schema.EventKind
		local wreck: Schema.Event = { kind = EK.WRECK, wreckId = 0x0102, defIndex = 0x0304, cell = 0x0506, offX = 7, offZ = 8, heading = 9, supply = 0x0a0b, fullSupply = 0x0c0d }
		local gone: Schema.Event = { kind = EK.WRECK_GONE, wreckId = 0x0102 }
		local state: Schema.Event = { kind = EK.WRECK_STATE, wreckId = 0x0102, supply = 0x0304, rez = 200 } -- (protocol 35, S-168)
		t.equal(hex(encodeOne(Schema.encodeEvent, wreck)), "09 02 01 04 03 06 05 07 08 09 0b 0a 0d 0c") -- supply, fullSupply since protocol 35
		t.equal(hex(encodeOne(Schema.encodeEvent, gone)), "0a 02 01")
		t.equal(hex(encodeOne(Schema.encodeEvent, state)), "1b 02 01 04 03 c8")
		roundTrip(t, { wreck, gone, state }, Schema.encodeEvent, Schema.decodeEvent)
		for _, e in { wreck, gone, state } do
			t.equal(buffer.len(encodeOne(Schema.encodeEvent, e)), Schema.EVENT_BYTES[e.kind], `size of event kind {e.kind}`)
			t.equal(Schema.eventBytes(e), Schema.EVENT_BYTES[e.kind])
			expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, e))
		end
		expectRejected(t, Schema.decodeEvent, { 9, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, "wreckId 0 is reserved")
		expectRejected(t, Schema.decodeEvent, { 9, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, "defIndex 0 is reserved")
		expectRejected(t, Schema.decodeEvent, { 27, 0, 0, 1, 0, 0 }, "wreckId 0 is reserved")

		-- rows: 2 rows of 2 bytes; cells: one seen, one unseen
		local rows: Schema.Event = { kind = EK.SIGHT_ROWS, firstRow = 3, rowCount = 2, rowBytes = 2, bits = fromBytes({ 0x01, 0x80, 0xFF, 0x00 }) }
		local cells: Schema.Event = { kind = EK.SIGHT_CELLS, cells = { 5 + Schema.SIGHT_SEEN, 0x0102 } }
		t.equal(hex(encodeOne(Schema.encodeEvent, rows)), "0b 03 02 02 01 80 ff 00")
		t.equal(hex(encodeOne(Schema.encodeEvent, cells)), "0c 02 05 80 02 01")
		t.equal(Schema.eventBytes(rows), 8)
		t.equal(Schema.eventBytes(cells), 6)
		local decoded = Packer.readAll(encodeOne(Schema.encodeEvent, rows), Schema.decodeEvent)[1]
		t.equal(decoded.firstRow, 3)
		t.equal(decoded.rowCount, 2)
		t.equal(decoded.rowBytes, 2)
		t.equal(hex(decoded.bits :: buffer), "01 80 ff 00")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, cells), Schema.decodeEvent)[1], cells)
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, rows))
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, cells))
		expectRejected(t, Schema.decodeEvent, { 12, 0 }, "SIGHT_CELLS with no cells")
		expectRejected(t, Schema.decodeEvent, { 11, 0, 0, 4 }, "SIGHT_ROWS of 0 rows")
		expectRejected(t, Schema.decodeEvent, { 11, 0, 255, 16 }, "SIGHT_ROWS of 255 rows")
		local ok = pcall(encodeOne, Schema.encodeEvent, { kind = EK.SIGHT_CELLS, cells = {} } :: Schema.Event)
		t.expect(not ok, "an empty SIGHT_CELLS is refused")
		ok = pcall(encodeOne, Schema.encodeEvent, { kind = EK.SIGHT_ROWS, firstRow = 0, rowCount = 2, rowBytes = 2, bits = buffer.create(3) } :: Schema.Event)
		t.expect(not ok, "SIGHT_ROWS bits must be rows × rowBytes")
	end)

	t.test("events round-trip, reject bad input, and every prefix is truncated", function()
		local events: { Schema.Event } = {
			{ kind = Schema.EventKind.ENTER, unitId = 65535, defIndex = 1, team = 8, cell = 65535, offX = 255, offZ = 0, heading = 255, alt = 0, health = 255, build = 0, state = 65535 },
			{ kind = Schema.EventKind.LEAVE, unitId = 1 },
			{ kind = Schema.EventKind.DEATH, unitId = 7, severity = 0, wreckId = 0 },
			{ kind = Schema.EventKind.FIRE, unitId = 65535, slot = 8, hit = false, cell = 65535, offX = 255, offZ = 0, y = -32768 },
			{ kind = Schema.EventKind.FIRE, unitId = 1, slot = 1, hit = true, cell = 0, offX = 0, offZ = 255, y = 32767 },
			{ kind = Schema.EventKind.SPAWN_PROJ, projId = 65535, weaponIndex = 1, cell = 1, offX = 2, offZ = 3, y = 4, vx = -32768, vy = 32767, vz = 0, targetId = 0 },
			{ kind = Schema.EventKind.IMPACT, projId = 1, cell = 65535, offX = 255, offZ = 255, y = -1 },
			{ kind = Schema.EventKind.DECOYED, projId = 2, cell = 3, offX = 4, offZ = 5, y = 6, vx = -7, vy = 8, vz = -9, decoyCell = 65535, decoyOffX = 0, decoyOffZ = 255, decoyY = -32768, decoyTicks = 255, countermeasure = 1 },
			{ kind = Schema.EventKind.LOST_LOCK, projId = 3, cell = 4, offX = 5, offZ = 6, y = 7, vx = 8, vy = -9, vz = 10 },
		}
		roundTrip(t, events, Schema.encodeEvent, Schema.decodeEvent)
		t.equal(buffer.len(encodeOne(Schema.encodeEvent, events[1])), Schema.ENTER_BYTES)
		for _, e in events do
			t.equal(buffer.len(encodeOne(Schema.encodeEvent, e)), Schema.EVENT_BYTES[e.kind], `size of event kind {e.kind}`)
			expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, e))
		end
		expectRejected(t, Schema.decodeEvent, { 4, 1, 0, 0x23, 0, 0, 0, 0, 0, 0 }, "reserved bits")
		expectRejected(t, Schema.decodeEvent, { 4, 1, 0, 0x10, 0, 0, 0, 0, 0, 0 }, "weapon slot 0 outside")
		expectRejected(t, Schema.decodeEvent, { 4, 1, 0, 9, 0, 0, 0, 0, 0, 0 }, "weapon slot 9 outside")
		expectRejected(t, Schema.decodeEvent, { 6, 0, 0, 0, 0, 0, 0, 0, 0 }, "projId 0 is reserved")
		expectRejected(t, Schema.decodeEvent, { 5, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, "weaponIndex 0 is reserved")
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, events[1]))
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, events[3]))
		expectRejected(t, Schema.decodeEvent, { 34, 1, 0 }, "unknown event kind 34") -- 9..12 since protocol 10, 13 since 14, 14..16 since 16, 17 since 18, 18 since 23, 19..21 since 24, 22 since 27, 23..24 since 29, 25 since 31, 26 since 34, 27 since 35, 28..30 since 36, 31..33 since 37
		expectRejected(t, Schema.decodeEvent, { 18, 10, 0, 0, 0, 0 }, "alert kind 10")
		-- protocol 16: strategic missiles (S-48)
		local EK = Schema.EventKind
		local icpt: Schema.Event = { kind = EK.INTERCEPTOR, projId = 0x0102, weaponIndex = 3, cell = 0x0405, offX = 6, offZ = 7, y = 8, vx = 1, vy = -1, vz = 2, targetId = 0x0a0b }
		t.equal(hex(encodeOne(Schema.encodeEvent, icpt)), "0e 02 01 03 00 05 04 06 07 08 00 01 00 ff ff 02 00 0b 0a")
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, icpt), Schema.decodeEvent)[1], icpt)
		for _, kind in { EK.LAUNCH_WARNING, EK.INTERCEPTED } do
			local e: Schema.Event = { kind = kind, projId = 0x0102, cell = 0x0304, offX = 5, offZ = 6, y = -2 }
			t.equal(hex(encodeOne(Schema.encodeEvent, e)), string.format("%02x 02 01 04 03 05 06 fe ff", kind))
			t.equal(buffer.len(encodeOne(Schema.encodeEvent, e)), Schema.EVENT_BYTES[kind])
			t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, e), Schema.decodeEvent)[1], e)
			expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, e))
			expectRejected(t, Schema.decodeEvent, { kind, 0, 0, 0, 0, 0, 0, 0, 0 }, "projId 0 is reserved")
		end
		t.equal(buffer.len(encodeOne(Schema.encodeEvent, icpt)), Schema.EVENT_BYTES[EK.INTERCEPTOR])
		-- protocol 18: a strategic missile with its goal (S-51)
		local strat: Schema.Event = { kind = EK.SPAWN_STRATEGIC, projId = 0x0102, weaponIndex = 3, cell = 0x0405, offX = 6, offZ = 7, y = 8, vx = 0, vy = 1200, vz = 0, targetId = 0, goalCell = 0x0a0b, goalOffX = 12, goalOffZ = 13, goalY = -1 }
		t.equal(hex(encodeOne(Schema.encodeEvent, strat)), "11 02 01 03 00 05 04 06 07 08 00 00 00 b0 04 00 00 00 00 0b 0a 0c 0d ff ff")
		t.equal(buffer.len(encodeOne(Schema.encodeEvent, strat)), Schema.EVENT_BYTES[EK.SPAWN_STRATEGIC])
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, strat), Schema.decodeEvent)[1], strat)
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, strat))
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, icpt))
		-- protocol 14: SHOT, a hidden shooter's hitscan shot (S-43); its weapon since protocol 28 (S-118)
		local shot: Schema.Event = { kind = Schema.EventKind.SHOT, hit = true, fromCell = 0x0102, fromOffX = 3, fromOffZ = 4, fromY = -5, cell = 0x0607, offX = 8, offZ = 9, y = 10, weaponIndex = 0x0b0c }
		t.equal(hex(encodeOne(Schema.encodeEvent, shot)), "0d 01 02 01 03 04 fb ff 07 06 08 09 0a 00 0c 0b")
		t.equal(buffer.len(encodeOne(Schema.encodeEvent, shot)), Schema.EVENT_BYTES[Schema.EventKind.SHOT])
		t.deepEqual(Packer.readAll(encodeOne(Schema.encodeEvent, shot), Schema.decodeEvent)[1], shot)
		expectTruncated(t, "event record", Schema.decodeEvent, encodeOne(Schema.encodeEvent, shot))
		expectRejected(t, Schema.decodeEvent, { 13, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, "SHOT hit byte 2")
		expectRejected(t, Schema.decodeEvent, { 2, 0, 0 }, "unitId 0 is reserved")
		expectRejected(t, Schema.decodeEvent, { 1, 1, 0, 1, 0, 17 }, "team 17 outside")
	end)

	t.test("projectile corrections round-trip, reject projId 0, and every prefix is truncated", function()
		local recs: { Schema.ProjSync } = {
			{ projId = 65535, cell = 65535, offX = 255, offZ = 0, y = -32768, vx = 32767, vy = -32768, vz = 0 },
			{ projId = 1, cell = 0, offX = 0, offZ = 255, y = 32767, vx = -1, vy = 1, vz = -2 },
		}
		roundTrip(t, recs, Schema.encodeProjSync, Schema.decodeProjSync)
		for _, r in recs do
			t.equal(buffer.len(encodeOne(Schema.encodeProjSync, r)), Schema.PROJ_SYNC_BYTES)
			expectTruncated(t, "projectile correction", Schema.decodeProjSync, encodeOne(Schema.encodeProjSync, r))
		end
		expectRejected(t, Schema.decodeProjSync, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, "projId 0 is reserved")
		t.equal(Schema.Channel.Projectiles.reliable, false, "corrections are unreliable")
	end)

	t.test("join handshake and economy records round-trip, reject bad input, and every prefix is truncated", function()
		local SK = Schema.SnapshotKind
		local recs: { Schema.SnapshotRecord } = {
			{ kind = SK.HELLO, protocol = 65535, defsHash = 4294967295 },
			{ kind = SK.REJECT, protocol = 0, defsHash = 0, reason = 1 },
			{ kind = SK.WELCOME, tick = 4294967295, player = 255, team = 8, allyTeam = 8, mapId = "skirmish:192", teamAllies = { 1, 2, 1, 2, 3, 3, 4, 8 } },
			{ kind = SK.WELCOME, tick = 0, player = 1, team = 1, allyTeam = 1, mapId = "", teamAllies = {} },
		}
		roundTrip(t, recs, Schema.encodeSnapshot, Schema.decodeSnapshot)
		for _, r in recs do
			expectTruncated(t, "snapshot record", Schema.decodeSnapshot, encodeOne(Schema.encodeSnapshot, r))
		end
		expectRejected(t, Schema.decodeSnapshot, { 9 }, "unknown snapshot kind 9")
		expectRejected(t, Schema.decodeSnapshot, { 2, 0, 0, 0, 0, 0, 0, 3 }, "unknown reject reason 3")
		local eco: Schema.Eco = {
			team = 8,
			supply = { stored = 4294967295, storage = 0, income = 12345, demand = 0, ratio = 255 },
			power = { stored = 0, storage = 4294967295, income = 0, demand = 99999, ratio = 0 },
			wind = 255,
			radarError = 65535,
			trackError = 0,
			precision = 255,
		}
		roundTrip(t, { eco }, Schema.encodeEco, Schema.decodeEco)
		t.equal(buffer.len(encodeOne(Schema.encodeEco, eco)), Schema.ECO_BYTES)
		expectTruncated(t, "eco record", Schema.decodeEco, encodeOne(Schema.encodeEco, eco))
		expectRejected(t, Schema.decodeEco, { 0 }, "team 0 outside 1..16") -- protocol 9: records carry their team
		expectRejected(t, Schema.decodeEco, { 17 }, "team 17 outside 1..16")
		t.equal(Schema.Channel.Snapshot.reliable, true, "the handshake is reliable")
		t.equal(Schema.Channel.Eco.reliable, true, "economy is reliable")
	end)

	t.test("unit state bits live in Shared and are the sim's", function()
		local World = require("../Sim/World")
		t.equal(World.State, Schema.UnitState, "one table (S-6)")
		t.deepEqual(Schema.UnitState, { MOVING = 1, TOGGLED_ON = 2, SUBMERGED = 4, LANDED = 8, REPEAT = 16, DEPLOYED = 32, DEPLOYING = 64, LOW_PRIORITY = 128 })
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
			{ unitId = 65535, cell = 65535, icon = 255, team = 8, flags = 31 },
			{ unitId = 2, cell = 1, icon = 126, team = 7, flags = Schema.StrategicFlag.GHOST },
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
		expectRejected(t, cmd, { 27, 0, 1, 0, 1, 0 }, "unknown cmdType 27") -- 15 is REPEAT (protocol 7), 16 CANCEL (protocol 12), 17 CHEAT (protocol 27), 18 PRIORITY (protocol 33), 19 RESURRECT (protocol 35), 20 START_POS and 21 READY (protocol 36), 22 FACTION, 23 START, 24 SHARE_UNITS, 25 SHARE_RESOURCE and 26 REQUEST (protocol 37)
		t.equal(hex(encodeOne(Schema.encodeCommand, { cmdType = CT.CANCEL, flags = 0, unitIds = { 0x0102 }, value = 3 })), "10 00 01 00 02 01 03", "CANCEL: value = queue position (protocol 12)")
		expectRejected(t, cmd, { 16, 0, 1, 0, 1, 0, 51 }, "value 51")
		expectRejected(t, cmd, { CT.STOP, 8, 1, 0, 1, 0 }, "reserved bits") -- 4 is GROUP since protocol 31 (S-137)
		expectRejected(t, cmd, { CT.STOP, LINE, 1, 0, 1, 0 }, "LINE flag")
		expectRejected(t, cmd, { CT.GUARD, 0, 0, 0 }, "unit count 0") -- (STOP may be empty since protocol 36: the pre-game)
		expectRejected(t, cmd, { CT.GUARD, 0, 201, 0 }, "unit count 201")
		expectRejected(t, cmd, { CT.GUARD, 0, 0xFF, 0xFF }, "unit count 65535")
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
		expectRejected(t, Schema.decodeState, { 1, 0, 128, 0 }, "owner field mask is empty") -- 128 is OWNER since protocol 20
		expectRejected(t, Schema.decodeState, { 1, 0, 128, 32 }, "owner field mask has reserved bits") -- 8 is CHARGES since protocol 21, 16 PRODUCING since 27
		expectRejected(t, Schema.decodeState, { 1, 0, 128, 2, 16 }, "states byte has reserved bits")
		expectRejected(t, Schema.decodeState, { 1, 0, 128, 1, 51, 0 }, "queue of 51 items")
		expectRejected(t, Schema.decodeState, { 1, 0, Schema.StateField.STOCK, 0 }, "stock slot mask is empty")
		expectRejected(t, Schema.decodeState, { 1, 0, Schema.StateField.TARGET, 0 }, "target slot mask is empty")
		expectRejected(t, Schema.decodeState, { 1, 0, Schema.StateField.AIM, 0 }, "aim slot mask is empty")

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
		t.throws(enc(Schema.encodeStrategic, { unitId = 1, cell = 0, icon = 0, team = 17, flags = 0 }), "team 17")
		t.throws(enc(Schema.encodeStrategic, { unitId = 1, cell = 0, icon = 256, team = 1, flags = 0 }), "8%-bit value")
		t.throws(enc(Schema.encodeStrategic, { unitId = 1, cell = 0, icon = 0, team = 1, flags = 32 }), "reserved bits")
		t.throws(enc(Schema.encodeState, { unitId = 1 }), "no fields")
		t.throws(enc(Schema.encodeState, { unitId = 1, aim = {} }), "aim list is empty")
		t.throws(enc(Schema.encodeState, { unitId = 1, aim = { { slot = 2, yaw = 0, pitch = 0 }, { slot = 1, yaw = 0, pitch = 0 } } }), "ascending")
		t.throws(enc(Schema.encodeState, { unitId = 1, aim = { { slot = 9, yaw = 0, pitch = 0 } } }), "ascending")
		t.throws(enc(Schema.encodeState, { unitId = 1, weapon = 65536 }), "u16 out of range")
		t.throws(enc(Schema.encodeState, { unitId = 1, stock = {} }), "stock list is empty")
		t.throws(enc(Schema.encodeState, { unitId = 1, stock = { { slot = 3, count = 1, progress = 0 }, { slot = 2, count = 1, progress = 0 } } }), "ascending")
		local badFacing: Command = { cmdType = CT.BUILD, flags = 0, unitIds = { 1 }, defIndex = 1, cell = 0, offX = 0, offZ = 0, facing = 4 }
		t.throws(enc(Schema.encodeCommand, badFacing), "facing 4")
		local noFacing: Command = { cmdType = CT.BUILD, flags = 0, unitIds = { 1 }, defIndex = 1, cell = 0, offX = 0, offZ = 0 }
		t.throws(enc(Schema.encodeCommand, noFacing), "missing field facing")
		t.throws(enc(Schema.encodeCommand, { cmdType = CT.GUARD, flags = 0, unitIds = ids(201, 1), targetId = 1 }), "1..200")
		t.throws(enc(Schema.encodeCommand, { cmdType = CT.GUARD, flags = 0, unitIds = {}, targetId = 1 }), "1..200")
		t.throws(enc(Schema.encodeCommand, { cmdType = CT.STOP, flags = 0, unitIds = ids(201, 1) }), "201 unit IDs")
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

		-- 128 strategic records of 7 bytes fill a 900-byte message (896 bytes; protocol 36)
		local strategic = many(SEED + 1, randomStrategic)
		messages = Packer.chunk(strategic, Schema.encodeStrategic)
		t.equal(#messages, math.ceil(RANDOM_COUNT / 128))
		t.equal(buffer.len(messages[1]), 896)
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
