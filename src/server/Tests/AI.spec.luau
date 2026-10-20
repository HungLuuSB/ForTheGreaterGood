--!strict
-- Skirmish AI behaviors (S-7): radar, fire-control radar, kiting artillery,
-- anti-air against aircraft. Full matches are in Skirmish.spec.
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function start(seed: number): Sim.Sim
	return Sim.new({
		seed = seed,
		players = PLAYERS,
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
end

-- Steps with only `brains` thinking; `rich` keeps their accounts full.
local function run(sim: Sim.Sim, brains: { Skirmish.Brain }, ticks: number, rich: boolean, stop: (() -> boolean)?)
	for _ = 1, ticks do
		if rich then
			for _, b in brains do
				local acc = sim.eco.accounts[b.team]
				acc.supply.stored = acc.supply.storage
				acc.power.stored = acc.power.storage
			end
		end
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if stop and stop() then
			return
		end
	end
end

local function owned(sim: Sim.Sim, player: number, defId: string): { number }
	local w = sim.world
	local out = {}
	for _, id in w.ids do
		if w.owner[id] == player and sim.defs.unitByIndex[w.defIndex[id]].id == defId then
			table.insert(out, id)
		end
	end
	return out
end

return function(t: RunAll.Context)
	t.test("the AI builds a radar tower early", function()
		local sim = start(21)
		local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
		run(sim, brains, 5400, false, function()
			return #owned(sim, 1, "ord_watchtower") > 0 and #owned(sim, 2, "chs_eye") > 0
		end)
		t.expect(#owned(sim, 1, "ord_watchtower") > 0, "Order built a Watchtower")
		t.expect(#owned(sim, 2, "chs_eye") > 0, "Chaos built an Eye")
		print(string.format("    radar towers by tick %d (%.1f min)", sim.tick, sim.tick / 900))
	end)

	t.test("with supply to spare the AI techs up to a fire-control radar escorting its waves", function()
		local sim = start(22)
		local brain = Skirmish.new(sim, 1)
		run(sim, { brain }, 9000, true, function()
			return #owned(sim, 1, "ord_arbiter") > 0
		end)
		local arbiters = owned(sim, 1, "ord_arbiter")
		t.expect(#owned(sim, 1, "ord_advvehplant") > 0, "built an Advanced Vehicle Plant")
		t.expect(#arbiters > 0, `and an Arbiter (tick {sim.tick})`)
		print(string.format("    Arbiter by tick %d (%.1f min)", sim.tick, sim.tick / 900))
	end)

	t.test("the AI answers known enemy aircraft with IR SAM trucks and a SAM site", function()
		local sim = start(23)
		local brain = Skirmish.new(sim, 1)
		local w = sim.world
		run(sim, { brain }, 1800, true) -- a plant and workers first
		-- Chaos helicopters hover over Order's base, holding fire
		for i = 1, 4 do
			local heli = Spawn.unit(sim, "chs_wasp", 2, brain.homeX + (i - 2) * 30, brain.homeZ - 80)
			World.setFireState(w, heli, World.FireState.HOLD_FIRE)
			World.setHealth(w, heli, 1e6)
		end
		run(sim, { brain }, 2700, true, function()
			return #owned(sim, 1, "ord_halo") >= 2 and #owned(sim, 1, "ord_vigil") > 0
		end)
		t.expect(#owned(sim, 1, "ord_halo") >= 2, `IR SAM trucks ({#owned(sim, 1, "ord_halo")})`)
		t.expect(#owned(sim, 1, "ord_vigil") > 0, "an IR SAM site at home")
	end)

	-- An AI Verdict howitzer with a Chaos tank closing in: it backs off; a
	-- Lancer in the same spot doesn't.
	local function closing(defId: string): (number, boolean)
		local sim = start(24)
		local brain = Skirmish.new(sim, 1)
		local w = sim.world
		local x, z = brain.homeX + brain.toward * 200, brain.homeZ + 150
		local gun = Spawn.unit(sim, defId, 1, x, z)
		World.setFireState(w, gun, World.FireState.HOLD_FIRE)
		local tank = Spawn.unit(sim, "chs_ravager", 2, x + brain.toward * 120, z)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local spotter = Spawn.unit(sim, "ord_herald", 1, x + brain.toward * 100, z + 40)
		World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
		run(sim, { brain }, 4, false)
		t.equal(Sensors.level(sim, 1, tank), Sensors.Level.VISIBLE, "the tank is seen")
		local d0 = math.sqrt((w.posX[gun] - w.posX[tank]) ^ 2 + (w.posZ[gun] - w.posZ[tank]) ^ 2)
		local kited = false
		run(sim, { brain }, 90, false, function()
			kited = kited or brain.kiting[gun] ~= nil
			return false
		end)
		return math.sqrt((w.posX[gun] - w.posX[tank]) ^ 2 + (w.posZ[gun] - w.posZ[tank]) ^ 2) - d0, kited
	end

	t.test("AI artillery kites away from a close enemy; tanks don't", function()
		local gained, kited = closing("ord_verdict")
		t.expect(kited, "the Verdict backed off")
		t.expect(gained > 40, `and opened the distance by {gained} studs`)
		local _, tankKited = closing("ord_lancer")
		t.expect(not tankKited, "a Lancer never kites (it moves only with the army)")
	end)
end
