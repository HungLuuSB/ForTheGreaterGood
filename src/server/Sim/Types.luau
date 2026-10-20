--!strict
-- Shared types for the server simulation. Types only: systems require this
-- instead of Sim.luau, which would be a require cycle.

local Defs = require("@shared/Defs/Defs")
local Prng = require("@shared/Util/Prng")
local Replay = require("./Replay")
local Schema = require("@shared/Net/Schema")
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
	players: { [number]: Player },
	playerOrder: { number }, -- player IDs, ascending
	queue: { QueuedCommand }, -- commands to apply on the next tick
	replay: Replay.Log,
	stats: { commandsApplied: number, commandsRejected: number },
}

return {}
