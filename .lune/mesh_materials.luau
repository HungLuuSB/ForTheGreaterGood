--!strict
-- Writes place/MeshMaterials.model.json (Rojo maps it to
-- ReplicatedStorage.MeshMaterials) from the mesh manifest (C-103,
-- src/client/Core/MeshMaterials): the meshed models' SurfaceAppearances and
-- the glow mask, which game scripts can't set but Rojo can.
-- Run after the manifest changes: `lune run mesh_materials`
-- (`lune run test_client MeshMaterials` fails while the file is stale).

local fs = require("@lune/fs")

local MeshMaterials = require("../src/client/Core/MeshMaterials")

local text = MeshMaterials.render()
-- git may check the file out with CRLF line ends
local old = if fs.isFile(MeshMaterials.FILE) then (string.gsub(fs.readFile(MeshMaterials.FILE), "\r\n", "\n")) else nil
if old == text then
	print(`{MeshMaterials.FILE} is up to date`)
else
	fs.writeFile(MeshMaterials.FILE, text)
	print(`wrote {MeshMaterials.FILE}`)
end
