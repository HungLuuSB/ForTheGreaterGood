--!strict
-- FTGG-FEEDBACK-4 (the user's 8v8 on Supreme Strait): the torpedo crash in
-- shallow water, the Titan's one missile against ground and air, the
-- Overwatch's and the Steadfast's shorter reach.
local Categories = require("@shared/Defs/Categories")
local Combat = require("../Sim/Combat/Combat")
local Schema = require("@shared/Net/Schema")
local Skirmish = require("../Sim/AI/Skirmish")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.T)
	t.test("a torpedo in water under a stud deep runs on instead of ending the match (error 210)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "map:supreme_strait" })
		local c = sim.combat
		local g = (sim.map :: any).grid
		-- the first water under a stud deep (the strait's shallows)
		local x0, z0, depth = nil, 0, 0
		for z = g.originZ + 8, g.originZ + g.sizeZ - 8, 8 do
			for x = g.originX + 8, g.originX + g.sizeX - 8, 2 do
				local d = Combat.waterDepth(c, x, z)
				if d > 0 and d < 1 then
					x0, z0, depth = x, z, d
					break
				end
			end
			if x0 then
				break
			end
		end
		assert(x0, "Supreme Strait has water under a stud deep")
		t.expect(depth < 1, `shallows at ({x0}, {z0}): {depth} deep`)
		local weapon = sim.defs.weapons.ord_torpedo
		local p = Combat.spawnProjectile(c, x0 :: number, Combat.surfaceHeight(c, x0 :: number, z0), z0, 0.5, 0, 0, weapon.index, 0, 1, 10, 0, sim.world) :: number
		for _ = 1, 5 do
			Sim.step(sim) -- errored with math.clamp's "max must be greater than or equal to min"
		end
		t.expect(c.projSlot[p] == nil or c.py[p] <= Combat.surfaceHeight(c, c.px[p], c.pz[p]), "it stays under the surface")
	end)

	t.test("the Titan fires one small missile a volley, at ground and air, never at a submarine", function()
		local defs = Sim.new({ seed = 1, players = PLAYERS }).defs
		local m = defs.weapons.ord_titan_missiles
		t.expect(m.salvo == nil or (m.salvo :: any).count == 1, "one missile a volley")
		t.expect(table.find(m.targets, "AIR") ~= nil, "it targets aircraft")
		t.expect(m.damage.AIR > 0, "and hurts them")
		t.expect(table.find(m.targets, "SUB") == nil and m.damage.SUB == 0, "no submarines")

		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		sim.autoheal.off = true
		local titan = Spawn.unit(sim, "ord_titan", 1, 0, 0)
		local plane = Spawn.unit(sim, "chs_buzzard", 2, 0, 200)
		World.setFireState(w, plane, World.FireState.HOLD_FIRE)
		local hp = w.health[plane]
		for _ = 1, 15 * 20 do
			Sim.step(sim)
			if w.slot[plane] == nil or w.health[plane] < hp then
				break
			end
		end
		t.expect(w.slot[plane] == nil or w.health[plane] < hp, "the Titan's missile hit the aircraft")
	end)

	-- (Overwatch and Steadfast's 25% cut was reverted to 10%: Feedback5.spec, S-236)
	t.test("in an 8v8 on Supreme Strait every AI factory faces the enemy side, airfields and gantries too", function()
		local players, ai = {}, {}
		for i = 1, 16 do
			table.insert(players, { id = i, team = i, allyTeam = if i <= 8 then 1 else 2 })
			ai[i] = "normal"
		end
		local sim = Sim.new({ seed = 1, players = players, mapId = "map:supreme_strait", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", ai = ai } })
		local w = sim.world
		local cx, cz, n = { 0, 0 }, { 0, 0 }, { 0, 0 }
		local home = {}
		for _, id in w.ids do
			if bit32.band(sim.defs.unitByIndex[w.defIndex[id]].categoryMask, Categories.Bit.COMMANDER) ~= 0 then
				local side = sim.players[w.owner[id]].allyTeam :: number
				cx[side] += w.posX[id]
				cz[side] += w.posZ[id]
				n[side] += 1
				home[w.owner[id]] = { w.posX[id], w.posZ[id] }
			end
		end
		local vec = { [Schema.Facing.NORTH] = { 0, 1 }, [Schema.Facing.EAST] = { 1, 0 }, [Schema.Facing.SOUTH] = { 0, -1 }, [Schema.Facing.WEST] = { -1, 0 } }
		local wrong = {}
		for p = 1, 16 do
			assert(home[p], `player {p} has a commander`)
			local enemy = if p <= 8 then 2 else 1
			local ex, ez = cx[enemy] / n[enemy] - home[p][1], cz[enemy] / n[enemy] - home[p][2]
			local brain = Skirmish.new(sim, p)
			local face = Skirmish.enemyFacing(brain)
			local f = vec[face]
			if f[1] * ex + f[2] * ez <= 0 then
				table.insert(wrong, p)
			end
			-- every land factory the AI builds takes that facing, whatever
			-- the call passed (airfields, gantries and the job list's plants
			-- were built facing north: away from the enemy for team 1)
			local pre = sim.players[p].faction == "order" and "ord_" or "chs_"
			for _, kind in { "vehplant", "botlab", "airfield", "advvehplant", "advbotlab", "advairfield", "gantry" } do
				local d = sim.defs.units[pre .. kind]
				if d then
					t.equal(Skirmish.factoryFacing(brain, d, home[p][1], home[p][2], Schema.Facing.NORTH), face, `player {p}'s {d.id}`)
				end
			end
			t.equal(Skirmish.factoryFacing(brain, sim.defs.units[pre .. "solar"], home[p][1], home[p][2], Schema.Facing.NORTH), Schema.Facing.NORTH, "not a factory: as passed")
			-- a shipyard faces out to sea, away from home
			local yard = sim.defs.units[pre .. "shipyard"]
			t.equal(Skirmish.factoryFacing(brain, yard, home[p][1] + 300, home[p][2] + 10, Schema.Facing.NORTH), Schema.Facing.EAST, `player {p}'s shipyard east of home faces east`)
		end
		t.deepEqual(wrong, {}, "players whose factories would face away from the enemy side")
	end)
end

