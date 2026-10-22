--!strict
-- Checks a mesh manifest entry (Meshes/Registry.luau, docs/contracts/rig.md
-- section 7) against its unit def. Pure data: runs in Lune and Roblox.

local Mesh = {}

Mesh.STATUSES = { approved = true, review = true }
Mesh.CHANNELS = { running = true, head = true, power = true, weapon = true }
Mesh.MAPS = { "ALB", "NOR", "RGH", "MTL", "EMI" }
-- how the client may move an animated piece (rig.md "Animated pieces", M-27)
Mesh.MOTIONS = { spin = true, turn = true, scroll = true, slide = true, open = true, lower = true, pulse = true }

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
		for name in e.pieces do
			local p = wp[name]
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
		for name in e.attachments or {} do
			if isAttachmentPiece(name) and not inDef[name] then
				bad(`attachment {name} isn't in the def's pieces`)
			end
		end
	end
	return problems
end

return Mesh
