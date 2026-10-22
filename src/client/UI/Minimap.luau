--!strict
-- PLACEHOLDER minimap (guide 15.7, 15.8), bottom left. Terrain tiles from
-- the map's layers, units as their icons (the strategic layer's, smaller:
-- C-122; radar blips stay dots) refreshed at the strategic rate, the camera
-- outline; left click moves the camera, right click orders the selection
-- there (Shift queues). Reads and calls only the client API (C-5).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Api = require("../Api")
local CoreDeposits = require("../Core/Deposits")
local Icons = require("../Core/Icons")
local Minimap = require("../Core/Minimap")
local TeamColors = require("../Render/TeamColors")
local Glyph = require("./Glyph")

local MinimapUI = {}

local SIZE = 220 -- pixels: top left, BAR layout (C-71; 280 until C-107, the user: smaller)
MinimapUI.SIZE = SIZE -- the build menu sits under it

export type UI = {
	gui: ScreenGui,
	map: Frame,
	terrain: Frame,
	fog: ImageLabel,
	fogContent: Content?,
	dots: Frame,
	camera: Frame,
	pool: { Frame }, -- blip dots
	glyphs: { Glyph.G }, -- unit icons
	depositList: { CoreDeposits.Deposit },
	depositDots: { Frame }, -- one per deposit: a neutral ring, filled in the holder's color when taken (C-123)
	icons: Icons.Table,
	nextDots: number,
	pings: { { frame: Frame, at: number } }, -- alert pings (C-68)
}

MinimapUI.PING_SECONDS = 3
local DEPOSIT_RING = Color3.fromRGB(205, 205, 195)

