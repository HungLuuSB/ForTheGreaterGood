--!strict
-- Checks a mesh manifest entry (Meshes/Registry.luau, docs/contracts/rig.md
-- section 7) against its unit def. Pure data: runs in Lune and Roblox.

local Mesh = {}

Mesh.STATUSES = { approved = true, review = true }
Mesh.CHANNELS = { running = true, head = true, power = true, weapon = true }
Mesh.MAPS = { "ALB", "NOR", "RGH", "MTL", "EMI" }
-- how the client may move an animated piece (rig.md "Animated pieces", M-27)
Mesh.MOTIONS = { spin = true, turn = true, scroll = true, slide = true, open = true, lower = true, pulse = true, swing = true }

local function isAssetId(v: any): boolean
	return type(v) == "string" and string.match(v, "^rbxassetid://%d+$") ~= nil
end
Mesh.isAssetId = isAssetId

local function isVec3(v: any): boolean
	return type(v) == "table" and #v == 3 and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end

local function isAttachmentPiece(name: string): boolean
	return string.match(name, "^muzzle%d*$") ~= nil
end

-- the beam shot (M-29, fx.md "Beam shot"): its textures and the values each
-- faction needs
Mesh.BEAM_TEXTURES = { "core", "glow", "filamentA", "filamentB", "charge", "impact", "scorch", "scorchGlow" }
Mesh.BEAM_VALUES = {
	"charge", "duration", "taper", "coreWidth", "glowWidth", "filamentWidth", "filaments", "spread", "fan", "tip", "jitter", "curve",
	"brightness", "glowBrightness", "filamentBrightness", "flareSize", "muzzleFlareSize", "impactSize", "impactTime", "scorchSize", "scorchTime", "scorchGlowTime",
}

-- Problems with the manifest's `beam` entry, empty when valid.
function Mesh.validateBeam(e: any): { string }
	local problems: { string } = {}
	if not Mesh.STATUSES[e.status] then
		table.insert(problems, `beam: status {tostring(e.status)} must be "approved" or "review"`)
	end
	for _, k in Mesh.BEAM_TEXTURES do
		if not isAssetId(e.textures and e.textures[k]) then
			table.insert(problems, `beam: texture {k} asset ID missing`)
		end
	end
	for _, faction in { "order", "chaos" } do
		local f = e.factions and e.factions[faction]
		if type(f) ~= "table" then
			table.insert(problems, `beam: no values for {faction}`)
			continue
		end
		for _, k in Mesh.BEAM_VALUES do
			if type(f[k]) ~= "number" then
				table.insert(problems, `beam: {faction}.{k} must be a number`)
			end
		end
		for _, k in { "coreColor", "glowColor", "filamentColor" } do
			if not isVec3(f[k]) then
				table.insert(problems, `beam: {faction}.{k} must be three numbers`)
			end
		end
	end
	return problems
end

-- Problems with the manifest's `shieldShell` entry (M-30, fx.md "Honeycomb
-- shell"), empty when valid.
function Mesh.validateShieldShell(e: any): { string }
	local problems: { string } = {}
	local function bad(msg: string)
		table.insert(problems, `shieldShell: {msg}`)
	end
	if not Mesh.STATUSES[e.status] then
		bad(`status {tostring(e.status)} must be "approved" or "review"`)
	end
	if not isAssetId(e.texture) then
		bad("texture asset ID missing")
	end
	if type(e.bands) ~= "table" or #e.bands == 0 then
		bad("no bands")
		return problems
	end
	local last = 0
	for i, b in e.bands do
		if not isAssetId(b.mesh) then
			bad(`band {i}: mesh asset ID missing`)
		end
		if type(b.opacity) ~= "number" or b.opacity < 0 or b.opacity > 1 then
			bad(`band {i}: opacity must be 0..1`)
		end
		if not isVec3(b.center) or not isVec3(b.size) then
			bad(`band {i}: center and size must be three numbers`)
		end
		if type(b.theta) ~= "table" or b.theta[1] ~= last or not (b.theta[2] > b.theta[1]) then
			bad(`band {i}: theta must continue from {last} degrees`)
		else
			last = b.theta[2]
		end
	end
	return problems
