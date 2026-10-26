--!strict
-- The loading screen while a match starts (BAR's: the battle behind, a tip,
-- a long progress bar; the key art with parallax layers once the models
-- stream delivers it, docs/contracts/key-art.md): reserving a server, then
-- teleporting; also while moving to a room on another lobby server (L-15).
-- In Studio the Studio stand-in match runs here instead (L-6), with its
-- controls: end the match now, make the "server" die, or go back early.
-- Each showing takes the next key art in turn, so every approved art
-- (1 "Commander's stand" once it's listed, 2 "Volley", 3 "Converging")
-- comes round.

local RunService = game:GetService("RunService")

local KeyArt = require("@client/UI/KeyArt")
local Meshes = require("@shared/Defs/Meshes/Registry")
local Net = require("../Net")
local Scene = require("../Scene")
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

Loading.TIPS = TIPS -- the joining screen's too (Boot)

local OLIVE = Color3.fromRGB(150, 160, 70)

-- The key arts KeyArt shows here (approved; in review too in Studio), by name.
local function artNames(): { string }
	local out = {}
	local all = (Meshes :: any).keyArt
	if type(all) == "table" then
		for name, e in all do
			if type(e) == "table" and (e.status == "approved" or (e.status == "review" and RunService:IsStudio())) then
				table.insert(out, name)
			end
		end
	end
	table.sort(out)
	return out
end

function Loading.new(gui: ScreenGui): any
	local root = Ui.frame(gui, "Loading", UDim2.fromScale(1, 1))
	root.ZIndex = 50
	root.Visible = false
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0.45
	root.Active = true
	-- the models stream's layered key art when there is some (L-13); else
	-- the live battle shows through the veil
	local art = KeyArt.new(root, 40)
	local title = Kit.text(root, "", "title", Color3.new(1, 1, 1))
	title.TextSize = 38
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.12, 0)
	title.Size = UDim2.new(0.8, 0, 0, 50)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 51
	local sub = Kit.text(root, "", "section", Color3.fromRGB(214, 218, 226))
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
	-- a soft dark outline keeps the text readable over bright key art
	for _, label in { title, sub, tip } do
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = Color3.new(0, 0, 0)
		outline.Thickness = 1.5
		outline.Transparency = 0.35
		outline.Parent = label
	end
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
	Ui.button(controls, "Leave early", "dark", function()
		Net.send({ op = "standIn", action = "leave" })
	end, 150, 36)
	for _, d in controls:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 52
		end
	end

	local tipIndex = math.random(1, #TIPS)
	local names = artNames()
	local artIndex = math.random(1, math.max(1, #names))
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
			elseif mode == "teleport" or mode == "hop" then
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
			if Net.hop then
				newMode = "hop"
			elseif room and room.phase == "starting" then
				newMode = "starting"
			elseif room and room.phase == "match" and mine and mine.away then
				newMode = if Net.standIn then "standIn" else "teleport"
			end
			if newMode ~= mode then
				if mode == nil and newMode ~= nil then
					artIndex = artIndex % math.max(1, #names) + 1
					local shown = art.show(names[artIndex])
					root.BackgroundTransparency = if shown then 1 else 0.45
					Scene.setCovered(shown) -- the art is opaque: pause the battle behind it
				elseif newMode == nil then
					art.hide()
					Scene.setCovered(false)
				end
				mode = newMode
				started = os.clock()
				tipIndex = tipIndex % #TIPS + 1
			end
			root.Visible = mode ~= nil
			if mode == "hop" then
				title.Text = Net.hop.roomName
				sub.Text = "Moving to the room's lobby server..."
				barText.Text = "Teleporting"
				tip.Text = TIPS[tipIndex]
				controls.Visible = false
				return true
			end
			if mode == nil or room == nil then
				return false
			end
			local map = Net.map(room.settings.mapId)
			title.Text = `{Ui.modeName(room.settings.mode, #room.slots)} on {if map then map.name else room.mapName}`
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
