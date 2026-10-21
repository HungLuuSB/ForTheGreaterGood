--!strict
-- Out-of-sight things in the world (C-32, from Core/Ghosts): radar and
-- sonar contacts as pulsing discs on the ground or water (sonar larger and
-- paler), and ghost structures as faintly glowing blue-grey copies where
-- they were last seen (they sit in the fog, so they glow to be found). Hidden at strategic zoom, where the icons show them. Looks are
-- placeholders ("Needs my review").

local Ghosts = require("../Core/Ghosts")
local Terrain = require("../Core/Terrain")
local World = require("../Core/World")
local Models = require("./Models")
local TeamColors = require("./TeamColors")

local Contacts = {}

Contacts.BLIP_SIZE = 6
Contacts.SONAR_SIZE = 10
Contacts.GHOST_TRANSPARENCY = 0.7
Contacts.GHOST_COLOR = Color3.fromRGB(150, 165, 190)
Contacts.GHOST_GREY = 0.75 -- how far ghost colors fade to GHOST_COLOR

export type Contacts = {
	folder: Folder,
	discs: { BasePart },
	ghostModels: { [number]: { model: Model, defId: string } }, -- ghost record id → its model
	free: { [string]: { Model } }, -- ghost models by def id, for reuse
	memory: Ghosts.State,
	stats: { contacts: number, ghosts: number },
}

function Contacts.new(): Contacts
	local folder = Instance.new("Folder")
	folder.Name = "Contacts"
	folder.Parent = workspace
	return { folder = folder, discs = {}, ghostModels = {}, free = {}, memory = Ghosts.new(), stats = { contacts = 0, ghosts = 0 } }
end

local function disc(c: Contacts, i: number): BasePart
	local p = c.discs[i]
	if p == nil then
		local part = Instance.new("Part")
		part.Name = "Contact"
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Parent = c.folder
		c.discs[i] = part
		p = part
	end
	return p :: BasePart
end

local function putBack(c: Contacts, defId: string, model: Model)
	model.Parent = nil
	local list = c.free[defId]
	if list == nil then
		list = {}
		c.free[defId] = list
	end
	table.insert(list, model)
end

local function ghostModel(c: Contacts, def: any): Model
	local list = c.free[def.id]
	if list and #list > 0 then
		return table.remove(list) :: Model
	end
	local model = Models.template(def):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = d.Color:Lerp(Contacts.GHOST_COLOR, Contacts.GHOST_GREY)
			d.Transparency = math.max(d.Transparency, Contacts.GHOST_TRANSPARENCY)
			d.Material = Enum.Material.Neon
			d.CastShadow = false
		end
	end
	return model
end

-- Per frame. `hidden` at strategic zoom. Call before the frame clears world.died.
function Contacts.step(c: Contacts, world: World.World, now: number, hidden: boolean)
	Ghosts.remember(c.memory, world)
	local ghosts, contacts = Ghosts.list(c.memory, world)
	c.stats.contacts, c.stats.ghosts = #contacts, #ghosts
	local layers = world.layers
	-- contacts
	local n = 0
	if not hidden and layers then
		for _, k in contacts do
			n += 1
			local p = disc(c, n)
			local size = if k.sonar then Contacts.SONAR_SIZE else Contacts.BLIP_SIZE
			local y = Terrain.surfaceY(layers, k.x, k.z) + 0.4
			p.Size = Vector3.new(0.3, size, size)
			p.CFrame = CFrame.new(k.x, y, k.z) * CFrame.Angles(0, 0, math.pi / 2)
			local color = TeamColors(k.team)
			p.Color = if k.sonar then color:Lerp(Color3.fromRGB(140, 230, 255), 0.5) else color
			p.Transparency = (if k.sonar then 0.45 else 0.25) + 0.3 * (0.5 + 0.5 * math.sin(now * 4 + k.id))
		end
	end
	for i = n + 1, #c.discs do
		c.discs[i].Transparency = 1
	end
	-- ghosts
	local keep: { [number]: boolean } = {}
	if not hidden and layers then
		for _, g in ghosts do
			keep[g.id] = true
			local entry = c.ghostModels[g.id]
			if entry and entry.defId ~= g.def.id then
				putBack(c, entry.defId, entry.model)
				entry = nil
			end
			if entry == nil then
				local model = ghostModel(c, g.def)
				entry = { model = model, defId = g.def.id }
				c.ghostModels[g.id] = entry
				-- placed like a unit (rig.md): the root part at the unit origin times RootOffset
				local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
				local y = World.groundY(world, g.x, g.z)
				local root = model.PrimaryPart :: BasePart
				model.Parent = c.folder
				root.CFrame = CFrame.new(g.x, y, g.z) * CFrame.Angles(0, g.heading + math.pi, 0) * offset
			end
		end
	end
	for id, entry in c.ghostModels do
		if not keep[id] then
			putBack(c, entry.defId, entry.model)
			c.ghostModels[id] = nil
		end
	end
end

return Contacts
