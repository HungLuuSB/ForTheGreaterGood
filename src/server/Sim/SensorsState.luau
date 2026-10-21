--!strict
-- Sensor state (data only; logic in Sensors.luau). Kept apart so Types can
-- describe it without a require cycle.

local Grid = require("@shared/Grid/Grid")
local Hash = require("@shared/Util/Hash")

local SensorsState = {}

SensorsState.Level = table.freeze({ HIDDEN = 0, RADAR = 1, SONAR = 2, VISIBLE = 3, GHOST = 4 })
SensorsState.KINDS = table.freeze({ "los", "airLos", "radar", "sonar", "jam", "track" })

export type Ghost = { defIndex: number, team: number, x: number, z: number, gen: number } -- gen: the remembered unit's (D109)

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
	-- per team: radar emitters (unit IDs, ids order) and the best radar error
	radars: { [number]: { number } },
	radarError: { [number]: number },
	-- per team: naval units and ASW helicopters, which detect submerged
	-- submarines within CLOSE_SONAR studs (ids order)
	closeSonar: { [number]: { number } },
	-- fire-control radar (D104): per team, enemy units that are radar
	-- detectable inside its track map, and the best track error; per
	-- powered sensor (tracking radars, jammers: D104, D108), the share of its
	-- power upkeep it gets (0..1), which scales its track and jam radii
	tracked: { [number]: { [number]: boolean } },
	trackError: { [number]: number },
	pinpoints: { [number]: number }, -- per team: finished Pinpointers (S-59); recomputed every sensor step
	powerScale: { [number]: number },
}

function SensorsState.new(grid: Grid.Grid?, teams: { number }): State
	local g = grid or Grid.new(256, 256)
	local width, depth = g.sensorX, g.sensorZ
	local maps, vis, ghosts, ghostIds, tracked = {}, {}, {}, {}, {}
	for _, team in teams do
		tracked[team] = {}
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
		radars = (function()
			local r = {}
			for _, team in teams do
				r[team] = {}
			end
			return r
		end)(),
		radarError = {},
		tracked = tracked,
		trackError = {},
		pinpoints = {},
		powerScale = {},
		closeSonar = (function()
			local r = {}
			for _, team in teams do
				r[team] = {}
			end
			return r
		end)(),
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
		local tids = {}
		for id in s.tracked[team] do
			table.insert(tids, id)
		end
		table.sort(tids)
		h = Hash.u32(h, #tids)
		for _, id in tids do
			h = Hash.u32(h, id)
		end
	end
	local sids = {}
	for id in s.powerScale do
		table.insert(sids, id)
	end
	table.sort(sids)
	for _, id in sids do
		h = Hash.number(Hash.u32(h, id), s.powerScale[id])
	end
	return h
end

return SensorsState
