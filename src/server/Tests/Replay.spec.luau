--!strict
local Replay = require("../Sim/Replay")
local RunAll = require("./RunAll")

local function sampleLog(): Replay.Log
	local log = Replay.new({
		protocolVersion = 1,
		defsHash = 0xDEADBEEF,
		seed = 4294967295,
		mapId = "test_map",
		scenario = "skirmish_test",
		players = { { id = 1, team = 1, allyTeam = 1 }, { id = 7, team = 8, allyTeam = 2 } },
		match = { mode = "TEAM", win = "ANNIHILATION", unitCap = 250 },
	})
	Replay.addCommand(log, 1, 1, buffer.fromstring("\7\0\1\0\1\0"))
	Replay.addCheckpoint(log, 300, 0x12345678)
	Replay.addCommand(log, 70000, 7, buffer.fromstring(""))
	return log
end

local function plain(log: Replay.Log): any
	local entries = {}
	for i, e in log.entries do
		entries[i] = {
			kind = e.kind,
			tick = e.tick,
			player = e.player,
			hash = e.hash,
			payload = if e.payload then buffer.tostring(e.payload) else nil,
		}
	end
	return { header = log.header, entries = entries }
end

return function(t: RunAll.Context)
	t.test("serialize/parse round-trips header and entries", function()
		local log = sampleLog()
		local parsed = Replay.parse(Replay.serialize(log))
		t.deepEqual(plain(parsed), plain(log))
		t.deepEqual(Replay.checkpoints(parsed), { { 300, 0x12345678 } })
	end)

	t.test("every truncated prefix is rejected", function()
		local buf = Replay.serialize(sampleLog())
		-- Prefixes that end exactly between entries are valid shorter logs.
		local valid: { [number]: boolean } = {}
		local probe = Replay.new(sampleLog().header)
		valid[buffer.len(Replay.serialize(probe))] = true
		for _, e in sampleLog().entries do
			table.insert(probe.entries, e)
			valid[buffer.len(Replay.serialize(probe))] = true
		end
		for n = 0, buffer.len(buf) - 1 do
			local prefix = buffer.create(n)
			buffer.copy(prefix, 0, buf, 0, n)
			local ok, err = pcall(Replay.parse, prefix)
			if valid[n] then
				t.expect(ok, `prefix of {n} bytes ends between entries and should parse`)
			else
				t.expect(not ok, `prefix of {n} bytes parsed`)
				t.expect(string.find(tostring(err), "truncated", 1, true) ~= nil, `unclear error: {err}`)
			end
		end
	end)

	t.test("bad magic, format and entry kind are rejected", function()
		t.throws(function()
			Replay.parse(buffer.fromstring("NOPE\1"))
		end, "not a replay")
		local buf = Replay.serialize(sampleLog())
		local wrongFormat = buffer.create(buffer.len(buf))
		buffer.copy(wrongFormat, 0, buf)
		buffer.writeu8(wrongFormat, 4, 99)
		t.throws(function()
			Replay.parse(wrongFormat)
		end, "unsupported format version 99")
		local header = Replay.serialize(Replay.new(sampleLog().header))
		local bad = buffer.create(buffer.len(header) + 5)
		buffer.copy(bad, 0, header)
		buffer.writeu8(bad, buffer.len(header), 9)
		t.throws(function()
			Replay.parse(bad)
		end, "unknown entry kind 9")
	end)

	t.test("long strings are refused when serializing", function()
		local log = sampleLog()
		log.header.mapId = string.rep("x", 256)
		t.throws(function()
			Replay.serialize(log)
		end, "string too long")
	end)
end
