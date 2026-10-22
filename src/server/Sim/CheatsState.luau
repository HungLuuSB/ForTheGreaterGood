--!strict
-- Cheat / test command state (S-102; data only, logic in Cheats.luau). Kept
-- apart so Types can describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local CheatsState = {}

export type Result = { op: number, result: number, count: number, total: number }

export type State = {
	enabled: boolean, -- the match allows cheats (match option `cheats`)
	offline: boolean, -- offline / Studio: SPEED is allowed (Sim config `offline`)
	used: boolean, -- a cheat was applied in this match (flags results and the replay)
	usedBy: { [number]: number }, -- player → cheats applied (Stats.report)
	instabuild: boolean, -- builds and factory output finish at once, free
	god: { [number]: boolean }, -- player → their units take no damage
	revealed: { [number]: boolean }, -- ally team → full sight
	aiPaused: { [number]: boolean }, -- player → the skirmish AI skips its turns
	killing: { [number]: boolean }, -- units a KILL queued this tick (they die through god mode)
	speed: number, -- requested sim speed (offline only); the tick driver reads it, the sim doesn't
	results: { [number]: { Result } }, -- player → this tick's answers (NetOut sends them)
}

function CheatsState.new(enabled: boolean, offline: boolean): State
	return {
		enabled = enabled,
		offline = offline,
		used = false,
		usedBy = {},
		instabuild = false,
		god = {},
		revealed = {},
		aiPaused = {},
		killing = {},
		speed = 1,
		results = {},
	}
end

-- Hash over the players in `order` and the ally teams in `allyTeams`
-- (ascending). Speed and results aren't hashed: nothing in the sim reads them.
function CheatsState.hash(s: State, order: { number }, allyTeams: { number }, h: number): number
	h = Hash.u32(h, (if s.enabled then 1 else 0) + (if s.used then 2 else 0) + (if s.instabuild then 4 else 0))
	for _, pid in order do
		h = Hash.u32(h, (if s.god[pid] then 1 else 0) + (if s.aiPaused[pid] then 2 else 0))
	end
	for _, ally in allyTeams do
		h = Hash.u32(h, if s.revealed[ally] then 1 else 0)
	end
	return h
end

return CheatsState
