--!strict
-- Player alerts and the "under attack" mark (S-68; guide 7.2, 7.3; audit
-- item 17; client request 39). Systems report what happened; this module
-- rate-limits it into per-player ALERT records that NetOut sends on the
-- Events channel (owner only; NUKE_LAUNCH to every player), and remembers
-- when each unit was last hit by an enemy for the strategic UNDER_ATTACK
-- flag (own and allied units hit in the last UNDER_ATTACK_TICKS).
--   UNIT_ATTACKED / STRUCTURE_ATTACKED  one per 400-stud zone per 20 s
--   COMMANDER_ATTACKED                  one per 10 s
--   UNIT_LOST / STRUCTURE_LOST          one per zone per 5 s
--   BUILD_DONE                          every factory unit and finished frame
--   STALL_SUPPLY / STALL_POWER          when the team's ratio drops below 1,
--                                       at most once per 30 s each
--   NUKE_LAUNCH                         every strategic launch, every player
-- Not hashed: nothing in the simulation reads it.

local Schema = require("@shared/Net/Schema")
local Lifecycle = require("./Lifecycle")
local Types = require("./Types")

local Alerts = {}

local AK = Schema.AlertKind
Alerts.ZONE = 400 -- studs
Alerts.ATTACK_TICKS = 300 -- 20 s
Alerts.COMMANDER_TICKS = 150
Alerts.LOST_TICKS = 75
Alerts.STALL_TICKS = 450
Alerts.UNDER_ATTACK_TICKS = 45 -- 3 s

export type Alert = { kind: number, x: number, z: number, defIndex: number }

export type State = {
	queue: { [number]: { Alert } }, -- player → this tick's alerts
	last: { [number]: { [string]: number } }, -- player → rate-limit key → tick
	lastHit: { [number]: number }, -- unit → tick an enemy last damaged it
	stalled: { [string]: boolean }, -- "team:resource" → below 1 at the last step
}

function Alerts.new(playerIds: { number }): State
	local s: State = { queue = {}, last = {}, lastHit = {}, stalled = {} }
	for _, pid in playerIds do
		s.queue[pid] = {}
		s.last[pid] = {}
	end
	return s
end

-- Queues `kind` for `player` unless one with the same key went out within
-- `every` ticks.
local function push(sim: Types.Sim, player: number, kind: number, x: number, z: number, defIndex: number, key: string?, every: number?)
	local s = sim.alerts
	local q = s.queue[player]
	if q == nil then
		return
	end
	if key then
		local last = s.last[player]
		local at = last[key]
		if at ~= nil and sim.tick - at < (every :: number) then
			return
		end
		last[key] = sim.tick
	end
	table.insert(q, { kind = kind, x = x, z = z, defIndex = defIndex })
end

local function zone(x: number, z: number): string
	return `{x // Alerts.ZONE}:{z // Alerts.ZONE}`
end

local COMMANDER: number? = nil
local function isCommander(sim: Types.Sim, def: any): boolean
	if COMMANDER == nil then
		COMMANDER = require("@shared/Defs/Categories").Bit.COMMANDER
	end
	return bit32.band(def.categoryMask, COMMANDER :: number) ~= 0
end

-- An enemy damaged unit `id` (Damage).
function Alerts.attacked(sim: Types.Sim, id: number)
	local w = sim.world
	sim.alerts.lastHit[id] = sim.tick
	local def = sim.defs.unitByIndex[w.defIndex[id]]
	local x, z = w.posX[id], w.posZ[id]
	if isCommander(sim, def) then
		push(sim, w.owner[id], AK.COMMANDER_ATTACKED, x, z, def.index, "commander", Alerts.COMMANDER_TICKS)
	elseif def.domain == "structure" then
		push(sim, w.owner[id], AK.STRUCTURE_ATTACKED, x, z, def.index, "s" .. zone(x, z), Alerts.ATTACK_TICKS)
	else
		push(sim, w.owner[id], AK.UNIT_ATTACKED, x, z, def.index, "u" .. zone(x, z), Alerts.ATTACK_TICKS)
	end
end

-- Unit `id` died (Damage, before it is removed).
function Alerts.lost(sim: Types.Sim, id: number)
	local w = sim.world
	local def = sim.defs.unitByIndex[w.defIndex[id]]
	local x, z = w.posX[id], w.posZ[id]
	local structure = def.domain == "structure"
	local kind = if structure then AK.STRUCTURE_LOST else AK.UNIT_LOST
	push(sim, w.owner[id], kind, x, z, def.index, (if structure then "S" else "U") .. zone(x, z), Alerts.LOST_TICKS)
end

-- Unit `id` was finished: a factory's unit or a completed frame (Build).
function Alerts.built(sim: Types.Sim, id: number)
	local w = sim.world
	push(sim, w.owner[id], AK.BUILD_DONE, w.posX[id], w.posZ[id], w.defIndex[id])
end

-- After an economy step: a team whose supply or power ratio dropped below 1.
function Alerts.economy(sim: Types.Sim)
	local s = sim.alerts
	for _, pid in sim.playerOrder do
		local team = sim.players[pid].team
		local acc = sim.eco.accounts[team]
		if acc == nil then
			continue
		end
		for _, r in { { "supply", AK.STALL_SUPPLY }, { "power", AK.STALL_POWER } } do
			local name, kind = r[1] :: string, r[2] :: number
			local key = `{team}:{name}`
			local now = (acc :: any)[name].ratio < 1
			local was = s.stalled[`{pid}:{key}`] == true
			s.stalled[`{pid}:{key}`] = now
			if now and not was then
				push(sim, pid, kind, 0, 0, 0, "stall" .. name, Alerts.STALL_TICKS)
			end
		end
	end
end

-- A strategic missile left its silo (Weapons' LAUNCH event): every player.
function Alerts.launch(sim: Types.Sim, x: number, z: number, defIndex: number)
	for _, pid in sim.playerOrder do
		push(sim, pid, AK.NUKE_LAUNCH, x, z, defIndex)
	end
end

-- Was unit `id` hit by an enemy in the last UNDER_ATTACK_TICKS?
function Alerts.underAttack(sim: Types.Sim, id: number): boolean
	local at = sim.alerts.lastHit[id]
	return at ~= nil and sim.tick - at <= Alerts.UNDER_ATTACK_TICKS
end

-- This tick's alerts for `player`, emptied (NetOut).
function Alerts.drain(sim: Types.Sim, player: number): { Alert }?
	local q = sim.alerts.queue[player]
	if q == nil or #q == 0 then
		return nil
	end
	sim.alerts.queue[player] = {}
	return q
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	sim.alerts.lastHit[id] = nil
end)

return Alerts
