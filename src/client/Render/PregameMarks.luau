--!strict
-- The pre-game on the map (C-218, net.md 9b; BAR's start screen, the
-- user's reference): each side's spawn box filled on the ground, the
-- viewer's green and the others red (spectators: each side in its first
-- player's colour); the map's start hints as faint discs; on every pick
-- that player's Commander (its faction's model, in its colour) with a disc
-- of StartAreas.SPACING (no one else may start inside it) and its name;
-- under the cursor the Commander's spot, green where the viewer may pick,
-- red where not. Drawn only while World.pregame is active.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local StartAreas = require("@shared/Match/StartAreas")
local Kit = require("../UI/Kit")
local Pregame = require("../Core/Pregame")
local World = require("../Core/World")
local MeshModels = require("./MeshModels")
local Models = require("./Models")
local TeamColors = require("./TeamColors")

local PregameMarks = {}

PregameMarks.TILES = 24 -- a box's fill: at most this many tiles along its longer side
PregameMarks.MIN_TILE = 16 -- studs
PregameMarks.LABEL_LIFT = 26 -- studs above the ground: a pick's name

PregameMarks.OWN = Color3.fromRGB(70, 190, 80) -- BAR: your area green
PregameMarks.ENEMY = Color3.fromRGB(205, 70, 62) -- the others red
local OK = Color3.fromRGB(96, 204, 122)
local NO = Color3.fromRGB(216, 86, 76)

export type Marks = {
	folder: Folder,
	areas: Folder, -- fills and hints
	picks: Folder,
	hover: Part,
	gui: ScreenGui,
	labels: { [number]: TextLabel }, -- by player
	areasKey: string?,
	picksKey: string?,
}

local function part(parent: Instance, color: Color3, transparency: number, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Parent = parent
	return p
end

-- A flat disc of `diameter` on the ground at (x, z).
local function disc(parent: Instance, world: World.World, x: number, z: number, diameter: number, color: Color3, transparency: number, material: Enum.Material?): Part
	local p = part(parent, color, transparency, material)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, diameter, diameter)
	p.CFrame = CFrame.new(x, World.groundY(world, x, z, true) + 0.7, z) * CFrame.Angles(0, 0, math.pi / 2)
	return p
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
	return { folder = folder, areas = areas, picks = picks, hover = hover, gui = gui, labels = {}, areasKey = nil, picksKey = nil }
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

-- A side's fill: green for the viewer's, red for the others; a spectator
-- sees each side in its first player's colour.
local function sideColor(world: World.World, ally: number): Color3
	if world.me.player ~= 0 then
		return if ally == world.me.allyTeam then PregameMarks.OWN else PregameMarks.ENEMY
	end
	local first: number? = nil
	for _, p in TeamColors.players() do
		if p.allyTeam == ally and (first == nil or p.id < first) then
			first = p.id
		end
	end
	return if first then TeamColors.ofPlayer(first) else Color3.fromRGB(200, 200, 200)
end

-- The box filled with tiles, each laid on the ground under its corners.
local function fill(parent: Instance, world: World.World, box: StartAreas.Box, color: Color3)
	local w, d = box[3] - box[1], box[4] - box[2]
	local tile = math.max(PregameMarks.MIN_TILE, math.max(w, d) / PregameMarks.TILES)
	local nx, nz = math.max(1, math.ceil(w / tile)), math.max(1, math.ceil(d / tile))
	local tx, tz = w / nx, d / nz
	local function at(x: number, z: number): Vector3
		return Vector3.new(x, World.groundY(world, x, z, true) + 0.6, z)
	end
	for i = 0, nx - 1 do
		for k = 0, nz - 1 do
			local x0, z0 = box[1] + i * tx, box[2] + k * tz
			local p00, p10, p01, p11 = at(x0, z0), at(x0 + tx, z0), at(x0, z0 + tz), at(x0 + tx, z0 + tz)
			local right = ((p10 - p00) + (p11 - p01)).Unit
			local forward = ((p01 - p00) + (p11 - p10)).Unit
			local up = forward:Cross(right).Unit
			local t = part(parent, color, 0.6, Enum.Material.SmoothPlastic)
			t.Size = Vector3.new(tx, 0.3, tz) -- edge to edge: overlaps would show as darker seams
			t.CFrame = CFrame.fromMatrix((p00 + p10 + p01 + p11) / 4, right, up)
		end
	end
