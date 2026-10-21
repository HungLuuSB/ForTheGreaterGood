--!strict
-- Per-player replication state (data only; logic in NetOut.luau). Not part of
-- the simulation hash: it only decides what is sent, never what happens.

local NetState = {}

NetState.CHANNELS = table.freeze({ "Snapshot", "Tactical", "State", "Strategic", "Events", "Projectiles", "Eco" })

export type PlayerNet = {
	camera: { number }?, -- minX, minZ, maxX, maxZ in cells; nil = no tactical tier
	tactical: { [number]: number }, -- unit IDs in this player's tactical tier → their generation (D109)
	tacticalList: { number }, -- the same, in the order they entered
	outbox: { [string]: { buffer } }, -- this tick's messages per channel
	bytes: { [string]: number }, -- cumulative bytes sent per channel
	messages: { [string]: number }, -- cumulative message count per channel
	projKnown: { [number]: boolean }, -- projectile IDs this client was sent SPAWN_PROJ for
	projInView: { [number]: boolean }, -- known homing projectiles in its view last tick (D102)
	welcome: buffer?, -- join handshake waiting for the next outbox (S-2)
	forceFull: boolean, -- after a join: strategic snapshot and Eco record now, not on cadence
	lastEco: string?, -- the last Eco record sent (bytes), to send only changes
	eventCounts: { [number]: number }, -- cumulative event records per Schema.EventKind
	sentTargets: { [number]: string }, -- own tactical units → the weapon targets last sent (S-16)
	sentStock: { [number]: string }, -- own tactical units → the missile stock last sent (S-47)
	sentOwner: { [number]: { string } }, -- own tactical units → queue, states, ammo last sent (S-61)
	spectator: boolean, -- sees everything, camera on the whole map (S-18)
	eventBytes: { [number]: number }, -- cumulative bytes per Schema.EventKind (bandwidth reports)
	sightVersion: number, -- the ally team's sight version the client has (-1: none; S-26)
	wrecksSent: { [number]: boolean }, -- wreck IDs the client was sent a WRECK for (S-26)
	wreckList: { number }, -- the same, in the order they were sent
	wreckVersion: number, -- the ally team's wreck knowledge version last compared
}

-- What an ally team knows of wrecks (S-26): a wreck is known once its spot
-- was in the team's sight while it existed, and forgotten once the team sees
-- the spot without it. `version` changes whenever the list does.
-- An ally team's sight (S-26): one byte (0 / 1) per sensor cell, as of the
-- last sensor tick; `changes` took version - 1 to version.
export type Sight = { cells: buffer, version: number, changes: { number } }

export type WreckKnowledge = {
	known: { [number]: { number } }, -- wreck ID → { x, z }
	list: { number }, -- known IDs, in the order the team learned of them
	version: number,
}

export type NetState = {
	players: { [number]: PlayerNet },
	spectators: { PlayerNet }, -- in the order they were added (S-18)
	iconIndex: { [number]: number }, -- unit def index → strategic icon (Shared/Net/Icons: the def index; 0 = unknown blip)
	wrecks: { [number]: WreckKnowledge }, -- per ally team (0: spectators)
	sight: { [number]: Sight }, -- per ally team
}

-- Replication state of one viewer (a player or a spectator).
function NetState.viewer(spectator: boolean): PlayerNet
	local outbox, bytes, messages = {}, {}, {}
	for _, ch in NetState.CHANNELS do
		outbox[ch] = {}
		bytes[ch] = 0
		messages[ch] = 0
	end
	return {
		camera = nil,
		tactical = {},
		tacticalList = {},
		outbox = outbox,
		bytes = bytes,
		messages = messages,
		projKnown = {},
		projInView = {},
		welcome = nil,
		forceFull = false,
		lastEco = nil,
		eventCounts = {},
		sentTargets = {},
		sentStock = {},
		sentOwner = {},
		spectator = spectator,
		eventBytes = {},
		sightVersion = -1,
		wrecksSent = {},
		wreckList = {},
		wreckVersion = -1,
	}
end

function NetState.new(playerIds: { number }, iconIndex: { [number]: number }): NetState
	local players = {}
	for _, pid in playerIds do
		players[pid] = NetState.viewer(false)
	end
	return { players = players, spectators = {}, iconIndex = iconIndex, wrecks = {}, sight = {} }
end

return NetState
