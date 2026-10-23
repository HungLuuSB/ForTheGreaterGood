--!strict
-- The lobby's constants (L-2): limits, enums, the color palette and the
-- timeouts of the match contract (docs/contracts/match.md). Pure data,
-- shared by the lobby server, its client and the Lune specs.

local Config = {}

-- The match place (the FTGG main game). The lobby and the match place must
-- be places of the same experience: reserved servers, MemoryStore and
-- DataStores are per experience.
Config.MATCH_PLACE_ID = 89435699207932

-- Match config / results record version (contract section 2).
Config.CONFIG_VERSION = 1

Config.PRIVACY = table.freeze({ "public", "friends", "private" })
Config.MODES = table.freeze({ "FFA", "TEAM" })
Config.WINS = table.freeze({ "COMMAND_ENDS", "ANNIHILATION" })
Config.LEVELS = table.freeze({ "easy", "normal", "hard" })
Config.FACTIONS = table.freeze({ "order", "chaos" })

Config.LABELS = table.freeze({
	public = "Public",
	friends = "Friends",
	private = "Private",
	FFA = "Free for all",
	TEAM = "Teams",
	COMMAND_ENDS = "Command ends",
	ANNIHILATION = "Annihilation",
	easy = "Easy",
	normal = "Normal",
	hard = "Hard",
	order = "Order",
	chaos = "Chaos",
})

Config.NAME_MIN = 3 -- room name, characters
Config.NAME_MAX = 32
Config.PASSWORD_MAX = 32
Config.MIN_PLAYERS = 2 -- a room's human cap (players and spectators)
Config.MAX_PLAYERS = 16
Config.DEFAULT_PLAYERS = 8
Config.MAX_ALLY_TEAMS = 4 -- guide 16.1: Team mode, 2-4 ally teams of up to 4
Config.MAX_TEAM_SIZE = 4
Config.MAX_FFA = 8 -- guide 16.1: FFA up to 8, each alone
Config.MAX_ROOMS = 40 -- per lobby server

-- Player colors (contract: `color` is an index into this list). Distinct on
-- the dark terrain and on the minimap; no two players share one.
Config.COLORS = table.freeze({
	{ name = "Blue", rgb = { 64, 132, 230 } },
	{ name = "Red", rgb = { 222, 70, 62 } },
	{ name = "Green", rgb = { 82, 186, 92 } },
	{ name = "Yellow", rgb = { 236, 200, 64 } },
	{ name = "Purple", rgb = { 156, 92, 214 } },
	{ name = "Orange", rgb = { 238, 132, 46 } },
	{ name = "Cyan", rgb = { 60, 200, 210 } },
	{ name = "Pink", rgb = { 232, 110, 180 } },
	{ name = "White", rgb = { 226, 229, 235 } },
	{ name = "Olive", rgb = { 140, 150, 70 } },
	{ name = "Brown", rgb = { 150, 100, 62 } },
	{ name = "Teal", rgb = { 40, 130, 120 } },
})

-- Match contract timing (contract section 6), seconds.
Config.TELEPORT_RETRIES = 3 -- per attempt group, before the room gets its players back
Config.ARRIVAL_TIMEOUT = 120 -- no heartbeat this long after the teleport: the match never started
Config.HEARTBEAT_EVERY = 30 -- the match server refreshes alive/<matchId>
Config.HEARTBEAT_TTL = 120 -- its expiry: a match server silent this long is dead
Config.POLL_EVERY = 15 -- the lobby checks a running match this often
Config.AWAY_GRACE = 180 -- after the result, members not back yet leave the room
Config.CONFIG_TTL = 6 * 3600 -- config/<id>, server/<id>, access/<id>, player/<id>
Config.RESULT_TTL = 3 * 24 * 3600 -- result/<id>

-- Profiles (contract section 7).
Config.HISTORY_MAX = 50
Config.PROFILE_STORE = "FtggProfiles"
Config.MATCH_MAP = "FtggMatch" -- the MemoryStore HashMap

-- Studio stand-in match (L-6): how long the in-process match runs.
Config.STAND_IN_SECONDS = 20

return table.freeze(Config)
