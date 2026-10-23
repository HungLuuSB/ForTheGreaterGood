--!strict
-- Point defence (S-149, the user): interceptor units that shoot down enemy
-- missiles and rockets flying near them, never units, one interceptor per
-- missile; a stock that a salvo can empty.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, err = Sim.submit(sim, player, w:finish())
	assert(ok, err)
end

-- Enemy artillery `shooterDef` (player 2) shells a tank of player 1 at the
-- origin for `ticks`; `defender` (player 1, beside the tank) may stand by.
-- Returns enemy shots fired at it, shots intercepted, the defender's
-- interceptor launches, and whether the defender ever took a unit.
local function barrage(shooterDef: string, defender: string?, ticks: number): (number, number, number, boolean)
	local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:160" })
	local w = sim.world
	local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
	World.setHealth(w, tank, 1e7)
	World.setFireState(w, tank, World.FireState.HOLD_FIRE)
	local shooter = Spawn.unit(sim, shooterDef, 2, 380, 0, -math.pi / 2)
	-- a spotter of the attacker's, near the tank, out of the fight
	local spotter = Spawn.unit(sim, "chs_jackal", 2, 90, -60)
	World.setHealth(w, spotter, 1e7)
	World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
	local d = 0
	if defender then
		d = Spawn.unit(sim, defender, 1, -30, 30)
		World.setHealth(w, d, 1e7)
	end
	submit(sim, 2, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = { shooter }, targetId = tank })
	local fired, intercepted, launches, tookUnit = 0, 0, 0, false
	local enemy: { [number]: boolean } = {}
	for _ = 1, ticks do
		sim.eco.accounts[1].supply.stored = 1000
		sim.eco.accounts[1].power.stored = 1000
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "SPAWN_PROJ" and e.unit == shooter then
				fired += 1
				enemy[e.other] = true
			elseif e.kind == "SPAWN_PROJ" and e.unit == d and d ~= 0 then
				launches += 1
			elseif e.kind == "INTERCEPTED" and enemy[e.other] then
				intercepted += 1
			end
		end
		if d ~= 0 then
			for slot = 1, 8 do
				local key = World.slotKey(d, slot)
				if (w.wTarget[key] or 0) ~= 0 then
					tookUnit = true
				end
			end
		end
	end
	return fired, intercepted, launches, tookUnit
end

return function(t: RunAll.Context)
	t.test("a Sanctum shoots down MLRS rockets aimed beside it; never a unit (S-149)", function()
		local fired0, intercepted0 = barrage("chs_hydra", nil, 450)
		t.expect(fired0 >= 8, `the MLRS fired ({fired0} rockets)`)
		t.equal(intercepted0, 0, "nothing intercepts without point defence")
		local fired, intercepted, launches, tookUnit = barrage("chs_hydra", "ord_sanctum", 450)
		-- an MLRS outfires the stock (4 rockets every 7 s): saturation, as intended
		t.expect(intercepted >= fired * 0.25, `a good share of the rockets shot down ({intercepted} of {fired})`)
		t.expect(intercepted >= launches * 0.55, `most interceptors hit ({intercepted} of {launches})`)
		t.expect(launches <= fired + 2, `one interceptor per rocket at most ({launches} for {fired})`)
		t.expect(not tookUnit, "it never targets a unit")
		print(string.format("    Sanctum vs MLRS: %d of %d rockets shot down with %d interceptors", intercepted, fired, launches))
	end)

	t.test("point defence stops guided missiles too: a Basilisk against a Sanction battery (S-149)", function()
		local fired, intercepted, launches = barrage("ord_sanction", "chs_basilisk", 600)
		t.expect(fired >= 2, `the battery fired ({fired} missiles)`)
		t.expect(intercepted >= 1, `missiles shot down ({intercepted} of {fired}, {launches} interceptors)`)
		print(string.format("    Basilisk vs Sanction: %d of %d missiles shot down with %d interceptors", intercepted, fired, launches))
	end)

	t.test("the mobile ones work on the move; anti-nukes still take only nukes (S-149)", function()
		local fired, intercepted = barrage("chs_hydra", "ord_shepherd", 450)
		t.expect(intercepted >= 1, `a Shepherd shoots rockets down ({intercepted} of {fired})`)
		local fired2, intercepted2 = barrage("chs_hydra", "ord_providence", 450)
		t.equal(intercepted2, 0, `an anti-nuke ignores rockets ({fired2} fired)`)
	end)
end
