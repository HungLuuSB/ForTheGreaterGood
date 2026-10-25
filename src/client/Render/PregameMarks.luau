--!strict
-- The pre-game on the map (C-218, net.md 9b): each side's spawn box as an
-- outline on the ground in its side's colour, the map's start hints as
-- discs, every player's pick as a beam with a disc of StartAreas.SPACING
-- (no one else may start inside it) and its name over it, and under the
-- cursor the Commander's spot, green where the viewer may pick, red where
-- not. Drawn only while World.pregame is active. A placeholder look.

local Players = game:GetService("Players")

local StartAreas = require("@shared/Match/StartAreas")
local Kit = require("../UI/Kit")
local Pregame = require("../Core/Pregame")
local World = require("../Core/World")
local TeamColors = require("./TeamColors")

local PregameMarks = {}

PregameMarks.SEGMENT = 16 -- studs per outline piece (each follows the ground)
PregameMarks.BEAM = 60 -- studs: a pick's beam
PregameMarks.LABEL_LIFT = 66 -- studs above the ground: a pick's name

local OK = Color3.fromRGB(96, 204, 122)
local NO = Color3.fromRGB(216, 86, 76)

export type Marks = {
	folder: Folder,
	areas: Folder, -- boxes and hints
	picks: Folder,
	hover: Part,
	gui: ScreenGui,
	labels: { [number]: TextLabel }, -- by player
	boxLabels: { TextLabel },
	areasKey: string?,
	picksKey: string?,
}

local function part(parent: Instance, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Parent = parent
	return p
end

-- A flat disc of `diameter` on the ground at (x, z).
local function disc(parent: Instance, world: World.World, x: number, z: number, diameter: number, color: Color3, transparency: number): Part
	local p = part(parent, color, transparency)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, diameter, diameter)
	p.CFrame = CFrame.new(x, World.groundY(world, x, z, true) + 0.4, z) * CFrame.Angles(0, 0, math.pi / 2)
	return p
end

local function label(parent: Instance, size: number): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 1)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromOffset(0, size + 8)
	t.BackgroundColor3 = Kit.COLOR.panel
	t.BackgroundTransparency = 0.25
	t.BorderSizePixel = 0
	t.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	t.TextSize = size
	t.TextColor3 = Kit.COLOR.text
	t.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = t
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = t
	t.Parent = parent
	return t
end

function PregameMarks.new(): Marks
	local folder = Instance.new("Folder")
	folder.Name = "FtggPregame"
	local areas = Instance.new("Folder")
	areas.Name = "Areas"
	areas.Parent = folder
	local picks = Instance.new("Folder")
	picks.Name = "Picks"
	picks.Parent = folder
	local hover = part(folder, OK, 0.35)
	hover.Name = "Hover"
	hover.Shape = Enum.PartType.Cylinder
	hover.Size = Vector3.new(0.3, 16, 16)
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggPregameMarks"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- positions come from WorldToViewportPoint
	gui.DisplayOrder = -1 -- under the HUD panels
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { folder = folder, areas = areas, picks = picks, hover = hover, gui = gui, labels = {}, boxLabels = {}, areasKey = nil, picksKey = nil }
end

-- A player's name in the match list, else "Player n".
function PregameMarks.nameOf(player: number): string
	for _, p in TeamColors.players() do
		if p.id == player and p.name then
			return p.name
		end
	end
	return `Player {player}`
end

-- A side's colour: its first player's, as this viewer sees it.
local function sideColor(ally: number): Color3
	local first: number? = nil
	for _, p in TeamColors.players() do
		if p.allyTeam == ally and (first == nil or p.id < first) then
			first = p.id
		end
	end
	return if first then TeamColors.ofPlayer(first) else Color3.fromRGB(200, 200, 200)
end

local function outline(parent: Instance, world: World.World, box: StartAreas.Box, color: Color3)
	local corners = { { box[1], box[2] }, { box[3], box[2] }, { box[3], box[4] }, { box[1], box[4] } }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local n = math.max(1, math.ceil(len / PregameMarks.SEGMENT))
		for k = 0, n - 1 do
			local x0, z0 = a[1] + (b[1] - a[1]) * k / n, a[2] + (b[2] - a[2]) * k / n
			local x1, z1 = a[1] + (b[1] - a[1]) * (k + 1) / n, a[2] + (b[2] - a[2]) * (k + 1) / n
			local p0 = Vector3.new(x0, World.groundY(world, x0, z0, true) + 0.8, z0)
			local p1 = Vector3.new(x1, World.groundY(world, x1, z1, true) + 0.8, z1)
			local seg = part(parent, color, 0.15)
			seg.Size = Vector3.new(2, 0.6, (p1 - p0).Magnitude + 1)
			seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		end
	end
