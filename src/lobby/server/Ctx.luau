--!strict
-- What the lobby server's modules share, filled in by Main: the services
-- (real or Studio stand-ins), the maps, and how to tell clients.

local MatchStore = require("./Services/MatchStore")
local ProfileStore = require("./Services/ProfileStore")
local Social = require("./Services/Social")
local Teleport = require("./Services/Teleport")
local Rooms = require("../shared/Rooms")

export type Ctx = {
	studio: boolean,
	store: MatchStore.Store,
	teleport: Teleport.Teleport,
	profiles: ProfileStore.Store,
	social: Social.Social,
	maps: { Rooms.MapInfo },
	-- something visible changed: resend views (all players, or one)
	publish: (user: number?) -> (),
	-- a short message for one player ("error" in red)
	toast: (user: number, text: string, kind: string?) -> (),
	-- a server-to-client event (the stand-in match screen)
	send: (user: number, msg: any) -> (),
}

local ctx: Ctx = {} :: any
return ctx
