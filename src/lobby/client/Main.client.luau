--!strict
-- The lobby client (L-10): BAR's lobby layout in the game's UI kit. A top
-- bar with the pages (Home, Skirmish, Multiplayer, Units: the unit
-- encyclopedia with its 3D showroom, L-18, Replays, Profile) and Settings; the battle room replaces the room browser while you're in one;
-- full-screen overlays while assets load on joining (Boot, L-23), while a
-- match starts or runs (the loading screen,
-- with the Studio stand-in's controls) and for a finished match's results.
-- Behind it all, the 3D scene (Scene).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Net = require("./Net")
local Scene = require("./Scene")
local Ui = require("./Ui")
local Home = require("./Pages/Home")
local Skirmish = require("./Pages/Skirmish")
local Browser = require("./Pages/Browser")
local Room = require("./Pages/Room")
local Replays = require("./Pages/Replays")
local Units = require("./Pages/Units")
local ProfilePage = require("./Pages/Profile")
local Settings = require("./Pages/Settings")
local Loading = require("./Overlays/Loading")
local Boot = require("./Overlays/Boot")
local MatchError = require("./Overlays/MatchError")
local Results = require("./Overlays/Results")

local Kit = Ui.Kit
local player = Players.LocalPlayer

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "Lobby"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local scale = Instance.new("UIScale")
scale.Name = "SettingsScale" -- the kit's panels fit to the screen at this scale
scale.Parent = gui

Scene.start()

-- a vignette over the scene: dark at the top and bottom where the UI sits
local shade = Ui.frame(gui, "Shade", UDim2.fromScale(1, 1))
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(0.18, 0.75),
	NumberSequenceKeypoint.new(0.65, 0.85),
	NumberSequenceKeypoint.new(1, 0.35),
})
grad.Parent = shade

-- top bar ---------------------------------------------------------------------

local BAR = 60
local top = Ui.frame(gui, "TopBar", UDim2.new(1, 0, 0, BAR))
top.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
top.BackgroundTransparency = 0.15
top.ZIndex = 5
local line = Ui.frame(top, "Line", UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 1, -1))
line.BackgroundColor3 = Kit.COLOR.border
line.BackgroundTransparency = 0.88

local logo = Instance.new("TextLabel")
logo.Name = "Logo"
logo.BackgroundTransparency = 1
logo.Position = UDim2.fromOffset(24, 0)
logo.Size = UDim2.new(0, 230, 1, 0)
logo.FontFace = Kit.font(Enum.FontWeight.Bold)
logo.RichText = true
logo.Text = `<font color="#EEBA5C">FTGG</font>  <font size="12" color="#969CA8">FOR THE GREATER GOOD</font>`
logo.TextSize = 26
logo.TextColor3 = Kit.COLOR.text
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.Parent = top

local tabs = Ui.frame(top, "Tabs", UDim2.new(0, 710, 1, 0), UDim2.fromOffset(270, 0))

-- Roblox's own buttons (its menu, chat) sit in the top-left corner over the
-- bar: the logo and tabs start where Roblox's free area begins.
local function clearRobloxButtons()
	local left = 0
	local ok, inset = pcall(function()
		return GuiService.TopbarInset
	end)
	if ok and inset then
		left = inset.Min.X
	end
	logo.Position = UDim2.fromOffset(math.max(24, left + 12), 0)
	tabs.Position = UDim2.fromOffset(math.max(24, left + 12) + 246, 0)
end
clearRobloxButtons()
pcall(function()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(clearRobloxButtons)
end)
Kit.list(tabs, 0, true)

local right = Ui.frame(top, "Right", UDim2.new(0, 420, 1, 0), UDim2.new(1, -440, 0, 0))
local rightList = Kit.list(right, Kit.SPACE.l, true)
rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
local onlineDot = Ui.swatch(right, Kit.COLOR.on, 8)
onlineDot.LayoutOrder = 1
Ui.corner(onlineDot, 4)
local online = Ui.label(right, "", "small", Kit.COLOR.dim, 2)
local me = Ui.label(right, player.DisplayName, "small", Kit.COLOR.text, 3)
local studioTag = Ui.label(right, "STUDIO STAND-INS", "small", Kit.COLOR.accent, 0)
studioTag.Visible = false

-- pages -----------------------------------------------------------------------

local body = Ui.frame(gui, "Body", UDim2.new(1, -48, 1, -BAR - 40), UDim2.fromOffset(24, BAR + 20))

type Page = { frame: Frame, show: (() -> ())?, hide: (() -> ())?, update: ((any) -> ())? }
local pages: { [string]: Page } = {}
local tabButtons: { [string]: TextButton } = {}
local current = "Home"
local router: any = {}

local TABS = { "Home", "Skirmish", "Multiplayer", "Units", "Replays", "Profile", "Settings" }

