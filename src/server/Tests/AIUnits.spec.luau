--!strict
-- The skirmish AI builds playtest 3's units (S-216, the user): a Bot Lab
-- and bots, Construction Turrets beside its factories, advanced solar; on a
-- sea map a naval worker for the offshore deposits. Whole matches: slow.
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local RunAll = require("./RunAll")

local function match(mapId: string, seed: number, level: string, minutes: number, each: ((Sim.Sim) -> ())?): Sim.Sim
	local sim = Sim.new({
		seed = seed,
		players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 3, allyTeam = 2 } },
		mapId = mapId,
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = level, [2] = level } },
	})
	local brains = Skirmish.forMatch(sim)
	for _ = 1, minutes * 60 * 15 do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if each and sim.tick % 150 == 0 then
			each(sim)
		end
		if sim.match.over then
			break
		end
	end
	return sim
end

-- player's finished units whose id is one of `ids`
local function count(sim: Sim.Sim, player: number, ids: { string }): number
	local w = sim.world
	local n = 0
	for _, id in w.ids do
		if w.owner[id] == player and w.buildProgress[id] >= 1 and table.find(ids, sim.defs.unitByIndex[w.defIndex[id]].id) then
			n += 1
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.slow("normal: a Bot Lab and bots, Construction Turrets beside a factory, advanced solar by 14 minutes (S-216)", function()
		-- what each player had at any point (S-223: by minute 13 one side's
		-- attack can take the other's turret down before the 14th)
		local seen = { {}, {} } :: { { [string]: boolean } }
		match("map:ridgeline", 7, "normal", 14, function(sim)
			local w = sim.world
			for _, p in { 1, 2 } do
				local s = seen[p]
				s.lab = s.lab or count(sim, p, { "ord_botlab" }) >= 1
				s.bots = s.bots or count(sim, p, { "ord_glint", "ord_mace", "ord_kestrel", "ord_lazarus" }) >= 2
				s.advSolar = s.advSolar or count(sim, p, { "ord_advsolar" }) >= 1
				-- a turret within reach of a factory
				for _, n in w.ids do
					if not s.served and w.owner[n] == p and sim.defs.unitByIndex[w.defIndex[n]].id == "ord_nano" then
						for _, f in w.ids do
							local fd = sim.defs.unitByIndex[w.defIndex[f]]
							if w.owner[f] == p and fd.domain == "structure" and fd.buildOptions and (w.posX[f] - w.posX[n]) ^ 2 + (w.posZ[f] - w.posZ[n]) ^ 2 <= Skirmish.NANO_REACH ^ 2 then
								s.served = true
							end
						end
					end
				end
			end
		end)
		for _, p in { 1, 2 } do
			t.expect(seen[p].lab, `player {p}: a Bot Lab`)
			t.expect(seen[p].bots, `player {p}: bots`)
			t.expect(seen[p].advSolar, `player {p}: advanced solar`)
			t.expect(seen[p].served, `player {p}: a Construction Turret beside a factory`)
		end
	end)
end
