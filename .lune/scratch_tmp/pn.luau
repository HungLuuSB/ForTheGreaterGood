local Guidance = require("../../src/shared/Combat/Guidance")
local DT = 1 / 15
local function sim(turnRate, circle, n)
	Guidance.N = n
	-- target at (0, 100, 0) flying +X at 195 (or circling radius 220)
	local misses = {}
	for k = 0, 35 do
		local ang = k / 36 * 2 * math.pi
		local px, py, pz = math.cos(ang) * 250, 0, math.sin(ang) * 250
		local th = 0
		local tx, ty, tz = 0, 100, 0
		local tvx, tvz = 195, 0
		local dx, dy, dz = tx - px, ty - py, tz - pz
		local l = math.sqrt(dx * dx + dy * dy + dz * dz)
		local vx, vy, vz = dx / l * 420, dy / l * 420, dz / l * 420
		local best = math.huge
		for _ = 1, 60 do
			vx, vy, vz = Guidance.pn(px, py, pz, vx, vy, vz, tx, ty, tz, tvx, 0, tvz, math.rad(turnRate) * DT, DT)
			local ntx, ntz = tx, tz
			if circle then
				th += 195 / 220 * DT
				tvx, tvz = math.cos(th) * 195, math.sin(th) * 195
			end
			ntx, ntz = tx + tvx * DT, tz + tvz * DT
			local npx, npy, npz = px + vx * DT, py + vy * DT, pz + vz * DT
			for s = 0, 20 do
				local f = s / 20
				local d = math.sqrt((px + (npx - px) * f - (tx + (ntx - tx) * f)) ^ 2 + (py + (npy - py) * f - ty) ^ 2 + (pz + (npz - pz) * f - (tz + (ntz - tz) * f)) ^ 2)
				best = math.min(best, d)
			end
			px, py, pz, tx, tz = npx, npy, npz, ntx, ntz
		end
		table.insert(misses, best)
	end
	table.sort(misses)
	return misses[18], misses[30], misses[36]
end
for _, n in { 3, 4, 5 } do
	for _, circle in { false, true } do
		local m, p80, worst = sim(160, circle, n)
		print(string.format("N=%d %s: median miss %.1f, 80%% %.1f, worst %.1f", n, if circle then "circling" else "straight", m, p80, worst))
	end
end
