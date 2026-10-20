--!strict
-- Records a match for the match viewer (tools/viewer/index.html; DECISIONS
-- D93). Two views:
--   spectator  the server's truth every frame: every unit, projectiles and
--              combat events
--   player     what one player's client knows, rebuilt from the real NetOut
--              packets by the headless client (Support/Client) with a
--              whole-map camera: tactical units (full detail), strategic
--              records (radar / sonar blips at their wobbled positions,
--              ghosts), and that player's ally-team sight map as fog.
--              Projectiles and combat events aren't on the wire yet (D82),
--              so the player view has none.
--
-- Format "ftgg-match" version 1 (JSON; positions in studs to 0.1):
--   meta     { format, version, scenario, mapId, seed, view, player, ally,
--              tickRate, ticksPerFrame, endTick, over, winner, icons }
--   map      { cellsX, cellsZ, cellSize, originX, originZ, sensorX, sensorZ,
--              sensorCell, height[], water[] (studs, row-major by cz),
--              supply[], starts[[x, z]] }
--   players  [{ id, team, ally }]
--   defs     [{ index, id, name, faction, domain, kind, radius, maxHealth }]
--   frames   [{ t,
--               u: [[id, defIndex, team, x, z, headingDeg, health‰, alt, state, target, build‰]],
--               s: [[id, team, x, z, flags, icon]]   (player view: strategic records)
--               p: [[x, y, z]]                     (spectator: projectiles)
--               e: [[kind, x, z]]                  (spectator: events since the last frame)
--               fog: base64 bitmap, 1 bit per sensor cell, 1 = in sight (player view) }]
-- `kind` is a drawing category (tank, artillery, aa, light, sensor, worker,
-- commander, jet, heli, ship, sub, factory, turret, extractor, power,
-- structure).

local Categories = require("@shared/Defs/Categories")
local Defs = require("@shared/Defs/Defs")
local Layers = require("@shared/Grid/Layers")
local Client = require("./Client")
local Json = require("./Json")
local NetOut = require("../../Sim/NetOut")
local Scenes = require("./Scenes")
local Sim = require("../../Sim/Sim")
local World = require("../../Sim/World")

local MatchExport = {}

MatchExport.FORMAT = "ftgg-match"
MatchExport.VERSION = 1

export type Options = {
	view: "spectator" | "player",
	player: number?,
	every: number?, -- ticks per frame (default 3)
	maxTicks: number?, -- default: the scene's
	onFrame: ((Sim.Sim, any) -> ())?, -- called with each captured frame (tests)
}

local BIT = Categories.Bit

function MatchExport.kind(d: Defs.UnitDef): string
	local cat = d.categoryMask
	local function has(name: string): boolean
		return bit32.band(cat, BIT[name]) ~= 0
	end
	if d.domain == "structure" then
		if d.buildOptions then
			return "factory"
		elseif #d.weapons > 0 then
			return "turret"
		elseif d.extractor then
			return "extractor"
		elseif d.production or d.wind or d.converter or d.storage then
			return "power"
		elseif d.sensors.radar > 0 or (d.sensors.jam or 0) > 0 or d.sensors.sonar > 0 then
			return "sensor"
		end
		return "structure"
	end
	if has("COMMANDER") then
		return "commander"
	elseif has("WORKER") then
		return "worker"
	elseif d.moveClass == "JET" then
		return "jet"
	elseif d.moveClass == "HELI" then
		return "heli"
	elseif d.moveClass == "SUB" then
		return "sub"
	elseif d.domain == "naval" then
		return "ship"
	elseif has("ARTILLERY") then
		return "artillery"
	elseif has("ANTIAIR") then
		return "aa"
	elseif has("RADAR_EMITTER") or has("JAMMER") then
		return "sensor"
	elseif has("LIGHT") then
		return "light"
	end
	return "tank"
end

