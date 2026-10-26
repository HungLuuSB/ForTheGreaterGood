--!strict
-- A small "IDLE" tag over each idle builder (C-158, BAR's idle mark;
-- Core/Idle): a screen-space layer like HealthBars (no BillboardGuis),
-- placed each frame over the unit where the renderer drew it. Hidden at
-- strategic zoom with the models. A placeholder look. Over an own unit
-- counting down to self-destruct (G13, protocol 39), the seconds left in red.

local Players = game:GetService("Players")

local Kit = require("../UI/Kit")
local World = require("../Core/World")

local IdleMarks = {}

IdleMarks.LIFT = 11 -- studs above the unit's drawn spot, clear of the health bar

export type Marks = { gui: ScreenGui, pool: { TextLabel }, counts: { TextLabel } }

function IdleMarks.new(): Marks
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggIdleMarks"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- positions come from WorldToViewportPoint
	gui.DisplayOrder = -1 -- under the HUD panels
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, pool = {}, counts = {} }
end

local function tag(m: Marks, i: number): TextLabel
	local t = m.pool[i]
	if t == nil then
		local made = Instance.new("TextLabel")
		made.Name = "Idle"
		made.AnchorPoint = Vector2.new(0.5, 1)
		made.Size = UDim2.fromOffset(32, 13)
		made.BackgroundColor3 = Kit.COLOR.panel
		made.BackgroundTransparency = 0.2
		made.BorderSizePixel = 0
		made.Font = Enum.Font.GothamBold
		made.TextSize = 10
		made.Text = "IDLE"
		made.TextColor3 = Kit.COLOR.accent
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 3)
		c.Parent = made
		made.Parent = m.gui
		m.pool[i] = made
		t = made
	end
	return t :: TextLabel
end

-- Once a frame, after the renderer placed the units.
function IdleMarks.step(m: Marks, world: World.World, idle: { number }, hidden: boolean, cam: Camera)
	local n = 0
	if not hidden then
		for _, id in idle do
			local u = world.units[id]
			if u and u.rx and u.ry and u.rz then
				local v, visible = cam:WorldToViewportPoint(Vector3.new(u.rx, u.ry + IdleMarks.LIFT, u.rz))
				if visible and v.Z > 0 then
					n += 1
					local t = tag(m, n)
					t.Position = UDim2.fromOffset(v.X, v.Y)
					t.Visible = true
				end
			end
		end
	end
	for i = n + 1, #m.pool do
		m.pool[i].Visible = false
	end
end

local COUNT_RED = Color3.fromRGB(235, 70, 60)

local function count(m: Marks, i: number): TextLabel
	local t = m.counts[i]
	if t == nil then
		local made = Instance.new("TextLabel")
		made.Name = "SelfDestruct"
		made.AnchorPoint = Vector2.new(0.5, 1)
		made.Size = UDim2.fromOffset(26, 22)
		made.BackgroundTransparency = 1
		made.Font = Enum.Font.GothamBlack
		made.TextSize = 20
		made.TextColor3 = COUNT_RED
		made.TextStrokeTransparency = 0.2
		made.Parent = m.gui
		m.counts[i] = made
		t = made
	end
	return t :: TextLabel
end

-- The self-destruct countdowns (G13): whole seconds left, running on from
-- the server's last count (its u8 seconds, set at `selfDestructAt`).
function IdleMarks.countdowns(m: Marks, world: World.World, renderTick: number, hidden: boolean, cam: Camera)
	local n = 0
	if not hidden then
		for _, u in world.units do
			local left = u.selfDestruct
			if left and left > 0 and u.rx and u.ry and u.rz then
				local shown = math.max(1, math.ceil(left - (renderTick - (u.selfDestructAt or renderTick)) / 15))
				local v, visible = cam:WorldToViewportPoint(Vector3.new(u.rx, u.ry + IdleMarks.LIFT + 3, u.rz))
				if visible and v.Z > 0 then
					n += 1
					local t = count(m, n)
					t.Text = tostring(shown)
					t.Position = UDim2.fromOffset(v.X, v.Y)
					t.Visible = true
				end
			end
		end
	end
	for i = n + 1, #m.counts do
		m.counts[i].Visible = false
	end
end

return IdleMarks