end

local function drawAreas(m: Marks, world: World.World, areas: Pregame.Areas)
	m.areas:ClearAllChildren()
	for _, ally in areas.sides.allies do
		local box = areas.boxes[ally]
		if box then
			fill(m.areas, world, box, sideColor(world, ally))
		end
	end
	for _, h in areas.hints do
		disc(m.areas, world, h.x, h.z, 12, Color3.new(1, 1, 1), 0.7, Enum.Material.SmoothPlastic)
	end
end

-- The player's Commander, in its colour, standing at (x, z).
local function commander(parent: Instance, world: World.World, player: number, x: number, z: number, color: Color3)
	local def = world.defs.units[Pregame.COMMANDER[Pregame.factionOf(world, player)]]
	if def == nil then
		return
	end
	local model = Models.template(def):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			if CollectionService:HasTag(d, "TeamColor") then
				d.Color = color
			end
		end
	end
	local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
	model:PivotTo(CFrame.new(x, World.groundY(world, x, z, true), z) * CFrame.Angles(0, math.pi, 0) * offset)
	model.Parent = parent
end

local function label(parent: Instance): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 1)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromOffset(0, 20)
	t.BackgroundTransparency = 1
	t.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	t.TextSize = 15
	t.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.3
	stroke.Thickness = 1.5
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function drawPicks(m: Marks, world: World.World)
	m.picks:ClearAllChildren()
	for pid, t in m.labels do
		local p = world.pregame.picks[pid]
		if p == nil or p.x == nil then
			t:Destroy()
			m.labels[pid] = nil
		end
	end
	for pid, p in world.pregame.picks do
		if p.x == nil or p.z == nil then
			continue
		end
		local x, z = p.x :: number, p.z :: number
		local color = TeamColors.ofPlayer(pid)
		local keepOut = disc(m.picks, world, x, z, StartAreas.SPACING * 2, color, 0.8, Enum.Material.SmoothPlastic)
		keepOut.Name = `KeepOut{pid}`
		commander(m.picks, world, pid, x, z, color)
		local tag = m.labels[pid] or label(m.gui)
		m.labels[pid] = tag
		tag.Name = `Pick{pid}`
		tag.TextColor3 = color
		tag.Text = PregameMarks.nameOf(pid) .. (if Pregame.isReady(world, pid) then "  ✓" else "")
		tag:SetAttribute("x", x)
		tag:SetAttribute("y", World.groundY(world, x, z, true) + PregameMarks.LABEL_LIFT)
		tag:SetAttribute("z", z)
	end
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
	-- (redrawn as meshes finish: a Commander drawn as a blockout gets its model)
	local picksKey = `{pg.version}/{TeamColors.version}/{Models.version}/{MeshModels.stats.built}`
	if picksKey ~= m.picksKey then
		m.picksKey = picksKey
		drawPicks(m, world)
	end
	m.folder.Parent = workspace
	m.gui.Enabled = true
	for _, t in m.labels do
		local x, y, z = t:GetAttribute("x"), t:GetAttribute("y"), t:GetAttribute("z")
		if type(x) == "number" and type(y) == "number" and type(z) == "number" then
			local v, visible = cam:WorldToViewportPoint(Vector3.new(x, y, z))
			t.Visible = visible and v.Z > 0
			t.Position = UDim2.fromOffset(v.X, v.Y)
		end
	end
	if hover and world.me.player ~= 0 then
		local ok = Pregame.canPick(world, areas, hover.X, hover.Z)
		m.hover.Color = if ok then OK else NO
		m.hover.CFrame = CFrame.new(hover.X, World.groundY(world, hover.X, hover.Z, true) + 0.9, hover.Z) * CFrame.Angles(0, 0, math.pi / 2)
		m.hover.Transparency = 0.35
	else
		m.hover.Transparency = 1
	end
end

return PregameMarks
