--!strict
-- Builds Cmd-channel payloads (Schema.encodeCommand; net.md section 9).
-- Pure Luau (C-7): the Roblox side only fires the returned buffers.

local Grid = require("@shared/Grid/Grid")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local Commands = {}

local CT = Schema.CmdType

local function encode(cmd: Schema.Command): buffer
	local w = Packer.Writer.new(64)
	Schema.encodeCommand(w, cmd)
	return w:finish()
end

-- A whole command as a payload (the cheat line's, from CheatText.parse; C-120).
Commands.encode = encode

-- The map-cell rectangle covering world points `xs`/`zs` (e.g. the ground
-- hits of the screen corners), clamped to the map (u16 on the wire since
-- protocol 38; a rectangle touching an edge covers what flies past it, S-189).
function Commands.cameraRect(grid: Grid.Grid, xs: { number }, zs: { number }): (number, number, number, number)
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for i = 1, #xs do
		local cx, cz = grid:cellAt(xs[i], zs[i])
		minX, maxX = math.min(minX, cx), math.max(maxX, cx)
		minZ, maxZ = math.min(minZ, cz), math.max(maxZ, cz)
	end
	local limX, limZ = grid.cellsX - 1, grid.cellsZ - 1
	return math.clamp(minX, 0, limX), math.clamp(minZ, 0, limZ), math.clamp(maxX, 0, limX), math.clamp(maxZ, 0, limZ)
end

function Commands.camera(minX: number, minZ: number, maxX: number, maxZ: number): buffer
	return encode({ cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ })
end

-- MOVE / FIGHT / PATROL / ATTACK_GROUND to a world point.
function Commands.toPoint(grid: Grid.Grid, cmdType: number, ids: { number }, x: number, z: number, queue: boolean?): buffer
	local cell, offX, offZ = grid:encode(x, z)
	return encode({
		cmdType = cmdType,
		flags = if queue then Schema.CmdFlag.QUEUE else 0,
		unitIds = ids,
		cell = cell,
		offX = offX,
		offZ = offZ,
	})
end

return Commands
