--!strict
-- Player-facing replays (guide 17.1, S-18): the stream the server sent one
-- viewer (a player, or a spectator, who sees everything), message by
-- message, tick by tick. A client plays it back through the same code that
-- reads the live stream, without re-simulating, so a replay keeps working
-- across platforms and after balance patches. It does need the protocol
-- version and defs it was recorded with (the header has both).
--
-- File layout (little-endian; varint = LEB128, 7 bits per byte):
--   magic "FTGP" | format u8 | protocol u16 | defsHash u32
--   mapIdLength u8 | mapId | viewer u8 (player ID; 0 = spectator)
--   playerCount u8 | (id u8, team u8, allyTeam u8) × playerCount
--   firstTick u32 | lastTick u32
--   frames: tickDelta varint (from the previous frame; the first from
--           firstTick) | messageCount varint |
--           (channel u8 | length varint | bytes) × messageCount
-- Only ticks with messages are stored; playback feeds empty outboxes for
-- the ticks between frames, as a live client would see them.
--
-- Format 2 (S-77; the default since): the same header, then the frame
-- stream compressed with Shared/Net/Lz and then Shared/Net/Huffman, after
-- reversible transforms that turn slowly changing records into repeats:
--   * every message's tick header becomes its difference from the frame's
--     tick (Tick.toWire), usually 0;
--   * Tactical records: unitId | zigzag varint of the cell's change | offX,
--     offZ, heading and alt changes (mod 256) | flags XOR, each against
--     the same unit's previous record in the file;
--   * State records: unitId | length varint | the record's other bytes XOR
--     the same unit's previous record when it was as long (else as is);
--   * Strategic snapshots: XOR the previous snapshot, byte by byte.
-- After the header: bodyHash u32 (FNV-1a of the transformed frame stream,
-- so a damaged file is refused), then the compressed stream.
-- Format 1 files still read.

local Hash = require("../Util/Hash")
local Huffman = require("./Huffman")
local Lz = require("./Lz")
local Packer = require("./Packer")
local Schema = require("./Schema")
local Tick = require("./Tick")

local PlayerReplay = {}

PlayerReplay.MAGIC = "FTGP"
PlayerReplay.FORMAT_VERSION = 2 -- 1: plain frames; 2: transformed and LZ-compressed (S-77)
-- Channel numbering in the file. NetState.CHANNELS lists the same names.
PlayerReplay.CHANNELS = table.freeze({ "Snapshot", "Tactical", "State", "Strategic", "Events", "Projectiles", "Eco" })
local CHANNEL_INDEX: { [string]: number } = {}
for i, name in PlayerReplay.CHANNELS do
	CHANNEL_INDEX[name] = i
end

export type Player = { id: number, team: number, allyTeam: number }
export type Header = {
	protocol: number,
	defsHash: number,
	mapId: string,
	viewer: number, -- player ID, 0 = spectator
	players: { Player },
}
export type Message = { channel: string, data: buffer }
export type Frame = { tick: number, messages: { Message } }
export type Replay = {
	header: Header,
	firstTick: number, -- the first tick recorded (frames may start later)
	lastTick: number,
	frames: { Frame },
}

function PlayerReplay.new(header: Header, firstTick: number): Replay
	return { header = header, firstTick = firstTick, lastTick = firstTick - 1, frames = {} }
end

-- Records what the viewer got after sim tick `tick` (its outbox, channel →
-- messages). Ticks must increase by one per call.
function PlayerReplay.record(rep: Replay, tick: number, outbox: { [string]: { buffer } })
	if tick ~= rep.lastTick + 1 then
		error(`PlayerReplay.record: expected tick {rep.lastTick + 1}, got {tick}`, 2)
	end
	rep.lastTick = tick
	local messages: { Message } = {}
	for _, name in PlayerReplay.CHANNELS do
		for _, data in outbox[name] or {} do
			-- copy: the outbox's buffers are the server's, rebuilt every tick
			local copy = buffer.create(buffer.len(data))
			buffer.copy(copy, 0, data)
			table.insert(messages, { channel = name, data = copy })
		end
	end
	if #messages > 0 then
		table.insert(rep.frames, { tick = tick, messages = messages })
	end
end

local function writeVarint(w: Packer.Writer, n: number)
	assert(n >= 0 and n == math.floor(n), "PlayerReplay: varints are non-negative integers")
	repeat
		local byte = n % 128
		n = n // 128
		w:writeU8(if n > 0 then byte + 128 else byte)
	until n == 0
end

local function readVarint(r: Packer.Reader): number
	local n, scale = 0, 1
	for _ = 1, 8 do
		local byte = r:readU8()
		n += (byte % 128) * scale
		if byte < 128 then
			return n
		end
		scale *= 128
	end
	return r:fail("varint longer than 8 bytes")
end

