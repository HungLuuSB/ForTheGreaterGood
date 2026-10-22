--!strict
-- The statistics panel's data (C-105): samples over time from the sim's
-- report (StatSeries, halving to stay under MAX), downsampling that keeps a
-- line's shape, axis numbers, and the rasterized chart lines.

local Chart = require("../../src/client/Core/Chart")
local StatSeries = require("../../src/roblox/StatSeries")

local function fakeSim(tick: number, stored: number): any
	return {
		tick = tick,
		playerOrder = { 1, 2 },
		players = { [1] = { team = 1 }, [2] = { team = 2 } },
		eco = { accounts = { [1] = { supply = { stored = stored }, power = { stored = stored * 2 } }, [2] = { supply = { stored = 5 }, power = { stored = 6 } } } },
	}
end

return function(t: any)
	t.test("samples every EVERY ticks per player, stored from the team account; halves past MAX", function()
		local s = StatSeries.new(100)
		t.expect(StatSeries.due(s, 100) and StatSeries.due(s, 100 + StatSeries.EVERY) and not StatSeries.due(s, 101), "due on the interval")
		StatSeries.sample(s, fakeSim(100 + StatSeries.EVERY, 40), { [1] = { unitsBuilt = 3, damageDealt = 12.4 }, [2] = {} })
		t.equal(s.t[1], StatSeries.EVERY / 15)
		t.equal(s.players["1"].unitsBuilt[1], 3)
		t.equal(s.players["1"].damageDealt[1], 12)
		t.equal(s.players["1"].supplyStored[1], 40)
		t.equal(s.players["1"].powerStored[1], 80)
		t.equal(s.players["2"].unitsBuilt[1], 0, "missing fields are 0")
		for i = 2, StatSeries.MAX + 1 do
			StatSeries.sample(s, fakeSim(100 + i * StatSeries.EVERY, i), { [1] = { unitsBuilt = i }, [2] = {} })
		end
		t.expect(#s.t <= StatSeries.MAX, `at most MAX samples ({#s.t})`)
		t.equal(s.every, StatSeries.EVERY * 2, "the interval doubled")
		t.equal(#s.players["1"].unitsBuilt, #s.t, "every line as long as the times")
		t.equal(s.t[1], StatSeries.EVERY / 15, "the first sample is kept")
	end)

	t.test("downsampling keeps at most MAX points, the ends and the peaks", function()
		local xs, ys = {}, {}
		for i = 1, 1000 do
			xs[i] = i
			ys[i] = if i == 500 then 999 else math.sin(i / 50)
		end
		local ox, oy = Chart.downsample(xs, ys, 120)
		t.equal(#ox, 120)
		t.equal(ox[1], 1)
		t.equal(ox[#ox], 1000)
		t.expect(table.find(oy, 999) ~= nil, "the spike survives")
		local sx = Chart.downsample({ 1, 2, 3 }, { 4, 5, 6 }, 120)
		t.equal(#sx, 3, "short lines pass through")
	end)

	t.test("axis numbers: nice maxima and short labels", function()
		t.equal(Chart.niceMax(0), 1)
		t.equal(Chart.niceMax(7), 10)
		t.equal(Chart.niceMax(130), 200)
		t.equal(Chart.niceMax(4100), 5000)
		t.equal(Chart.format(950), "950")
		t.equal(Chart.format(1500), "1.5k")
		t.equal(Chart.format(20000), "20k")
		t.equal(Chart.format(3e6), "3M")
		t.equal(Chart.clock(125), "2:05")
	end)

	t.test("the rasterizer draws the line in its colour and leaves the rest clear", function()
		local w, h = 40, 20
		local buf = buffer.create(w * h * 4)
		Chart.raster(buf, w, h, { { xs = { 0, 10 }, ys = { 0, 10 }, r = 200, g = 50, b = 10 } }, 10, 10)
		local function px(x: number, y: number): (number, number, number)
			local o = (y * w + x) * 4
			return buffer.readu8(buf, o), buffer.readu8(buf, o + 1), buffer.readu8(buf, o + 3)
		end
		local r, g, a = px(1, h - 2) -- the bottom-left end
		t.expect(a > 100 and r == 200 and g == 50, `the line is there ({r} {g} {a})`)
		local _, _, empty = px(w - 2, h - 2) -- far from the diagonal
		t.equal(empty, 0)
	end)
end
