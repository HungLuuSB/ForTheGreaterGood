--!strict
-- The loading screen on joining the lobby (L-23, the user: "load assets just
-- as when you connect to a match"): full screen in the look of the match
-- start's (Loading: key art, a tip, the olive bar) while the lobby caches
-- what it draws, weighted as the match's own (client-B's Render/Preload):
--   0.10  connected (the first view from the server)
--   0.10  the map list (and its previews)
--   0.55  every approved unit mesh built (Render/MeshModels, all of them at
--         once: the showroom and the battle behind never pop in)
--   0.25  the meshes' textures, the icon sheets and the effect templates
--         downloaded (ContentProvider:PreloadAsync)
-- A mesh that fails to build counts as done (its blockout draws instead).
-- After SKIP_AFTER seconds a button lets you in without waiting.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Defs = require("@shared/Defs/Defs")
local IconAtlas = require("@client/UI/IconAtlas")
local KeyArt = require("@client/UI/KeyArt")
local Meshes = require("@shared/Defs/Meshes/Registry")
local MeshModels = require("@client/Render/MeshModels")
local Loading = require("./Loading")
local Net = require("../Net")
local Scene = require("../Scene")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Boot = {}

Boot.SKIP_AFTER = 12 -- seconds
Boot.FADE = 0.5
local OLIVE = Color3.fromRGB(150, 160, 70)
local TIP_EVERY = 6

-- The textures to download: every SurfaceAppearance the meshes use, the
-- icon sheets, the effect templates.
local function textureList(): { any }
	local list: { any } = {}
	local materials = ReplicatedStorage:WaitForChild("MeshMaterials", 10)
	if materials then
		for _, c in materials:GetChildren() do
			table.insert(list, c)
		end
	end
	local vfx = ReplicatedStorage:FindFirstChild("Vfx")
	if vfx then
		table.insert(list, vfx)
	end
	for _, image in IconAtlas.images do
		if image ~= "" then
			table.insert(list, image)
		end
	end
	return list
end

-- Shows the screen and starts the caching; `done` runs once it has faded out.
function Boot.start(gui: ScreenGui, done: () -> ())
	local root = Ui.frame(gui, "Boot", UDim2.fromScale(1, 1))
	root.ZIndex = 60
	root.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	root.BackgroundTransparency = 0
	root.Active = true
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(40, 44, 40), Color3.fromRGB(10, 11, 14))
	grad.Parent = root
	local art = KeyArt.new(root, 61)
	local title = Kit.text(root, "FOR THE GREATER GOOD", "title", Color3.new(1, 1, 1))
	title.TextSize = 40
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.12, 0)
	title.Size = UDim2.new(0.8, 0, 0, 50)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local sub = Kit.text(root, "Connecting...", "section", Color3.fromRGB(214, 218, 226))
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0.12, 54)
	sub.Size = UDim2.new(0.8, 0, 0, 30)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	local tip = Kit.text(root, "", "section", Color3.new(1, 1, 1))
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.new(0.5, 0, 1, -110)
	tip.Size = UDim2.new(0.7, 0, 0, 50)
	tip.TextWrapped = true
	tip.TextXAlignment = Enum.TextXAlignment.Center
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
	local fill = Ui.frame(track, "Fill", UDim2.fromScale(0, 1))
	fill.BackgroundColor3 = OLIVE
	fill.BackgroundTransparency = 0
	local barText = Kit.text(track, "0%", "small", Color3.new(1, 1, 1))
	barText.Size = UDim2.fromScale(1, 1)
	barText.TextXAlignment = Enum.TextXAlignment.Center
	barText.ZIndex = 3
	local skip = Ui.button(root, "Continue", "dark", function() end, 140, 34)
	skip.AnchorPoint = Vector2.new(0.5, 1)
	skip.Position = UDim2.new(0.5, 0, 1, -30)
	skip.Visible = false
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") and d ~= art.frame and not d:IsDescendantOf(art.frame) then
			d.ZIndex = math.max(d.ZIndex, 62)
		end
	end
	barText.ZIndex = 64

	local tips = Loading.TIPS
	local tipIndex = math.random(1, #tips)
	tip.Text = tips[tipIndex]
	art.show()
	Scene.setCovered(true) -- the art is opaque: the battle behind waits

	-- the meshes: every approved one with a def
	local defs = Defs.load()
	local total = 0
	for id, e in (Meshes :: any).units do
		if e.status == "approved" and defs.units[id] then
			total += 1
		end
	end
	MeshModels.start(defs)

	-- the textures, in the background
	local textures = 0
	task.spawn(function()
		local list = textureList()
		if #list == 0 then
			textures = 1
			return
		end
		local count = 0
		pcall(function()
			ContentProvider:PreloadAsync(list, function()
				count += 1
				textures = math.min(count / #list, 0.99)
			end)
		end)
		textures = 1
	end)
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		Scene.setCovered(false)
		art.hide()
		local info = TweenInfo.new(Boot.FADE)
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				TweenService:Create(d, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		TweenService:Create(root, info, { BackgroundTransparency = 1 }):Play()
		task.delay(Boot.FADE, function()
			root:Destroy()
			done()
		end)
	end
	skip.MouseButton1Click:Connect(finish)

	local started = os.clock()
	local tipAt = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if finished then
			conn:Disconnect()
			return
		end
		local s = MeshModels.stats
		local meshes = if total == 0 then 1 else math.min((s.built + s.failed) / total, 1)
		local connected = if Net.view ~= nil then 1 else 0
		local maps = if Net.maps ~= nil then 1 else 0
		local k = 0.1 * connected + 0.1 * maps + 0.55 * meshes + 0.25 * textures
		fill.Size = UDim2.fromScale(k, 1)
		barText.Text = `{math.floor(k * 100)}%`
		if connected == 0 then
			sub.Text = "Connecting to the lobby..."
		elseif maps == 0 then
			sub.Text = "Loading the maps..."
		elseif meshes < 1 then
			sub.Text = `Building unit models: {s.built + s.failed} / {total}`
		elseif textures < 1 then
			sub.Text = `Downloading textures: {math.floor(textures * 100)}%`
		else
			sub.Text = "Ready"
		end
		local now = os.clock()
		if now - tipAt >= TIP_EVERY then
			tipAt = now
			tipIndex = tipIndex % #tips + 1
			tip.Text = tips[tipIndex]
		end
		skip.Visible = now - started >= Boot.SKIP_AFTER
		if k >= 1 then
			conn:Disconnect()
			finish()
		end
	end)
end

return Boot