local function paint()
	for name, b in tabButtons do
		local on = name == current
		b.TextColor3 = if on then Kit.COLOR.text else Kit.COLOR.dim
		b.BackgroundTransparency = if on then 0.93 else 1
		local bar = b:FindFirstChild("Under") :: Frame?
		if bar then
			bar.Visible = on
		end
	end
end

local function pageFor(name: string): string
	if name == "Multiplayer" then
		local v = Net.view
		return if v and v.room then "Room" else "Browser"
	end
	return name
end

function router.go(name: string)
	current = name
	local target = pageFor(name)
	for n, p in pages do
		local on = n == target
		if not on and p.frame.Visible and p.hide then
			p.hide()
		end
	end
	for n, p in pages do
		local on = n == target
		if on and not p.frame.Visible and p.show then
			p.show()
		end
		p.frame.Visible = on
	end
	paint()
end

for i, name in TABS do
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BackgroundColor3 = Kit.COLOR.raised
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.Size = UDim2.new(0, if name == "Multiplayer" then 128 else 96, 1, 0)
	b.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	b.TextSize = 16
	b.Text = string.upper(name)
	b.LayoutOrder = i
	b.Parent = tabs
	local under = Ui.frame(b, "Under", UDim2.new(1, -24, 0, 2), UDim2.new(0, 12, 1, -3))
	under.BackgroundColor3 = Kit.COLOR.accent
	under.BackgroundTransparency = 0
	b.MouseButton1Click:Connect(function()
		router.go(name)
	end)
	tabButtons[name] = b
end

local function mount(name: string, module: any)
	local frame = Ui.frame(body, name, UDim2.fromScale(1, 1))
	frame.Visible = false
	local p = module.new(frame, router)
	pages[name] = { frame = frame, show = p.show, hide = p.hide, update = p.update }
end

mount("Home", Home)
mount("Skirmish", Skirmish)
mount("Browser", Browser)
mount("Room", Room)
mount("Units", Units)
mount("Replays", Replays)
mount("Profile", ProfilePage)
mount("Settings", Settings)

-- toasts ----------------------------------------------------------------------

local toasts = Ui.frame(gui, "Toasts", UDim2.fromOffset(520, 300), UDim2.new(0.5, -260, 1, -320))
toasts.ZIndex = 30
local tl = Kit.list(toasts, Kit.SPACE.s)
tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
local toastOrder = 0
Net.onToast(function(text: string, style: string)
	toastOrder += 1
	local t = Ui.card(toasts, "Toast", UDim2.fromOffset(0, 40), nil, 0.05)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.LayoutOrder = toastOrder
	t.ZIndex = 30
	local s = t:FindFirstChildOfClass("UIStroke")
	if s and style == "error" then
		s.Color = Kit.COLOR.off
		s.Transparency = 0.2
	end
	Kit.pad(t, Kit.SPACE.l, 0, Kit.SPACE.l, 0)
	local l = Ui.label(t, text, "label", if style == "error" then Kit.COLOR.defeat else Kit.COLOR.text)
	l.Size = UDim2.new(0, 0, 1, 0)
	l.ZIndex = 31
	task.delay(5, function()
		t:Destroy()
	end)
end)

-- overlays --------------------------------------------------------------------

local loading = Loading.new(gui)
local results = Results.new(gui)
local matchError = MatchError.new(gui)
-- the joining screen: caches the meshes, textures and maps first (L-23)
Boot.start(gui, function() end)

-- views -----------------------------------------------------------------------

local wasInRoom = false
Net.onView(function(v: any)
	online.Text = `{v.online} player{if v.online == 1 then "" else "s"} online`
	me.Text = v.me.name
	studioTag.Visible = v.studio
	for _, p in pages do
		if p.update then
			p.update(v)
		end
	end
	-- joining or leaving a room switches Multiplayer between browser and room
	local inRoom = v.room ~= nil
	if inRoom ~= wasInRoom then
		wasInRoom = inRoom
		if inRoom then
			router.go("Multiplayer")
		elseif current == "Multiplayer" then
			router.go("Multiplayer")
		end
	end
	body.Visible = not loading.update(v)
	results.update(v)
	matchError.update(v)
end)
Net.onStandIn(function(_s: any)
	if Net.view then
		body.Visible = not loading.update(Net.view)
	end
end)
Net.onHop(function(_h: any)
	if Net.view then
		body.Visible = not loading.update(Net.view)
	end
end)

router.go("Home")
task.spawn(function()
	Net.loadMaps()
	-- pages drawn before the maps arrived (a room's preview) draw again
	if Net.view then
		for _, p in pages do
			if p.update then
				p.update(Net.view)
			end
		end
	end
end)
print("[Lobby] client ready")
