--!strict
-- Headless client demos (C-10): the real Sim and the real client (World,
-- NetIn, Api) run in Lune, and the client's view is written as a scene for
-- `lune run render_scene`. Proof for client features when Studio can't
-- show them; not a substitute for a playtest. From the project root:
--   lune run client_demo build <out.txt>     build ghost, a frame, a queued row
--   lune run client_demo combat <out.txt>    a Lancer / Ravager fight with effects

local fs = require("@lune/fs")
local process = require("@lune/process")

local Api = require("../src/client/Api")
local Commands = require("../src/client/Core/Commands")
local Effects = require("../src/client/Core/Effects")
local Icons = require("../src/client/Core/Icons")
local NetIn = require("../src/client/Core/NetIn")
local World = require("../src/client/Core/World")
local NetOut = require("../src/server/Sim/NetOut")
local Sim = require("../src/server/Sim/Sim")

local DT = 1 / 15
local TEAM_RGB = { "58,120,230", "214,62,48", "64,176,84", "232,196,52" } -- Render/TeamColors

local demo, out = process.args[1], process.args[2]
if demo == nil or out == nil then
	print("usage: lune run client_demo <build|combat> <out.txt>")
	process.exit(1)
end

local function setup(config: any)
	local sim = Sim.new(config)
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local api = Api.new(world, function(payload: buffer)
		assert(Sim.submit(sim, 1, payload))
	end)
	local cells = (sim.map :: any).grid.cellsX
	api.send(Commands.camera(0, 0, cells - 1, cells - 1))
	local tick = 0
	local function run(n: number, each: ((number) -> ())?)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.entered)
			table.clear(world.left)
			Api.frame(api, tick * DT)
			if each then
				each(tick)
			end
			table.clear(world.died)
		end
	end
	run(2)
	return sim, world, api, run
end

-- The client's view as a scene (Debug/SceneDump's format, plus G for the ghost).
local function scene(world: any, api: any, extra: { string }?): string
	local g = world.grid
	local lines = { string.format("M %.0f %.0f %.0f %.0f", g.originX, g.originZ, g.sizeX, g.sizeZ) }
	for _, u in world.units do
		local def = World.def(world, u)
		if u.tier == "tactical" and def then
			local aim = u.aim[1]
			table.insert(lines, string.format("U %s %s %.1f %.1f %.2f %.2f %.2f", def.id, TEAM_RGB[u.team] or "200,200,200", u.x, u.z, u.heading, if aim then aim.yaw else 0, if aim then aim.pitch else 0))
		end
	end
	for _, id in api.state.selection do
		local u = world.units[id]
		local def = World.def(world, u)
		table.insert(lines, string.format("D %.1f %.1f %.1f 110 235 120 0.45", u.x, u.z, (if def then def.footprint else 1) * 8 * 0.95))
		local from = { u.x, u.z }
		for _, p in api.waypoints.byUnit[id] or {} do
			table.insert(lines, string.format("L %.1f %.1f %.1f %.1f 0.35 235 220 80", from[1], from[2], p.x, p.z))
			table.insert(lines, string.format("D %.1f %.1f 1.4 235 220 80 0.8", p.x, p.z))
			from = { p.x, p.z }
		end
	end
	local p = api.state.placement
	if p then
		table.insert(lines, string.format("G %s %.1f %.1f %d %d", p.defId, p.x, p.z, p.facing, if p.valid then 1 else 0))
	end
	for _, line in extra or {} do
		table.insert(lines, line)
	end
	return table.concat(lines, "\n") .. "\n"
end

if demo == "build" then
	local _sim, world, api, run = setup({ seed = 2, players = { { id = 1, team = 1 } }, mapId = "start:48", scenario = "standard_start" })
	local cv = World.ownIds(world)[1]
	local u = world.units[cv]
	api.actions.select({ cv })
	-- a generator now, then a queued row of solars
	assert(api.actions.beginPlacement("ord_generator"))
	assert(api.actions.place(u.x + 36, u.z - 20, false, false))
	assert(api.actions.beginPlacement("ord_solar"))
	assert(api.actions.placeRow(u.x + 20, u.z + 40, u.x + 70, u.z + 40, true, false))
	run(15 * 12)
	-- the ghost, held over the Command Vehicle (red: units in the way) and a valid spot
	assert(api.actions.beginPlacement("ord_vehplant"))
	api.actions.updatePlacement(u.x - 40, u.z - 30)
	local ok, why = api.actions.updatePlacement(u.x - 40, u.z - 30)
	print(`ghost at a free spot: {ok} {why}`)
	fs.writeFile(out, scene(world, api))
	local red = string.gsub(out, "%.txt$", "_invalid.txt")
	api.actions.updatePlacement(world.units[cv].x, world.units[cv].z)
	ok, why = api.actions.updatePlacement(world.units[cv].x, world.units[cv].z)
	print(`ghost on the Command Vehicle: {ok} {why}`)
	fs.writeFile(red, scene(world, api))
	print(`wrote {out} and {red}`)
