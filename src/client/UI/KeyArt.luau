--!strict
-- A copy of the lobby place's src/lobby/client/KeyArt.luau (session D),
-- so the match's loading screen (UI/MatchLoading, C-176) shows the same art
-- the same way and the hand-off across the teleport looks continuous; keep
-- the two in step.
--
-- Key art with parallax layers (L-13, docs/contracts/key-art.md): the
-- models stream's layered pictures from the mesh manifest's `keyArt`, each
-- layer cut into tiles, drawn to cover the screen and shifted by the mouse
-- in proportion to its depth (with a slow idle drift). Approved art shows
-- everywhere; art in review only in Studio. Without any, `available` is
-- false and callers keep what they draw today.

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Meshes = require("@shared/Defs/Meshes/Registry")

local KeyArt = {}

local SHIFT = 0.025 -- of the screen width, at depth 1
local BLEED = 0.9 -- the visible part of each layer

local function arts(): { { name: string, entry: any } }
	local out = {}
	local all = (Meshes :: any).keyArt
	if type(all) ~= "table" then
		return out
	end
	for name, e in all do
		if type(e) == "table" and type(e.layers) == "table" and (e.status == "approved" or (e.status == "review" and RunService:IsStudio())) then
			table.insert(out, { name = name, entry = e })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

function KeyArt.available(): boolean
	return #arts() > 0
end

export type View = {
	frame: Frame,
	show: (name: string?) -> boolean, -- false: no art to show
	hide: () -> (),
}

function KeyArt.new(parent: Instance, zIndex: number): View
	local holder = Instance.new("Frame")
	holder.Name = "KeyArt"
	holder.BackgroundColor3 = Color3.new(0, 0, 0)
	holder.BackgroundTransparency = 0
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.ClipsDescendants = true
	holder.Visible = false
	holder.ZIndex = zIndex
	holder.Parent = parent

	-- dark bands behind the title and the tip
	for _, band in { { 0, 0.22, 0 }, { 0.68, 0.32, 180 } } do
		local f = Instance.new("Frame")
		f.Name = "Band"
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(0, band[1])
		f.Size = UDim2.fromScale(1, band[2])
		f.ZIndex = zIndex + 5
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = 90 + band[3]
		g.Transparency = NumberSequence.new(0.25, 1)
		g.Parent = f
	end

	type Layer = { frame: Frame, depth: number, tiles: { ImageLabel } }
	local layers: { Layer } = {}
	local conn: RBXScriptConnection? = nil
	local smoothX, smoothY = 0, 0
	local shown = 0 -- each show bumps it, so a stale preload never fades in

	local function clear()
		for _, l in layers do
			l.frame:Destroy()
		end
		table.clear(layers)
	end

	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end

	local function frameStep(dt: number)
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
		-- cover the screen at 16:9, then add the bleed
		local w, h
		if vp.X / math.max(vp.Y, 1) > 16 / 9 then
			w, h = vp.X, vp.X * 9 / 16
		else
			w, h = vp.Y * 16 / 9, vp.Y
		end
		w, h = w / BLEED, h / BLEED
		local mouse = UserInputService:GetMouseLocation()
		local mx = math.clamp(mouse.X / math.max(vp.X, 1) * 2 - 1, -1, 1)
		local my = math.clamp(mouse.Y / math.max(vp.Y, 1) * 2 - 1, -1, 1)
		local a = 1 - math.exp(-dt * 2.5)
		smoothX += (mx - smoothX) * a
		smoothY += (my - smoothY) * a
		local t = os.clock()
		local driftX, driftY = math.sin(t * 0.15) * 0.25, math.sin(t * 0.11) * 0.15
		for _, l in layers do
			local dx = -(smoothX + driftX) * SHIFT * vp.X * l.depth
			local dy = -(smoothY + driftY) * SHIFT * vp.X * l.depth * 0.5
			l.frame.Size = UDim2.fromOffset(w, h)
			l.frame.Position = UDim2.new(0.5, dx, 0.5, dy)
		end
	end

	local view: View
	view = {
		frame = holder,
		show = function(name: string?): boolean
			local list = arts()
			if #list == 0 then
				return false
			end
			local pick = list[math.random(1, #list)]
			for _, a in list do
				if a.name == name then
					pick = a
				end
			end
			shown += 1
			local mine = shown
			clear()
			local e = pick.entry
			local cols = (e.tiles and e.tiles[1]) or 1
			local rows = (e.tiles and e.tiles[2]) or 1
			local all: { ImageLabel } = {}
			for i, layer in e.layers do
				local f = Instance.new("Frame")
				f.Name = tostring(layer.name or i)
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.BackgroundTransparency = 1
				f.ZIndex = zIndex + i
				f.Parent = holder
				local tiles = {}
				for k, id in layer.images or {} do
					local c, r = (k - 1) % cols, (k - 1) // cols
					local img = Instance.new("ImageLabel")
					img.BackgroundTransparency = 1
					img.Image = id
					img.ImageTransparency = 1
					img.Position = UDim2.fromScale(c / cols, r / rows)
					img.Size = UDim2.fromScale(1 / cols, 1 / rows)
					img.ZIndex = zIndex + i
					img.Parent = f
					table.insert(tiles, img)
					table.insert(all, img)
				end
				table.insert(layers, { frame = f, depth = tonumber(layer.depth) or 0.5, tiles = tiles })
			end
			holder.Visible = true
			stop()
			conn = RunService.RenderStepped:Connect(frameStep)
			frameStep(1)
			-- fade in only once every tile has loaded
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync(all)
				end)
				if shown ~= mine then
					return
				end
				local t0 = os.clock()
				while shown == mine do
					local k = math.min(1, (os.clock() - t0) / 0.6)
					for _, img in all do
						img.ImageTransparency = 1 - k
					end
					if k >= 1 then
						break
					end
					RunService.RenderStepped:Wait()
				end
			end)
			return true
		end,
		hide = function()
			shown += 1
			holder.Visible = false
			stop()
			clear()
		end,
	}
	return view
end

return KeyArt