-- Delta transforms (format 2). `enc` true: original → transformed; false:
-- the inverse. `st` carries the previous records across messages.
type TransformState = { tac: { [number]: { number } }, state: { [number]: buffer }, strategic: buffer? }

local readu8, readu16, writeu8 = buffer.readu8, buffer.readu16, buffer.writeu8

local function zig(n: number): number
	return if n >= 0 then n * 2 else -n * 2 - 1
end
local function unzig(n: number): number
	return if n % 2 == 0 then n // 2 else -(n + 1) // 2
end

local function header(w: Packer.Writer, data: buffer, tick: number, enc: boolean)
	local h = readu16(data, 0)
	local base = Tick.toWire(tick)
	w:writeU16(if enc then (h - base) % 65536 else (h + base) % 65536)
end

local function transformTactical(data: buffer, tick: number, st: TransformState, enc: boolean): buffer
	local w = Packer.Writer.new(buffer.len(data) + 16)
	header(w, data, tick, enc)
	local r = Packer.Reader.new(data, 2)
	local tac = st.tac
	while not r:atEnd() do
		local uid = r:readU16()
		local prev = tac[uid] or { 0, 0, 0, 0, 0, 0 }
		local cell, ox, oz, hd, fl, alt
		if enc then
			cell, ox, oz, hd, fl = r:readU16(), r:readU8(), r:readU8(), r:readU8(), r:readU8()
			alt = if fl % 2 == 1 then r:readU8() else 0
			w:writeU16(uid)
			writeVarint(w, zig(cell - prev[1]))
			w:writeU8((ox - prev[2]) % 256)
			w:writeU8((oz - prev[3]) % 256)
			w:writeU8((hd - prev[4]) % 256)
			w:writeU8(bit32.bxor(fl, prev[5]))
			if fl % 2 == 1 then
				w:writeU8((alt - prev[6]) % 256)
			end
		else
			cell = prev[1] + unzig(readVarint(r))
			ox, oz, hd = (r:readU8() + prev[2]) % 256, (r:readU8() + prev[3]) % 256, (r:readU8() + prev[4]) % 256
			fl = bit32.bxor(r:readU8(), prev[5])
			alt = if fl % 2 == 1 then (r:readU8() + prev[6]) % 256 else 0
			w:writeU16(uid)
			w:writeU16(cell)
			w:writeU8(ox)
			w:writeU8(oz)
			w:writeU8(hd)
			w:writeU8(fl)
			if fl % 2 == 1 then
				w:writeU8(alt)
			end
		end
		tac[uid] = { cell, ox, oz, hd, fl, alt }
	end
	return w:finish()
end

local function transformState(data: buffer, tick: number, st: TransformState, enc: boolean): buffer
	local w = Packer.Writer.new(buffer.len(data) + 32)
	header(w, data, tick, enc)
	local r = Packer.Reader.new(data, 2)
	while not r:atEnd() do
		local uid, body, len
		if enc then
			local start = (r :: any)._pos
			Schema.decodeState(r) -- (only to find where the record ends)
			local stop = (r :: any)._pos
			uid = readu16(data, start)
			len = stop - start - 2
			body = buffer.create(len)
			buffer.copy(body, 0, data, start + 2, len)
		else
			uid = r:readU16()
			len = readVarint(r)
			body = r:readBuffer(len)
		end
		local prev = st.state[uid]
		local out = buffer.create(len)
		buffer.copy(out, 0, body, 0, len)
		if prev and buffer.len(prev) == len then
			for k = 0, len - 1 do
				writeu8(out, k, bit32.bxor(readu8(body, k), readu8(prev, k)))
			end
		end
		w:writeU16(uid)
		if enc then
			writeVarint(w, len)
		end
		w:writeBytes(out)
		st.state[uid] = if enc then body else out
	end
	return w:finish()
end

local function transformStrategic(data: buffer, tick: number, st: TransformState, enc: boolean): buffer
	local n = buffer.len(data)
	local out = buffer.create(n)
	buffer.copy(out, 0, data, 0, n)
	local w = Packer.Writer.new(2)
	header(w, data, tick, enc)
	buffer.copy(out, 0, w:finish(), 0, 2)
	local prev = st.strategic
	if prev then
		for k = 2, math.min(n, buffer.len(prev)) - 1 do
			writeu8(out, k, bit32.bxor(readu8(data, k), readu8(prev, k)))
		end
	end
	st.strategic = if enc then data else out
	return out
end

local function transform(channel: string, data: buffer, tick: number, st: TransformState, enc: boolean): buffer
	if buffer.len(data) < 2 then
		return data
	end
	if channel == "Tactical" then
		return transformTactical(data, tick, st, enc)
	elseif channel == "State" then
		return transformState(data, tick, st, enc)
	elseif channel == "Strategic" then
		return transformStrategic(data, tick, st, enc)
	end
	return data
