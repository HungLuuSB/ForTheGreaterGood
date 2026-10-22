--!strict
-- Supply deposits on the ground (C-123, the user: no neon squares, no glow).
-- Each deposit is C's deposit model (Meshes.fx.deposit, a variant and a yaw
-- per deposit from Core/Deposits.look) with its ground patch tinted to the
-- terrain; until that is approved, a dark, subtle patch with a few stones.
-- A structure standing on a deposit hides it (an extractor built over it);
-- it shows again when the structure is gone.
-- The overlay (BAR's metal view), only when it helps: while an extractor is
-- being placed, or toggled with TOGGLE_KEY. Free deposits get a soft ring
-- and their yield (the placed extractor's, else the deposit's value);
-- deposits other players hold get a dim marker; the player's own show
-- nothing.

local CoreDeposits = require("../Core/Deposits")
local CoreTerrain = require("../Core/Terrain")
local MeshModels = require("./MeshModels")

local Deposits = {}

Deposits.TOGGLE_KEY = Enum.KeyCode.F4 -- BAR's metal view key (Settings > Keys)
Deposits.REFRESH = 0.25 -- seconds between holder checks
local PATCH_DARK = Color3.fromRGB(30, 28, 25)
local STONE = Color3.fromRGB(58, 55, 51)
local RING = Color3.fromRGB(236, 232, 214)
local TAKEN = Color3.fromRGB(150, 150, 150)

export type Site = {
	d: CoreDeposits.Deposit,
	y: number, -- ground height at its center
	tint: Color3, -- the terrain's color there
	patch: Instance, -- the fallback patch or C's model
	meshed: boolean,
	hidden: boolean,
	overlay: Part?, -- the overlay's flat canvas, made on first show
	ring: Frame?,
	label: TextLabel?,
	marker: Frame?,
}

export type View = {
	folder: Folder,
	overlayFolder: Folder,
	sites: { Site },
	enabled: boolean, -- the toggle (TOGGLE_KEY)
	nextAt: number,
	holders: { [number]: CoreDeposits.Holder },
}

function Deposits.new(): View
	local folder = Instance.new("Folder")
	folder.Name = "Deposits"
	local overlayFolder = Instance.new("Folder")
	overlayFolder.Name = "DepositOverlay"
	return { folder = folder, overlayFolder = overlayFolder, sites = {}, enabled = false, nextAt = 0, holders = {} }
end

function Deposits.setEnabled(v: View, on: boolean)
	v.enabled = on
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

-- The terrain's color at (x, z) (the patch is tinted to it).
local function terrainTint(layers: any, feature: any, x: number, z: number): Color3
	local name = CoreTerrain.material(layers, x, z, feature)
	local ok, color = pcall(function()
		return workspace.Terrain:GetMaterialColor((Enum.Material :: any)[name])
	end)
	return if ok and typeof(color) == "Color3" then color else Color3.fromRGB(96, 110, 70)
end

-- The fallback: a dark scraped patch and a few low stones (no glow).
local function plainPatch(s: Site): Model
	local d = s.d
	local model = Instance.new("Model")
	model.Name = "Deposit"
	local _, yaw = CoreDeposits.look(d, 1)
	local base = CFrame.new(d.x, s.y, d.z) * CFrame.Angles(0, math.rad(yaw), 0)
	part("Patch", Vector3.new(0.12, 6.6, 6.6), base * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), s.tint:Lerp(PATCH_DARK, 0.62), Enum.Material.Ground, model).Shape = Enum.PartType.Cylinder
	for k = 1, 4 do
		local a = math.rad(yaw + k * 97)
		local r = 0.8 + (k * 0.55) % 2
		local size = 0.5 + (k % 3) * 0.25
		part(`Stone{k}`, Vector3.new(size, size * 0.55, size * 0.8), base * CFrame.new(math.cos(a) * r, size * 0.2, math.sin(a) * r) * CFrame.Angles(0.3 * k, a, 0.2), STONE:Lerp(PATCH_DARK, (k % 2) * 0.4), Enum.Material.Slate, model)
	end
	return model
end

-- C's model for the site, if its variant is built (tinted, placed).
local function meshedPatch(s: Site, variants: number): Model?
	local variant, yaw = CoreDeposits.look(s.d, variants)
	local template = MeshModels.deposit(variant)
	if template == nil then
		return nil
	end
	local model = template:Clone()
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CastShadow = false
			if game:GetService("CollectionService"):HasTag(p, MeshModels.TEAM_TAG) then
				p.Color = s.tint -- the patch: the terrain's color through the mask
			end
		end
	end
	local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
	model:PivotTo(CFrame.new(s.d.x, s.y, s.d.z) * CFrame.Angles(0, math.rad(yaw), 0) * offset)
	return model
