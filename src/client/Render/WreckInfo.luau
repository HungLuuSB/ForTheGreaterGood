--!strict
-- Wreck information (C-216, S-168; Core/ReclaimZones decides what): with
-- only workers selected, each reclaim zone as a thin green ring on the
-- ground with "+N supply" on its far edge; and the wreck under the mouse
-- named with its supply left ("Lancer wreck · 45 supply"). Labels are a
-- screen-space layer like IdleMarks (no BillboardGuis); rings are pooled
-- CylinderHandleAdornments. Zones are looked up a few times a second.

local Players = game:GetService("Players")

local Kit = require("../UI/Kit")
local ReclaimZones = require("../Core/ReclaimZones")
local World = require("../Core/World")

local WreckInfo = {}

WreckInfo.ZONE_COLOR = Color3.fromRGB(110, 210, 120)
WreckInfo.REFRESH = 0.25 -- seconds between zone lookups
WreckInfo.RING_WIDTH = 2 -- studs

export type State = {
	folder: Folder,
	gui: ScreenGui,
	rings: { CylinderHandleAdornment },
	labels: { TextLabel },
	hover: TextLabel,
	zones: { ReclaimZones.Zone },
	at: number,
}

local FLAT = CFrame.Angles(math.pi / 2, 0, 0) -- a handle cylinder's axis is its Z: turned to stand on Y

local function label(parent: Instance, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, size + 8)
	l.BackgroundColor3 = Kit.COLOR.panel
	l.BackgroundTransparency = 0.35
	l.BorderSizePixel = 0
	l.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	l.TextSize = size
	l.TextColor3 = Kit.COLOR.text
	l.Visible = false
	l.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = l
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = l
	return l
end

function WreckInfo.new(): State
	local folder = Instance.new("Folder")
	folder.Name = "ReclaimZones"
	folder.Parent = workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggWreckInfo"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- positions come from WorldToViewportPoint
	gui.DisplayOrder = -1 -- under the HUD panels
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local hover = label(gui, 14)
	hover.AnchorPoint = Vector2.new(0, 1)
	return { folder = folder, gui = gui, rings = {}, labels = {}, hover = hover, zones = {}, at = -math.huge }
end

-- Per frame. `mouse`: the ground point under the mouse (nil off the map);
-- `mousePx`: the mouse in viewport pixels.
function WreckInfo.step(s: State, world: World.World, selection: { number }, cam: Camera, now: number, mouse: Vector3?, mousePx: Vector2)
	-- zones, with only workers selected
	if now - s.at >= WreckInfo.REFRESH then
		s.at = now
		s.zones = if ReclaimZones.workersOnly(world, selection) then ReclaimZones.of(world) else {}
	end
	for i, z in s.zones do
		local ring = s.rings[i]
		if ring == nil then
			local a = Instance.new("CylinderHandleAdornment")
			a.Name = "Zone"
			a.Adornee = workspace.Terrain
			a.AlwaysOnTop = true -- a flat ring at the centre's height hides under higher ground (like RadarRings, C-64)
			a.AdornCullingMode = Enum.AdornCullingMode.Never
			a.Color3 = WreckInfo.ZONE_COLOR
			a.Height = 0.3
			a.Transparency = 0.35
			a.Parent = s.folder
			s.rings[i] = a
			ring = a
		end
		local y = World.groundY(world, z.x, z.z, true)
		ring.Radius = z.r
		ring.InnerRadius = z.r - WreckInfo.RING_WIDTH
		ring.CFrame = CFrame.new(z.x, y + 0.4, z.z) * FLAT
		ring.Visible = true
		local l = s.labels[i]
		if l == nil then
			l = label(s.gui, 15)
			l.TextColor3 = WreckInfo.ZONE_COLOR
			s.labels[i] = l
		end
		-- the label on the ring's far (north) edge, clear of the wrecks inside it
		local v, onScreen = cam:WorldToViewportPoint(Vector3.new(z.x, y + 2, z.z - z.r))
		l.Visible = onScreen
		if onScreen then
			l.Text = `+{z.supply} supply`
			l.Position = UDim2.fromOffset(v.X, v.Y)
		end
	end
	for i = #s.zones + 1, #s.rings do
		s.rings[i].Visible = false
	end
	for i = #s.zones + 1, #s.labels do
		s.labels[i].Visible = false
	end
	-- the wreck under the mouse
	local w = if mouse then ReclaimZones.wreckAt(world, mouse.X, mouse.Z) else nil
	s.hover.Visible = w ~= nil
	if w then
		s.hover.Text = ReclaimZones.label(world, w)
		s.hover.Position = UDim2.fromOffset(mousePx.X + 14, mousePx.Y - 6)
	end
end

return WreckInfo
