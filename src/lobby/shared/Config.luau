--!strict
-- The lobby's constants (L-2): limits, enums, the color palette and the
-- timeouts of the match contract (docs/contracts/match.md). Pure data,
-- shared by the lobby server, its client and the Lune specs.

local Match = require("@shared/Match/MatchConfig")

local Config = {}

-- The match place (the FTGG main game). The lobby and the match place must
-- be places of the same experience: reserved servers, MemoryStore and
-- DataStores are per experience.
Config.MATCH_PLACE_ID = 89435699207932

-- The match contract's version, enums, limits and palette are shared with
-- the match place (@shared/Match/MatchConfig, S-145).
Config.CONFIG_VERSION = Match.CONFIG_VERSION
Config.MODES = Match.MODES
Config.WINS = Match.WINS
Config.LEVELS = Match.LEVELS
Config.FACTIONS = Match.FACTIONS
Config.MAX_ALLY_TEAMS = Match.MAX_ALLY_TEAMS
Config.MAX_TEAM_SIZE = Match.MAX_TEAM_SIZE
Config.MAX_FFA = Match.MAX_FFA
Config.COLORS = Match.COLORS

Config.PRIVACY = table.freeze({ "public", "friends", "private" })

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
Config.MAX_ROOMS = 40 -- per lobby server

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
