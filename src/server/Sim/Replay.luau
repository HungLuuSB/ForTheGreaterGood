--!strict
-- Replay log (guide 17.1): a header that pins everything the simulation
-- depends on, then every applied command in order, plus world-hash
-- checkpoints for desync detection.
--
-- Binary layout (little-endian, via Packer):
--   header   magic "FTGR" | format u8 | protocol u16 | defsHash u32 | seed u32
--            | mapId (len u8 + bytes) | scenario (len u8 + bytes)
--            | playerCount u8 | (player u8, team u8, allyTeam u8, start u8 (0 =
--              by player order; S-141)) × playerCount
--            | hasMatch u8 [| mode u8 (1 FFA, 2 TEAM) | win u8 (1 COMMAND_ENDS,
--              2 ANNIHILATION) | unitCap u16]
--            | cheats u8 (bit 0 allowed, bit 1 used, bit 2 offline; S-102)
--   entries  kind u8, then
--            COMMAND     tick u32 | player u8 | length u16 | payload (Schema command record)
--            CHECKPOINT  tick u32 | hash u32

local Packer = require("@shared/Net/Packer")

local Replay = {}

Replay.MAGIC = "FTGR"
Replay.FORMAT_VERSION = 4 -- 2: ally teams and match options in the header; 3: cheat flags (S-102); 4: chosen starts (S-141)
Replay.Kind = table.freeze({ COMMAND = 1, CHECKPOINT = 2 })

export type PlayerInfo = { id: number, team: number, allyTeam: number?, start: number? }
export type MatchInfo = { mode: "FFA" | "TEAM", win: "COMMAND_ENDS" | "ANNIHILATION", unitCap: number?, friendlyFire: boolean? }

export type Header = {
	protocolVersion: number,
	defsHash: number,
	seed: number,
	mapId: string,
	scenario: string,
	players: { PlayerInfo }, -- in player ID order
	match: MatchInfo?, -- nil: no match rules
	cheats: boolean?, -- cheat commands allowed (S-102)
	cheated: boolean?, -- a cheat was used: set by Cheats when one applies
	offline: boolean?, -- offline / Studio match
}

export type Entry = {
	kind: number,
	tick: number,
	player: number?, -- COMMAND
	payload: buffer?, -- COMMAND
	hash: number?, -- CHECKPOINT
}

export type Log = { header: Header, entries: { Entry } }

function Replay.new(header: Header): Log
	return { header = header, entries = {} }
end

function Replay.addCommand(log: Log, tick: number, player: number, payload: buffer)
	table.insert(log.entries, { kind = Replay.Kind.COMMAND, tick = tick, player = player, payload = payload })
end

function Replay.addCheckpoint(log: Log, tick: number, hash: number)
	table.insert(log.entries, { kind = Replay.Kind.CHECKPOINT, tick = tick, hash = hash })
end

-- { {tick, hash}, ... } in log order.
function Replay.checkpoints(log: Log): { { number } }
	local out = {}
	for _, e in log.entries do
		if e.kind == Replay.Kind.CHECKPOINT then
			table.insert(out, { e.tick, e.hash :: number })
		end
	end
	return out
end

local function writeShortString(w: Packer.Writer, s: string)
	if #s > 255 then
		error(`Replay: string too long ({#s} > 255 bytes)`, 3)
	end
	w:writeU8(#s)
	w:writeString(s)
end

function Replay.serialize(log: Log): buffer
	local h = log.header
	local w = Packer.Writer.new(256)
	w:writeString(Replay.MAGIC)
	w:writeU8(Replay.FORMAT_VERSION)
	w:writeU16(h.protocolVersion)
	w:writeU32(h.defsHash)
	w:writeU32(h.seed)
	writeShortString(w, h.mapId)
	writeShortString(w, h.scenario)
	w:writeU8(#h.players)
	for _, p in h.players do
		w:writeU8(p.id)
		w:writeU8(p.team)
		w:writeU8(p.allyTeam or p.team)
		w:writeU8(p.start or 0)
	end
	local m = h.match
	if m then
		w:writeU8(if m.friendlyFire == false then 2 else 1) -- 2: friendly fire off (S-73)
		w:writeU8(if m.mode == "FFA" then 1 else 2)
		w:writeU8(if m.win == "COMMAND_ENDS" then 1 else 2)
		w:writeU16(m.unitCap or 0)
	else
		w:writeU8(0)
	end
	w:writeU8((if h.cheats then 1 else 0) + (if h.cheated then 2 else 0) + (if h.offline then 4 else 0))
	for _, e in log.entries do
		w:writeU8(e.kind)
		w:writeU32(e.tick)
		if e.kind == Replay.Kind.COMMAND then
			local payload = e.payload :: buffer
			w:writeU8(e.player :: number)
			w:writeU16(buffer.len(payload))
			w:writeBytes(payload)
		else
			w:writeU32(e.hash :: number)
		end
	end
	return w:finish()
end

-- Parses a serialized log. Errors clearly on a wrong magic/format or any
-- truncated or malformed entry.
function Replay.parse(buf: buffer): Log
	local r = Packer.Reader.new(buf)
	r.context = "replay header"
	local magic = r:readString(4)
	if magic ~= Replay.MAGIC then
		error(`Replay: not a replay (magic {string.format("%q", magic)})`, 2)
	end
	local format = r:readU8()
	if format ~= Replay.FORMAT_VERSION then
		error(`Replay: unsupported format version {format} (expected {Replay.FORMAT_VERSION})`, 2)
	end
	local header: Header = {
		protocolVersion = r:readU16(),
		defsHash = r:readU32(),
		seed = r:readU32(),
		mapId = r:readString(r:readU8()),
		scenario = r:readString(r:readU8()),
		players = {},
	}
	for _ = 1, r:readU8() do
		local p: PlayerInfo = { id = r:readU8(), team = r:readU8(), allyTeam = r:readU8() }
		local start = r:readU8()
		if start > 0 then
			p.start = start
		end
		table.insert(header.players, p)
	end
	local hasMatch = r:readU8()
	if hasMatch == 1 or hasMatch == 2 then
		local mode, win, cap = r:readU8(), r:readU8(), r:readU16()
		if (mode ~= 1 and mode ~= 2) or (win ~= 1 and win ~= 2) then
			error(`Replay: bad match options (mode {mode}, win {win})`, 2)
		end
		header.match = {
			mode = if mode == 1 then "FFA" else "TEAM",
			win = if win == 1 then "COMMAND_ENDS" else "ANNIHILATION",
			unitCap = if cap > 0 then cap else nil,
			friendlyFire = if hasMatch == 2 then false else nil,
		}
	end
	local cheatFlags = r:readU8()
	header.cheats = if bit32.band(cheatFlags, 1) ~= 0 then true else nil
	header.cheated = if bit32.band(cheatFlags, 2) ~= 0 then true else nil
	header.offline = if bit32.band(cheatFlags, 4) ~= 0 then true else nil

	local log = Replay.new(header)
	r.context = "replay entry"
	while not r:atEnd() do
		local kind = r:readU8()
		local tick = r:readU32()
		if kind == Replay.Kind.COMMAND then
			local player = r:readU8()
			local payload = r:readBuffer(r:readU16())
			Replay.addCommand(log, tick, player, payload)
		elseif kind == Replay.Kind.CHECKPOINT then
			Replay.addCheckpoint(log, tick, r:readU32())
		else
			r:fail(`unknown entry kind {kind}`)
		end
	end
	return log
end

return Replay