end

-- Serializes `rep`: format 2 (transformed and compressed) unless `format` 1.
function PlayerReplay.serialize(rep: Replay, format: number?): buffer
	local version = format or PlayerReplay.FORMAT_VERSION
	local h = rep.header
	local w = Packer.Writer.new(4096)
	w:writeString(PlayerReplay.MAGIC)
	w:writeU8(version)
	w:writeU16(h.protocol)
	w:writeU32(h.defsHash)
	assert(#h.mapId <= 255, "PlayerReplay: mapId longer than 255 bytes")
	w:writeU8(#h.mapId)
	w:writeString(h.mapId)
	w:writeU8(h.viewer)
	w:writeU8(#h.players)
	for _, p in h.players do
		w:writeU8(p.id)
		w:writeU8(p.team)
		w:writeU8(p.allyTeam)
	end
	w:writeU32(rep.firstTick)
	w:writeU32(rep.lastTick)
	local body = if version == 1 then w else Packer.Writer.new(65536)
	local st: TransformState = { tac = {}, state = {} }
	local prev = rep.firstTick
	for _, f in rep.frames do
		writeVarint(body, f.tick - prev)
		prev = f.tick
		writeVarint(body, #f.messages)
		for _, m in f.messages do
			local data = if version == 1 then m.data else transform(m.channel, m.data, f.tick, st, true)
			body:writeU8(CHANNEL_INDEX[m.channel])
			writeVarint(body, buffer.len(data))
			body:writeBytes(data)
		end
	end
	if version ~= 1 then
		local plain = body:finish()
		w:writeU32(Hash.fnv1a(buffer.tostring(plain)))
		w:writeBytes(Huffman.encode(Lz.compress(plain)))
	end
	return w:finish()
end

function PlayerReplay.parse(buf: buffer): Replay
	local r = Packer.Reader.new(buf)
	r.context = "player replay header"
	local magic = r:readString(4)
	if magic ~= PlayerReplay.MAGIC then
		error(`PlayerReplay: not a player replay (magic {string.format("%q", magic)})`, 2)
	end
	local format = r:readU8()
	if format ~= 1 and format ~= 2 then
		error(`PlayerReplay: unsupported format version {format} (1 and 2 read)`, 2)
	end
	local header: Header = {
		protocol = r:readU16(),
		defsHash = r:readU32(),
		mapId = r:readString(r:readU8()),
		viewer = r:readU8(),
		players = {},
	}
	for _ = 1, r:readU8() do
		table.insert(header.players, { id = r:readU8(), team = r:readU8(), allyTeam = r:readU8() })
	end
	local rep = PlayerReplay.new(header, r:readU32())
	rep.lastTick = r:readU32()
	if format == 2 then
		local want = r:readU32()
		local rest = r:readBuffer(buffer.len(buf) - (r :: any)._pos)
		local ok, plain = pcall(function()
			return Lz.decompress(Huffman.decode(rest))
		end)
		if not ok then
			r:fail("truncated or corrupt frames")
		end
		if Hash.fnv1a(buffer.tostring(plain)) ~= want then
			r:fail("corrupt frames (hash mismatch)")
		end
		r = Packer.Reader.new(plain)
	end
	r.context = "player replay frame"
	local st: TransformState = { tac = {}, state = {} }
	local tick = rep.firstTick
	while not r:atEnd() do
		tick += readVarint(r)
		if tick > rep.lastTick then
			r:fail(`frame at tick {tick} after the last tick {rep.lastTick}`)
		end
		local messages: { Message } = {}
		for _ = 1, readVarint(r) do
			local channel = PlayerReplay.CHANNELS[r:readU8()]
			if channel == nil then
				r:fail("unknown channel")
			end
			local data = r:readBuffer(readVarint(r))
			if format == 2 then
				data = transform(channel, data, tick, st, false)
			end
			table.insert(messages, { channel = channel, data = data })
		end
		table.insert(rep.frames, { tick = tick, messages = messages })
	end
	return rep
end

-- Plays the replay back: calls `deliver(tick, outbox)` for every tick from
-- firstTick to lastTick, with that tick's messages per channel (empty
-- channels on ticks without a frame), as the live client got them.
function PlayerReplay.play(rep: Replay, deliver: (tick: number, outbox: { [string]: { buffer } }) -> ())
	local i = 1
	for tick = rep.firstTick, rep.lastTick do
		local outbox: { [string]: { buffer } } = {}
		for _, name in PlayerReplay.CHANNELS do
			outbox[name] = {}
		end
		local f = rep.frames[i]
		if f and f.tick == tick then
			for _, m in f.messages do
				table.insert(outbox[m.channel], m.data)
			end
			i += 1
		end
		deliver(tick, outbox)
	end
end

return PlayerReplay
