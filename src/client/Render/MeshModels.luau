--!strict
-- BAR-style unit models built on the client from the mesh manifest (C-103;
-- docs/contracts/rig.md section 7, `@shared/Defs/Meshes/Registry`): the game
-- place keeps no model files, so each "approved" entry is assembled once
-- at start from its uploaded meshes and maps, rigged like the blockouts
-- (rig.md 1-2), with its glow parts (docs/contracts/fx.md "Unit glow").
-- Entries still in "review" keep their blockout. Making a MeshPart yields
-- (CreateMeshPartAsync), so models build in background threads, a few at a
-- time; Render/Models uses one as soon as it is ready and `onReady` lets
-- the renderer swap the blockouts already drawn.
-- Game scripts can't write a SurfaceAppearance's texture maps or emissive
-- mask (they need the Plugin capability), but they may clone one: Rojo
-- syncs ReplicatedStorage.MeshMaterials (place/MeshMaterials.model.json,
-- `lune run mesh_materials`) with a SurfaceAppearance per model and the
-- glow parts' masked "Glow" one, and those are cloned here. Without them a
-- piece falls back to its color map as the MeshPart's TextureContent (its
-- alpha shows the part's color, the team paint) and glow parts don't emit.
-- What the runtime allowed is in `stats.caps`.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Meshes = require("@shared/Defs/Meshes/Registry")

local MeshModels = {}

MeshModels.AT_ONCE = 8 -- models building at the same time (4 until C-143)
MeshModels.TEAM_TAG = "TeamColor"
MeshModels.GLOW_TAG = "Glow"

local ready: { [string]: Model } = {}
local pending: { [string]: boolean } = {}
local listeners: { (string) -> () } = {}
MeshModels.stats = { built = 0, failed = 0, seconds = 0, errors = {} :: { string }, caps = {} :: { [string]: boolean }, readyAt = {} :: { [string]: number }, order = "" }

-- Sets `prop` if this script may; remembers whether it could.
local function try(inst: Instance, prop: string, value: any): boolean
	local caps = MeshModels.stats.caps
	if caps[prop] == false then
		return false
	end
	local ok = pcall(function()
		(inst :: any)[prop] = value
	end)
	caps[prop] = ok
	return ok
end

