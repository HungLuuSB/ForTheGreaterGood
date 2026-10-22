--!strict
-- Unit portraits for the build menu (C-107, BAR style): a ViewportFrame
-- showing the unit's model (the BAR mesh when it's loaded, else its
-- blockout) at a three-quarter angle from above, in the player's team
-- color. A portrait follows its model: `set` rebuilds only when the def,
-- the team or the template changed (a mesh model finishing replaces the
-- blockout stand-in). The model is static: no physics, no animation.

local CollectionService = game:GetService("CollectionService")

local Models = require("../Render/Models")
local TeamColors = require("../Render/TeamColors")

local Portrait = {}

Portrait.FOV = 30
-- from the unit's front right, above (its forward is -Z)
local VIEW = Vector3.new(0.8, 0.65, -1).Unit

export type Portrait = { frame: ViewportFrame, camera: Camera, key: string?, template: Model?, model: Model? }

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

-- Shows def `def` in team `team`'s color (rebuilds only on a change).
function Portrait.set(p: Portrait, def: any, team: number)
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
	local color = TeamColors(team)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "TeamColor") then
			d.Color = color
		end
	end
	model.Parent = p.frame
	p.model = model
	-- frame the whole model
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.Magnitude / 2, 1)
	local distance = radius / math.sin(math.rad(Portrait.FOV / 2)) * 0.95
	local center = cf.Position
	p.camera.CFrame = CFrame.lookAt(center + VIEW * distance, center)
end

return Portrait
