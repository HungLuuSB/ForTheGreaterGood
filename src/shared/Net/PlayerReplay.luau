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

local Packer = require("./Packer")

local PlayerReplay = {}

PlayerReplay.MAGIC = "FTGP"
PlayerReplay.FORMAT_VERSION = 1
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

function PlayerReplay.serialize(rep: Replay): buffer
	local h = rep.header
	local w = Packer.Writer.new(4096)
	w:writeString(PlayerReplay.MAGIC)
	w:writeU8(PlayerReplay.FORMAT_VERSION)
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
	local prev = rep.firstTick
	for _, f in rep.frames do
		writeVarint(w, f.tick - prev)
		prev = f.tick
		writeVarint(w, #f.messages)
		for _, m in f.messages do
			w:writeU8(CHANNEL_INDEX[m.channel])
			writeVarint(w, buffer.len(m.data))
			w:writeBytes(m.data)
		end
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
	if format ~= PlayerReplay.FORMAT_VERSION then
		error(`PlayerReplay: unsupported format version {format} (expected {PlayerReplay.FORMAT_VERSION})`, 2)
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
	r.context = "player replay frame"
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
			table.insert(messages, { channel = channel, data = r:readBuffer(readVarint(r)) })
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