local TURN = CFrame.Angles(0, math.pi, 0) -- the meshes come in turned 180° about Y

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- (RenderFidelity can only be chosen here: game scripts can't set it later)
local function meshPart(id: string, center: { number }, size: { number }, precise: boolean?): MeshPart
	local options = if precise then { RenderFidelity = Enum.RenderFidelity.Precise } else nil
	local part = (AssetService :: any):CreateMeshPartAsync((Content :: any).fromUri(id), options) :: MeshPart
	part.Size = v3(size)
	part.CFrame = CFrame.new(v3(center)) * TURN
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Anchored = false
	return part
end

-- Runs `fns` at once and waits for all (each mesh piece is its own
-- CreateMeshPartAsync: one at a time, a 20-piece model took ~5 s, C-143).
-- Rethrows the first error.
local function together(fns: { () -> () })
	local left, err = #fns, nil
	local me = coroutine.running()
	for _, fn in fns do
		task.spawn(function()
			local ok, e = pcall(fn)
			if not ok and err == nil then
				err = e
			end
			left -= 1
			if left == 0 and coroutine.status(me) == "suspended" then
				task.spawn(me)
			end
		end)
	end
	if left > 0 then
		coroutine.yield()
	end
	if err then
		error(err, 0)
	end
end

-- Builds entry `e` for def `def` (yields). Model space = unit space.
local function build(def: any, e: any): Model
	local materials = ReplicatedStorage:FindFirstChild("MeshMaterials")
	local look = materials and materials:FindFirstChild(def.id)
	local glowLook = materials and materials:FindFirstChild("Glow")
	local model = Instance.new("Model")
	model.Name = def.model
	local parts: { [string]: MeshPart } = {}
	local maps = e.maps
	-- pieces, made all at once (the joints come after, with both ends)
	local made: { [string]: MeshPart } = {}
	local jobs = {}
	for name, p in e.pieces do
		table.insert(jobs, function()
			made[name] = meshPart(p.mesh, p.center, p.size)
		end)
	end
	together(jobs)
	for name, p in e.pieces do
		local part = made[name]
		part.Name = name
		if look and look:IsA("SurfaceAppearance") then
			look:Clone().Parent = part -- maps, Overlay: the alpha shows the team color (rig.md 6)
		else
			local sa = Instance.new("SurfaceAppearance")
			if try(sa, "ColorMapContent", (Content :: any).fromUri(maps.ALB)) then
				sa.AlphaMode = Enum.AlphaMode.Overlay
				try(sa, "NormalMapContent", (Content :: any).fromUri(maps.NOR))
				try(sa, "RoughnessMapContent", (Content :: any).fromUri(maps.RGH))
				try(sa, "MetalnessMapContent", (Content :: any).fromUri(maps.MTL))
				sa.Parent = part
			else
				sa:Destroy()
				part.TextureContent = (Content :: any).fromUri(maps.ALB)
			end
		end
		parts[name] = part
	end
	for _, name in e.teamPieces or {} do
		if parts[name] then
			CollectionService:AddTag(parts[name], MeshModels.TEAM_TAG)
		end
	end
	for name, p in e.pieces do
		local part = parts[name]
		if p.parent then
			local parent = parts[p.parent]
			local pivot = CFrame.new(v3(p.pivot :: any))
			local joint = Instance.new("Motor6D")
			joint.Name = name
			joint.Part0 = parent
			joint.Part1 = part
			joint.C0 = parent.CFrame:Inverse() * pivot
			joint.C1 = part.CFrame:Inverse() * pivot
			joint.Parent = part
		end
		part.Parent = model
	end
	local base = parts.base
	base.Anchored = true
	for name, a in e.attachments or {} do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = parts[a.parent].CFrame:Inverse() * CFrame.new(v3(a.at))
		attachment.Parent = parts[a.parent]
	end
	-- glow parts: albedo = tint, the shared white mask, welded to their piece
	local glowParts: { [number]: MeshPart } = {}
	local glowJobs = {}
	for i, g in e.glow or {} do
		table.insert(glowJobs, function()
			glowParts[i] = meshPart(g.mesh, g.center, g.size, true)
		end)
	end
	together(glowJobs)
	for i, g in e.glow or {} do
		local part = glowParts[i]
		part.Name = g.name
		part.CastShadow = false
		local tint = Color3.fromRGB(g.tint[1], g.tint[2], g.tint[3])
		part.Color = tint
		local sa = if glowLook and glowLook:IsA("SurfaceAppearance") then glowLook:Clone() else Instance.new("SurfaceAppearance")
		if glowLook == nil then
			try(sa, "EmissiveMaskContent", (Content :: any).fromUri(Meshes.glowMask))
		end
		try(sa, "EmissiveTint", tint)
		try(sa, "EmissiveStrength", g.strength)
		sa.Parent = part
		part:SetAttribute("GlowChannel", g.channel)
		part:SetAttribute("GlowPiece", g.piece)
		part:SetAttribute("GlowTint", tint)
		part:SetAttribute("GlowStrength", g.strength)
		CollectionService:AddTag(part, MeshModels.GLOW_TAG)
		local weld = Instance.new("WeldConstraint")
		weld.Name = "Weld"
		weld.Part0 = parts[g.piece]
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	model.PrimaryPart = base
	model:SetAttribute("DefId", def.id)
	model:SetAttribute("RootOffset", base.CFrame)
	model:SetAttribute("FootprintStuds", (def.footprint or 1) * 8)
	model:SetAttribute("Meshed", true)
	return model
end

-- Starts building every approved entry that has a def in `defs`.
-- The order (C-106): a job's priority is the highest `want` it got (types
-- drawn on screen first, then the player's faction, then the rest); ties
-- go alphabetically. Priorities can rise while jobs wait.
type Job = { def: any, entry: any, want: number }
local waiting: { [string]: Job } = {}
local started = false

-- Raises def `id`'s place in the queue to at least `level` (if it waits).
function MeshModels.want(id: string, level: number)
	local job = waiting[id]
	if job and level > job.want then
		job.want = level
	end
end

-- Whether start has run.
function MeshModels.started(): boolean
	return started
end

local function nextJob(): Job?
	local best: Job? = nil
	for _, job in waiting do
		if best == nil or job.want > best.want or (job.want == best.want and job.def.id < best.def.id) then
			best = job
		end
	end
	return best
end

-- Review entries to build anyway (a Studio debug switch for reviewing a
-- model in game: FtggClientDebug:Invoke("reviewmesh", id), C-160).
MeshModels.REVIEW = {} :: { [string]: boolean }

function MeshModels.start(defs: any)
	started = true
	for id, e in Meshes.units do
		local def = defs.units and defs.units[id]
		if (e.status == "approved" or MeshModels.REVIEW[id]) and def and ready[id] == nil and not pending[id] then
			pending[id] = true
			waiting[id] = { def = def, entry = e, want = 0 }
		end
	end
	local t0 = os.clock()
	local running = 0
	task.spawn(function()
		task.wait() -- let the caller set this frame's priorities first
		while true do
			while running >= MeshModels.AT_ONCE do
				task.wait()
			end
			local job = nextJob()
			if job == nil then
				break
			end
			waiting[job.def.id] = nil
			running += 1
			task.spawn(function()
				local id = job.def.id
				local ok, result = pcall(build, job.def, job.entry)
				pending[id] = nil
				running -= 1
				if ok then
					ready[id] = result
					MeshModels.stats.built += 1
					MeshModels.stats.readyAt[id] = os.clock() - t0
					MeshModels.stats.order ..= (if MeshModels.stats.order == "" then "" else " ") .. id
					for _, f in listeners do
						task.spawn(f, id)
					end
				else
					MeshModels.stats.failed += 1
					table.insert(MeshModels.stats.errors, `{id}: {result}`)
					warn(`[Client] mesh model {id} failed, the blockout stays: {result}`)
				end
				MeshModels.stats.seconds = os.clock() - t0
			end)
		end
	end)
end

-- Wreck meshes (C-115, models-C's `wreck` per entry): the live entry's rig
-- (piece names, parents, pivots) with the wreck's own meshes, centers and
-- sizes and its maps (MeshMaterials `wreck_<id>`); no glow parts, no team
-- pieces. Used once the wreck is approved (`wreck.status == "approved"`;
-- they start as review) or with WRECKS_ANYWAY (a debug switch for review).
-- Built on demand in the background; nil until ready.
MeshModels.WRECKS_ANYWAY = false
local wrecks: { [string]: Model } = {}
local wrecksPending: { [string]: boolean } = {}

local function buildWreck(def: any, e: any): Model
	local w = e.wreck
	local materials = ReplicatedStorage:FindFirstChild("MeshMaterials")
	local look = materials and materials:FindFirstChild("wreck_" .. def.id)
	local model = Instance.new("Model")
	model.Name = def.model .. "_wreck"
	local parts: { [string]: MeshPart } = {}
	for name, p in w.pieces do
		local part = meshPart(p.mesh, p.center, p.size)
		part.Name = name
		part.CastShadow = true
		if look and look:IsA("SurfaceAppearance") then
			look:Clone().Parent = part
		else
			part.TextureContent = (Content :: any).fromUri(w.maps.ALB)
		end
		parts[name] = part
	end
	for name, part in parts do
		local live = e.pieces[name]
		if live and live.parent and parts[live.parent] then
			local parent = parts[live.parent]
			local pivot = CFrame.new(v3(live.pivot))
			local joint = Instance.new("Motor6D")
			joint.Name = name
			joint.Part0 = parent
			joint.Part1 = part
			joint.C0 = parent.CFrame:Inverse() * pivot
			joint.C1 = part.CFrame:Inverse() * pivot
			joint.Parent = part
		end
		part.Parent = model
	end
	parts.base.Anchored = true
	model.PrimaryPart = parts.base
	model:SetAttribute("DefId", def.id)
	model:SetAttribute("RootOffset", parts.base.CFrame)
	model:SetAttribute("Meshed", true)
	return model
end

-- The meshed wreck template for def `def` (clone it), or nil (none, not
-- approved, or still building: the build starts on the first ask).
function MeshModels.wreck(def: any): Model?
	local ready = wrecks[def.id]
	if ready then
		return ready
	end
	local e = Meshes.units[def.id] :: any
	local w = e and e.wreck
	if w == nil or e.status ~= "approved" or (w.status ~= "approved" and not MeshModels.WRECKS_ANYWAY) or wrecksPending[def.id] then
		return nil
	end
	wrecksPending[def.id] = true
	task.spawn(function()
		local ok, result = pcall(buildWreck, def, e)
		wrecksPending[def.id] = nil
		if ok then
			wrecks[def.id] = result
		else
			warn(`[Client] wreck mesh {def.id} failed, the darkened model stays: {result}`)
		end
	end)
	return nil
end

-- Supply deposit looks (Meshes.fx.deposit and its `variants`, C-123): the
-- template for variant `i` (clone it), or nil (no entry, not approved yet
-- unless DEPOSITS_ANYWAY, or still building: the build starts on the
-- first ask). The `base` piece is the ground patch (TeamColor tag: the
-- caller tints it to the terrain).
MeshModels.DEPOSITS_ANYWAY = false
local deposits: { [number]: Model } = {}
local depositsPending: { [number]: boolean } = {}

function MeshModels.depositVariants(): number
	local e = ((Meshes :: any).fx or {}).deposit
	if e == nil or (e.status ~= "approved" and not MeshModels.DEPOSITS_ANYWAY) then
		return 0
	end
	return if e.variants then #e.variants else 1
end

function MeshModels.deposit(i: number): Model?
	if deposits[i] then
		return deposits[i]
	end
	local e = ((Meshes :: any).fx or {}).deposit
	if e == nil or depositsPending[i] or i > MeshModels.depositVariants() then
		return nil
	end
	local v = if e.variants then e.variants[i] else e
	depositsPending[i] = true
	task.spawn(function()
		local name = if e.variants then `fx_deposit_{i}` else "fx_deposit"
		local ok, result = pcall(build, { id = name, model = name, footprint = 1 }, v)
		if ok then
			deposits[i] = result
		else
			warn(`[Client] deposit mesh {i} failed, the plain patch stays: {result}`)
		end
	end)
	return nil
end

-- Map feature looks (S-197: Meshes.fx.feature_tree / feature_rock, each
-- with `variants`, models-C's): the template for variant `i` of `name`
-- (clone it), or nil (no entry, not approved yet unless FEATURES_ANYWAY, or
-- still building: the build starts on the first ask). One `base` piece,
-- its origin on the ground at the feature's centre.
MeshModels.FEATURES_ANYWAY = false
local fxBuilt: { [string]: Model } = {}
local fxPending: { [string]: boolean } = {}
MeshModels.fxVersion = 0 -- bumps when a variant finishes (Render/Deaths swaps its placeholders)

function MeshModels.fxVariants(name: string): number
	local e = ((Meshes :: any).fx or {})[name]
	if e == nil or (e.status ~= "approved" and not MeshModels.FEATURES_ANYWAY) then
		return 0
	end
	return if e.variants then #e.variants else 1
end

function MeshModels.fxVariant(name: string, i: number): Model?
	local key = `{name}_{i}`
	if fxBuilt[key] then
		return fxBuilt[key]
	end
	local e = ((Meshes :: any).fx or {})[name]
	if e == nil or fxPending[key] or i > MeshModels.fxVariants(name) then
		return nil
	end
	local v = if e.variants then e.variants[i] else e
	fxPending[key] = true
	task.spawn(function()
		local ok, result = pcall(build, { id = key, model = key, footprint = 1 }, v)
		if ok then
			fxBuilt[key] = result
			MeshModels.fxVersion += 1
		else
			warn(`[Client] {key} mesh failed, the placeholder stays: {result}`)
		end
	end)
	return nil
end

-- The built model for def `id` (a template: clone it), if ready.
function MeshModels.get(id: string): Model?
	return ready[id]
end

-- Whether def `id`'s model is still building.
function MeshModels.pending(id: string): boolean
	return pending[id] == true
end

-- Calls `f(defId)` each time a model finishes.
function MeshModels.onReady(f: (string) -> ())
	table.insert(listeners, f)
end

return MeshModels
