--!strict
local Packer = require("@shared/Net/Packer")
local RunAll = require("./RunAll")

local Writer = Packer.Writer
local Reader = Packer.Reader

local function bytesOf(buf: buffer): { number }
	local out = table.create(buffer.len(buf))
	for i = 0, buffer.len(buf) - 1 do
		out[i + 1] = buffer.readu8(buf, i)
	end
	return out
end

local function fromBytes(bytes: { number }): buffer
	local buf = buffer.create(#bytes)
	for i, b in bytes do
		buffer.writeu8(buf, i - 1, b)
	end
	return buf
end

return function(t: RunAll.Context)
	t.test("u8/u16/i16/u32 round-trip at edge values", function()
		local w = Writer.new(1)
		local u8s = { 0, 1, 127, 128, 255 }
		local u16s = { 0, 1, 255, 256, 32767, 32768, 65535 }
		local i16s = { -32768, -32767, -256, -1, 0, 1, 255, 32767 }
		local u32s = { 0, 1, 65535, 65536, 2147483647, 2147483648, 4294967295 }
		for _, v in u8s do
			w:writeU8(v)
		end
		for _, v in u16s do
			w:writeU16(v)
		end
		for _, v in i16s do
			w:writeI16(v)
		end
		for _, v in u32s do
			w:writeU32(v)
		end
		local buf = w:finish()
		t.equal(buffer.len(buf), #u8s + 2 * #u16s + 2 * #i16s + 4 * #u32s, "finish() trims to the written length")

		local r = Reader.new(buf)
		for _, v in u8s do
			t.equal(r:readU8(), v)
		end
		for _, v in u16s do
			t.equal(r:readU16(), v)
		end
		for _, v in i16s do
			t.equal(r:readI16(), v)
		end
		for _, v in u32s do
			t.equal(r:readU32(), v)
		end
		t.expect(r:atEnd(), "reader should be at the end")
	end)

	t.test("multi-byte values are little-endian", function()
		local w = Writer.new()
		w:writeU16(0x1234)
		w:writeI16(-2)
		w:writeU32(0x89ABCDEF)
		t.deepEqual(bytesOf(w:finish()), { 0x34, 0x12, 0xFE, 0xFF, 0xEF, 0xCD, 0xAB, 0x89 })
	end)

	t.test("writer grows past its initial capacity", function()
		local w = Writer.new(1)
		for i = 1, 10000 do
			w:writeU16(i)
		end
		local r = Reader.new(w:finish())
		for i = 1, 10000 do
			t.equal(r:readU16(), i)
		end
	end)

	t.test("writes reject out-of-range and non-integer values", function()
		local w = Writer.new()
		t.throws(function()
			w:writeU8(256)
		end, "u8 out of range")
		t.throws(function()
			w:writeU8(-1)
		end, "u8 out of range")
		t.throws(function()
			w:writeU16(65536)
		end, "u16 out of range")
		t.throws(function()
			w:writeI16(32768)
		end, "i16 out of range")
		t.throws(function()
			w:writeI16(-32769)
		end, "i16 out of range")
		t.throws(function()
			w:writeU32(2 ^ 32)
		end, "u32 out of range")
		t.throws(function()
			w:writeU8(1.5)
		end, "u8 out of range")
		t.throws(function()
			w:writeBits(8, 3)
		end, "3%-bit value out of range")
		t.equal(w:len(), 0, "failed writes must not advance the writer")
	end)

	t.test("bit fields cross byte boundaries (exact bytes)", function()
		local w = Writer.new()
		w:writeBits(0b101, 3) -- bits 0-2
		w:writeBits(0b1100110, 7) -- bits 3-9: low 5 bits finish byte 0, top 2 start byte 1
		w:flushBits()
		t.deepEqual(bytesOf(w:finish()), { 0x35, 0x03 })
	end)

	t.test("bit fields round-trip for every width 1..32", function()
		local w = Writer.new()
		for n = 1, 32 do
			w:writeBits(2 ^ n - 1, n) -- all ones
			w:writeBits(0, n)
			w:writeBits(2 ^ (n - 1), n) -- top bit only
		end
		w:flushBits()
		local r = Reader.new(w:finish())
		for n = 1, 32 do
			t.equal(r:readBits(n), 2 ^ n - 1, `{n}-bit all ones`)
			t.equal(r:readBits(n), 0, `{n}-bit zero`)
			t.equal(r:readBits(n), 2 ^ (n - 1), `{n}-bit top bit`)
		end
		r:alignBits()
		t.expect(r:atEnd(), "reader should be at the end")
	end)

	t.test("bits and bytes mix only on byte boundaries", function()
		local w = Writer.new()
		w:writeBits(1, 1)
		t.throws(function()
			w:writeU8(0)
		end, "unflushed bits")
		t.throws(function()
			w:finish()
		end, "unflushed bits")
		w:flushBits()
		w:writeU8(0xAB)
		t.deepEqual(bytesOf(w:finish()), { 0x01, 0xAB }, "flush pads with zero bits")

		local r = Reader.new(fromBytes({ 0x01, 0xAB }))
		t.equal(r:readBits(1), 1)
		t.throws(function()
			r:readU8()
		end, "unconsumed bits")
		r:alignBits()
		t.equal(r:readU8(), 0xAB)
	end)

	t.test("nonzero padding bits are rejected", function()
		local r = Reader.new(fromBytes({ 0x81 }))
		t.equal(r:readBits(1), 1)
		t.throws(function()
			r:alignBits()
		end, "nonzero padding")
	end)

	t.test("truncated reads give a clear error", function()
		t.throws(function()
			Reader.new(fromBytes({ 1 })):readU16()
		end, "truncated: need 2 byte%(s%) at offset 0, only 1 left")
		t.throws(function()
			Reader.new(fromBytes({ 1, 2, 3 })):readU32()
		end, "truncated")
		t.throws(function()
			Reader.new(buffer.create(0)):readU8()
		end, "truncated")
		t.throws(function()
			Reader.new(fromBytes({ 0xFF })):readBits(9)
		end, "truncated")
		t.throws(function()
			Reader.new(fromBytes({ 1, 2, 3, 4 }), 1, 2):readU32()
		end, "truncated")
	end)

	t.test("reader rejects non-buffers and bad ranges", function()
		t.throws(function()
			Reader.new(("abc" :: any) :: buffer)
		end, "expected a buffer, got string")
		t.throws(function()
			Reader.new((nil :: any) :: buffer)
		end, "expected a buffer, got nil")
		t.throws(function()
			Reader.new(buffer.create(4), 2, 3)
		end, "outside a 4%-byte buffer")
	end)

	t.test("strings and raw buffers round-trip with bounds checks", function()
		local w = Writer.new(1)
		w:writeString("FTGR")
		w:writeString("")
		w:writeU8(7)
		local buf = w:finish()
		t.equal(buffer.len(buf), 5)
		local r = Reader.new(buf)
		t.equal(r:readString(4), "FTGR")
		t.equal(r:readString(0), "")
		t.equal(r:readU8(), 7)
		local r2 = Reader.new(buf)
		t.equal(buffer.tostring(r2:readBuffer(2)), "FT")
		t.throws(function()
			r2:readString(4)
		end, "truncated: need 4 byte%(s%) at offset 2, only 3 left")
		t.throws(function()
			r2:readString(-1)
		end, "integer >= 0")
	end)

	t.test("chunk fills messages exactly to the limit", function()
		local function encode(w: Packer.Writer, v: number)
			w:writeU8(v)
			w:writeU16(v)
		end
		local records = {}
		for i = 1, 300 do
			records[i] = i % 256
		end
		local messages = Packer.chunk(records, encode, 900) -- 300 × 3 bytes = exactly 900
		t.equal(#messages, 1)
		t.equal(buffer.len(messages[1]), 900)

		table.insert(records, 7)
		messages = Packer.chunk(records, encode, 900)
		t.equal(#messages, 2, "one more record spills into a second message")
		t.equal(buffer.len(messages[2]), 3)

		t.equal(#Packer.chunk({}, encode), 0, "no records, no messages")
	end)

	t.test("chunk counts the header and rejects oversized records", function()
		local messages = Packer.chunk({ 1, 2, 3, 4, 5 }, function(w, v: number)
			w:writeU16(v)
		end, 6, function(w)
			w:writeU16(0xBEEF)
		end)
		t.equal(#messages, 3, "2-byte header + 2 records per 6-byte message")
		local all = {}
		for _, m in messages do
			t.expect(buffer.len(m) <= 6, "message over the limit")
			local records, header = Packer.readAll(m, function(r)
				return r:readU16()
			end, function(r)
				return r:readU16()
			end)
			t.equal(header, 0xBEEF)
			for _, v in records do
				table.insert(all, v)
			end
		end
		t.deepEqual(all, { 1, 2, 3, 4, 5 })

		t.throws(function()
			Packer.chunk({ 1 }, function(w, _v: number)
				w:writeU32(0)
			end, 3)
		end, "too big")
	end)
end
