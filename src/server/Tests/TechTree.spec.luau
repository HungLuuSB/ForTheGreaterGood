--!strict
local Defs = require("@shared/Defs/Defs")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

-- Guide section 13, by faction (13.1 command and workers, 13.2 ground,
-- 13.3 air, 13.4 naval, 13.5 structures).
local ROSTER = {
	order = {
		"sovereign", "mason", "architect", "skywright", "zenith", "tidewright", "harbormaster",
		"herald", "lancer", "verdict", "halo", "oracle", "paladin", "judgement", "seraph", "veil", "tideguard",
		"falcon", "guardian", "absolution", "archon", "phantom", "tidewatch", "archangel",
		"sentry", "silence", "crusader", "dominion", "sanctuary",
		"bulwark", "bastion", "vigil", "aegis", "edict", "watchtower", "beacon", "curtain", "veilspire",
		"moat", "undertow", "rampart", "ear", "choir", "reckoning", "witness",
	},
	chaos = {
		"warlord", "scrapper", "forgemaster", "vulture", "condor", "wrecker", "reaver",
		"jackal", "ravager", "hellmouth", "hornet", "watcher", "juggernaut", "hydra", "gorgon", "shroud", "mire",
		"harpy", "wasp", "plague", "manticore", "behemoth", "leech", "banshee",
		"barracuda", "lamprey", "corsair", "kraken", "leviathan", "siren",
		"spike", "maw", "thorn", "wyvern", "cataclysm", "eye", "allseer", "smog", "blackout",
		"riptide", "fang", "breaker", "listener", "deepear", "ragnarok", "augur",
	},
}
local PREFIX = { order = "ord_", chaos = "chs_" }
local COMMANDER = { order = "ord_sovereign", chaos = "chs_warlord" }

-- Move class per role (guide 6.1, 12, 13).
local MOVE_CLASS = {
	ord_herald = "WHEELED", chs_jackal = "WHEELED",
	ord_halo = "WHEELED", chs_hornet = "WHEELED",
	ord_seraph = "WHEELED", chs_gorgon = "WHEELED",
	ord_oracle = "WHEELED", chs_watcher = "WHEELED",
	ord_paladin = "HEAVY_TRACKED", chs_juggernaut = "HEAVY_TRACKED",
	ord_tideguard = "AMPHIB", chs_mire = "AMPHIB",
	ord_lancer = "TRACKED", chs_ravager = "TRACKED",
	ord_skywright = "HELI", chs_vulture = "HELI", ord_zenith = "HELI", chs_condor = "HELI",
	ord_guardian = "HELI", chs_wasp = "HELI", ord_tidewatch = "HELI", chs_leech = "HELI",
	ord_falcon = "JET", chs_harpy = "JET", ord_absolution = "JET", chs_plague = "JET",
	ord_archon = "JET", chs_manticore = "JET", ord_phantom = "JET", chs_behemoth = "JET",
	ord_archangel = "JET", chs_banshee = "JET",
	ord_tidewright = "SHIP", chs_wrecker = "SHIP", ord_harbormaster = "SHIP", chs_reaver = "SHIP",
	ord_sentry = "SHIP", chs_barracuda = "SHIP", ord_crusader = "SHIP", chs_corsair = "SHIP",
	ord_dominion = "SHIP", chs_kraken = "SHIP", ord_sanctuary = "SHIP", chs_leviathan = "SHIP", chs_siren = "SHIP",
	ord_silence = "SUB", chs_lamprey = "SUB",
}

local function isFactory(d: Defs.UnitDef): boolean
	return d.domain == "structure" and d.buildOptions ~= nil
end

-- Units reachable from `start` through build options, with the builder of
-- each (the first found, breadth-first).
local function reach(defs: Defs.DefSet, start: string): { [string]: string }
	local from: { [string]: string } = { [start] = "start" }
	local queue, head = { start }, 1
	while queue[head] do
		local id = queue[head]
		head += 1
		for _, option in defs.units[id].buildOptions or {} do
			if from[option] == nil then
				from[option] = id
				table.insert(queue, option)
			end
		end
	end
	return from
end

