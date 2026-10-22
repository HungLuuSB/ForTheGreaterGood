--!strict
-- Start-position fairness (S-23). The bias came from targeting: a weapon
-- without a target searched on its stagger tick (id + tick) % 6, so its
-- search ticks had its ID's parity, and Sensors updates on even ticks: even-ID
-- units reacted to new enemies a tick sooner. In mirrored matches player 2's
-- units get the even IDs (both sides produce on the same ticks, player 1
-- first). The stagger phase is now a mixed hash of the ID.
local Hash = require("@shared/Util/Hash")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

-- Identical groups in mirrored positions after `shift` placeholder units
-- (they shift the IDs); `eastFirst` spawns the east side first. Returns
-- the survivors per side and which side holds the even IDs.
local function mirrorFight(unit: string, eastFirst: boolean, shift: number): (number, number, string)
	local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 3, allyTeam = 2 } }, mapId = "flat:64" })
	local w = sim.world
	for j = 1, shift do
		Spawn.unit(sim, "ord_generator", 1, -200, -200 + j * 16)
	end
	local west, east = {}, {}
	local n = 6
	for i = 1, n do
		local z = (i - (n + 1) / 2) * 12
		if eastFirst then
			table.insert(east, Spawn.unit(sim, unit, 2, 70, z, -math.pi / 2))
			table.insert(west, Spawn.unit(sim, unit, 1, -70, z, math.pi / 2))
		else
			table.insert(west, Spawn.unit(sim, unit, 1, -70, z, math.pi / 2))
			table.insert(east, Spawn.unit(sim, unit, 2, 70, z, -math.pi / 2))
		end
	end
	local function alive(list: { number }): number
		local k = 0
		for _, id in list do
			if w.slot[id] then
				k += 1
			end
		end
		return k
	end
	for _ = 1, 900 do
		Sim.step(sim)
		if alive(west) == 0 or alive(east) == 0 then
			break
		end
	end
	return alive(west), alive(east), if west[1] % 2 == 0 then "west" else "east"
end

