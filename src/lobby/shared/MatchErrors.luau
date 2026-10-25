--!strict
-- Why a player couldn't get into (or stay in) a match (L-21; contract
-- section 11, the user's request: "any failed attempt to connect to the game
-- match must be displayed on the lobby when return with error code +
-- description"). 1xx happen on the lobby's side, before or while players
-- leave; 2xx on the match server's side, reported back in the returning
-- player's teleport data or in the match's result record. The list and its
-- cleaning are shared with the match place (`@shared/Match/MatchConfig`:
-- ERRORS, cleanError); the lobby adds the teleport mapping and its one-line
-- form. Pure Luau.

local Shared = require("@shared/Match/MatchConfig")

local MatchErrors = {}

export type Entry = Shared.ErrorEntry
export type Error = Shared.MatchError

MatchErrors.LIST = Shared.ERRORS
MatchErrors.DETAIL_MAX = Shared.ERROR_DETAIL_MAX

-- An error from outside (teleport data, a result record, a remote), cleaned:
-- a listed code, a short string detail; nil when it isn't one.
MatchErrors.clean = Shared.cleanError

-- TeleportInitFailed's result → code.
local TELEPORT: { [string]: number } = {
	GameNotFound = 111,
	GameEnded = 112,
	GameFull = 113,
	Unauthorized = 114,
	Flooded = 115,
	IsTeleporting = 116,
}
function MatchErrors.teleport(resultName: string): number
	return TELEPORT[resultName] or 110
end

-- "Error 113 · Match server full", for one-line notices.
function MatchErrors.line(err: Error): string
	local entry = MatchErrors.LIST[err.code]
	return `Error {err.code} · {if entry then entry.title else "Unknown"}`
end

return MatchErrors