elseif demo == "combat" then
	-- the duel, drawn the way the client would at render tick T - 2
	local sim, world, api, run = setup({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
	local fx = Effects.new()
	-- both sides close in (as the playtest's bot orders do), so shells fly between them
	local own = World.ownIds(world)
	api.actions.select(own)
	api.actions.smartOrder(0, 0, nil, false)
	local Packer = require("@shared/Net/Packer")
	local Schema = require("@shared/Net/Schema")
	local enemy = {}
	for _, id in sim.world.ids do
		if sim.world.owner[id] == 2 then
			table.insert(enemy, id)
		end
	end
	local w = Packer.Writer.new(64)
	local cell, offX, offZ = world.grid:encode(0, 0)
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = enemy, cell = cell, offX = offX, offZ = offZ })
	assert(Sim.submit(sim, 2, w:finish()))
	local best, bestScore = "", -1
	run(15 * 9, function(tick)
		-- the client keeps died / events for Effects; run() clears died after this hook
		Effects.update(fx, world, tick - 2, tick * DT, 0, 0)
		local n = 0
		for _ in fx.projectiles do
			n += 1
		end
		local score = n + #fx.bursts * 2
		if tick > 30 and score > bestScore then
			bestScore = score
			local extra = {}
			for _, v in Effects.visible(fx, tick - 2) do
				table.insert(extra, string.format("E %.1f %.1f 1.4 255 205 110 1", v[2], v[4]))
			end
			for _, b in fx.bursts do
				local age = math.clamp((tick * DT - b.born) / b.life, 0, 1)
				local color = if b.kind == "death" then "255 110 50" elseif b.kind == "muzzle" then "255 235 170" else "255 170 70"
				table.insert(extra, string.format("E %.1f %.1f %.1f %s %.2f", b.x, b.z, b.radius * 2 * (0.35 + 0.65 * age), color, 0.85 - 0.8 * age))
			end
			for _, t in fx.tracers do
				table.insert(extra, string.format("L %.1f %.1f %.1f %.1f 0.3 255 230 160", t.x0, t.z0, t.x1, t.z1))
			end
			best = scene(world, api, extra)
		end
	end)
	fs.writeFile(out, best)
	print(`wrote {out} (busiest frame: {bestScore})`)
elseif demo == "icons" then
	-- strategic zoom over a skirmish start: everything as icons, a few selected
	local sim, world, api, run = setup({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "ew_test" })
	run(15 * 4)
	local own = World.ownIds(world)
	api.actions.select({ own[1], own[2], own[3] })
	local tbl = Icons.table(sim.defs)
	-- "screen" = world studs shifted to be positive (the on-screen test drops negatives)
	local project = function(x: number, _y: number, z: number)
		return x + 4096, z + 4096, true
	end
	local lines = {}
	local draws = Icons.draws(tbl, world, project, math.huge, math.huge, api.selection.set)
	for _, d in draws do
		local rgb = string.split(TEAM_RGB[d.style.team] or "200,200,200", ",")
		table.insert(lines, string.format("I %.1f %.1f %s %d %s %s %s %.2f %d", d.x - 4096, d.y - 4096, d.style.shape, d.style.size, rgb[1], rgb[2], rgb[3], d.style.alpha, if d.style.selected then 1 else 0))
	end
	local g = world.grid
	fs.writeFile(out, string.format("M %.0f %.0f %.0f %.0f\n", g.originX, g.originZ, g.sizeX, g.sizeZ) .. table.concat(lines, "\n") .. "\n")
	print(`wrote {out}: {#draws} icons`)
else
	print(`unknown demo {demo}`)
	process.exit(1)
end