end

-- Problems with the manifest's `shieldWave` entry (fx.md "Dome waves"): bands
-- whose centres step evenly from the top (0) to the rim (90), each spanning
-- two steps, and the wave values the client scales by strength.
function Mesh.validateShieldWave(e: any): { string }
	local problems: { string } = {}
	local function bad(msg: string)
		table.insert(problems, `shieldWave: {msg}`)
	end
	if not Mesh.STATUSES[e.status] then
		bad(`status {tostring(e.status)} must be "approved" or "review"`)
	end
	if not isAssetId(e.texture) then
		bad("texture asset ID missing")
	end
	for _, k in { "radius", "width", "waves", "seconds", "opacity" } do
		if type(e[k]) ~= "number" or e[k] <= 0 then
			bad(`{k} must be a positive number`)
		end
	end
	if type(e.bands) ~= "table" or #e.bands < 2 then
		bad("needs at least two bands")
		return problems
	end
	local step = 90 / (#e.bands - 1)
	for i, b in e.bands do
		if not isAssetId(b.mesh) then
			bad(`band {i}: mesh asset ID missing`)
		end
		if not isVec3(b.center) or not isVec3(b.size) then
			bad(`band {i}: center and size must be three numbers`)
		end
		if type(b.centre) ~= "number" or math.abs(b.centre - (i - 1) * step) > 1e-3 then
			bad(`band {i}: centre must be {(i - 1) * step} degrees`)
		end
		if type(b.theta) ~= "table" or b.theta[1] ~= math.max(0, b.centre - step) or b.theta[2] ~= math.min(90, b.centre + step) then
			bad(`band {i}: theta must span two steps round its centre`)
		end
	end
	return problems
end

-- Problems with the manifest's `shieldColumn` entry (fx.md "Energy column").
function Mesh.validateShieldColumn(e: any): { string }
	local problems: { string } = {}
	local function bad(msg: string)
		table.insert(problems, `shieldColumn: {msg}`)
	end
	if not Mesh.STATUSES[e.status] then
		bad(`status {tostring(e.status)} must be "approved" or "review"`)
	end
	for _, layer in { "core", "swirl", "glow" } do
		local l = e[layer]
		if type(l) ~= "table" then
			bad(`{layer} missing`)
			continue
		end
		if not isAssetId(l.texture) then
			bad(`{layer}: texture asset ID missing`)
		end
		for _, k in { "width0", "width1", "textureLength", "brightness" } do
			if type(l[k]) ~= "number" or l[k] <= 0 then
				bad(`{layer}: {k} must be a positive number`)
			end
		end
		if type(l.transparency) ~= "number" or l.transparency < 0 or l.transparency > 1 then
			bad(`{layer}: transparency must be 0..1`)
		end
	end
	if type(e.weakest) ~= "number" or e.weakest <= 0 or e.weakest > 1 then
		bad("weakest must be 0..1")
	end
	if type(e.deploy) ~= "table" or type(e.collapse) ~= "table" then
		bad("deploy and collapse timings missing")
	end
	return problems
end

-- Problems with the manifest's `shieldEnergy` entry (fx.md "Shield energy"):
-- every texture an asset, the bands stepping evenly from the apex (0) to the
-- ground (90) without gaps, the grid and hit cap meshes, and the values the
-- client needs.
function Mesh.validateShieldEnergy(e: any): { string }
	local problems: { string } = {}
	local function bad(msg: string)
		table.insert(problems, `shieldEnergy: {msg}`)
	end
	if not Mesh.STATUSES[e.status] then
		bad(`status {tostring(e.status)} must be "approved" or "review"`)
	end
	local tex = e.textures or {}
	for _, k in { "pulse", "glow", "line", "spark", "flare", "streak", "field" } do
		if not isAssetId(tex[k]) then
			bad(`texture {k} asset ID missing`)
		end
	end
	for k, n in { waveGlow = 3, waveLine = 3, hit = 8 } do
		if type(tex[k]) ~= "table" or #tex[k] ~= n then
			bad(`textures.{k} must list {n} images`)
			continue
		end
		for i, id in tex[k] do
			if not isAssetId(id) then
				bad(`textures.{k}[{i}] asset ID missing`)
			end
		end
	end
	if type(e.bands) ~= "table" or #e.bands < 2 then
		bad("needs at least two bands")
	else
		local step = 90 / #e.bands
		for i, b in e.bands do
			if not isAssetId(b.mesh) then
				bad(`band {i}: mesh asset ID missing`)
			end
			if not isVec3(b.center) or not isVec3(b.size) then
				bad(`band {i}: center and size must be three numbers`)
			end
			if type(b.theta) ~= "table" or math.abs(b.theta[1] - (i - 1) * step) > 1e-3 or math.abs(b.theta[2] - i * step) > 1e-3 then
				bad(`band {i}: theta must be {(i - 1) * step}..{i * step} degrees`)
			end
		end
	end
	for _, k in { "hexGrid", "hitCap" } do
		local p = e[k]
		if type(p) ~= "table" or not isAssetId(p.mesh) or not isVec3(p.center) or not isVec3(p.size) then
			bad(`{k} needs a mesh, center and size`)
		end
	end
	for _, group in { "timing", "counts", "sizes" } do
		if type(e[group]) ~= "table" then
			bad(`{group} missing`)
			continue
		end
		for k, v in e[group] do
			if type(v) ~= "number" or v <= 0 then
				bad(`{group}.{k} must be a positive number`)
			end
		end
	end
	if type(e.counts) == "table" and type(e.bands) == "table" and e.counts.bands ~= #e.bands then
		bad("counts.bands must match the bands listed")
	end
	if type(e.tints) ~= "table" or not isVec3(e.tints.order) or not isVec3(e.tints.chaos) then
		bad("tints.order and tints.chaos must be RGB")
	end
	return problems
end

-- Problems with one entry, empty when valid. `def` is the unit def (nil for
-- an fx entry, which has no def to match); `visual` is the blockout's
-- `visualPieces` (client-only jointed pieces, rig.md 4), also allowed.
function Mesh.validate(id: string, e: any, def: any?, visual: { string }?): { string }
	local problems: { string } = {}
	local function bad(msg: string)
		table.insert(problems, `{id}: {msg}`)
	end
	if not Mesh.STATUSES[e.status] then
		bad(`status {tostring(e.status)} must be "approved" or "review"`)
	end
	if not isAssetId(e.model) then
		bad("model asset ID missing")
	end
	for _, k in Mesh.MAPS do
		if not isAssetId(e.maps and e.maps[k]) then
			bad(`map {k} asset ID missing`)
		end
	end
	if type(e.pieces) ~= "table" or e.pieces.base == nil then
		bad("no base piece")
		return problems
	end
	for name, p in e.pieces do
		if not isAssetId(p.mesh) then
			bad(`piece {name}: mesh asset ID missing`)
		end
		if not isVec3(p.center) or not isVec3(p.size) then
			bad(`piece {name}: center and size must be three numbers`)
		end
		if name == "base" then
			if p.parent ~= nil then
				bad("base can't have a parent")
			end
		else
			if p.parent == nil or e.pieces[p.parent] == nil then
				bad(`piece {name}: parent {tostring(p.parent)} isn't a piece`)
			end
			if not isVec3(p.pivot) then
				bad(`piece {name}: pivot missing`)
			end
		end
	end
	for name, a in e.attachments or {} do
		if e.pieces[a.parent] == nil then
			bad(`attachment {name}: parent {tostring(a.parent)} isn't a piece`)
		end
		if not isVec3(a.at) then
			bad(`attachment {name}: at must be three numbers`)
		end
	end
	for _, name in e.teamPieces or {} do
		if e.pieces[name] == nil then
			bad(`team piece {name} isn't a piece`)
		end
	end
	local glowNames: { [string]: boolean } = {}
	for _, g in e.glow or {} do
		if glowNames[g.name] then
			bad(`glow part {g.name} listed twice`)
		end
		glowNames[g.name] = true
		if e.pieces[g.piece] == nil then
			bad(`glow part {g.name}: piece {tostring(g.piece)} isn't a piece`)
		end
		if not Mesh.CHANNELS[g.channel] then
			bad(`glow part {g.name}: unknown channel {tostring(g.channel)}`)
		end
		if g.name ~= `{g.piece}_glow_{g.channel}` then
			bad(`glow part {g.name}: name must be <piece>_glow_<channel>`)
		end
		if not isAssetId(g.mesh) then
			bad(`glow part {g.name}: mesh asset ID missing`)
		end
		if not isVec3(g.tint) or type(g.strength) ~= "number" or g.strength <= 0 then
			bad(`glow part {g.name}: tint and strength required`)
		end
	end
	for _, name in e.visualPieces or {} do
		if e.pieces[name] == nil then
			bad(`visual piece {name} isn't a piece`)
		end
	end
	for name, a in e.anim or {} do
		if e.pieces[name] == nil then
			bad(`anim {name} isn't a piece`)
		end
		if not Mesh.MOTIONS[a.motion] then
			bad(`anim {name}: unknown motion {tostring(a.motion)}`)
		end
		if not isVec3(a.axis) then
			bad(`anim {name}: axis must be three numbers`)
		end
	end
	-- variants (supply deposits, M-28): each a full entry
	for i, v in e.variants or {} do
		for _, problem in Mesh.validate(`{id}[{i}]`, v, nil, nil) do
			table.insert(problems, problem)
		end
	end
	-- the wreck version (M-24): the live mesh's pieces, its own meshes and
	-- maps, no glow (EMI not needed)
	local w = e.wreck
	if w ~= nil then
		if not Mesh.STATUSES[w.status] then
			bad(`wreck: status {tostring(w.status)} must be "approved" or "review"`)
		end
		if not isAssetId(w.model) then
			bad("wreck: model asset ID missing")
		end
		for _, k in Mesh.MAPS do
			if k ~= "EMI" and not isAssetId(w.maps and w.maps[k]) then
				bad(`wreck: map {k} asset ID missing`)
			end
		end
		local wp = if type(w.pieces) == "table" then w.pieces else {}
		-- the mesh's own animated sub-pieces (M-27) may stay merged into
		-- their parent on a wreck: nothing moves on a wreck
		local sub: { [string]: boolean } = {}
		for _, name in e.visualPieces or {} do
			sub[name] = true
		end
		for name in e.pieces do
			local p = wp[name]
			if p == nil and sub[name] then
				continue
			end
			if p == nil or not isAssetId(p.mesh) then
				bad(`wreck: piece {name} mesh missing`)
			elseif not isVec3(p.center) or not isVec3(p.size) then
				bad(`wreck: piece {name}: center and size must be three numbers`)
			end
		end
		for name in wp do
			if e.pieces[name] == nil then
				bad(`wreck: piece {name} isn't a live piece`)
			end
		end
	end
	if def then
		if def.id ~= id then
			bad("id doesn't match the def")
		end
		local inDef: { [string]: boolean } = {}
		for _, name in def.pieces or {} do
			inDef[name] = true
			if isAttachmentPiece(name) then
				if (e.attachments or {})[name] == nil then
					bad(`def piece {name} must be an attachment`)
				end
			elseif e.pieces[name] == nil then
				bad(`def piece {name} has no mesh piece`)
			end
		end
		local inVisual: { [string]: boolean } = {}
		for _, name in visual or {} do
			inVisual[name] = true
		end
		for _, name in e.visualPieces or {} do -- the mesh's own animated sub-pieces
			inVisual[name] = true
		end
		for name in e.pieces do
			if not inDef[name] and not inVisual[name] then
				bad(`piece {name} isn't in the def's pieces or the blockout's visualPieces`)
			end
		end
		-- an unarmed def may carry a decorative muzzle (the Commander mechs'
		-- weapon pods, M-31): nothing fires from it
		local armed = def.weapons ~= nil and #def.weapons > 0
		for name in e.attachments or {} do
			if isAttachmentPiece(name) and not inDef[name] and armed then
				bad(`attachment {name} isn't in the def's pieces`)
			end
		end
	end
	return problems
end

return Mesh