end

-- Draws every deposit of the map (call after Ground.build).
function Deposits.build(v: View, layers: any, feature: any)
	v.folder:ClearAllChildren()
	v.overlayFolder:ClearAllChildren()
	v.sites = {}
	v.holders = {}
	for _, d in CoreDeposits.list(layers) do
		local s: Site = {
			d = d,
			y = CoreTerrain.groundY(layers, d.x, d.z),
			tint = terrainTint(layers, feature, d.x, d.z),
			patch = nil :: any,
			meshed = false,
			hidden = false,
		}
		s.patch = plainPatch(s)
		s.patch.Parent = v.folder
		table.insert(v.sites, s)
	end
	v.folder.Parent = workspace
	v.overlayFolder.Parent = workspace
end

local function overlayOf(v: View, s: Site): Part
	if s.overlay then
		return s.overlay
	end
	local p = part("Overlay", Vector3.new(8, 0.05, 8), CFrame.new(s.d.x, s.y + 0.5, s.d.z), RING, Enum.Material.SmoothPlastic, v.overlayFolder)
	p.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(160, 160)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false -- true hides a SurfaceGui under a Workspace part (tested in Studio)
	gui.Parent = p
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.8, 0.8)
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = RING
	stroke.Thickness = 5
	stroke.Transparency = 0.35
	stroke.Parent = ring
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.7, 0.4)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = RING
	label.TextStrokeTransparency = 0.4
	label.TextTransparency = 0.1
	label.Parent = gui
	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.Size = UDim2.fromScale(0.28, 0.28)
	marker.BackgroundColor3 = TAKEN
	marker.BackgroundTransparency = 0.55
	marker.BorderSizePixel = 0
	marker.Parent = gui
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(0.5, 0)
	mc.Parent = marker
	s.overlay, s.ring, s.label, s.marker = p, ring, label, marker
	return p
end

-- Once a frame: holders (every REFRESH), hidden patches, C's models as they
-- become ready, and the overlay.
function Deposits.step(v: View, api: any, now: number)
	local world = api.world
	if #v.sites == 0 then
		return
	end
	if now >= v.nextAt then
		v.nextAt = now + Deposits.REFRESH
		local list = {}
		for k, s in v.sites do
			list[k] = s.d
		end
		v.holders = CoreDeposits.holders(world, list)
		local variants = MeshModels.depositVariants()
		for k, s in v.sites do
			if variants > 0 and not s.meshed then
				local m = meshedPatch(s, variants)
				if m then
					s.patch:Destroy()
					s.patch, s.meshed = m, true
				end
			end
			-- built over (a live structure on it): hidden under it
			local h = v.holders[k]
			local hidden = h ~= nil and not h.ghost
			if hidden ~= s.hidden or s.patch.Parent == nil then
				s.hidden = hidden
				s.patch.Parent = if hidden then nil else v.folder
			end
		end
	end
	-- the overlay: placing an extractor, or the toggle
	local p = api.state.placement
	local placing = p and world.defs.unitByIndex[p.defIndex]
	local rate = if placing and placing.extractor then placing.extractor.rate else nil
	local show = v.enabled or rate ~= nil
	local yaw = 0
	if show then
		local look = workspace.CurrentCamera.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z) - math.pi / 2 -- text upright toward the camera (a Top-face canvas reads along the part's X)
	end
	for k, s in v.sites do
		if not show then
			if s.overlay and s.overlay.Parent then
				s.overlay.Parent = nil
			end
			continue
		end
		local h = v.holders[k]
		local mine = h ~= nil and h.team == world.me.team
		if mine then
			if s.overlay and s.overlay.Parent then
				s.overlay.Parent = nil
			end
			continue
		end
		local o = overlayOf(v, s)
		o.CFrame = CFrame.new(s.d.x, s.y + 0.5, s.d.z) * CFrame.Angles(0, yaw, 0)
		local free = h == nil
		;(s.ring :: Frame).Visible = free
		;(s.label :: TextLabel).Visible = free
		;(s.label :: TextLabel).Text = CoreDeposits.yieldText(s.d, rate)
		;(s.marker :: Frame).Visible = not free
		o.Parent = v.overlayFolder
	end
end

return Deposits