end

local function drawAreas(m: Marks, world: World.World, areas: Pregame.Areas)
	m.areas:ClearAllChildren()
	for _, t in m.boxLabels do
		t:Destroy()
	end
	table.clear(m.boxLabels)
	for _, ally in areas.sides.allies do
		local color = sideColor(ally)
		outline(m.areas, world, areas.boxes[ally], color)
		local t = label(m.gui, 13)
		t.Name = `Box{ally}`
		t.TextColor3 = color
		t.Text = if world.me.player ~= 0 and ally == world.me.allyTeam then "YOUR START AREA" else `TEAM {ally}`
		t:SetAttribute("ally", ally)
		table.insert(m.boxLabels, t)
	end
	for _, h in areas.hints do
		disc(m.areas, world, h.x, h.z, 14, sideColor(h.ally), 0.55)
	end
end

local function drawPicks(m: Marks, world: World.World)
	m.picks:ClearAllChildren()
	for pid, t in m.labels do
		if world.pregame.picks[pid] == nil then
			t:Destroy()
			m.labels[pid] = nil
		end
	end
	for pid, p in world.pregame.picks do
		local t = m.labels[pid]
		if p.x == nil or p.z == nil then
			if t then
				t.Visible = false
			end
			continue
		end
		local x, z = p.x :: number, p.z :: number
		local color = TeamColors.ofPlayer(pid)
		local y = World.groundY(world, x, z, true)
		local beam = part(m.picks, color, 0.3)
		beam.Size = Vector3.new(1.5, PregameMarks.BEAM, 1.5)
		beam.CFrame = CFrame.new(x, y + PregameMarks.BEAM / 2, z)
		disc(m.picks, world, x, z, StartAreas.SPACING * 2, color, 0.85)
		disc(m.picks, world, x, z, 16, color, 0.2)
		if t == nil then
			t = label(m.gui, 14)
			m.labels[pid] = t
		end
		local tag = t :: TextLabel
		tag.Name = `Pick{pid}`
		tag.TextColor3 = color
		local ready = Pregame.isReady(world, pid)
		tag.Text = PregameMarks.nameOf(pid) .. (if pid == world.me.player then " (you)" else "") .. (if ready then "  ✓ READY" else "")
		tag:SetAttribute("x", x)
		tag:SetAttribute("y", y + PregameMarks.LABEL_LIFT)
		tag:SetAttribute("z", z)
	end
end

local function place(t: TextLabel, cam: Camera, at: Vector3)
	local v, visible = cam:WorldToViewportPoint(at)
	t.Visible = visible and v.Z > 0
	t.Position = UDim2.fromOffset(v.X, v.Y)
end

-- Once a frame. `hover` is the ground point under the cursor.
function PregameMarks.step(m: Marks, world: World.World, areas: Pregame.Areas?, hover: Vector3?, cam: Camera)
	local pg = world.pregame
	if not pg.active or areas == nil then
		if m.folder.Parent then
			m.folder.Parent = nil
			m.gui.Enabled = false
			m.areasKey, m.picksKey = nil, nil -- drawn again on the next pre-game
		end
		return
	end
	local areasKey = `{areas.key}/{TeamColors.version}/{world.me.player}`
	if areasKey ~= m.areasKey then
		m.areasKey = areasKey
		drawAreas(m, world, areas)
	end
	local picksKey = `{pg.version}/{TeamColors.version}`
	if picksKey ~= m.picksKey then
		m.picksKey = picksKey
		drawPicks(m, world)
	end
	m.folder.Parent = workspace
	m.gui.Enabled = true
	for _, t in m.labels do
		local x, y, z = t:GetAttribute("x"), t:GetAttribute("y"), t:GetAttribute("z")
		if type(x) == "number" and type(y) == "number" and type(z) == "number" then
			place(t, cam, Vector3.new(x, y, z))
		end
	end
	for _, t in m.boxLabels do
		local box = areas.boxes[t:GetAttribute("ally") :: number]
		if box then
			local x, z = (box[1] + box[3]) / 2, box[2] + 10 -- the box's north edge
			place(t, cam, Vector3.new(x, World.groundY(world, x, z, true) + 4, z))
		end
	end
	if hover and world.me.player ~= 0 then
		local ok = Pregame.canPick(world, areas, hover.X, hover.Z)
		m.hover.Color = if ok then OK else NO
		m.hover.CFrame = CFrame.new(hover.X, World.groundY(world, hover.X, hover.Z, true) + 0.5, hover.Z) * CFrame.Angles(0, 0, math.pi / 2)
		m.hover.Transparency = 0.35
	else
		m.hover.Transparency = 1
	end
end

return PregameMarks
