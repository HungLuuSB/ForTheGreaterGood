--!strict
-- Shared types for the server simulation. Types only: systems require this
-- instead of Sim.luau, which would be a require cycle.

local BuildState = require("./BuildState")
local Combat = require("./Combat/Combat")
local Defs = require("@shared/Defs/Defs")
local Economy = require("./Economy")
local Nav = require("./Nav")
local NetState = require("./NetState")
local Passability = require("@shared/Grid/Passability")
local Prng = require("@shared/Util/Prng")
local Replay = require("./Replay")
local Schema = require("@shared/Net/Schema")
local SensorsState = require("./SensorsState")
local World = require("./World")

export type Player = { id: number, team: number }

export type QueuedCommand = {
	player: number,
	payload: buffer, -- as received; recorded into the replay when applied
	cmd: Schema.Command,
}

export type Sim = {
	tick: number, -- last completed tick (0 before the first step)
	seed: number,
	mapId: string,
	scenario: string,
	world: World.World,
	rng: Prng.Prng, -- the only randomness the sim may use
	defs: Defs.DefSet,
	map: Passability.PassMap?, -- nil for mapId "none"
	nav: Nav.Nav?, -- movement state; nil without a map
	combat: Combat.Combat, -- projectiles, damage queue, wrecks, this tick's events
	eco: Economy.Economy, -- team accounts
	build: BuildState.BuildState, -- construction orders, factory queues, reclaim
	sensors: SensorsState.State, -- sensor maps, visibility, ghosts
	net: NetState.NetState, -- per-player replication (not hashed)
	players: { [number]: Player },
	playerOrder: { number }, -- player IDs, ascending
	queue: { QueuedCommand }, -- commands to apply on the next tick
	replay: Replay.Log,
	stats: { commandsApplied: number, commandsRejected: number },
}

return {}
