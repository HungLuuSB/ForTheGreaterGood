--!strict
-- A finished match's summary, shown once when you're back in the room
-- (L-4): victory or defeat, the map, mode and length, and every player's
-- result and numbers from the match server's results record.

local Players = game:GetService("Players")

local Ui = require("../Ui")

local Kit = Ui.Kit

local Results = {}

local function num(n: number?): string
	if n == nil then
		return "–"
	end
	if n >= 10000 then
		return string.format("%.1fk", n / 1000)
	end
	return tostring(math.floor(n))
end

function Results.new(gui: ScreenGui): any
	local seen: { [string]: boolean } = {}
	local open: any = nil

	local function show(r: any)
		local me = Players.LocalPlayer.UserId
		local mine = nil
		for _, p in r.players do
			if p.user == me then
				mine = p
			end
		end
		local headline, color
		if r.outcome == "abandoned" then
			headline, color = "Match abandoned", Kit.COLOR.dim
		elseif r.outcome == "draw" then
			headline, color = "Draw", Kit.COLOR.text
		elseif mine == nil then
			headline, color = if r.winner then `Ally team {r.winner} won` else "Every human is out", Kit.COLOR.text
		elseif mine.won then
			headline, color = "Victory", Kit.COLOR.victory
		else
			headline, color = "Defeat", Kit.COLOR.defeat
		end
		local p = Kit.panel(gui, "Match results", Vector2.new(860, 250 + 36 * (#r.players + 1)))
		p.root.ZIndex = 45
		p.scrim.ZIndex = 44
		local function close()
			p.root:Destroy()
			p.scrim:Destroy()
			open = nil
		end
		open = close
		Kit.list(p.content, Kit.SPACE.s)
		local h = Kit.text(p.content, headline, "title", color)
		h.TextSize = 32
		h.Size = UDim2.new(1, 0, 0, 40)
		h.LayoutOrder = 1
		local facts = `{r.mapName}  ·  {Ui.label2(r.mode)}  ·  {Ui.clock(r.seconds or 0)}`
		if r.reason then
			facts ..= `  ·  {r.reason}`
		end
		if r.cheatsUsed then
			facts ..= "  ·  cheats used (not counted)"
		end
		local f = Kit.text(p.content, facts, "small")
		f.LayoutOrder = 2
		local rows = {}
		for _, pl in r.players do
			local s = pl.stats or {}
			table.insert(rows, {
				function(cell: Frame)
					local l = Kit.list(cell, 6, true)
					l.VerticalAlignment = Enum.VerticalAlignment.Center
					Ui.swatch(cell, Ui.color(pl.color), 12)
					Ui.label(cell, pl.name, "label", if pl.user == me then Kit.COLOR.accent else Kit.COLOR.text, 1)
				end,
				Ui.label2(pl.faction),
				tostring(pl.allyTeam),
				if r.outcome == "abandoned" then "–" elseif pl.won then "Won" elseif pl.outAt then `Out at {Ui.clock(pl.outAt)}` else "Lost",
				num(s.unitsBuilt),
				num(s.unitsKilled),
				num(s.unitsLost),
				num(s.damageDealt),
			})
		end
		Kit.table(p.content, {
			{ title = "PLAYER", width = 0.27 },
			{ title = "FACTION", width = 0.1 },
			{ title = "TEAM", width = 0.07 },
			{ title = "RESULT", width = 0.16 },
			{ title = "BUILT", width = 0.09, align = "right" },
			{ title = "KILLED", width = 0.1, align = "right" },
			{ title = "LOST", width = 0.09, align = "right" },
			{ title = "DAMAGE", width = 0.12, align = "right" },
		}, rows, 36, 3)
		local b = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 36))
		b.LayoutOrder = 4
		local bl = Kit.list(b, Kit.SPACE.s, true)
		bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		Ui.button(b, "Back to the room", "primary", close, 170, 34)
	end

	return {
		update = function(v: any)
			local room = v.room
			local r = room and room.results
			if r == nil or seen[r.matchId] then
				return
			end
			-- only once you're back (not while still away in the match)
			for _, m in room.members do
				if m.user == v.me.user and m.away then
					return
				end
			end
			seen[r.matchId] = true
			if open then
				open()
			end
			show(r)
		end,
	}
end

return Results
