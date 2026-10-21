--!strict
-- System 9: Damage & Lifecycle (guide 10.6).
--
-- Applies this tick's queued damage in queue order (damage already includes
-- the armor-class lookup and AoE falloff), remembers the attacker (for
-- Return Fire), then removes the dead in the order they died. Severity =
-- overkill as a fraction of max health (0..1 → u8 in the DEATH event); a
-- unit killed with severity <= 0.5 leaves a wreck worth half its supply,
-- except aircraft shot down in flight (they crash and burn).

local Combat = require("../Combat/Combat")
local Lifecycle = require("../Lifecycle")
local Types = require("../Types")
local World = require("../World")

local dead: { number } = {}

return function(sim: Types.Sim)
	local c = sim.combat
	local count = c.dmgCount
	if count == 0 then
		return
	end
	table.clear(c.queued)
	local w = sim.world
	local nDead = 0
	for i = 1, count do
		local t = c.dmgTarget[i]
		if w.slot[t] == nil then
			continue -- died earlier this tick or already gone
		end
		local before = w.health[t]
		if before <= 0 then
			continue -- already dying this tick
		end
		local after = before - c.dmgAmount[i]
		World.setHealth(w, t, after)
		-- the results screen (S-63): enemy health removed, and who finished it
		local player = c.dmgPlayer[i]
		local ps = sim.playerStats[player]
		local enemy = ps ~= nil and w.ally[t] ~= sim.players[player].allyTeam
		if enemy and ps then
			ps.damageDealt += math.min(c.dmgAmount[i], before)
		end
		local attacker = c.dmgAttacker[i]
		if attacker ~= t then
			w.lastAttacker[t] = attacker
			w.lastAttackerGen[t] = if attacker ~= 0 then w.gen[attacker] or 0 else 0 -- D109
		end
		if after <= 0 then
			nDead += 1
			dead[nDead] = t
			if enemy and ps then
				ps.unitsKilled += 1
			end
		end
	end
	c.dmgCount = 0

	for i = 1, nDead do
		local id = dead[i]
		dead[i] = nil
		local def = sim.defs.unitByIndex[w.defIndex[id]]
		local lost = sim.playerStats[w.owner[id]]
		if lost then
			lost.unitsLost += 1
		end
		local severity = math.clamp(-w.health[id] / def.health, 0, 1)
		local wreck = 0
		-- aircraft shot down in flight crash and burn: no wreck (client
		-- request 19); a landed one may leave one
		local airborne = def.domain == "air" and bit32.band(w.state[id], World.State.LANDED) == 0
		if severity <= Combat.WRECK_MAX_SEVERITY and not airborne then
			wreck = Combat.addWreck(c, w.posX[id], w.posZ[id], def, w.heading[id])
		end
		Combat.addEvent(c, {
			kind = "DEATH",
			tick = sim.tick,
			unit = id,
			other = wreck,
			severity = math.floor(severity * 255 + 0.5),
			x = w.posX[id],
			z = w.posZ[id],
		})
		c.stats.kills += 1
		Lifecycle.remove(sim, id)
	end
end