local function r1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function MatchExport.base64(bytes: { number }): string
	local out = {}
	for i = 1, #bytes, 3 do
		local a, b, c = bytes[i], bytes[i + 1] or 0, bytes[i + 2] or 0
		local n = a * 65536 + b * 256 + c
		local chars = 4
		if bytes[i + 1] == nil then
			chars = 2
		elseif bytes[i + 2] == nil then
			chars = 3
		end
		for k = 1, 4 do
			if k <= chars then
				local v = (n // 64 ^ (4 - k)) % 64
				table.insert(out, string.sub(B64, v + 1, v + 1))
			else
				table.insert(out, "=")
			end
		end
	end
	return table.concat(out)
end

local function mapData(sim: Sim.Sim): any
	local pm = sim.map :: any
	local layers = pm.layers :: Layers.Layers
	local g = pm.grid
	local height, water, supply = {}, {}, {}
	for i = 0, g.cellCount - 1 do
		height[i + 1] = math.floor(Layers.getHeight(layers, i) * 4 + 0.5) / 4
		water[i + 1] = math.floor(Layers.getWater(layers, i) * 4 + 0.5) / 4
		supply[i + 1] = Layers.getSupply(layers, i)
	end
	local starts = Json.array()
	for _, s in layers.starts do
		table.insert(starts, { r1(s[1]), r1(s[2]) })
	end
	return {
		cellsX = g.cellsX,
		cellsZ = g.cellsZ,
		cellSize = 8,
		originX = g.originX,
		originZ = g.originZ,
		sensorX = g.sensorX,
		sensorZ = g.sensorZ,
		sensorCell = 16,
		height = height,
		water = water,
		supply = supply,
		starts = starts,
	}
end

local function iconNames(sim: Sim.Sim): { string }
	local names = {}
	for _, def in sim.defs.unitByIndex do
		if table.find(names, def.icon) == nil then
			table.insert(names, def.icon)
		end
	end
	table.sort(names)
	return names
end

-- Records `scene` (from Scenes) and returns the export table.
function MatchExport.record(scene: Scenes.Scene, name: string, opts: Options): any
	local sim = scene.sim
	local w = sim.world
	local c = sim.combat
	local every = opts.every or 3
	local maxTicks = opts.maxTicks or scene.maxTicks
	local player = opts.player
	local g = (sim.map :: any).grid
	local view: Client.View? = nil
	local ally = 0
	if opts.view == "player" then
		assert(player and sim.players[player], "MatchExport: a player view needs a valid player")
		ally = sim.players[player].allyTeam :: number
		NetOut.setCamera(sim, player, 0, 0, math.min(g.cellsX - 1, 255), math.min(g.cellsZ - 1, 255))
		view = Client.new(g)
	end

	local defs = Json.array()
	for index, d in sim.defs.unitByIndex do
		defs[index] = {
			index = index,
			id = d.id,
			name = d.name,
			faction = d.faction,
			domain = d.domain,
			kind = MatchExport.kind(d),
			radius = r1(c.profiles[index].radius),
			maxHealth = d.health,
		}
	end
	local players = Json.array()
	for _, pid in sim.playerOrder do
		table.insert(players, { id = pid, team = sim.players[pid].team, ally = sim.players[pid].allyTeam })
	end

	local frames = Json.array()
	local pendingEvents = Json.array()
	local EVENT_KIND = { IMPACT = "impact", DEATH = "death", DECOYED = "decoy", LOST_LOCK = "lost" }

	local function capture()
		local frame: any = { t = sim.tick, u = Json.array() }
		if view == nil then
			for _, id in w.ids do
				local d = sim.defs.unitByIndex[w.defIndex[id]]
				table.insert(frame.u, {
					id,
					w.defIndex[id],
					w.team[id],
					r1(w.posX[id]),
					r1(w.posZ[id]),
					math.floor(math.deg(w.heading[id]) % 360 + 0.5),
					math.clamp(math.floor(w.health[id] / d.health * 1000 + 0.5), 0, 1000),
					math.floor(w.alt[id] + 0.5),
					w.state[id],
					if w.weaponCount[id] > 0 then w.wTarget[World.slotKey(id, 1)] else 0,
					math.floor(w.buildProgress[id] * 1000 + 0.5),
				})
			end
			frame.p = Json.array()
			for _, pid in c.proj do
				table.insert(frame.p, { r1(c.px[pid]), r1(c.py[pid]), r1(c.pz[pid]) })
			end
			frame.e = pendingEvents
			pendingEvents = Json.array()
		else
			local v = view :: Client.View
			frame.s = Json.array()
			local ids = {}
			for id in v.units do
				table.insert(ids, id)
			end
			table.sort(ids)
			for _, id in ids do
				local u = v.units[id]
				if u.tier == "tactical" then
					table.insert(frame.u, {
						id,
						u.defIndex or 0,
						u.team,
						r1(u.x),
						r1(u.z),
						math.floor((u.heading or 0) / 256 * 360 + 0.5) % 360,
						math.floor((u.health or 255) / 255 * 1000 + 0.5),
						0,
						u.state or 0,
						0,
						math.floor((u.build or 255) / 255 * 1000 + 0.5),
					})
				else
					table.insert(frame.s, { id, u.team, r1(u.x), r1(u.z), u.flags or 0, u.icon or 0 })
				end
			end
			-- the ally team's sight, 1 bit per sensor cell
			local los = sim.sensors.maps[ally].los
			local cells = g.sensorX * g.sensorZ
			local bytes = table.create((cells + 7) // 8, 0)
			for i = 0, cells - 1 do
				if buffer.readu16(los, i * 2) > 0 then
					local b = i // 8 + 1
					bytes[b] += 2 ^ (7 - i % 8)
				end
			end
			frame.fog = MatchExport.base64(bytes)
		end
		table.insert(frames, frame)
		if opts.onFrame then
			opts.onFrame(sim, frame)
		end
	end

	capture()
	for _ = 1, maxTicks do
		scene.drive(sim)
		Sim.step(sim)
		if view then
			Client.receive(view, sim.net.players[player :: number].outbox)
		else
			for _, e in c.events do
				local kind = EVENT_KIND[e.kind]
				if kind and e.x and e.z then
					table.insert(pendingEvents, { kind, r1(e.x), r1(e.z) })
				end
			end
		end
		local finished = scene.done(sim)
		if sim.tick % every == 0 or finished then
			capture()
		end
		if finished then
			break
		end
	end

	return {
		meta = {
			format = MatchExport.FORMAT,
			version = MatchExport.VERSION,
			scenario = name,
			mapId = sim.mapId,
			seed = sim.seed,
			view = opts.view,
			player = player or 0,
			ally = ally,
			tickRate = 15,
			ticksPerFrame = every,
			endTick = sim.tick,
			over = sim.match.over,
			winner = sim.match.winner,
			icons = iconNames(sim),
		},
		map = mapData(sim),
		players = players,
		defs = defs,
		frames = frames,
	}
end

function MatchExport.encode(data: any): string
	return Json.encode(data, 2)
end

return MatchExport