return function(t: RunAll.Context)
	t.test("search phases don't follow ID parity", function()
		local slots = { [0] = { 0, 0, 0, 0, 0, 0 }, [1] = { 0, 0, 0, 0, 0, 0 } }
		local pairOffset = { 0, 0, 0, 0, 0, 0 }
		for id = 1, 600 do
			local p = Hash.mix32(id) % 6
			slots[id % 2][p + 1] += 1
			if id % 2 == 0 then
				local q = Hash.mix32(id - 1) % 6
				pairOffset[(p - q) % 6 + 1] += 1 -- a mirror pair's units get consecutive IDs
			end
		end
		for parity = 0, 1 do
			for slot = 1, 6 do
				t.expect(slots[parity][slot] >= 30 and slots[parity][slot] <= 70, `{if parity == 0 then "even" else "odd"} IDs in phase {slot - 1}: {slots[parity][slot]} of 300`)
			end
		end
		for d = 1, 6 do
			t.expect(pairOffset[d] >= 25 and pairOffset[d] <= 75, `consecutive IDs {d - 1} ticks apart: {pairOffset[d]} of 300`)
		end
	end)

	t.slow("in mirror fights the side holding the even IDs has no edge", function()
		-- Lancers: precise guns, so a fight is decided by who reacts first
		local even, odd, draws = 0, 0, 0
		for _, unit in { "ord_lancer" } do
			for shift = 0, 19 do
				for _, eastFirst in { false, true } do
					local west, east, evenSide = mirrorFight(unit, eastFirst, shift)
					local winner = if west > east then "west" elseif east > west then "east" else nil
					if winner == nil then
						draws += 1
					elseif winner == evenSide then
						even += 1
					else
						odd += 1
					end
				end
			end
		end
		print(string.format("    mirror fights: even-ID side won %d, odd-ID side %d, draws %d", even, odd, draws))
		local decided = even + odd
		t.expect(decided > 0 and even <= decided * 0.8 and odd <= decided * 0.8, `neither parity wins over 80%: even {even}, odd {odd} (before S-23 the even side won all 40)`)
	end)

	-- S-31: on Twin Lakes the east pair won every Hard–Normal 2v2. Mirrored
	-- players think at different ticks, and the generator rule read the
	-- power stall ratio at that moment; it reads 1 just after a builder
	-- finishes, so one side built an extractor where its mirror built a
	-- generator, and the east's economy pulled ahead every game.
	t.slow("Hard 2v2 mirror on Twin Lakes: mirrored players build the same things in the same places", function()
		local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
		local sim = Sim.new({
			seed = 7,
			players = players,
			mapId = "map:twin_lakes",
			scenario = "standard_start",
			match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { [1] = "hard", [2] = "hard", [3] = "hard", [4] = "hard" } },
		})
		local brains = Skirmish.forMatch(sim)
		local g = (sim.map :: any).grid
		local midX = g.originX + g.cellsX * 8 / 2 -- the west / east mirror line
		local orders: { { string } } = { {}, {}, {}, {} }
		local function value(owner: number): number
			local v = 0
			for _, id in sim.world.ids do
				if sim.world.owner[id] == owner then
					local c = sim.defs.unitByIndex[sim.world.defIndex[id]].cost
					v += (c.supply + c.power / 10) * sim.world.buildProgress[id]
				end
			end
			return v
		end
		for _ = 1, 900 * 3 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			for _, q in sim.queue do
				local cmd = q.cmd
				if cmd.cmdType == Schema.CmdType.BUILD and (cmd.cell or 0) ~= 0 then
					-- structures: the def and the site, mirrored for the east pair
					local x, z = g:decode(cmd.cell :: number, cmd.offX :: number, cmd.offZ :: number)
					if q.player >= 3 then
						x = 2 * midX - x
					end
					table.insert(orders[q.player], `{sim.defs.unitByIndex[cmd.defIndex :: number].id}@{math.floor(x / 8 + 0.5)},{math.floor(z / 8 + 0.5)}`)
				end
			end
			Sim.step(sim)
		end
		local leads = {}
		for _, pair in { { 1, 3 }, { 2, 4 } } do
			local a, b = orders[pair[1]], orders[pair[2]]
			local same = 0
			while same < math.min(#a, #b) and a[same + 1] == b[same + 1] do
				same += 1
			end
			-- later, single trips taking a few ticks more on one side or the other
			-- (flow-field tie-breaks, no net direction) reorder jobs. Since S-94
			-- (plants at twice the build power) Hard opens with six generators,
			-- so that jitter reaches the 8th job; the first 7 must match
			t.expect(same >= 7, `players {pair[1]} and {pair[2]}: the first {same} structures match (before S-31 they parted at the 3rd: extractor against generator)`)
			table.insert(leads, value(pair[1]) / value(pair[2]) - 1) -- the west's lead
		end
		-- no side leads: the teams within 10%, and the two pairs not both
		-- ahead on the same side by more than 5% (before S-31 the east led
		-- by 7–15% for every player). One pair may drift on its own: since
		-- S-94's faster plants, trip jitter moves a mirror ~12% either way
		local west, east = value(1) + value(2), value(3) + value(4)
		t.expect(math.abs(west - east) <= 0.1 * math.max(west, east), `teams at 3 minutes: west {west} against east {east}`)
		t.expect(not ((leads[1] > 0.05 and leads[2] > 0.05) or (leads[1] < -0.05 and leads[2] < -0.05)), `both pairs lean the same way: {leads[1] * 100}%, {leads[2] * 100}%`)
	end)

	-- The same AI level on both starts of a mirrored map, both factions, six
	-- seeds: wins (or the value lead after 10 minutes) split close to even.
	t.slow("mirror AI matches on a mirrored map split close to even between the starts", function()
		local west, east = 0, 0
		for seed = 1, 6 do
			for _, teams in { { 1, 3 }, { 2, 4 } } do -- Order mirror, Chaos mirror
				local sim = Sim.new({
					seed = seed,
					players = { { id = 1, team = teams[1], allyTeam = 1 }, { id = 2, team = teams[2], allyTeam = 2 } },
					mapId = "map:ridgeline",
					scenario = "standard_start",
					match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = "normal", [2] = "normal" } },
				})
				local brains = Skirmish.forMatch(sim)
				for _ = 1, 900 * 10 do
					for _, b in brains do
						Skirmish.tick(b)
					end
					Sim.step(sim)
					if sim.match.over then
						break
					end
				end
				local winner = sim.match.winner
				if not sim.match.over then
					local v = { 0, 0 }
					for _, id in sim.world.ids do
						local a = sim.world.ally[id]
						if a == 1 or a == 2 then
							local c = sim.defs.unitByIndex[sim.world.defIndex[id]].cost
							v[a] += (c.supply + c.power / 10) * sim.world.buildProgress[id]
						end
					end
					winner = if v[1] > v[2] then 1 elseif v[2] > v[1] then 2 else 0
				end
				if winner == 1 then
					west += 1
				elseif winner == 2 then
					east += 1
				end
			end
		end
		print(string.format("    mirror AI matches: west %d, east %d of 12", west, east))
		t.expect(west >= 4 and east >= 4, `close to even: west {west}, east {east} of 12`)
	end)
end
