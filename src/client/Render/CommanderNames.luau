--!strict
-- Each Commander's player name over it in game (the user, C-218): a
-- screen-space layer like IdleMarks (no BillboardGuis), placed each frame
-- over the Commander where the renderer drew it, in the player's colour.
-- Names come from the match's player list (Render/TeamColors.players).
-- Hidden at strategic zoom with the models.

local Players = game:GetService("Players")

local Kit = require("../UI/Kit")
local World = require("../Core/World")
local TeamColors = require("./TeamColors")

local CommanderNames = {}

CommanderNames.LIFT = 11 -- studs above the drawn spot (IdleMarks.LIFT) ...
CommanderNames.ABOVE = 15 -- ... then pixels higher: stacked over the idle tag at any zoom

export type Names = { gui: ScreenGui, pool: { TextLabel } }

function CommanderNames.new(): Names
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggCommanderNames"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- positions come from WorldToViewportPoint
	gui.DisplayOrder = -1 -- under the HUD panels
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, pool = {} }
end

local function tag(n: Names, i: number): TextLabel
	local t = n.pool[i]
	if t == nil then
		local made = Instance.new("TextLabel")
		made.Name = "Commander"
		made.AnchorPoint = Vector2.new(0.5, 1)
		made.AutomaticSize = Enum.AutomaticSize.X
		made.Size = UDim2.fromOffset(0, 16)
		made.BackgroundTransparency = 1
		made.FontFace = Kit.font(Enum.FontWeight.SemiBold)
		made.TextSize = 13
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.3
		stroke.Thickness = 1.5
		stroke.Parent = made
		made.Parent = n.gui
		n.pool[i] = made
		t = made
	end
	return t :: TextLabel
end

-- Once a frame, after the renderer placed the units.
function CommanderNames.step(n: Names, world: World.World, hidden: boolean, cam: Camera)
	local count = 0
	if not hidden then
		local names: { [number]: string } = {}
		for _, p in TeamColors.players() do
			names[p.team] = p.name or `Player {p.id}`
		end
		for _, u in world.units do
			local def = World.def(world, u)
			if u.rx and u.ry and u.rz and def and table.find(def.categories or {}, "COMMANDER") then
				local v, visible = cam:WorldToViewportPoint(Vector3.new(u.rx, u.ry + CommanderNames.LIFT, u.rz))
				if visible and v.Z > 0 then
					count += 1
					local t = tag(n, count)
					t.Text = names[u.team] or `Team {u.team}`
					t.TextColor3 = TeamColors.of(u.team)
					t.Position = UDim2.fromOffset(v.X, v.Y - CommanderNames.ABOVE)
					t.Visible = true
				end
			end
		end
	end
	for i = count + 1, #n.pool do
		n.pool[i].Visible = false
	end
end

return CommanderNames
