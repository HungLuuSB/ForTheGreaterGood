--!strict
-- System 9: Damage & Lifecycle (guide 10.6).
--
-- Applies this tick's queued damage in queue order (damage already includes
-- the armor-class lookup and AoE falloff), remembers the attacker (for
-- Return Fire), then removes the dead in the order they died. Severity =
-- overkill as a fraction of max health (0..1 → u8 in the DEATH event); a
-- unit killed with severity <= 0.5 leaves a wreck worth half its supply,
-- except aircraft shot down in flight (they crash and burn) and frames
-- still under construction (S-87: they leave nothing and set off no death
-- blast; they only become the real thing when complete).

local Alerts = require("../Alerts")
local Combat = require("../Combat/Combat")
local Deploy = require("../Deploy")
local Lifecycle = require("../Lifecycle")
local SelfDestruct = require("../SelfDestruct")
local Types = require("../Types")
local World = require("../World")

local dead: { number } = {}

-- A def's death blast as the weapon table Combat.explode reads (S-70).
-- A self-destruct's (S-194) is bigger: SelfDestruct.blastScale.
local blastWeapon: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local selfBlastWeapon: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
-- A def's own `selfDestructBlast` replaces the scaled one (S-209, the
-- Juggernaut: almost a nuke); `deathBlast.onlyDefs` limits who it hurts (the
-- nano turrets hurt only nanos).
local function blastOf(sim: Types.Sim, def: any, selfDestructed: boolean?): any
	local cache = if selfDestructed then selfBlastWeapon else blastWeapon
	local b = cache[def]
	if b == nil then
		local d = def.deathBlast
		local own = if selfDestructed then def.selfDestructBlast else nil
		local k = if selfDestructed and own == nil then SelfDestruct.blastScale(def) else 1
		local damage = (if own then own.damage else d.damage) * k
		local only = nil
		if d.onlyDefs then
			only = {}
			for _, id in d.onlyDefs do
				local u = sim.defs.units[id]
				if u then
					only[u.index] = true
				end
			end
		end
		b = {
			damage = { LIGHT = damage, ARMORED = damage, STRUCTURE = damage, SHIP = damage, AIR = 0, SUB = 0 },
			aoe = (if own then own.aoe else d.aoe) * k,
			edgeEffectiveness = if own then own.edge else d.edge,
			onlyDefs = only,
		}
		cache[def] = b
	end
	return b
end

-- Is an upgrade frame being built on `id` (an extractor turning advanced)?
local function upgradedFrom(sim: Types.Sim, id: number): boolean
	for _, replaced in sim.build.upgrading do
		if replaced == id then
			return true
		end
	end
	return false
end

return function(sim: Types.Sim)
	local c = sim.combat
	SelfDestruct.step(sim) -- (S-194) countdowns that ran out: their units die now
	local count = c.dmgCount
	if count == 0 then
		return
	end
	table.clear(c.queued)
	local w = sim.world
	local cheats = sim.cheats
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
		if cheats.god[w.owner[t]] and not cheats.killing[t] then
			continue -- god mode (S-102)
		end
		local amount = c.dmgAmount[i]
		if w.deploy[t] == 1 then
			amount /= Deploy.armor(sim, t) -- a deployed Warden's fortification (S-64)
		elseif Combat.retracted(sim, t) then
			amount /= sim.defs.unitByIndex[w.defIndex[t]].retract.armor -- retracted into its shell (S-96)
		end
		local after = before - amount
		World.setHealth(w, t, after)
		-- the results screen (S-63): enemy health removed, and who finished it
		local player = c.dmgPlayer[i]
		if player == 0 and c.dmgAttacker[i] ~= 0 and w.slot[c.dmgAttacker[i]] then
			player = w.owner[c.dmgAttacker[i]] -- queued without a player: its attacker's
		end
		local ps = sim.playerStats[player]
		local enemy = ps ~= nil and w.ally[t] ~= sim.players[player].allyTeam
		if enemy and ps then
			ps.damageDealt += math.min(amount, before)
			Alerts.attacked(sim, t) -- the owner's ALERT, the UNDER_ATTACK flag (S-68)
			local taken = sim.playerStats[w.owner[t]] -- damage taken (S-88, client request 41)
			if taken then
				taken.damageTaken += math.min(amount, before)
			end
		end
		local attacker = c.dmgAttacker[i]
		if attacker ~= t and attacker ~= 0 then -- (a death blast has no attacker: it doesn't wipe who shot it, S-185)
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
	if next(cheats.killing) ~= nil then
		table.clear(cheats.killing)
	end

	for i = 1, nDead do
		local id = dead[i]
		dead[i] = nil
		local def = sim.defs.unitByIndex[w.defIndex[id]]
		local lost = sim.playerStats[w.owner[id]]
		if lost then
			lost.unitsLost += 1
		end
		Alerts.lost(sim, id)
		local severity = math.clamp(-w.health[id] / def.health, 0, 1)
		local wreck = 0
		-- aircraft shot down in flight crash and burn: no wreck (client
		-- request 19); a landed one may leave one
		local airborne = def.domain == "air" and bit32.band(w.state[id], World.State.LANDED) == 0
		local frame = w.buildProgress[id] < 1
		local selfDestructed = c.selfDestructed[id] == true
		-- (S-194) no wreck from a self-destruct or a D-Gun bolt
		if severity <= Combat.WRECK_MAX_SEVERITY and not airborne and not frame and not selfDestructed and not c.noWreck[id] then
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
		local quiet = sim.match.quiet[id]
		sim.match.quiet[id] = nil
		local noBlast = selfDestructed and def.deathBlast ~= nil and def.deathBlast.notSelfDestruct == true -- (S-209: a self-destructed nano hurts nobody)
		if def.deathBlast and not frame and not quiet and not noBlast and not upgradedFrom(sim, id) then
			-- its death blast (guide 8.5, S-70; every unit since S-178): every
			-- unit in reach, own and allied included (team 0 is nobody's);
			-- applied next tick, so blasts can set each other off. Not for a
			-- self-destruct (S-144) or a structure an upgrade frame stands on
			local x, z = w.posX[id], w.posZ[id]
			Combat.explode(c, w, x, Combat.groundHeight(c, x, z) + 4, z, blastOf(sim, def, selfDestructed), 0, 0, 0, w.owner[id])
			Combat.addEvent(c, { kind = "BLAST", tick = sim.tick, unit = id, other = 0, x = x, z = z })
		end
		Lifecycle.remove(sim, id)
	end
	table.clear(c.noWreck)
end
