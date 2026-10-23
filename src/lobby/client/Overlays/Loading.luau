--!strict
-- The loading screen while a match starts (BAR's: the battle behind, a tip,
-- a long progress bar): reserving a server, then teleporting. In Studio the
-- Studio stand-in match runs here instead (L-6), with its controls: end the
-- match now, make the "server" die, or go back early.

local Net = require("../Net")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Loading = {}

local TIPS = {
	"Radar shows where enemies are, not exactly: radar-guided shots miss more than sighted ones.",
	"Builders can help a factory: right-click your factory with builders selected.",
	"Ctrl + right click keeps a group together at its slowest unit's speed.",
	"Shells and beams stop at a shield dome: get under it, or wear its charge down first.",
	"Your Command Vehicle ends the match when it dies (Command Ends): keep it out of artillery range.",
	"Jammers hide units from radar; burn-through gets closer than the jammer wants.",
}

local OLIVE = Color3.fromRGB(150, 160, 70)

function Loading.new(gui: ScreenGui): any
	local root = Ui.frame(gui, "Loading", UDim2.fromScale(1, 1))
	root.ZIndex = 50
	root.Visible = false
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0.45
	root.Active = true
	local title = Kit.text(root, "", "title", Color3.new(1, 1, 1))
	title.TextSize = 38
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.12, 0)
	title.Size = UDim2.new(0.8, 0, 0, 50)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 51
	local sub = Kit.text(root, "", "section", Kit.COLOR.dim)
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0.12, 54)
	sub.Size = UDim2.new(0.8, 0, 0, 30)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = 51
	local tip = Kit.text(root, "", "section", Color3.new(1, 1, 1))
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.new(0.5, 0, 1, -110)
	tip.Size = UDim2.new(0.7, 0, 0, 50)
	tip.TextWrapped = true
	tip.TextXAlignment = Enum.TextXAlignment.Center
	tip.ZIndex = 51
	local track = Ui.frame(root, "Bar", UDim2.new(0.6, 0, 0, 24), UDim2.new(0.2, 0, 1, -80))
	track.BackgroundColor3 = Color3.fromRGB(40, 42, 46)
	track.BackgroundTransparency = 0.1
	track.ZIndex = 51
	local fill = Ui.frame(track, "Fill", UDim2.fromScale(0, 1))
	fill.BackgroundColor3 = OLIVE
	fill.BackgroundTransparency = 0
	fill.ZIndex = 52
	local barText = Kit.text(track, "", "small", Color3.new(1, 1, 1))
	barText.Size = UDim2.fromScale(1, 1)
	barText.TextXAlignment = Enum.TextXAlignment.Center
	barText.ZIndex = 53

	local controls = Ui.frame(root, "StandIn", UDim2.new(0, 560, 0, 40), UDim2.new(0.5, -280, 0.12, 100))
	controls.ZIndex = 51
	local cl = Kit.list(controls, Kit.SPACE.s, true)
	cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Ui.button(controls, "End match now", "go", function()
		Net.send({ op = "standIn", action = "finish" })
	end, 170, 36)
	Ui.button(controls, "Server dies", "stop", function()
		Net.send({ op = "standIn", action = "die" })
	end, 150, 36)
	Ui.button(controls, "Leave early", "ghost", function()
		Net.send({ op = "standIn", action = "leave" })
	end, 150, 36)
	for _, d in controls:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 52
		end
	end

	local tipIndex = math.random(1, #TIPS)
	local mode: string? = nil
	local started = 0

	task.spawn(function()
		while true do
			task.wait(0.1)
			if mode == "starting" then
				-- an honest guess: reserving takes a few seconds
				local k = math.min(0.6, (os.clock() - started) / 8)
				fill.Size = UDim2.fromScale(k, 1)
			elseif mode == "standIn" and Net.standIn then
				local left = math.max(0, Net.standIn.endsAt - os.clock())
				barText.Text = `Stand-in match: ends in {Ui.clock(left)}`
				local total = 20
				fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
			elseif mode == "teleport" then
				fill.Size = UDim2.fromScale(math.min(0.95, 0.6 + (os.clock() - started) / 30), 1)
			end
		end
	end)

	-- update returns whether the screen shows (the pages hide behind it)
	return {
		update = function(v: any): boolean
			local room = v.room
			local mine = nil
			if room then
				for _, m in room.members do
					if m.user == v.me.user then
						mine = m
					end
				end
			end
			local newMode: string? = nil
			if room and room.phase == "starting" then
				newMode = "starting"
			elseif room and room.phase == "match" and mine and mine.away then
				newMode = if Net.standIn then "standIn" else "teleport"
			end
			if newMode ~= mode then
				mode = newMode
				started = os.clock()
				tipIndex = tipIndex % #TIPS + 1
			end
			root.Visible = mode ~= nil
			if mode == nil or room == nil then
				return false
			end
			local map = Net.map(room.settings.mapId)
			title.Text = `{Ui.label2(room.settings.mode)} on {if map then map.name else room.mapName}`
			tip.Text = TIPS[tipIndex]
			controls.Visible = mode == "standIn"
			if mode == "starting" then
				sub.Text = "Reserving a match server..."
				barText.Text = "Preparing the match"
			elseif mode == "teleport" then
				sub.Text = "Teleporting to the match server..."
				barText.Text = "Teleporting"
			else
				sub.Text = "Studio can't teleport: this stands in for the match server"
			end
			return true
		end,
	}
end

return Loading
