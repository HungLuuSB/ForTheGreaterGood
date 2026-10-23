--!strict
-- Home (BAR's landing page): the title over the battle, Quick play (a
-- skirmish against a Normal AI on the first duel map, started at once),
-- the way to the battle rooms, and what's new.

local Net = require("../Net")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Home = {}

local NEWS = {
	{ "Battle rooms are open", "Make a room, pick the map and the rules, add AI, ready up. Public, friends-only or private with a code." },
	{ "Skirmish against the AI", "Easy, Normal or Hard on any map. Quick play starts a 1v1 against a Normal AI right away." },
	{ "Your record", "Every match you finish is kept on your profile: wins, losses and the last 50 games." },
}

function Home.new(frame: Frame, router: any): any
	-- centre: title and the big button
	local centre = Ui.frame(frame, "Centre", UDim2.fromOffset(640, 360), UDim2.new(0.5, -320, 0.42, -180))
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 84)
	title.FontFace = Kit.font(Enum.FontWeight.Bold)
	title.Text = "FOR THE GREATER GOOD"
	title.TextSize = 64
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(240, 242, 246)
	title.Parent = centre
	local tStroke = Instance.new("UIStroke")
	tStroke.Thickness = 2
	tStroke.Transparency = 0.6
	tStroke.Color = Color3.new(0, 0, 0)
	tStroke.Parent = title
	local sub = Kit.text(centre, "Order against Chaos, on land, in the air and at sea", "section", Kit.COLOR.dim)
	sub.Position = UDim2.fromOffset(0, 92)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	local quick = Ui.button(centre, "QUICK PLAY", "go", function()
		local maps = Net.maps
		local first = nil
		for _, m in maps or {} do
			if m.starts == 2 then
				first = m
				break
			end
		end
		Net.send({ op = "quick", mapId = if first then first.id else nil, faction = "order", level = "normal" })
	end, 300, 58)
	quick.Position = UDim2.new(0.5, -150, 0, 160)
	quick.TextSize = 20
	quick.FontFace = Kit.font(Enum.FontWeight.Bold)
	local hint = Kit.text(centre, "1v1 against a Normal AI", "small", Kit.COLOR.dim)
	hint.Position = UDim2.fromOffset(0, 224)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	local more = Ui.frame(centre, "More", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 262))
	local ml = Kit.list(more, Kit.SPACE.m, true)
	ml.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Ui.button(more, "Battle rooms", "ghost", function()
		router.go("Multiplayer")
	end, 150, 34)
	Ui.button(more, "Skirmish", "ghost", function()
		router.go("Skirmish")
	end, 150, 34)

	-- left: news cards
	local news = Ui.frame(frame, "News", UDim2.new(0, 300, 1, -20), UDim2.fromOffset(0, 10))
	Kit.list(news, Kit.SPACE.m)
	for i, n in NEWS do
		local card = Ui.card(news, "Card", UDim2.new(1, 0, 0, 0), nil, 0.15)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.LayoutOrder = i
		Kit.pad(card, Kit.SPACE.l)
		Kit.list(card, Kit.SPACE.xs)
		local h = Kit.text(card, n[1], "section")
		h.LayoutOrder = 1
		local b = Kit.text(card, n[2], "small")
		b.TextWrapped = true
		b.AutomaticSize = Enum.AutomaticSize.Y
		b.Size = UDim2.new(1, 0, 0, 0)
		b.LayoutOrder = 2
	end

	-- right: your record at a glance
	local rec = Ui.card(frame, "Record", UDim2.fromOffset(280, 0), UDim2.new(1, -280, 0, 10), 0.15)
	rec.AutomaticSize = Enum.AutomaticSize.Y
	Kit.pad(rec, Kit.SPACE.l)
	Kit.list(rec, Kit.SPACE.xs)
	Kit.text(rec, "YOUR RECORD", "small", Kit.COLOR.faint).LayoutOrder = 0
	local line1 = Kit.text(rec, "", "section")
	line1.LayoutOrder = 1
	local line2 = Kit.text(rec, "", "small")
	line2.LayoutOrder = 2
	Ui.button(rec, "Profile", "ghost", function()
		router.go("Profile")
	end, 100, 28).LayoutOrder = 3

	return {
		update = function(v: any)
			local p = v.profile
			if p then
				local s = p.summary
				line1.Text = `{s.wins} won · {s.losses} lost`
				line2.Text = if s.winRate then string.format("%d matches · %d%% win rate", s.played, math.floor(s.winRate * 100 + 0.5)) else `{s.played} matches played`
			else
				line1.Text = "Loading..."
				line2.Text = ""
			end
		end,
	}
end

return Home
