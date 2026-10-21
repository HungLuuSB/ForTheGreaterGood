--!strict
-- Match rules state (data only; logic in Match.luau). Kept apart so Types
-- can describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local MatchState = {}

export type Mode = "FFA" | "TEAM"
export type WinCondition = "COMMAND_ENDS" | "ANNIHILATION"
export type AiLevel = "easy" | "normal" | "hard"

-- Match options (guide 16.1–16.4). Absent → no rules: nobody is ever
-- eliminated and there is no unit cap (tests and sandboxes).
export type Config = {
	mode: Mode,
	win: WinCondition,
	unitCap: number?, -- per player; default from the player count (Match.defaultCap)
	ai: { [number]: AiLevel }?, -- players the skirmish AI plays, and how well (S-17)
}

export type MatchState = {
	enabled: boolean,
	mode: Mode,
	win: WinCondition,
	unitCap: number, -- 0 = no cap
	ai: { [number]: AiLevel }, -- player → skirmish AI level (S-17); not in the replay: AI commands are recorded
	units: { [number]: number }, -- player → owned units and structures (frames included)
	commanders: { [number]: number }, -- player → owned COMMANDER units
	eliminated: { [number]: number }, -- player → tick eliminated
	over: boolean,
	winner: number, -- ally team that won; 0 while running or when nobody is left
	endTick: number,
}

function MatchState.new(config: Config?, unitCap: number): MatchState
	return {
		enabled = config ~= nil,
		mode = if config then config.mode else "FFA",
		win = if config then config.win else "COMMAND_ENDS",
		unitCap = if config then unitCap else 0,
		ai = if config and config.ai then table.clone(config.ai) else {},
		units = {},
		commanders = {},
		eliminated = {},
		over = false,
		winner = 0,
		endTick = 0,
	}
end

local WIN_CODE = { COMMAND_ENDS = 1, ANNIHILATION = 2 }

-- Hash over the players in `order` (ascending IDs).
function MatchState.hash(m: MatchState, order: { number }, h: number): number
	h = Hash.u32(h, if m.enabled then 1 else 0)
	h = Hash.u32(h, WIN_CODE[m.win])
	h = Hash.u32(h, m.unitCap)
	for _, pid in order do
		h = Hash.u32(h, pid)
		h = Hash.u32(h, m.units[pid] or 0)
		h = Hash.u32(h, m.commanders[pid] or 0)
		h = Hash.u32(h, m.eliminated[pid] or 0xFFFFFFFF)
	end
	h = Hash.u32(h, if m.over then 1 else 0)
	h = Hash.u32(h, m.winner)
	return Hash.u32(h, m.endTick)
end

return MatchState
