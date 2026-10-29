--!strict
-- Aircraft put the player's orders first (S-204, the user's playtest 3 H12,
-- H13): a jet sent home flies home instead of chasing what its weapon picked,
-- and a bomber given an attack order bombs that target, not the nearest one.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: any)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	submit(sim, player, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

local function dist(w: World.World, id: number, x: number, z: number): number
	return math.sqrt((w.posX[id] - x) ^ 2 + (w.posZ[id] - z) ^ 2)
end

return function(t: RunAll.Context)
	t.test("a fighter sent home flies home, though its missiles have a plane to chase (H12)", function()
		local sim = Sim.new({ seed = 7, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local falcon = Spawn.unit(sim, "ord_falcon", 1, 0, 0, math.pi / 2)
		local harpy = Spawn.unit(sim, "chs_harpy", 2, 250, 0, -math.pi / 2)
		moveTo(sim, 2, { harpy }, 250, 0) -- the enemy plane circles where it is
		sim.ew.flares[harpy] = 0
		for _ = 1, 45 do
			Sim.step(sim)
		end
		local home = { x = -700, z = 0 }
		moveTo(sim, 1, { falcon }, home.x, home.z)
		local start = dist(w, falcon, home.x, home.z)
		for _ = 1, 150 do -- 10 s
			Sim.step(sim)
		end
		t.expect(w.slot[falcon] ~= nil, "the fighter lives")
		local now = dist(w, falcon, home.x, home.z)
		t.expect(now < start - 400 or now < 260, `the fighter flew home: {math.floor(start)} → {math.floor(now)} studs from it`)
	end)

	t.test("a bomber with an attack order bombs that target, not a nearer one (H13)", function()
		local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local bomber = Spawn.unit(sim, "ord_absolution", 1, -900, 0, math.pi / 2)
		local near = Spawn.unit(sim, "chs_extractor", 2, -500, 0)
		local far = Spawn.unit(sim, "chs_depot", 2, 400, 200) -- past the bomb bay's 800-stud reach
		-- player 1 sees both: a solar array beside each
		local eyes = { Spawn.unit(sim, "ord_solar", 1, -500, 40), Spawn.unit(sim, "ord_solar", 1, 400, 240) }
		for _, id in { near, far, eyes[1], eyes[2] } do
			World.setBuildProgress(w, id, 1)
		end
		for _ = 1, 30 do -- the team's sight settles
			Sim.step(sim)
		end
		submit(sim, 1, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = { bomber }, targetId = far })
		local key = World.slotKey(bomber, 1)
		local onFar, onNear = 0, 0
		local hitFar = false
		local hp0 = w.health[far]
		for _ = 1, 900 do -- 60 s
			Sim.step(sim)
			if w.wTarget[key] == far then
				onFar += 1
			elseif w.wTarget[key] == near and w.slot[far] ~= nil then
				onNear += 1 -- (once the depot is gone, the extractor is fair game)
			end
			if w.slot[far] == nil or w.health[far] < hp0 then
				hitFar = true
			end
		end
		t.expect(onNear == 0, `the bomb bay never picked the nearer extractor ({onNear} ticks)`)
		t.expect(onFar > 0, "the bomb bay aimed at the ordered target")
		t.expect(hitFar, "the ordered target was bombed")
	end)
end
