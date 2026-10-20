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
}

export type NetState = {
	players: { [number]: PlayerNet },
	iconIndex: { [number]: number }, -- unit def index → strategic icon (1..63; 0 = unknown blip)
}

function NetState.new(playerIds: { number }, iconIndex: { [number]: number }): NetState
	local players = {}
	for _, pid in playerIds do
		local outbox, bytes, messages = {}, {}, {}
		for _, ch in NetState.CHANNELS do
			outbox[ch] = {}
			bytes[ch] = 0
			messages[ch] = 0
		end
		players[pid] = {
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
		}
	end
	return { players = players, iconIndex = iconIndex }
end

return NetState
