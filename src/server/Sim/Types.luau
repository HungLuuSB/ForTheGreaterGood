--!strict
-- Shared types for the server simulation. Types only: systems require this
-- instead of Sim.luau, which would be a require cycle.

local AirState = require("./AirState")
local OrdersState = require("./OrdersState")
local EWState = require("./EWState")
local MatchState = require("./MatchState")
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
local Stats = require("./Stats")
local World = require("./World")

-- team: economy and ownership (one account per team); allyTeam: shared
-- sight, no friendly targeting, overflow sharing (guide 16.1). Default
-- allyTeam = team.
export type Player = { id: number, team: number, allyTeam: number? }

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
	air: AirState.AirState, -- aircraft ammo and rearming
	orders: OrdersState.OrdersState, -- unit order queues, factory rally / repeat (S-4)
	ew: EWState.EWState, -- countermeasure charges and cooldowns
	match: MatchState.MatchState, -- match rules: counts, eliminations, result
	sensors: SensorsState.State, -- sensor maps, visibility, ghosts
	net: NetState.NetState, -- per-player replication (not hashed)
	players: { [number]: Player },
	playerOrder: { number }, -- player IDs, ascending
	allyOf: { [number]: number }, -- team → ally team
	allyTeams: { number }, -- ascending
	queue: { QueuedCommand }, -- commands to apply on the next tick
	replay: Replay.Log,
	stats: { commandsApplied: number, commandsRejected: number },
	playerStats: { [number]: Stats.PlayerStats }, -- the results screen's numbers (S-63); not hashed
}

return {}
