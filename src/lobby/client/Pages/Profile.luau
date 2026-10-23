--!strict
-- The profile page (L-8): your avatar and name, your totals, and the match
-- history the lobby keeps (newest first, up to 50). Matches with cheats and
-- spectated ones are listed but not counted.

local Players = game:GetService("Players")

local Net = require("../Net")
local Ui = require("../Ui")

local Kit = Ui.Kit

local ProfilePage = {}

local RESULT_COLOR = {
	won = Color3.fromRGB(132, 222, 140),
	lost = Color3.fromRGB(236, 104, 92),
	draw = Color3.fromRGB(200, 200, 200),
	abandoned = Color3.fromRGB(150, 156, 168),
	spectated = Color3.fromRGB(150, 156, 168),
}

local function ago(t: number): string
	local s = os.time() - t
	if s < 3600 then
		return `{math.max(1, s // 60)} min ago`
	elseif s < 86400 then
		return `{s // 3600} h ago`
	end
	return os.date("%Y-%m-%d", t)
end

function ProfilePage.new(frame: Frame, _router: any): any
	local player = Players.LocalPlayer
	local head = Ui.card(frame, "Head", UDim2.new(1, 0, 0, 132), nil, 0.12)
	Kit.pad(head, Kit.SPACE.xl, Kit.SPACE.l)
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
	avatar.Size = UDim2.fromOffset(96, 96)
	avatar.Parent = head
	Ui.corner(avatar, 48)
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then
			avatar.Image = url
		end
	end)
	local name = Kit.text(head, player.DisplayName, "title")
	name.TextSize = 34
	name.Position = UDim2.fromOffset(116, 6)
	name.Size = UDim2.new(1, -116, 0, 42)
	local since = Kit.text(head, `@{player.Name}`, "small")
	since.Position = UDim2.fromOffset(118, 50)

	local tiles = Ui.frame(head, "Tiles", UDim2.new(0, 640, 1, 0), UDim2.new(1, -640, 0, 0))
	local tl = Kit.list(tiles, Kit.SPACE.m, true)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local values: { [string]: TextLabel } = {}
	for i, k in { "Played", "Won", "Lost", "Win rate", "Favourite", "Abandoned" } do
		local t = Ui.frame(tiles, k, UDim2.fromOffset(96, 80))
		t.LayoutOrder = i
		local v = Kit.text(t, "–", "title")
		v.TextSize = 28
		v.Size = UDim2.new(1, 0, 0, 44)
		v.TextXAlignment = Enum.TextXAlignment.Center
		local l = Kit.text(t, string.upper(k), "small", Kit.COLOR.faint)
		l.Position = UDim2.fromOffset(0, 44)
		l.TextXAlignment = Enum.TextXAlignment.Center
		values[k] = v
	end

	local hist = Ui.card(frame, "History", UDim2.new(1, 0, 1, -148), UDim2.fromOffset(0, 148), 0.12)
	Kit.pad(hist, Kit.SPACE.l)
	local ht = Kit.text(hist, "Match history", "section")
	ht.Size = UDim2.new(1, 0, 0, 28)
	local listHolder = Ui.frame(hist, "List", UDim2.new(1, 0, 1, -36), UDim2.fromOffset(0, 36))
	local scroll = Kit.scroll(listHolder)

	return {
		update = function(v: any)
			local p = v.profile
			if p == nil then
				return
			end
			local s = p.summary
			values["Played"].Text = tostring(s.played)
			values["Won"].Text = tostring(s.wins)
			values["Lost"].Text = tostring(s.losses)
			values["Win rate"].Text = if s.winRate then `{math.floor(s.winRate * 100 + 0.5)}%` else "–"
			values["Favourite"].Text = if s.favourite then Ui.label2(s.favourite) else "–"
			values["Abandoned"].Text = tostring(s.abandoned)
			Ui.clear(scroll)
			local rows = {}
			for _, e in p.history do
				table.insert(rows, {
					function(cell: Frame)
						local l = Kit.text(cell, string.upper(e.result), "label", RESULT_COLOR[e.result] or Kit.COLOR.text)
						l.Size = UDim2.fromScale(1, 1)
						l.FontFace = Kit.font(Enum.FontWeight.SemiBold)
					end,
					e.mapName,
					Ui.label2(e.mode) .. (if e.ai > 0 then ` · {e.ai} AI` else ""),
					if e.faction then Ui.label2(e.faction) else "–",
					if e.seconds > 0 then Ui.clock(e.seconds) else "–",
					`{e.players}` .. (if e.cheats then " · cheats" else ""),
					ago(e.at),
				})
			end
			if #rows == 0 then
				local empty = Kit.text(scroll, "No matches yet. Finish one and it shows here.", "label", Kit.COLOR.dim)
				empty.Size = UDim2.new(1, 0, 0, 60)
				empty.TextXAlignment = Enum.TextXAlignment.Center
				return
			end
			Kit.table(scroll, {
				{ title = "RESULT", width = 0.13 },
				{ title = "MAP", width = 0.19 },
				{ title = "MODE", width = 0.2 },
				{ title = "FACTION", width = 0.12 },
				{ title = "LENGTH", width = 0.1 },
				{ title = "PLAYERS", width = 0.12 },
				{ title = "WHEN", width = 0.14 },
			}, rows, 34)
		end,
	}
end

return ProfilePage