function MinimapUI.new(api: Api.Api): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Minimap"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local map = Instance.new("Frame")
	map.Name = "Map"
	map.AnchorPoint = Vector2.new(0, 0)
	map.Position = UDim2.fromOffset(0, 0)
	map.Size = UDim2.fromOffset(SIZE, SIZE)
	map.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	map.BorderSizePixel = 0
	map.Active = true
	map.ClipsDescendants = true
	map.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 200, 200)
	stroke.Thickness = 1
	stroke.Parent = map
	local label = Instance.new("TextLabel")
	label.Name = "Placeholder"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Position = UDim2.fromOffset(0, -16)
	label.Font = Enum.Font.Code
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(230, 200, 90)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = map
	local function layer(name: string, z: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = z
		f.Parent = map
		return f
	end
	local terrain = layer("Terrain", 1)
	-- the fog of war: the fog blanket's own image (C-100), over the terrain, under the dots
	local fog = Instance.new("ImageLabel")
	fog.Name = "Fog"
	fog.BackgroundTransparency = 1
	fog.Size = UDim2.fromScale(1, 1)
	fog.ZIndex = 2
	fog.Visible = false
	fog.Parent = map
	local dots = layer("Dots", 3)
	local camera = Instance.new("Frame")
	camera.Name = "Camera"
	camera.BackgroundTransparency = 1
	camera.ZIndex = 4
	local camStroke = Instance.new("UIStroke")
	camStroke.Color = Color3.new(1, 1, 1)
	camStroke.Thickness = 1
	camStroke.Parent = camera
	camera.Parent = map
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	map.InputBegan:Connect(function(input)
		local world = api.world
		if not world.joined then
			return
		end
		local isLeft = input.UserInputType == Enum.UserInputType.MouseButton1
		local isRight = input.UserInputType == Enum.UserInputType.MouseButton2
		if not (isLeft or isRight) then
			return
		end
		local rel = Vector2.new(input.Position.X, input.Position.Y) - map.AbsolutePosition
		local x, z = Minimap.toWorld(world.grid, rel.X / map.AbsoluteSize.X, rel.Y / map.AbsoluteSize.Y)
		if isLeft then
			api.actions.focusCamera(x, z)
		else
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			api.actions.smartOrder(x, z, nil, shift)
		end
	end)

	return { gui = gui, map = map, terrain = terrain, fog = fog, fogContent = nil, dots = dots, camera = camera, pool = {}, glyphs = {}, depositList = {}, depositDots = {}, icons = Icons.table(api.world.defs), nextDots = 0, pings = {} }
end

local function tileColor(tile: Minimap.Tile): Color3
	if tile.water > 0 then
		return Color3.fromRGB(40, 80, 130):Lerp(Color3.fromRGB(20, 40, 80), math.clamp(tile.water / 20, 0, 1))
	end
	return Color3.fromRGB(70, 92, 56):Lerp(Color3.fromRGB(130, 120, 95), math.clamp((tile.height + 10) / 40, 0, 1))
end

-- Rebuilds the terrain for a new map (after a WELCOME with another map).
-- The fog of war: the fog blanket's image (nil: none, e.g. a spectator or fog off).
function MinimapUI.setFog(ui: UI, content: Content?, show: boolean)
	if content ~= ui.fogContent then
		ui.fogContent = content
		ui.fog.ImageContent = content or Content.none
	end
	ui.fog.Visible = show and content ~= nil
end

function MinimapUI.setMap(ui: UI, layers: any)
	ui.terrain:ClearAllChildren()
	for _, tile in Minimap.terrain(layers) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(tile.u, tile.v)
		f.Size = UDim2.fromScale(tile.w, tile.h)
		f.BackgroundColor3 = tileColor(tile)
		f.Parent = ui.terrain
	end
	-- deposits: small neutral rings on the exact cells, filled when taken (step)
	ui.depositList = CoreDeposits.list(layers)
	ui.depositDots = {}
	local g = layers.grid
	for _, d in ui.depositList do
		local f = Instance.new("Frame")
		f.Name = "Deposit"
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale((d.cx + 0.5) / g.cellsX, (d.cz + 0.5) / g.cellsZ)
		f.Size = UDim2.fromOffset(5, 5)
		f.BackgroundTransparency = 1
		f.ZIndex = 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		local ring = Instance.new("UIStroke")
		ring.Color = DEPOSIT_RING
		ring.Thickness = 1
		ring.Transparency = 0.2
		ring.Parent = f
		f.Parent = ui.terrain
		table.insert(ui.depositDots, f)
	end
end

-- An alert's ping (C-68): a ring that grows and fades at (x, z).
function MinimapUI.ping(ui: UI, grid: any, x: number, z: number, color: Color3)
	local u, v = Minimap.toMap(grid, x, z)
	local f = Instance.new("Frame")
	f.Name = "Ping"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(u, v)
	f.BackgroundTransparency = 1
	f.ZIndex = 4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 2
	s.Parent = f
	f.Parent = ui.map
	table.insert(ui.pings, { frame = f, at = os.clock() })
end

function MinimapUI.step(ui: UI, api: Api.Api, now: number)
	local world = api.world
	local clock = os.clock()
	for i = #ui.pings, 1, -1 do
		local p = ui.pings[i]
		local t = (clock - p.at) / MinimapUI.PING_SECONDS
		if t >= 1 then
			p.frame:Destroy()
			table.remove(ui.pings, i)
		else
			local px = 6 + 40 * (t * 3 % 1) -- three rings over the ping's life
			p.frame.Size = UDim2.fromOffset(px, px)
			local s = p.frame:FindFirstChildOfClass("UIStroke") :: UIStroke
			s.Transparency = t
		end
	end
	local u0, v0, u1, v1 = Minimap.cameraBox(world.grid, api.state.camera.rect)
	ui.camera.Position = UDim2.fromScale(u0, v0)
	ui.camera.Size = UDim2.fromScale(u1 - u0, v1 - v0)
	if now < ui.nextDots then
		return
	end
	ui.nextDots = now + Minimap.REFRESH
	-- deposits: filled in the holder's team color once a structure stands on them
	local holders = CoreDeposits.holders(world, ui.depositList)
	for k, f in ui.depositDots do
		local h = holders[k]
		f.BackgroundTransparency = if h then 0 else 1
		if h then
			f.BackgroundColor3 = TeamColors(h.team)
		end
	end
	local dots = Minimap.dots(world, api.selection.set)
	local nDots, nIcons = 0, 0
	for _, d in dots do
		if d.kind ~= "blip" then
			-- the unit's icon (ghosts faint, selected lightened, under attack blinking: Glyph)
			nIcons += 1
			local g = ui.glyphs[nIcons]
			if g == nil then
				g = Glyph.new(ui.dots)
				ui.glyphs[nIcons] = g
			end
			local style = Icons.style(ui.icons, world, world.units[d.id], d.selected)
			style.size = math.max(6, math.floor(style.size * Minimap.ICON_SCALE + 0.5))
			Glyph.apply(g, style, TeamColors(d.team))
			g.root.Position = UDim2.fromScale(d.u, d.v)
			g.root.ZIndex = nIcons
			g.root.Visible = true
			continue
		end
		nDots += 1
		local i = nDots
		local f = ui.pool[i]
		if f == nil then
			f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.BorderSizePixel = 0
			local s = Instance.new("UIStroke")
			s.Parent = f
			f.Parent = ui.dots
			ui.pool[i] = f
		end
		local px = if d.kind == "structure" then 5 elseif d.kind == "blip" then 3 else 4
		f.Size = UDim2.fromOffset(px, px)
		f.Position = UDim2.fromScale(d.u, d.v)
		f.BackgroundColor3 = TeamColors(d.team)
		f.BackgroundTransparency = if d.kind == "ghost" then 1 elseif d.kind == "blip" then 0.4 else 0
		local s = f:FindFirstChildOfClass("UIStroke") :: UIStroke
		-- under attack (S-68): a red outline that blinks with the refresh
		local blink = d.attacked and math.floor(now * 4) % 2 == 0
		s.Color = if blink then Color3.fromRGB(255, 60, 50) elseif d.selected then Color3.new(1, 1, 1) else TeamColors(d.team)
		s.Thickness = if blink then 2 else 1
		s.Enabled = blink or d.selected or d.kind == "ghost"
		f.Visible = true
	end
	for i = nDots + 1, #ui.pool do
		ui.pool[i].Visible = false
	end
	for i = nIcons + 1, #ui.glyphs do
		ui.glyphs[i].root.Visible = false
	end
end

return MinimapUI
