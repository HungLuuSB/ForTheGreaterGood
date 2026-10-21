--!strict
-- Per-player match statistics for the results screen (C-77), counted by
-- the Roblox server from the sim's state after each step (the sim doesn't
-- count them yet: client request 38). Pure Luau, no requires.
--   built    units finished during the match (structures included; the
--            starting units don't count)
--   lost     finished units that died (or were reclaimed)
--   gathered supply / power income credited, from the team's economy
--   spent    supply / power drawn by construction, after stall ratios
--   taken    health its units lost to damage (repairs don't count back), a
--            dying unit's remaining health included (and a reclaimed one's)
-- Accounts are per team; every lobby player has a team of their own.
-- Damage dealt and kills need the attacker, which only the sim knows
-- (request 38): `dealt` stays nil.

local MatchStats = {}

export type Player = {
	built: number,
	lost: number,
	supplyGathered: number,
	powerGathered: number,
	supplySpent: number,
	powerSpent: number,
	taken: number,
	dealt: number?,
}

export type Stats = {
	players: { [number]: Player },
	owner: { [number]: number }, -- unit id → owner, for finished units alive last step
	health: { [number]: number }, -- unit id → health last step
	unfinished: { [number]: boolean },
	spentSeen: { [number]: { supply: number, power: number } }, -- per team: the account's `spent` last step
}

local DT = 1 / 15

local function blank(): Player
	return { built = 0, lost = 0, supplyGathered = 0, powerGathered = 0, supplySpent = 0, powerSpent = 0, taken = 0, dealt = nil }
end

-- Starts counting at the sim's current state: the units standing now are
-- the starting units.
function MatchStats.new(sim: any): Stats
	local s: Stats = { players = {}, owner = {}, health = {}, unfinished = {}, spentSeen = {} }
	for _, pid in sim.playerOrder do
		s.players[pid] = blank()
	end
	local w = sim.world
	for _, id in w.ids do
		if w.buildProgress[id] >= 1 then
			s.owner[id] = w.owner[id]
		else
			s.unfinished[id] = true
		end
		s.health[id] = w.health[id]
	end
	for team, acc in sim.eco.accounts do
		s.spentSeen[team] = { supply = acc.supply.spent, power = acc.power.spent }
	end
	return s
end

local function teamOwner(sim: any): { [number]: number }
	local out = {}
	for _, pid in sim.playerOrder do
		out[sim.players[pid].team] = pid
	end
	return out
end

-- Counts one sim step.
function MatchStats.step(s: Stats, sim: any)
	local w = sim.world
	local alive: { [number]: boolean } = {}
	for _, id in w.ids do
		alive[id] = true
		local owner = w.owner[id]
		local p = s.players[owner]
		if p == nil then
			continue
		end
		local finished = w.buildProgress[id] >= 1
		if finished and s.owner[id] == nil then
			-- a new finished unit: built this match (a frame finishing, or a factory's unit)
			s.owner[id] = owner
			s.unfinished[id] = nil
			p.built += 1
		elseif not finished then
			s.unfinished[id] = true
		end
		local h, before = w.health[id], s.health[id]
		if before and h < before then
			p.taken += before - h
		end
		s.health[id] = h
	end
	for id, owner in s.owner do
		if not alive[id] then
			local p = s.players[owner]
			if p then
				p.lost += 1
				p.taken += s.health[id] or 0
			end
			s.owner[id] = nil
			s.health[id] = nil
		end
	end
	for id in s.unfinished do
		if not alive[id] then
			s.unfinished[id] = nil
			s.health[id] = nil
		end
	end
	local byTeam = teamOwner(sim)
	for team, acc in sim.eco.accounts do
		local p = s.players[byTeam[team]]
		local seen = s.spentSeen[team] or { supply = 0, power = 0 }
		if p then
			p.supplyGathered += acc.supply.income * DT
			p.powerGathered += acc.power.income * DT
			-- `spent` grows within an economy window and resets when it settles
			p.supplySpent += if acc.supply.spent >= seen.supply then acc.supply.spent - seen.supply else acc.supply.spent
			p.powerSpent += if acc.power.spent >= seen.power then acc.power.spent - seen.power else acc.power.spent
		end
		s.spentSeen[team] = { supply = acc.supply.spent, power = acc.power.spent }
	end
end

-- Per-player totals, rounded, for the results payload.
function MatchStats.summary(s: Stats): { [number]: Player }
	local out = {}
	for pid, p in s.players do
		out[pid] = {
			built = p.built,
			lost = p.lost,
			supplyGathered = math.floor(p.supplyGathered + 0.5),
			powerGathered = math.floor(p.powerGathered + 0.5),
			supplySpent = math.floor(p.supplySpent + 0.5),
			powerSpent = math.floor(p.powerSpent + 0.5),
			taken = math.floor(p.taken + 0.5),
			dealt = p.dealt,
		}
	end
	return out
end

return MatchStats
