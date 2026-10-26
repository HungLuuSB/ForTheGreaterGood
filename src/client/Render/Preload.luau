--!strict
-- Caching everything before a lobby match starts (C-173, the user: "CACHE
-- EVERYTHING AT LOADING"): how far this client is, 0..1, from what has to
-- be ready before the first tick plays:
--   0.10  joined (the WELCOME: map, defs, seat)
--   0.20  the map's ground built (Render/Ground: terrain or mesh tiles)
--   0.50  every approved unit mesh built (Render/MeshModels, started for all
--         of them at once: both factions, so nothing pops in mid-match)
--   0.20  the meshes' textures and the icon sheets downloaded
--         (ContentProvider:PreloadAsync on the SurfaceAppearances and
--         IconAtlas.images; the user: every model ready before the match)
-- A model that fails to build counts as done (its blockout draws instead).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Meshes = require("@shared/Defs/Meshes/Registry")
local IconAtlas = require("../UI/IconAtlas")
local Ground = require("./Ground")
local MeshModels = require("./MeshModels")
local World = require("../Core/World")

local Preload = {}

export type State = { textures: number, texturesStarted: boolean, total: number }

function Preload.new(): State
	local total = 0
	for _, e in (Meshes :: any).units do
		if e.status == "approved" then
			total += 1
		end
	end
	return { textures = 0, texturesStarted = false, total = total }
end

-- Starts downloading the textures (once): every SurfaceAppearance the
-- meshes use, then whatever else Roblox has queued.
local function startTextures(st: State)
	st.texturesStarted = true
	task.spawn(function()
		local materials = ReplicatedStorage:WaitForChild("MeshMaterials", 30)
		local list: { any } = if materials then materials:GetChildren() else {}
		for _, image in IconAtlas.images do
			table.insert(list, image)
		end
		if #list == 0 then
			st.textures = 1
			return
		end
		local done = 0
		pcall(function()
			ContentProvider:PreloadAsync(list, function()
				done += 1
				st.textures = math.min(done / #list, 0.99)
			end)
		end)
		st.textures = 1
	end)
end

-- This client's progress, 0..1.
function Preload.progress(st: State, world: World.World): number
	if not st.texturesStarted then
		startTextures(st)
	end
	local joined = if world.joined then 1 else 0
	local last = Ground.last
	local ground = if last and (last.seconds ~= nil or last.mesh ~= nil) then 1 else 0
	local s = MeshModels.stats
	local meshes = if st.total == 0 then 1 else math.min((s.built + s.failed) / st.total, 1)
	return 0.1 * joined + 0.2 * ground + 0.5 * meshes + 0.2 * st.textures
end

return Preload
