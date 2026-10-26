--!strict
-- Match errors (F38, L-21): one numbered list, the same in the code and in
-- docs/contracts/match.md section 11; errors from outside are cleaned;
-- teleport results map to their codes; a failed match's results carry it.

local fs = require("@lune/fs")

local MatchConfig = require("../shared/MatchConfig")
local MatchErrors = require("../shared/MatchErrors")
local Rooms = require("../shared/Rooms")
local RunAll = require("../../server/Tests/RunAll")

return function(t: RunAll.Context)
	t.test("every code has a title and a description, 1xx lobby side and 2xx match side", function()
		local n = 0
		for code, e in MatchErrors.LIST do
			n += 1
			t.expect(code >= 101 and code <= 299 and code == math.floor(code), `code {code}`)
			t.expect(#e.title > 0 and #e.title <= 40, `{code}: title`)
			t.expect(#e.description > 0 and string.sub(e.description, -1) == ".", `{code}: description`)
		end
		t.expect(n >= 20, `{n} codes`)
		t.expect(MatchErrors.LIST[299] ~= nil, "a code for an unnamed match-side reason")
	end)

	t.test("the contract's table is the code's", function()
		local doc = fs.readFile("docs/contracts/match.md")
		local section = string.match(doc, "## 11%. Errors.-\n(.-)\n## ") :: string
		t.expect(section ~= nil, "section 11")
		local listed: { [number]: string } = {}
		for code, title in string.gmatch(section, "\n| (%d%d%d) | ([^|]-) |") do
			listed[tonumber(code) :: number] = title
		end
		for code, e in MatchErrors.LIST do
			t.equal(listed[code], e.title, `code {code} in the contract`)
		end
		for code in listed do
			t.expect(MatchErrors.LIST[code] ~= nil, `contract code {code} in MatchErrors`)
		end
	end)

	t.test("errors from teleport data or a result are cleaned", function()
		t.deepEqual(MatchErrors.clean({ code = 209 }), { code = 209 })
		t.deepEqual(MatchErrors.clean({ code = 202, detail = "player 3: color" }), { code = 202, detail = "player 3: color" })
		t.equal(MatchErrors.clean({ code = 777 }), nil, "not listed")
		t.equal(MatchErrors.clean({ code = "209" }), nil)
		t.equal(MatchErrors.clean("209"), nil)
		t.equal(MatchErrors.clean(nil), nil)
		t.equal((MatchErrors.clean({ code = 210, detail = 5 }) :: any).detail, nil, "a detail is text")
		t.equal(#((MatchErrors.clean({ code = 210, detail = string.rep("x", 900) }) :: any).detail), MatchErrors.DETAIL_MAX)
		t.equal(MatchErrors.line({ code = 113 }), "Error 113 · Match server full")
	end)

	t.test("TeleportInitFailed results map to codes", function()
		t.equal(MatchErrors.teleport("GameFull"), 113)
		t.equal(MatchErrors.teleport("Unauthorized"), 114)
		t.equal(MatchErrors.teleport("Failure"), 110)
		t.equal(MatchErrors.teleport(""), 110)
	end)

	t.test("a match that failed as a whole shows its error with the results", function()
		local maps = { { id = "map:duel", name = "Duel", starts = 2 } }
		local r = assert(Rooms.new("r1", { name = "Errors", privacy = "public" }, 10, "Host", maps))
		Rooms.apply(r, maps, 10, { op = "addAi" })
		local c = MatchConfig.build(r, "m1", 1, 0, { placeId = 1, jobId = "job" })
		local result: any = { version = MatchConfig.CONFIG_VERSION, matchId = "m1", outcome = "abandoned", seconds = 0, endedAt = 5, cheatsUsed = false, error = { code = 209, detail = "every player left" }, players = { { id = 1, won = false }, { id = 2, won = false } } }
		t.equal(MatchConfig.validateResult(result, c), nil)
		t.deepEqual(MatchConfig.summary(c, result, "Duel").error, { code = 209, detail = "every player left" })
		result.error = { code = 42 }
		t.equal(MatchConfig.summary(c, result, "Duel").error, nil, "an unknown code isn't shown")
	end)
end
