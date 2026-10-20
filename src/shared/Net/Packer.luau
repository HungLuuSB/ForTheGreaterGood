--!strict
-- Buffer read/write helpers for every network payload (guide 7.1, 7.3).
--
-- Byte order is little-endian (Luau's buffer library). The bit writer packs
-- LSB-first: the first bit written lands in bit 0 of the next byte.
--
-- Writers assert on out-of-range values (an encoder bug must never put garbage
-- on the wire). Readers treat their input as untrusted (guide 19): every read
-- is bounds-checked and failures raise a clear "Packer: ..." error instead of
-- returning garbage. Callers decoding client data wrap the decode in pcall.

local readu8 = buffer.readu8
local readu16 = buffer.readu16
local readi16 = buffer.readi16
local readu32 = buffer.readu32
local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local writei16 = buffer.writei16
local writeu32 = buffer.writeu32

local Packer = {}

-- Practical per-message limit for UnreliableRemoteEvent payloads.
Packer.MAX_MESSAGE_BYTES = 900

local DEFAULT_CAPACITY = 64

local function checkInt(value: number, min: number, max: number, what: string)
	if type(value) ~= "number" or value ~= math.floor(value) or value < min or value > max then
		error(`Packer: {what} out of range [{min}, {max}]: {value}`, 3)
	end
end

--------------------------------------------------------------------------------
-- Writer
--------------------------------------------------------------------------------

local Writer = {}
Writer.__index = Writer

type WriterData = {
	_buf: buffer,
	_pos: number,
	_acc: number, -- pending bits, value
	_accBits: number, -- pending bits, count (0..7 between calls)
}
export type Writer = typeof(setmetatable({} :: WriterData, Writer))

function Writer.new(capacity: number?): Writer
	return setmetatable({
		_buf = buffer.create(math.max(capacity or DEFAULT_CAPACITY, 1)),
		_pos = 0,
		_acc = 0,
		_accBits = 0,
	}, Writer)
end

local function grow(self: Writer, n: number)
	local needed = self._pos + n
	local cap = buffer.len(self._buf)
	if needed > cap then
		local grown = buffer.create(math.max(cap * 2, needed))
		buffer.copy(grown, 0, self._buf, 0, self._pos)
		self._buf = grown
	end
end

-- Room for n more bytes; byte writes are only legal on a byte boundary.
local function ensure(self: Writer, n: number)
	if self._accBits ~= 0 then
		error("Packer: byte write with unflushed bits; call flushBits() first", 3)
	end
	grow(self, n)
end

function Writer.writeU8(self: Writer, value: number)
	checkInt(value, 0, 0xFF, "u8")
	ensure(self, 1)
	writeu8(self._buf, self._pos, value)
	self._pos += 1
end

function Writer.writeU16(self: Writer, value: number)
	checkInt(value, 0, 0xFFFF, "u16")
	ensure(self, 2)
	writeu16(self._buf, self._pos, value)
	self._pos += 2
end

function Writer.writeI16(self: Writer, value: number)
	checkInt(value, -0x8000, 0x7FFF, "i16")
	ensure(self, 2)
	writei16(self._buf, self._pos, value)
	self._pos += 2
end

function Writer.writeU32(self: Writer, value: number)
	checkInt(value, 0, 0xFFFFFFFF, "u32")
	ensure(self, 4)
	writeu32(self._buf, self._pos, value)
	self._pos += 4
end

-- Appends raw bytes (e.g. an already-encoded record).
function Writer.writeBytes(self: Writer, source: buffer, offset: number?, count: number?)
	local from = offset or 0
	local n = count or (buffer.len(source) - from)
	ensure(self, n)
	buffer.copy(self._buf, self._pos, source, from, n)
	self._pos += n
end

-- Appends the low `count` bits of value (count 1..32). Bits accumulate until
-- they fill whole bytes; call flushBits() before the next byte write or finish().
-- Arithmetic stays exact: at most 7 + 32 = 39 pending bits, well under 2^53.
function Writer.writeBits(self: Writer, value: number, count: number)
	checkInt(count, 1, 32, "bit count")
	checkInt(value, 0, 2 ^ count - 1, `{count}-bit value`)
	local acc = self._acc + value * 2 ^ self._accBits
	local accBits = self._accBits + count
	while accBits >= 8 do
		local byte = acc % 256
		grow(self, 1)
		writeu8(self._buf, self._pos, byte)
		self._pos += 1
		acc = (acc - byte) / 256
		accBits -= 8
	end
	self._acc = acc
	self._accBits = accBits
end

-- Writes any pending bits as one byte, zero-padded at the top.
function Writer.flushBits(self: Writer)
	if self._accBits > 0 then
		grow(self, 1)
		writeu8(self._buf, self._pos, self._acc)
		self._pos += 1
		self._acc = 0
		self._accBits = 0
	end
end

-- Bytes written so far (pending bits not included).
function Writer.len(self: Writer): number
	return self._pos
end

-- Returns a new buffer trimmed to the written length.
function Writer.finish(self: Writer): buffer
	if self._accBits ~= 0 then
		error("Packer: finish() with unflushed bits; call flushBits() first", 2)
	end
	local out = buffer.create(self._pos)
	buffer.copy(out, 0, self._buf, 0, self._pos)
	return out
end

-- Empties the writer, keeping its storage for reuse.
function Writer.reset(self: Writer)
	self._pos = 0
	self._acc = 0
	self._accBits = 0
end

Packer.Writer = Writer

--------------------------------------------------------------------------------
-- Reader
--------------------------------------------------------------------------------

local Reader = {}
Reader.__index = Reader

type ReaderData = {
	_buf: buffer,
	_pos: number,
	_start: number,
	_limit: number,
	_acc: number,
	_accBits: number,
	-- What is being decoded, for error messages ("tactical record"). Set by Schema.
	context: string?,
}
export type Reader = typeof(setmetatable({} :: ReaderData, Reader))

-- Reads `buf` from `offset` (default 0) for `length` bytes (default: to the end).
-- Errors if `buf` is not a buffer: remote payloads can be any type.
function Reader.new(buf: buffer, offset: number?, length: number?): Reader
	if typeof(buf) ~= "buffer" then
		error(`Packer: expected a buffer, got {typeof(buf)}`, 2)
	end
	local total = buffer.len(buf)
	local start = offset or 0
	local limit = if length then start + length else total
	if start < 0 or start > total or limit < start or limit > total then
		error(`Packer: reader range [{start}, {limit}) is outside a {total}-byte buffer`, 2)
	end
	return setmetatable({
		_buf = buf,
		_pos = start,
		_start = start,
		_limit = limit,
		_acc = 0,
		_accBits = 0,
		context = nil,
	}, Reader)
end

function Reader.fail(self: Reader, message: string): never
	error(`Packer: {self.context or "buffer"}: {message}`, 0)
end

local function take(self: Reader, n: number): number
	if self._accBits ~= 0 then
		self:fail("byte read with unconsumed bits; call alignBits() first")
	end
	local pos = self._pos
	if pos + n > self._limit then
		self:fail(`truncated: need {n} byte(s) at offset {pos - self._start}, only {self._limit - pos} left`)
	end
	self._pos = pos + n
	return pos
end

function Reader.readU8(self: Reader): number
	return readu8(self._buf, take(self, 1))
end

function Reader.readU16(self: Reader): number
	return readu16(self._buf, take(self, 2))
end

function Reader.readI16(self: Reader): number
	return readi16(self._buf, take(self, 2))
end

function Reader.readU32(self: Reader): number
	return readu32(self._buf, take(self, 4))
end

-- Reads `count` bits (1..32), LSB-first, matching Writer.writeBits.
function Reader.readBits(self: Reader, count: number): number
	if type(count) ~= "number" or count ~= math.floor(count) or count < 1 or count > 32 then
		error(`Packer: bit count out of range [1, 32]: {count}`, 2)
	end
	local acc = self._acc
	local accBits = self._accBits
	while accBits < count do
		local pos = self._pos
		if pos >= self._limit then
			self:fail(`truncated: need {count - accBits} more bit(s) at offset {pos - self._start}`)
		end
		acc += readu8(self._buf, pos) * 2 ^ accBits
		self._pos = pos + 1
		accBits += 8
	end
	local scale = 2 ^ count
	local value = acc % scale
	self._acc = (acc - value) / scale
	self._accBits = accBits - count
	return value
end

-- Drops the rest of a partially read byte. The padding must be zero, as
-- Writer.flushBits writes it; anything else means a malformed payload.
function Reader.alignBits(self: Reader)
	if self._acc ~= 0 then
		self:fail("nonzero padding bits")
	end
	self._accBits = 0
end

function Reader.remaining(self: Reader): number
	return self._limit - self._pos
end

function Reader.atEnd(self: Reader): boolean
	return self._pos >= self._limit and self._accBits == 0
end

-- Bytes consumed so far.
function Reader.offset(self: Reader): number
	return self._pos - self._start
end

Packer.Reader = Reader

--------------------------------------------------------------------------------
-- Messages: many records back to back, split under a byte limit
--------------------------------------------------------------------------------

-- Packs records into messages of at most maxBytes (default MAX_MESSAGE_BYTES),
-- in order, never splitting a record. writeHeader, if given, starts every
-- message (e.g. the server tick) and counts toward the limit.
function Packer.chunk<T>(
	records: { T },
	encode: (Writer, T) -> (),
	maxBytes: number?,
	writeHeader: ((Writer) -> ())?
): { buffer }
	local limit = maxBytes or Packer.MAX_MESSAGE_BYTES
	local messages: { buffer } = {}
	local message = Writer.new(limit)
	local scratch = Writer.new()

	local function startMessage()
		message:reset()
		if writeHeader then
			writeHeader(message)
		end
	end

	startMessage()
	local headerBytes = message:len()
	local count = 0

	for i, record in records do
		scratch:reset()
		encode(scratch, record)
		local size = scratch:len()
		if headerBytes + size > limit then
			error(`Packer: record {i} is {size} bytes, too big for a {limit}-byte message`, 2)
		end
		if message:len() + size > limit then
			table.insert(messages, message:finish())
			startMessage()
			count = 0
		end
		message:writeBytes(scratch._buf, 0, size)
		count += 1
	end
	if count > 0 then
		table.insert(messages, message:finish())
	end
	return messages
end

-- Decodes one message produced by chunk(). Returns the records and the header
-- (if readHeader is given). Errors if any record is malformed or cut short.
function Packer.readAll<T, H>(message: buffer, decode: (Reader) -> T, readHeader: ((Reader) -> H)?): ({ T }, H?)
	local reader = Reader.new(message)
	local header = if readHeader then readHeader(reader) else nil
	local records: { T } = {}
	while not reader:atEnd() do
		table.insert(records, decode(reader))
	end
	return records, header
end

return Packer
