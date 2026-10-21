--!strict
-- System 9: Damage & Lifecycle (guide 10.6).
--
-- Applies this tick's queued damage in queue order (damage already includes
-- the armor-class lookup and AoE falloff), remembers the attacker (for
-- Return Fire), then removes the dead in the order they died. Severity =
-- overkill as a fraction of max health (0..1 → u8 in the DEATH event); a
-- unit killed with severity <= 0.5 leaves a wreck worth half its supply.

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
		local attacker = c.dmgAttacker[i]
		if attacker ~= t then
			w.lastAttacker[t] = attacker
			w.lastAttackerGen[t] = if attacker ~= 0 then w.gen[attacker] or 0 else 0 -- D109
		end
		if after <= 0 then
			nDead += 1
			dead[nDead] = t
		end
	end
	c.dmgCount = 0

	for i = 1, nDead do
		local id = dead[i]
		dead[i] = nil
		local def = sim.defs.unitByIndex[w.defIndex[id]]
		local severity = math.clamp(-w.health[id] / def.health, 0, 1)
		local wreck = 0
		if severity <= Combat.WRECK_MAX_SEVERITY then
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
