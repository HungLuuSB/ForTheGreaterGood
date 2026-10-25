--!strict
-- Why a player couldn't get into (or stay in) a match, as one numbered list
-- shared by the lobby and the match place (L-21; docs/contracts/match.md
-- section 8, the user's request: "any failed attempt to connect to the game
-- match must be displayed on the lobby when return with error code +
-- description"). 1xx happen on the lobby's side, before or while players
-- leave; 2xx on the match server's side, reported back in the returning
-- player's teleport data or in the match's result record. Pure Luau.

local MatchErrors = {}

export type Entry = { title: string, description: string }
export type Error = { code: number, detail: string? }

local function e(title: string, description: string): Entry
	return table.freeze({ title = title, description = description })
end

MatchErrors.LIST = table.freeze({
	-- the lobby's side
	[101] = e("No match place", "The lobby couldn't find the game's match place."),
	[102] = e("Bad match setup", "The lobby built a match setup that failed its own check."),
	[103] = e("No match server", "Roblox didn't give the lobby a server for the match."),
	[104] = e("Match store unavailable", "The lobby couldn't save the match setup (MemoryStore)."),
	[105] = e("Room changed", "The room changed while the match was starting."),
	[106] = e("Nobody to send", "None of the room's players were on this lobby server."),
	[110] = e("Teleport failed", "Roblox couldn't send the players to the match server."),
	[111] = e("Match server not found", "The teleport couldn't find the match server."),
	[112] = e("Match server closed", "The match server shut down before you arrived."),
	[113] = e("Match server full", "The match server had no room for you."),
	[114] = e("Teleport not allowed", "Roblox refused the teleport to the match."),
	[115] = e("Too many teleports", "Roblox is limiting teleports right now."),
	[116] = e("Already teleporting", "Another teleport was still in progress."),
	[120] = e("Match server stopped answering", "The match server stopped reporting, so the match was ended."),
	[121] = e("Match not found", "The running match's details have expired; it can't be rejoined."),
	-- the match server's side
	[201] = e("No match setup", "The match server found no setup for itself."),
	[202] = e("Bad match setup", "The match server refused the lobby's match setup."),
	[203] = e("Version mismatch", "The lobby and the match place are on different versions."),
	[204] = e("Game version mismatch", "Your game client and the match server are on different versions."),
	[205] = e("Not in this match", "You aren't one of this match's players or spectators."),
	[206] = e("Match full", "The match had no free seat for you."),
	[207] = e("Match already over", "The match ended before you arrived."),
	[208] = e("Players didn't arrive", "Not everyone reached the match in time, so it didn't start."),
	[209] = e("Everyone left", "Every player left, so the match was abandoned."),
	[210] = e("Match server error", "The match server hit an error and ended the match."),
	[299] = e("Match server problem", "The match server sent you back for a reason it didn't name."),
} :: { [number]: Entry })

MatchErrors.DETAIL_MAX = 200 -- characters of `detail` kept

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

-- An error from outside (teleport data, a result record, a remote), cleaned:
-- a listed code, a short string detail; nil when it isn't one.
function MatchErrors.clean(v: any): Error?
	if type(v) ~= "table" or type(v.code) ~= "number" or MatchErrors.LIST[v.code] == nil then
		return nil
	end
	local detail = if type(v.detail) == "string" and #v.detail > 0 then string.sub(v.detail, 1, MatchErrors.DETAIL_MAX) else nil
	return { code = v.code, detail = detail }
end

-- "Error 113 · Match server full", for one-line notices.
function MatchErrors.line(err: Error): string
	local entry = MatchErrors.LIST[err.code]
	return `Error {err.code} · {if entry then entry.title else "Unknown"}`
end

return MatchErrors
