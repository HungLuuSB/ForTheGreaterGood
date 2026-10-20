--!strict
-- Per-player replication state (data only; logic in NetOut.luau). Not part of
-- the simulation hash: it only decides what is sent, never what happens.

local NetState = {}

NetState.CHANNELS = table.freeze({ "Tactical", "State", "Strategic", "Events", "Projectiles" })

export type PlayerNet = {
	camera: { number }?, -- minX, minZ, maxX, maxZ in cells; nil = no tactical tier
	tactical: { [number]: boolean }, -- unit IDs in this player's tactical tier
	tacticalList: { number }, -- the same, in the order they entered
	outbox: { [string]: { buffer } }, -- this tick's messages per channel
	bytes: { [string]: number }, -- cumulative bytes sent per channel
	messages: { [string]: number }, -- cumulative message count per channel
	projKnown: { [number]: boolean }, -- projectile IDs this client was sent SPAWN_PROJ for
	projInView: { [number]: boolean }, -- known homing projectiles in its view last tick (D102)
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
			eventCounts = {},
		}
	end
	return { players = players, iconIndex = iconIndex }
end

return NetState
