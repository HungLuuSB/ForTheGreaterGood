local process = require("@lune/process")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local level = process.args[1] or "hard"
local seed = tonumber(process.args[2]) or 7
local ticks = (tonumber(process.args[3]) or 5) * 900
local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
local sim = Sim.new({ seed = seed, players = players, mapId = "map:twin_lakes", scenario = "standard_start",
	match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { [1] = level, [2] = level, [3] = level, [4] = level } } })
local brains = Skirmish.forMatch(sim)
if process.args[4] == "aligned" then
	for _, b in brains do
		b.thinkOffset = if b.player == 1 or b.player == 3 then 0 else b.cfg.think // 2
	end
end
local g = sim.map.grid
local cx = g.originX + g.cellsX * 8 / 2
local w = sim.world
local function snapshot(owner, mirror)
	local per = {}
	for _, id in w.ids do
		if w.owner[id] == owner then
			local x = w.posX[id]
			if mirror then x = 2 * cx - x end
			local d = sim.defs.unitByIndex[w.defIndex[id]].id
			local e = per[d] or { n = 0, x = 0, z = 0, b = 0 }
			e.n += 1; e.x += x; e.z += w.posZ[id]; e.b += w.buildProgress[id]
			per[d] = e
		end
	end
	return per
end
local function differ(a, b)
	local out = {}
	for d, e in a do
		local f = b[d]
		if f == nil or f.n ~= e.n or math.abs(f.x - e.x) > 0.5 or math.abs(f.z - e.z) > 0.5 or math.abs(f.b - e.b) > 0.01 then
			table.insert(out, string.format("%s west n=%d x=%.1f z=%.1f b=%.2f / east n=%s x=%s z=%s b=%s", d, e.n, e.x, e.z, e.b, f and f.n or 0, f and string.format("%.1f", f.x) or "-", f and string.format("%.1f", f.z) or "-", f and string.format("%.2f", f.b) or "-"))
		end
	end
	for d, f in b do
		if a[d] == nil then table.insert(out, d .. " only east n=" .. f.n) end
	end
	return out
end
local reported = {}
for _ = 1, ticks do
	for _, b in brains do Skirmish.tick(b) end
	Sim.step(sim)
	for _, pair in { { 1, 3 }, { 2, 4 } } do
		local key = pair[1]
		if not reported[key] then
			local d = differ(snapshot(pair[1], false), snapshot(pair[2], true))
			if #d > 0 then
				reported[key] = true
				print(string.format("tick %d: player %d vs mirrored %d: %s", sim.tick, pair[1], pair[2], table.concat(d, "; ")))
			end
		end
	end
	if sim.match.over then break end
end
print("end tick", sim.tick, "over", sim.match.over, "winner", sim.match.winner)
