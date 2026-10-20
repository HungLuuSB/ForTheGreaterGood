--!strict
-- Sensor state (data only; logic in Sensors.luau). Kept apart so Types can
-- describe it without a require cycle.

local Grid = require("@shared/Grid/Grid")
local Hash = require("@shared/Util/Hash")

local SensorsState = {}

SensorsState.Level = table.freeze({ HIDDEN = 0, RADAR = 1, SONAR = 2, VISIBLE = 3, GHOST = 4 })
SensorsState.KINDS = table.freeze({ "los", "airLos", "radar", "sonar", "jam" })

export type Ghost = { defIndex: number, team: number, x: number, z: number }

export type State = {
	width: number, -- sensor cells
	depth: number,
	originX: number,
	originZ: number,
	maps: { [number]: { [string]: buffer } }, -- team → kind → u16 counts
	teams: { number },
	-- per-unit stamp record (what is currently added to the maps)
	stampCell: { [number]: number }, -- sensor cell index, absent = not stamped
	stampTeam: { [number]: number },
	stampRadius: { [number]: { number } }, -- radii per kind, in KINDS order
	-- visibility of enemies, per observing team
	vis: { [number]: { [number]: number } },
	ghosts: { [number]: { [number]: Ghost } }, -- team → structure ID → last seen
	ghostIds: { [number]: { number } }, -- team → structure IDs (insertion order)
	-- radar wobble seed (task 12) and per-team extras
	extra: { [string]: any },
}

function SensorsState.new(grid: Grid.Grid?, teams: { number }): State
	local g = grid or Grid.new(256, 256)
	local width, depth = g.sensorX, g.sensorZ
	local maps, vis, ghosts, ghostIds = {}, {}, {}, {}
	for _, team in teams do
		local m = {}
		for _, kind in SensorsState.KINDS do
			m[kind] = buffer.create(width * depth * 2)
		end
		maps[team] = m
		vis[team] = {}
		ghosts[team] = {}
		ghostIds[team] = {}
	end
	return {
		width = width,
		depth = depth,
		originX = g.originX,
		originZ = g.originZ,
		maps = maps,
		teams = table.clone(teams),
		stampCell = {},
		stampTeam = {},
		stampRadius = {},
		vis = vis,
		ghosts = ghosts,
		ghostIds = ghostIds,
		extra = {},
	}
end

function SensorsState.hash(s: State, h: number): number
	for _, team in s.teams do
		local vis = s.vis[team]
		local ids = {}
		for id in vis do
			table.insert(ids, id)
		end
		table.sort(ids)
		h = Hash.u32(h, #ids)
		for _, id in ids do
			h = Hash.u32(Hash.u32(h, id), vis[id])
		end
		for _, gid in s.ghostIds[team] do
			h = Hash.u32(h, gid)
		end
	end
	return h
end

return SensorsState
