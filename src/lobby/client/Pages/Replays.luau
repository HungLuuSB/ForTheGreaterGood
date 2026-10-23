--!strict
-- Replays (L-11): your recent matches, each with whether a replay can be
-- watched. Watching needs the match place's replay viewer behind a reserved
-- server (contract section 8, a request to the client stream), so until
-- then the list shows the matches and says where replays are saved.

local Ui = require("../Ui")

local Kit = Ui.Kit

local Replays = {}

function Replays.new(frame: Frame, _router: any): any
	local title = Kit.text(frame, "Replays", "title")
	title.TextSize = 40
	title.Size = UDim2.new(0, 400, 0, 52)
	local note = Kit.text(frame, "Save a replay from a match's results screen. Watching saved replays from the lobby opens once the match place can play them on a reserved server.", "small", Kit.COLOR.dim)
	note.Position = UDim2.fromOffset(2, 52)
	note.Size = UDim2.new(1, 0, 0, 20)
	local card = Ui.card(frame, "List", UDim2.new(1, 0, 1, -90), UDim2.fromOffset(0, 90), 0.12)
	Kit.pad(card, Kit.SPACE.l)
	local scroll = Kit.scroll(card)
	return {
		update = function(v: any)
			Ui.clear(scroll)
			local rows = {}
			for _, e in (v.profile and v.profile.history) or {} do
				if e.result ~= "abandoned" then
					table.insert(rows, {
						os.date("%Y-%m-%d %H:%M", e.at),
						e.mapName,
						Ui.label2(e.mode),
						if e.seconds > 0 then Ui.clock(e.seconds) else "–",
						string.upper(string.sub(e.result, 1, 1)) .. string.sub(e.result, 2),
						function(cell: Frame)
							local b = Ui.button(cell, "Watch", "ghost", function() end, 90, 26)
							b.Position = UDim2.new(0, 0, 0.5, -13)
							Ui.enable(b, false)
						end,
					})
				end
			end
			if #rows == 0 then
				local empty = Kit.text(scroll, "No matches to replay yet.", "label", Kit.COLOR.dim)
				empty.Size = UDim2.new(1, 0, 0, 60)
				empty.TextXAlignment = Enum.TextXAlignment.Center
				return
			end
			Kit.table(scroll, {
				{ title = "PLAYED", width = 0.2 },
				{ title = "MAP", width = 0.2 },
				{ title = "MODE", width = 0.16 },
				{ title = "LENGTH", width = 0.12 },
				{ title = "RESULT", width = 0.14 },
				{ title = "", width = 0.18 },
			}, rows, 38)
		end,
	}
end

return Replays
