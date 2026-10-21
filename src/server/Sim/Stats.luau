--!strict
-- Match statistics per player (S-63, client request 38): the results
-- screen's units built and lost, resources gathered and spent, and damage
-- dealt. Server-side only (no wire format): the Roblox server reads
-- Stats.report at match end. Counted where things happen:
--   unitsBuilt    finished units, structures included (Build: PRODUCED,
--                 BUILD_DONE); the starting Command Vehicle doesn't count
--   unitsLost     own units that died (Damage)
--   unitsKilled   enemy units this player's damage finished (Damage)
--   damageDealt   health removed from enemy units, capped at what the target
--                 had left (Damage); a projectile keeps its shooter's player
--                 after the shooter dies (Combat.pPlayer)
-- Resources come from the player's team account (Economy: players sharing a
-- team share an account):
--   gathered      production, extraction, wind, reclaim and converter
--                 output credited per economy window (refunds included),
--                 before the storage cap
--   spent         drawn by construction, production, stockpiles, rearming
--                 and converters, after stall ratios; a window's
--                 forgiven shortfall isn't counted
-- Not hashed: it only reads the sim, and nothing in the sim reads it back.

local Stats = {}

export type PlayerStats = {
	unitsBuilt: number,
	unitsLost: number,
	unitsKilled: number,
	damageDealt: number,
}

export type Report = {
	unitsBuilt: number,
	unitsLost: number,
	unitsKilled: number,
	damageDealt: number,
	supplyGathered: number,
	powerGathered: number,
	supplySpent: number,
	powerSpent: number,
}

function Stats.new(playerIds: { number }): { [number]: PlayerStats }
	local out = {}
	for _, id in playerIds do
		out[id] = { unitsBuilt = 0, unitsLost = 0, unitsKilled = 0, damageDealt = 0 }
	end
	return out
end

-- Every player's statistics so far, with their team account's resources.
function Stats.report(sim: any): { [number]: Report }
	local out = {}
	for _, pid in sim.playerOrder do
		local s = sim.playerStats[pid]
		local acc = sim.eco.accounts[sim.players[pid].team]
		out[pid] = {
			unitsBuilt = s.unitsBuilt,
			unitsLost = s.unitsLost,
			unitsKilled = s.unitsKilled,
			damageDealt = s.damageDealt,
			supplyGathered = if acc then acc.supply.gathered else 0,
			powerGathered = if acc then acc.power.gathered else 0,
			supplySpent = if acc then acc.supply.drawn else 0,
			powerSpent = if acc then acc.power.drawn else 0,
		}
	end
	return out
end

return Stats
