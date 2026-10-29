--!strict
-- Unit portraits for the build menu (C-107, BAR style): a ViewportFrame
-- showing the unit's model (the BAR mesh when it's loaded, else its
-- blockout) at a three-quarter angle from above, in the player's team
-- color, standing on its terrain (C-192, Core/PortraitStage). Every
-- portrait uses it: the build menu, the unit panel and its type tiles. A portrait follows its model: `set` rebuilds only when the def,
-- the team or the template changed (a mesh model finishing replaces the
-- blockout stand-in). The model is static: no physics, no animation.
-- A unit with a pre-rendered picture (2D-E's E-11, UI/UnitPictures; C-262)
-- shows that instead, in its faction's own colour, once its sheet is
-- uploaded; the rest keep the live model.

local CollectionService = game:GetService("CollectionService")

local PortraitStage = require("../Core/PortraitStage")
local Models = require("../Render/Models")
local TeamColors = require("../Render/TeamColors")
local UnitPictures = require("./UnitPictures")

local Portrait = {}

Portrait.FOV = 30
Portrait.GROUND = Color3.fromRGB(104, 96, 78) -- the terrain under a unit (C-192)
Portrait.WATER = Color3.fromRGB(46, 104, 140)
Portrait.SEABED = Color3.fromRGB(58, 70, 66)
-- from the unit's front right, above (its forward is -Z)
local VIEW = Vector3.new(0.8, 0.65, -1).Unit

export type Portrait = { frame: ViewportFrame, camera: Camera, key: string?, template: Model?, model: Model?, picture: ImageLabel? }

function Portrait.new(parent: Instance): Portrait
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Portrait"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(150, 155, 165)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.6, -1, 0.4)
	vf.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = Portrait.FOV
	cam.Parent = vf
	vf.CurrentCamera = cam
	return { frame = vf, camera = cam, key = nil, template = nil, model = nil }
end

-- Shows def `def`'s picture (C-262); false when it has none yet.
local function showPicture(p: Portrait, def: any): boolean
	local image, x, y = UnitPictures.of(def.id)
	if image == nil then
		if p.picture then
			p.picture.Visible = false
		end
		p.frame.Visible = true
		return false
	end
	local pic = p.picture
	if pic == nil then
		local made = Instance.new("ImageLabel")
		made.Name = "Picture"
		made.BackgroundTransparency = 1
		made.Size = UDim2.fromScale(1, 1)
		made.ScaleType = Enum.ScaleType.Crop
		made.ImageRectSize = Vector2.new(UnitPictures.TILE, UnitPictures.TILE)
		made.ZIndex = p.frame.ZIndex
		made.Parent = p.frame.Parent
		p.picture = made
		pic = made
	end
	local shown = pic :: ImageLabel
	shown.Image = image
	shown.ImageRectOffset = Vector2.new(x, y)
	shown.Visible = true
	p.frame.Visible = false
	return true
end

-- Shows or hides the portrait, picture or model, whichever `set` chose.
function Portrait.setVisible(p: Portrait, on: boolean)
	local picture = on and p.picture ~= nil and p.key ~= nil and string.sub(p.key, -8) == "|picture"
	p.frame.Visible = on and not picture
	if p.picture then
		p.picture.Visible = picture
	end
end

-- Shows def `def` in team `team`'s color (rebuilds only on a change): its
-- picture when it has one, else its model.
function Portrait.set(p: Portrait, def: any, team: number)
	if showPicture(p, def) then
		p.key, p.template = `{def.id}|picture`, nil
		return
	end
	local template = Models.template(def)
	local key = `{def.id}|{team}`
	if key == p.key and template == p.template then
		return
	end
	p.key, p.template = key, template
	if p.model then
		p.model:Destroy()
	end
	local model = template:Clone()
	local color = TeamColors.of(team)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "TeamColor") then
			d.Color = color
		end
	end
	model.Parent = p.frame
	p.model = model
	-- the unit on its terrain (C-192): ground, water, a shore, or ground far
	-- below an aircraft; parts of the model, so they go with it
	local cf, size = model:GetBoundingBox()
	local kind = PortraitStage.kind(def)
	local bottom = cf.Position.Y - size.Y / 2
	local reach = math.max(size.X, size.Z) * 0.75 + 1
	local floorY = if kind == "air" then bottom - size.Y * PortraitStage.AIR_GAP else bottom
	local at = Vector3.new(cf.Position.X, floorY, cf.Position.Z)
	local function disc(name: string, color: Color3, transparency: number, y: number, offset: Vector3?, width: number?): Part
		local d = Instance.new("Part")
		d.Name = name
		d.Anchored = true
		d.CanCollide = false
		d.Shape = if width then Enum.PartType.Block else Enum.PartType.Cylinder
		d.Material = Enum.Material.SmoothPlastic
		d.Color = color
		d.Transparency = transparency
		if width then
			d.Size = Vector3.new(reach * 2, 0.4, width) -- a strip across the unit's front
			d.CFrame = CFrame.new(at + Vector3.new(0, y - 0.2, 0) + (offset or Vector3.zero))
		else
			d.Size = Vector3.new(0.4, reach * 2, reach * 2)
			d.CFrame = CFrame.new(at + Vector3.new(0, y - 0.2, 0) + (offset or Vector3.zero)) * CFrame.Angles(0, 0, math.pi / 2)
		end
		d.Parent = model
		return d
	end
	if kind == "water" then
		-- the hull sits a little in the water; the bed shows through below
		local waterline = size.Y * PortraitStage.WATERLINE
		disc("Seabed", Portrait.SEABED, 0, -size.Y * 0.4)
		disc("Water", Portrait.WATER, 0.3, waterline)
	elseif kind == "shore" then
		-- ground under the unit's back half, water ahead of it
		disc("Ground", Portrait.GROUND, 0, 0)
		disc("Water", Portrait.WATER, 0.25, 0.25, Vector3.new(0, 0, -reach * 0.5), reach) -- (a unit faces -Z)
	else
		disc("Ground", Portrait.GROUND, 0, 0)
		if kind == "air" then
			-- its shadow on the ground
			local s = disc("Shadow", Color3.new(0, 0, 0), 0.55, 0.05)
			s.Size = Vector3.new(0.4, math.max(size.X, size.Z) * 0.8, math.max(size.X, size.Z) * 0.8)
		end
	end
	-- frame the unit, and the ground under an aircraft
	local lo = math.min(bottom, floorY)
	local top = cf.Position.Y + size.Y / 2
	local center = Vector3.new(cf.Position.X, (lo + top) / 2, cf.Position.Z)
	local span = Vector3.new(size.X, top - lo, size.Z)
	local radius = math.max(span.Magnitude / 2, 1)
	local distance = radius / math.sin(math.rad(Portrait.FOV / 2)) * 0.95
	p.camera.CFrame = CFrame.lookAt(center + VIEW * distance, center)
end

return Portrait
