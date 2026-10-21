--!strict
-- Strategic missile warnings (C-57): while a nuke flies (Core/Effects'
-- `warnings`, from LAUNCH_WARNING, which every player gets), a blinking
-- "NUCLEAR LAUNCH DETECTED" banner, a red marker where it was launched and a
-- pulsing red ring of its blast radius where it will come down
-- (Effects.landing, from the missile's own state); a white flash over the
-- screen when one detonates in view. Rings are always-on-top line
-- adornments on the Terrain (default ZIndex, culling off), like the
-- missile sensor view. Looks are placeholders.

local Players = game:GetService("Players")

local Effects = require("../Core/Effects")
local World = require("../Core/World")

local NukeWarning = {}

local RED = Color3.fromRGB(255, 50, 40)
local RING_SEGMENTS = 48
local LAUNCH_RADIUS = 30 -- studs: the launch point marker

export type State = {
	gui: ScreenGui,
	banner: TextLabel,
	flash: Frame,
	folder: Folder,
	lines: { LineHandleAdornment },
	used: number,
	flashedAt: number,
	seen: { [any]: boolean }, -- nuke bursts already flashed
}

function NukeWarning.new(): State
	local gui = Instance.new("ScreenGui")
	gui.Name = "NukeWarning"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 140)
	banner.Size = UDim2.fromOffset(360, 34)
	banner.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
	banner.BackgroundTransparency = 0.2
	banner.BorderSizePixel = 0
	banner.Font = Enum.Font.Code
	banner.TextSize = 20
	banner.TextColor3 = RED
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 0.95)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local folder = Instance.new("Folder")
	folder.Name = "NukeWarning"
	folder.Parent = workspace
	return { gui = gui, banner = banner, flash = flash, folder = folder, lines = {}, used = 0, flashedAt = -math.huge, seen = setmetatable({}, { __mode = "k" }) :: any }
end

local function line(s: State, a: Vector3, b: Vector3, thickness: number, transparency: number)
	s.used += 1
	local l = s.lines[s.used]
	if l == nil then
		local inst = Instance.new("LineHandleAdornment")
		inst.Adornee = workspace.Terrain
		inst.AlwaysOnTop = true
		inst.AdornCullingMode = Enum.AdornCullingMode.Never
		inst.Color3 = RED
		inst.Parent = s.folder
		s.lines[s.used] = inst
		l = inst
	end
	local len = (b - a).Magnitude
	l.CFrame = CFrame.lookAt(a, b)
	l.Length = math.max(len, 0.01)
	l.Thickness = thickness
	l.Transparency = transparency
	l.Visible = true
end

local function ring(s: State, world: World.World, x: number, z: number, r: number, thickness: number, transparency: number)
	local prev: Vector3? = nil
	for i = 0, RING_SEGMENTS do
		local a = i / RING_SEGMENTS * 2 * math.pi
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		local p = Vector3.new(px, World.groundY(world, px, pz) + 1, pz)
		if prev then
			line(s, prev, p, thickness, transparency)
		end
		prev = p
	end
end

-- `now`: real seconds (blinking, the flash). The banner is one notice for
-- any number of nukes in flight (the user, C-61): time to impact and radar
-- tracks are in the sensor view (N, C-58).
function NukeWarning.step(s: State, fx: Effects.Fx, world: World.World, now: number, cam: Camera)
	s.used = 0
	local text: string? = nil
	for _, w in fx.warnings do
		local p = w.proj
		local live = p ~= nil and not p.gone
		-- the launch point
		ring(s, world, w.x, w.z, LAUNCH_RADIUS, 3, 0.2)
		if live then
			text = "NUCLEAR LAUNCH DETECTED"
			local proj = p :: Effects.Proj
			local x, z = Effects.landing(world, proj)
			if x then
				local pulse = 0.5 + 0.5 * math.sin(now * 8)
				ring(s, world, x, z :: number, proj.weapon.aoe or 150, 4, 0.15 + 0.4 * pulse)
				local cross = 12
				local y = World.groundY(world, x, z :: number) + 1
				line(s, Vector3.new(x - cross, y, z :: number), Vector3.new(x + cross, y, z :: number), 3, 0.2)
				line(s, Vector3.new(x, y, (z :: number) - cross), Vector3.new(x, y, (z :: number) + cross), 3, 0.2)
			end
		end
	end
	for i = s.used + 1, #s.lines do
		if s.lines[i].Visible then
			s.lines[i].Visible = false
		end
	end
	s.banner.Visible = text ~= nil and math.floor(now * 3) % 2 == 0
	if text then
		s.banner.Text = text
	end
	-- a detonation in view flashes the screen
	for _, b in fx.bursts do
		if b.kind == "nuke" and not s.seen[b] then
			s.seen[b] = true
			local _, onScreen = cam:WorldToViewportPoint(Vector3.new(b.x, b.y, b.z))
			if onScreen then
				s.flashedAt = now
			end
		end
	end
	local t = (now - s.flashedAt) / 1.2
	s.flash.BackgroundTransparency = if t < 1 then 0.15 + 0.85 * t * t else 1
end

return NukeWarning