return function(t: RunAll.Context)
	local defs = Defs.load()

	t.test("from game start, every roster unit is reachable through the build tree, for both factions", function()
		for faction, roster in ROSTER do
			local from = reach(defs, COMMANDER[faction])
			for _, name in roster do
				local id = PREFIX[faction] .. name
				t.expect(defs.units[id] ~= nil, `{id} exists (guide 13)`)
				t.expect(from[id] ~= nil, `{id} is reachable from {COMMANDER[faction]}`)
			end
			-- and nothing of the faction is left out of the tree
			local total, reached = 0, 0
			for id, d in defs.units do
				if d.faction == faction then
					total += 1
					if from[id] then
						reached += 1
					else
						t.expect(false, `{id} is not reachable`)
					end
				end
			end
			print(`    {faction}: {reached} / {total} defs reachable from {COMMANDER[faction]}`)
		end
	end)

	t.test("tech gating: T1 builders reach T2 only through advanced factories", function()
		for id, d in defs.units do
			for _, option in d.buildOptions or {} do
				local o = defs.units[option]
				t.equal(o.faction, d.faction, `{id} builds only its own faction ({option})`)
				if d.tier <= 1 and o.tier >= 2 then
					t.expect(isFactory(o), `T1 {id} may build T2 only if it is a factory, not {option}`)
				end
				if o.domain ~= "structure" and o.tier >= 2 then
					t.expect(d.tier >= 2 and isFactory(d), `T2 unit {option} comes from an advanced factory, not {id}`)
				end
			end
		end
	end)

	t.test("move classes and domains match the roles", function()
		for id, mc in MOVE_CLASS do
			t.equal(defs.units[id].moveClass, mc, id)
		end
		for id, d in defs.units do
			for _, option in d.buildOptions or {} do
				local o = defs.units[option]
				if o.domain == "naval" then
					t.expect(isFactory(d) and d.placement == "water", `ships come from shipyards: {option} from {id}`)
				elseif o.domain == "air" then
					t.expect(isFactory(d) and string.find(id, "airfield") ~= nil, `aircraft come from airfields: {option} from {id}`)
				end
			end
			if d.domain == "naval" then
				t.expect(d.moveClass == "SHIP" or d.moveClass == "SUB", `{id} is a ship or a submarine`)
			end
		end
		for _, id in { "ord_moat", "chs_riptide", "ord_undertow", "chs_fang", "ord_ear", "chs_listener", "ord_choir", "chs_deepear",
			"ord_shipyard", "chs_shipyard", "ord_advshipyard", "chs_advshipyard", "ord_tidal", "chs_tidal" } do
			t.equal(defs.units[id].placement, "water", `{id} stands on water`)
		end
	end)

	t.test("every weapon can damage something it targets", function()
		local classOf = {
			GROUND = { "LIGHT", "ARMORED" }, STRUCTURE = { "STRUCTURE" }, NAVAL = { "SHIP" }, AIR = { "AIR" }, SUB = { "SUB" },
		}
		for id, wd in defs.weapons do
			if wd.interceptOnly then
				continue -- anti-nukes hit strategic missiles only (S-111)
			end
			local best = 0
			for _, cat in wd.targets do
				for _, armor in classOf[cat] or {} do
					best = math.max(best, wd.damage[armor] or 0)
				end
			end
			t.expect(best > 0, `{id} deals damage to one of its targets`)
		end
	end)

	t.test("new factories and builders work in the sim: shipyard → naval worker → tidal; airfield → air worker → solar", function()
		local function cmd(sim: Sim.Sim, ids: { number }, defId: string, x: number, z: number)
			local g = (sim.map :: any).grid
			local cell, ox, oz = g:encode(x, z)
			local w = Packer.Writer.new()
			Schema.encodeCommand(w, { cmdType = Schema.CmdType.BUILD, flags = 0, unitIds = ids, defIndex = sim.defs.units[defId].index, cell = cell, offX = ox, offZ = oz, facing = 0 })
			assert(Sim.submit(sim, 1, w:finish()))
		end
		local function chain(mapId: string, factory: string, fx: number, worker: string, structure: string, sx: number): (boolean, boolean)
			local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = mapId })
			Spawn.unit(sim, "ord_sovereign", 1, -400, -400) -- income
			for i = 1, 4 do
				Spawn.unit(sim, "ord_generator", 1, -430 + i * 30, -460)
			end
			local plant = Spawn.unit(sim, factory, 1, fx, 0, math.pi / 2)
			cmd(sim, { plant }, worker, fx, 0)
			local made, built = nil, false
			for _ = 1, 4000 do
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "PRODUCED" and made == nil then
						made = e.unit
						cmd(sim, { e.unit }, structure, sx, 60)
					elseif e.kind == "BUILD_DONE" and made ~= nil then
						built = true
					end
				end
				if built then
					break
				end
			end
			return made ~= nil, built
		end
		local madeShip, tidal = chain("sea:128", "ord_shipyard", 0, "ord_tidewright", "ord_tidal", 80)
		t.expect(madeShip, "the shipyard launched a naval worker")
		t.expect(tidal, "which built a tidal generator on the water")
		local madeHeli, solar = chain("flat:128", "ord_airfield", 0, "ord_skywright", "ord_solar", 120)
		t.expect(madeHeli, "the airfield produced an air worker")
		t.expect(solar, "which built a solar array")
	end)
end
