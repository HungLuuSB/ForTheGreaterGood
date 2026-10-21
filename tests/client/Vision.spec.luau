--!strict
-- The client's sight map (C-32) equals the server's `los` map for the
-- player's team, cell for cell, while its units are in the camera; once
-- the camera moves away they are strategic records (cell centers at 3 Hz,
-- the def remembered), and the map stays close. Units never seen in the
-- camera only have an icon's sample def (request 9 asks for the map).

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Vision = require("../../src/client/Core/Vision")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")

local DT = 1 / 15

local function compare(camera: { number }, mapId: string, scenario: string, later: { number }?): (number, number, number)
	local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = mapId, scenario = scenario })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	assert(Sim.submit(sim, 1, Commands.camera(camera[1], camera[2], camera[3], camera[4])))
	local vision
	local ally = sim.players[1].allyTeam or sim.players[1].team
	local checked, exact, worst = 0, 0, 0
	for tick = 1, 200 do -- the duel is decided around tick 220; the server stops restamping then
		if tick == 20 and later then
			assert(Sim.submit(sim, 1, Commands.camera(later[1], later[2], later[3], later[4])))
		end
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		if not world.joined then
			continue
		end
		vision = vision or Vision.new(world.grid)
		Vision.update(vision, world) -- before the frame clears `died`, as in Main
		table.clear(world.died)
		if tick % 2 == 0 and tick > (if later then 30 else 4) then
			-- the server restamps on sensor ticks; compare right after one
			local los = sim.sensors.maps[ally].los
			local wrong = 0
			for i = 0, vision.width * vision.depth - 1 do
				if (buffer.readu16(los, i * 2) > 0) ~= (buffer.readu16(vision.seen, i * 2) > 0) then
					wrong += 1
				end
			end
			checked += 1
			if wrong == 0 then
				exact += 1
			end
			worst = math.max(worst, wrong)
		end
	end
	return checked, exact, worst
end

return function(t: any)
	t.test("the client's sight map equals the server's while units move and fight", function()
		local checked, exact, worst = compare({ 0, 0, 47, 47 }, "flat:48", "duel_test")
		print(string.format("    duel, all tactical: %d of %d sensor ticks exact (worst %d cells off)", exact, checked, worst))
		t.expect(checked > 90, "plenty of sensor ticks")
		t.expect(exact / checked >= 0.95, `nearly every tick exact ({exact} / {checked})`)
		t.expect(worst <= 8, "and never more than a few cells off")
	end)

	t.test("close when the own units have left the camera (strategic records)", function()
		local checked, exact, worst = compare({ 0, 0, 47, 47 }, "flat:48", "duel_test", { 0, 0, 3, 3 })
		print(string.format("    duel, camera moved away: %d of %d sensor ticks exact (worst %d cells off)", exact, checked, worst))
		t.expect(checked > 70, "plenty of sensor ticks")
		t.expect(exact / checked >= 0.9, `nearly every tick exact ({exact} / {checked})`)
		t.expect(worst <= 60, `the strategic records' 3 Hz lag costs at most a few edge cells ({worst})`)
	end)
end
