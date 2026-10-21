--!strict
-- Aircraft state (data only; logic in Air.luau). Kept apart so Types can
-- describe it without a require cycle.

local Hash = require("@shared/Util/Hash")

local AirState = {}

-- "fly": normal; "return": flying to a rearm pad (empty, or recovered to its
-- home); "rearm": landed on a pad, rearming; "docked": landed on its home
-- pad, full, held there until given an order (carriers, S-36).
export type Phase = "fly" | "return" | "rearm" | "docked"

export type AirState = {
	ammo: { [number]: number }, -- rounds left (aircraft with a def ammo count)
	phase: { [number]: Phase },
	pad: { [number]: number }, -- rearm pad in use or targeted (0 = none)
	padGen: { [number]: number }, -- its generation (D109)
	progress: { [number]: number }, -- rearm progress toward the next round, 0..1
	resumeX: { [number]: number }, -- where to go back to after rearming
	resumeZ: { [number]: number },
	-- countermeasure restock during a rearm, spread evenly over its rounds
	cmPerRound: { [number]: number }, -- charges restocked per round
	cmSupplyPerRound: { [number]: number }, -- their supply cost per round
	cmProgress: { [number]: number }, -- toward the next charge, 0..1
	-- bombers (D91): "in" = lining up on the target, "out" = flying away to
	-- set up the next run; egress keeps the heading straight after a release
	run: { [number]: "in" | "out" },
	egressUntil: { [number]: number }, -- tick
	-- attack-ground order (bombers, D100): bomb this spot until another order
	groundX: { [number]: number },
	groundZ: { [number]: number },
	-- home base (S-36): a carrier or airfield; empty aircraft go there
	-- first, and a recovered aircraft stays docked there
	home: { [number]: number },
	homeGen: { [number]: number },
	hold: { [number]: boolean }, -- stay docked on the home pad once full
}

function AirState.new(): AirState
	return {
		ammo = {},
		phase = {},
		pad = {},
		padGen = {},
		progress = {},
		resumeX = {},
		resumeZ = {},
		cmPerRound = {},
		cmSupplyPerRound = {},
		cmProgress = {},
		run = {},
		egressUntil = {},
		groundX = {},
		groundZ = {},
		home = {},
		homeGen = {},
		hold = {},
	}
end

function AirState.clearUnit(a: AirState, id: number)
	a.ammo[id] = nil
	a.phase[id] = nil
	a.pad[id] = nil
	a.padGen[id] = nil
	a.progress[id] = nil
	a.resumeX[id] = nil
	a.resumeZ[id] = nil
	a.cmPerRound[id] = nil
	a.cmSupplyPerRound[id] = nil
	a.cmProgress[id] = nil
	a.run[id] = nil
	a.egressUntil[id] = nil
	a.groundX[id] = nil
	a.groundZ[id] = nil
	a.home[id] = nil
	a.homeGen[id] = nil
	a.hold[id] = nil
end

local PHASE_CODE = { fly = 1, ["return"] = 2, rearm = 3, docked = 4 }

-- Hash over units in `ids` (ascending).
function AirState.hash(a: AirState, ids: { number }, h: number): number
	for _, id in ids do
		local phase = a.phase[id]
		if phase then
			h = Hash.u32(Hash.u32(h, id), PHASE_CODE[phase])
			h = Hash.u32(h, a.ammo[id] or 0)
			h = Hash.u32(Hash.u32(h, a.pad[id] or 0), a.padGen[id] or 0)
			h = Hash.number(h, a.progress[id] or 0)
			h = Hash.number(h, a.cmPerRound[id] or 0)
			h = Hash.number(h, a.cmSupplyPerRound[id] or 0)
			h = Hash.number(h, a.cmProgress[id] or 0)
			h = Hash.u32(h, if a.run[id] == "out" then 2 elseif a.run[id] == "in" then 1 else 0)
			h = Hash.u32(h, a.egressUntil[id] or 0)
			h = Hash.number(Hash.number(h, a.groundX[id] or 0), a.groundZ[id] or 0)
			h = Hash.u32(Hash.u32(h, a.home[id] or 0), a.homeGen[id] or 0)
			h = Hash.u32(h, if a.hold[id] then 1 else 0)
		end
	end
	return h
end

return AirState
