--!strict
-- Sharing with allies (F23, the user; S-176, net.md SHARE 33): the
-- SHARE_UNITS, SHARE_RESOURCE and REQUEST commands the team panel sends,
-- and a line for each SHARE event (a gift or a request for help) the panel
-- shows. Gifts and requests reach the giver's ally team and spectators.
-- Pure Luau (C-7).

local Schema = require("@shared/Net/Schema")
local Commands = require("./Commands")

local Share = {}

local SK = Schema.ShareKind
local CT = Schema.CmdType

Share.RESOURCES = table.freeze({ supply = SK.SUPPLY, power = SK.POWER })
Share.ASK = table.freeze({ units = SK.ASK_UNITS, supply = SK.ASK_SUPPLY, power = SK.ASK_POWER })

-- Give units `ids` (own, complete, not a Commander) to ally player `to`.
function Share.units(ids: { number }, to: number): buffer
	return Commands.encode({ cmdType = CT.SHARE_UNITS, flags = 0, unitIds = ids, value = to })
end

-- Give `amount` of `resource` ("supply" / "power") to ally player `to`.
function Share.resource(to: number, resource: string, amount: number): buffer
	return Commands.encode({ cmdType = CT.SHARE_RESOURCE, flags = 0, unitIds = {}, toPlayer = to, resource = Share.RESOURCES[resource], amount = math.max(0, math.floor(amount)) })
end

-- Ask the allies for "units", "supply" or "power".
function Share.ask(what: string): buffer
	return Commands.encode({ cmdType = CT.REQUEST, flags = 0, unitIds = {}, value = Share.ASK[what] })
end

local NOUN = { [SK.UNITS] = "units", [SK.SUPPLY] = "supply", [SK.POWER] = "power" }
local ASKS = { [SK.ASK_UNITS] = "units", [SK.ASK_SUPPLY] = "supply", [SK.ASK_POWER] = "power" }

-- The line for a SHARE event: `nameOf(player)` gives a player's name; `me`
-- is the viewer (gifts to it read "you").
function Share.text(e: any, me: number, nameOf: (number) -> string): string
	local from = if e.player == me then "You" else nameOf(e.player)
	local ask = ASKS[e.shareKind]
	if ask then
		return `{from} {if e.player == me then "ask" else "asks"} for {ask}`
	end
	local to = if e.toPlayer == me then "you" else nameOf(e.toPlayer)
	local amount = if e.shareKind == SK.UNITS then `{e.amount} unit{if e.amount == 1 then "" else "s"}` else `{e.amount} {NOUN[e.shareKind]}`
	return `{from} gave {to} {amount}`
end

return table.freeze(Share)
