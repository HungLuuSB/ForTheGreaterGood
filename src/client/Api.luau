--!strict
-- The client API a UI reads and calls (docs/contracts/client-state.md, C-5):
-- `state` (read-only tables), `changed` (signals), `actions` (validated,
-- then sent as Cmd payloads). Input code uses the same actions. Pure Luau
-- (C-7): `send` is injected (the Cmd remote in Roblox, a Sim in tests).

local Alerts = require("./Core/Alerts")
local Orders = require("./Core/Orders")
local Commands = require("./Core/Commands")
local Placement = require("./Core/Placement")
local Schema = require("@shared/Net/Schema")
local Selection = require("./Core/Selection")
local Signal = require("./Core/Signal")
local Waypoints = require("./Core/Waypoints")
local Upgrades = require("./Core/Upgrades")
local World = require("./Core/World")
local CommandSet = require("./Core/CommandSet")

local Api = {}

local CT = Schema.CmdType

-- The build ghost (guide 15.6): what, where (snapped), facing, and whether
-- the client's check passes (the server re-checks).
export type PlacementState = {
	defId: string,
	defIndex: number,
	x: number,
	z: number,
	facing: number, -- 0..3 = 0/90/180/270 degrees
	valid: boolean,
	reason: string?,
	replaces: number?, -- an upgrade in place: the own extractor the ghost sits on (C-121)
}

export type Res = { stored: number, storage: number, income: number, demand: number, ratio: number }

export type State = {
	player: World.Me,
	tick: number,
	units: { [number]: World.Unit },
	selection: { number },
	groups: { [number]: { number } },
	camera: { x: number, z: number, zoom: number, strategic: boolean, rect: { number }, corners: { number }? },
	hover: { unit: number?, x: number, z: number }?,
	hoverWreck: number?, -- the wreck under the mouse when no unit is (the unit panel shows it, G2)
	depositHint: { defId: string, defIndex: number, x: number, z: number }?, -- an extractor the selected builders could put on the free deposit under the mouse (C-244): drawn as a ghost, right-click orders it
	placement: PlacementState?,
	economy: { supply: Res, power: Res, wind: number, supplyShare: number, powerShare: number, convertAt: number }?, -- the levels: percent of storage (S-198)
	alerts: { Alerts.Alert }, -- recent alerts, newest last (C-68)
	-- the command a left click gives (C-68): "attack", "fight", "move",
	-- "patrol" or "guard"; nil = normal selection clicks
	commandMode: string?,
	-- the selection's fire / move state as the server has them (protocol 20,
	-- S-61): the first selected unit that has one; nil when none does
	fireState: number?,
	moveState: number?,
	retreat: number?, -- the first selected aircraft's Schema.RetreatAt (protocol 39)
	front: boolean, -- Space held: orders go to the head of the queue (FRONT, protocol 40; set by Input/Controls)
	selfDestructing: boolean, -- a selected unit counts down to self-destruct
	factoryQueues: { [number]: { number } }, -- own factory → its queue on the server (def indices, the head in production; S-61)
}

export type Api = {
	state: State,
	changed: {
		selection: Signal.Signal<{ number }>,
		economy: Signal.Signal<any>,
		focus: Signal.Signal<{ number }>, -- camera jump requests { x, z }
		placement: Signal.Signal<PlacementState?>,
		orders: Signal.Signal<Orders.Intent>, -- every order sent (markers)
		alert: Signal.Signal<Alerts.Alert>, -- a new alert (C-68)
		commandMode: Signal.Signal<string?>,
	},
	actions: { [string]: any },
	world: World.World,
	selection: Selection.Selection,
	waypoints: Waypoints.Waypoints,
	send: (buffer) -> (),
	alertState: Alerts.State,
	seenSelection: number,
	seenJoins: number, -- world.joins last frame: a new WELCOME starts a fresh view (C-78)
	seenEconomy: any,
}

local function res(r: Schema.EcoResource): Res
	return { stored = r.stored, storage = r.storage, income = r.income / 10, demand = r.demand / 10, ratio = r.ratio / 255 }
end

function Api.new(world: World.World, send: (buffer) -> ()): Api
	local sel = Selection.new()
	local api: Api
	local state: State = {
		player = world.me,
		tick = world.latestTick,
		units = world.units,
		selection = sel.ids,
		groups = sel.groups,
		camera = { x = 0, z = 0, zoom = 0, strategic = false, rect = { 0, 0, 0, 0 } },
		hover = nil,
		placement = nil,
		economy = nil,
		alerts = {},
		commandMode = nil,
		fireState = nil,
		retreat = nil,
		selfDestructing = false,
		front = false,
		moveState = nil,
		factoryQueues = {},
	}
	local alertState = Alerts.new()
	state.alerts = alertState.list

	local function issue(intent: Orders.Intent, ids: { number }?): (boolean, string?)
		if state.front and Orders.FRONTABLE[intent.cmdType] then
			intent.front = true -- Space held (FRONT, S-199)
		end
		local targets = ids or sel.ids
		if #targets == 0 then
			return false, "nothing selected"
		end
		-- only the units that have this command (C-193): no move line from a turret
		targets = Orders.able(world, intent.cmdType, targets)
		if #targets == 0 then
			return false, "no selected unit can do that"
		end
		for _, payload in Orders.encode(world, intent, targets) do
			send(payload)
		end
		Waypoints.issue(api.waypoints, world, intent, targets)
		api.changed.orders:Fire(intent)
		return true
	end

	local actions = {}

	function actions.select(ids: { number }, mode: ("replace" | "add" | "toggle")?)
		Selection.set(sel, world, ids, mode)
		return true
	end

	-- Every own unit of def `defId` (the input layer narrows it to the screen).
	function actions.selectType(defId: string)
		local ids = {}
		for id, u in world.units do
			local def = World.def(world, u)
			if u.team == world.me.team and def and def.id == defId then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		Selection.set(sel, world, ids, "replace")
		return true
	end

	function actions.setGroup(n: number)
		if n < 1 or n > Selection.GROUPS then
			return false, "groups are 1..9"
		end
		Selection.saveGroup(sel, n)
		return true
	end

	function actions.recallGroup(n: number, add: boolean?)
		if n < 1 or n > Selection.GROUPS then
			return false, "groups are 1..9"
		end
		Selection.recallGroup(sel, world, n, add)
		return true
	end

	function actions.order(kind: string, target: any, queue: boolean?, group: boolean?)
		local cmdType = Orders.KIND[kind]
		if cmdType == nil then
			return false, `unknown order {kind}`
		end
		if type(target) == "number" then
			if world.units[target] == nil then
				return false, "unknown target"
			end
			return issue({ cmdType = cmdType, queue = queue == true, targetId = target })
		end
		return issue({ cmdType = cmdType, queue = queue == true, x = target.x, z = target.z, group = group == true })
	end

	-- `group` (Ctrl): a move keeps the selection together (GROUP, S-137, C-169).
	function actions.smartOrder(x: number, z: number, unitId: number?, queue: boolean?, group: boolean?)
		if #sel.ids == 0 then
			return false, "nothing selected"
		end
		for _, part in Orders.smartFor(world, x, z, unitId, queue, sel.ids, group) do
			issue(part.intent, part.ids)
		end
		return true
	end

	function actions.lineMove(x1: number, z1: number, x2: number, z2: number, queue: boolean?, group: boolean?)
		return issue({ cmdType = CT.MOVE, queue = queue == true, x = x1, z = z1, x2 = x2, z2 = z2, group = group == true })
	end

	function actions.stop()
		return issue({ cmdType = CT.STOP, queue = false })
	end

	function actions.setFireState(n: number)
		return issue({ cmdType = CT.SET_FIRE_STATE, queue = false, value = n })
	end

	function actions.setMoveState(n: number)
		return issue({ cmdType = CT.SET_MOVE_STATE, queue = false, value = n })
	end

	-- A resource bar's slider (ECO_LEVEL, S-198): the supply or power share
	-- level (stored above it goes to the allies, fairly) or the converters'
	-- level (power stored above it may be converted), `percent` 0..100.
	function actions.setEcoLevel(level: number, percent: number)
		api.send(Commands.encode({ cmdType = CT.ECO_LEVEL, flags = 0, unitIds = {}, ecoLevel = level, value = math.clamp(math.floor(percent + 0.5), 0, 100) }))
		return true
	end

	-- Aircraft: the health below which they fly to a rearm pad to heal
	-- (Schema.RetreatAt; SET_RETREAT, S-194, G17).
	function actions.setRetreat(n: number)
		return issue({ cmdType = CT.SET_RETREAT, queue = false, value = n })
	end

	-- Self-destruct (S-194, G13): starts the selection's countdown, or stops
	-- it when any selected unit is already counting down (`on` forces one).
	function actions.selfDestruct(on: boolean?)
		local start = if on == nil then not state.selfDestructing else on
		return issue({ cmdType = CT.SELF_DESTRUCT, queue = false, value = if start then 1 else 0 })
	end

	-- Factories: repeat the queue on / off (REPEAT, S-13).
	function actions.setRepeat(on: boolean)
		return issue({ cmdType = CT.REPEAT, queue = false, value = if on then 1 else 0 })
	end

	-- Resource priority (S-156, C-196): high (the default) or low.
	function actions.setPriority(high: boolean)
		return issue({ cmdType = CT.PRIORITY, queue = false, value = if high then 1 else 0 })
	end

	-- CANCEL (S-35): an unfinished frame is cancelled; a factory drops queue
	-- item `index` (1-based; 0 = all).
	function actions.cancel(index: number?)
		local i = index or 0
		return issue({ cmdType = CT.CANCEL, queue = false, value = i })
	end

	-- Queues `count` of `defId` in the selected factories that can build it
	-- (one BUILD per unit, the factory's position as the spot).
	function actions.queueBuild(defId: string, count: number?)
		local def = world.defs.units[defId]
		if def == nil then
			return false, "unknown def"
		end
		local n = math.clamp(count or 1, 1, 50)
		local sent = 0
		for _, id in sel.ids do
			local u = world.units[id]
			local udef = u and World.def(world, u)
			if u and udef and udef.domain == "structure" and table.find(udef.buildOptions or {}, defId) then
				for _ = 1, n do
					issue({ cmdType = CT.BUILD, queue = true, defIndex = def.index, x = u.x, z = u.z, facing = 0 }, { id })
				end
				sent += 1
			end
		end
		return sent > 0, if sent == 0 then "no selected factory builds it" else nil
	end

	-- The command a left click gives (attack / fight / move / patrol / guard), or nil.
	function actions.setCommandMode(kind: string?)
		if kind ~= nil and #sel.ids == 0 then
			return false, "nothing selected"
		end
		state.commandMode = kind
		api.changed.commandMode:Fire(kind)
		return true
	end

	-- Gives the current command at (x, z) or on unit `unitId` (input and UI
	-- both use this): attack an enemy or the ground, guard a unit, or fight /
	-- move / patrol to the point. Keeps the mode with `keep` (Shift).
	function actions.commandAt(x: number, z: number, unitId: number?, queue: boolean?, keep: boolean?, group: boolean?)
		local kind = state.commandMode
		if kind == nil then
			return false, "no command"
		end
		local u = if unitId then world.units[unitId] else nil
		local ok, why
		if kind == "attack" then
			if u and u.team ~= world.me.team then
				ok, why = actions.order("attack", unitId, queue)
			else
				ok, why = actions.order("attackGround", { x = x, z = z }, queue)
			end
		elseif kind == "guard" then
			if u == nil then
				return false, "guard needs a unit"
			end
			ok, why = actions.order("guard", unitId, queue)
		elseif kind == "repair" then
			if u == nil or u.team ~= world.me.team then
				return false, "repair needs an own unit"
			end
			ok, why = actions.order("repair", unitId, queue)
		elseif kind == "dgun" then
			-- the D-Gun at the point (S-194, G5): Commanders walk into range first
			ok, why = issue({ cmdType = CT.DGUN, queue = queue == true, x = x, z = z })
		elseif kind == "reclaim" or kind == "resurrect" then
			-- the known wreck nearest the click (wrecks aren't pickable models), C-109;
			-- RESURRECT the same way (S-168, C-216: workers with canResurrect)
			local best, bestD2 = nil, 24 * 24
			for wid, w in world.wrecks do
				if kind == "resurrect" and w.feature then
					continue -- trees and rocks don't come back (S-197)
				end
				local d2 = (w.x - x) ^ 2 + (w.z - z) ^ 2
				if d2 < bestD2 then
					best, bestD2 = wid, d2
				end
			end
			if best == nil then
				return false, "no wreck there"
			end
			ok, why = issue({ cmdType = if kind == "resurrect" then CT.RESURRECT else CT.RECLAIM, queue = queue == true, targetId = best })
		else
			ok, why = actions.order(kind, { x = x, z = z }, queue, group)
		end
		if not keep then
			actions.setCommandMode(nil)
		end
		return ok, why
	end

	-- Smart Reclaim / repair / resurrect (F42, S-183): every selected unit
	-- that has `kind` ("reclaim", "repair", "resurrect") takes the targets
	-- inside the circle one after another.
	local AREA_OP = { reclaim = Schema.AreaOp.RECLAIM, repair = Schema.AreaOp.REPAIR, resurrect = Schema.AreaOp.RESURRECT }
	function actions.areaOrder(kind: string, x: number, z: number, radius: number, queue: boolean?)
		local op = AREA_OP[kind]
		if op == nil then
			return false, "no area order " .. kind
		end
		local ids = {}
		for _, id in sel.ids do
			local u = world.units[id]
			local def = u and World.def(world, u)
			if def and u.team == world.me.team and CommandSet.forDef(def, world.defs)[kind] then
				table.insert(ids, id)
			end
		end
		if #ids == 0 then
			return false, "no selected unit can do that"
		end
		return issue({ cmdType = CT.AREA, queue = queue == true, x = x, z = z, areaOp = op, radius = radius }, ids)
	end

	function actions.toggle(on: boolean)
		return issue({ cmdType = CT.TOGGLE, queue = false, value = if on then 1 else 0 })
	end

	function actions.focusCamera(x: number, z: number)
		api.changed.focus:Fire({ x, z })
		return true
	end

	-- Selected own units that can build `defId` (its id is in their buildOptions).
	local function buildersOf(defId: string): { number }
		local out = {}
		for _, id in sel.ids do
			local u = world.units[id]
			local def = u and World.def(world, u)
			if def and def.buildOptions and table.find(def.buildOptions, defId) then
				table.insert(out, id)
			end
		end
		return out
	end

	local function defOf(defId: string): any
		for _, def in world.defs.unitByIndex do
			if def.id == defId then
				return def
			end
		end
		return nil
	end

	local lastFacing = 0 -- the last placement rotation (F14)
	function actions.beginPlacement(defId: string)
		local def = defOf(defId)
		if def == nil or def.domain ~= "structure" then
			return false, "not a structure"
		end
		if #buildersOf(defId) == 0 then
			return false, "no selected builder can build it"
		end
		-- the last rotation carries on to every later placement (F14, the user)
		local facing = if state.placement then state.placement.facing else lastFacing
		state.placement = { defId = defId, defIndex = def.index, x = state.camera.x, z = state.camera.z, facing = facing, valid = false, reason = nil }
		api.changed.placement:Fire(state.placement)
		return true
	end

	function actions.rotatePlacement()
		local p = state.placement
		if p == nil then
			return false, "not placing"
		end
		p.facing = (p.facing + 1) % 4
		lastFacing = p.facing
		return true
	end

	function actions.cancelPlacement()
		if state.placement == nil then
			return false, "not placing"
		end
		state.placement = nil
		api.changed.placement:Fire(nil)
		return true
	end

	-- Moves the ghost to (x, z): snaps and checks it.
	function actions.updatePlacement(x: number, z: number)
		local p = state.placement
		if p == nil then
			return false, "not placing"
		end
		local def = world.defs.unitByIndex[p.defIndex]
		x, z = Placement.assist(world, def, x, z) -- extractors jump onto a nearby deposit
		local r = Placement.check(world, def, x, z, Placement.planned(world, api.waypoints.byUnit))
		p.x, p.z, p.valid, p.reason = r.x, r.z, r.ok, r.reason
		p.replaces = if r.ok and r.replaces ~= 0 then r.replaces else nil
		return r.ok, r.reason
	end

	-- Places the ghost at (x, z): a BUILD to the selected builders. Placing
	-- ends unless `keep` (Shift places several); `queue` appends the build.
	function actions.place(x: number, z: number, queue: boolean?, keep: boolean?)
		local p = state.placement
		if p == nil then
			return false, "not placing"
		end
		local ok, why = actions.updatePlacement(x, z)
		if not ok then
			return false, why
		end
		local sent, reason = issue({ cmdType = CT.BUILD, queue = queue == true, x = p.x, z = p.z, defIndex = p.defIndex, facing = p.facing }, buildersOf(p.defId))
		if sent and not keep then
			actions.cancelPlacement()
		end
		return sent, reason
	end

	-- A row of the ghost's structure dragged from (x1, z1) to (x2, z2): one
	-- BUILD per valid spot, queued after the first (guide 15.6).
	function actions.placeRow(x1: number, z1: number, x2: number, z2: number, queue: boolean?, keep: boolean?)
		local p = state.placement
		if p == nil then
			return false, "not placing"
		end
		local def = world.defs.unitByIndex[p.defIndex]
		local builders = buildersOf(p.defId)
		local placed = 0
		for _, spot in Placement.row(world, def, x1, z1, x2, z2) do
			-- queued builds, this row's earlier spots included (C-165)
			local r = Placement.check(world, def, spot[1], spot[2], Placement.planned(world, api.waypoints.byUnit))
			if r.ok then
				local sent = issue({ cmdType = CT.BUILD, queue = queue == true or placed > 0, x = r.x, z = r.z, defIndex = p.defIndex, facing = p.facing }, builders)
				if sent then
					placed += 1
				end
			end
		end
		if placed > 0 and not keep then
			actions.cancelPlacement()
		end
		return placed > 0, if placed == 0 then "no valid spot" else nil
	end

	-- The selected builders' center (where an area's visiting order starts).
	local function buildersCenter(builders: { number }, x: number, z: number): (number, number)
		local sx, sz, n = 0, 0, 0
		for _, id in builders do
			local u = world.units[id]
			if u then
				sx, sz, n = sx + u.x, sz + u.z, n + 1
			end
		end
		if n == 0 then
			return x, z
		end
		return sx / n, sz / n
	end

	-- An extractor drag: one BUILD on every free deposit and every own
	-- extractor it upgrades within `radius` of (cx, cz), nearest the builders
	-- first, queued after the first (BAR's area extractor; C-121). Other
	-- structures place a row instead (placeRow).
	function actions.placeArea(cx: number, cz: number, radius: number, queue: boolean?, keep: boolean?)
		local p = state.placement
		if p == nil then
			return false, "not placing"
		end
		local def = world.defs.unitByIndex[p.defIndex]
		local builders = buildersOf(p.defId)
		local fx, fz = buildersCenter(builders, cx, cz)
		local placed = 0
		for _, r in Placement.area(world, def, cx, cz, radius, fx, fz, Placement.planned(world, api.waypoints.byUnit)) do
			if issue({ cmdType = CT.BUILD, queue = queue == true or placed > 0, x = r.x, z = r.z, defIndex = p.defIndex, facing = p.facing }, builders) then
				placed += 1
			end
		end
		if placed > 0 and not keep then
			actions.cancelPlacement()
		end
		return placed > 0, if placed == 0 then "no extractor spot there" else nil
	end

	-- The extractor the selected builders would put on a free deposit (the
	-- user's QoL, C-244): T2 when a selected builder can build the advanced
	-- one, else T1 (Commanders, T1 builders). Nil with no builder selected.
	function actions.hintExtractor(): any?
		local best = nil
		for _, id in sel.ids do
			local u = world.units[id]
			local def = u and World.def(world, u)
			for _, opt in (def and def.buildOptions) or {} do
				local d = defOf(opt)
				if d and d.extractor and (best == nil or (Upgrades.isUpgrade(world.defs, d) and not Upgrades.isUpgrade(world.defs, best))) then
					best = d
				end
			end
		end
		return best
	end

	-- The free deposit near (x, z) the selected builders could take: the
	-- extractor and its spot, or nil (no builder, no free deposit there, an
	-- own extractor already on it).
	function actions.depositHintAt(x: number, z: number): { defId: string, defIndex: number, x: number, z: number }?
		local def = actions.hintExtractor()
		if def == nil then
			return nil
		end
		-- (a deposit patch is 16 studs across: the mouse anywhere on it finds it)
		local spots = Placement.area(world, def, x, z, 24, x, z, Placement.planned(world, api.waypoints.byUnit))
		local r = spots[1]
		if r == nil or (r.replaces or 0) ~= 0 then
			return nil -- (an upgrade in place stays the Upgrade command's, C-121)
		end
		return { defId = def.id, defIndex = def.index, x = r.x, z = r.z }
	end

	-- Orders the hinted extractor (right-click on a free deposit, C-244);
	-- `queue` (Shift) appends it.
	function actions.buildHint(queue: boolean?): (boolean, string?)
		local h = state.depositHint
		if h == nil then
			return false, "no deposit there"
		end
		return issue({ cmdType = CT.BUILD, queue = queue == true, x = h.x, z = h.z, defIndex = h.defIndex, facing = 0 }, buildersOf(h.defId))
	end

	-- The "Upgrade extractors" area command (C-121): the selected builders'
	-- best upgrading extractor (Upgrades.upgraderFor) onto every own
	-- extractor it upgrades within `radius` of (cx, cz), nearest first.
	function actions.upgradeArea(cx: number, cz: number, radius: number, queue: boolean?)
		local defs = {}
		for _, id in sel.ids do
			local u = world.units[id]
			local def = u and World.def(world, u)
			if def then
				table.insert(defs, def)
			end
		end
		local def = Upgrades.upgraderFor(world.defs, defs)
		if def == nil then
			return false, "no selected builder can upgrade extractors"
		end
		local builders = buildersOf(def.id)
		local fx, fz = buildersCenter(builders, cx, cz)
		local placed = 0
		for _, id in Upgrades.inCircle(world, def, cx, cz, radius, fx, fz) do
			local sx, sz = Upgrades.site(world, def, id)
			local r = Placement.check(world, def, sx, sz, Placement.planned(world, api.waypoints.byUnit))
			if r.ok and issue({ cmdType = CT.BUILD, queue = queue == true or placed > 0, x = r.x, z = r.z, defIndex = def.index, facing = 0 }, builders) then
				placed += 1
			end
		end
		return placed > 0, if placed == 0 then "no extractor to upgrade there" else nil
	end

	api = {
		state = state,
		changed = {
			selection = Signal.new(),
			economy = Signal.new(),
			focus = Signal.new(),
			orders = Signal.new(),
			placement = Signal.new(),
			alert = Signal.new(),
			commandMode = Signal.new(),
		},
		actions = actions,
		world = world,
		selection = sel,
		waypoints = Waypoints.new(),
		send = send,
		alertState = alertState,
		seenSelection = 0,
		seenJoins = world.joins,
		seenEconomy = nil,
	}
	return api
end

-- Once per frame, after packets and before drawing (and before the frame
-- clears world.died): prunes the selection, follows waypoints and factory
-- queues, raises the server's alerts (C-85), refreshes the state and
-- fires the signals.
function Api.frame(api: Api, now: number)
	local world, sel, state = api.world, api.selection, api.state
	if world.joins ~= api.seenJoins then
		-- a new WELCOME (a rejoin or a new match): unit IDs start over, so the
		-- old selection, groups, waypoints and command mode would point at
		-- other units
		api.seenJoins = world.joins
		Selection.set(sel, world, {}, "replace")
		for _, g in sel.groups do
			table.clear(g)
		end
		Waypoints.reset(api.waypoints)
		state.commandMode = nil
		state.placement = nil
	end
	Selection.prune(sel, world)
	Waypoints.update(api.waypoints, world, now)
	state.player = world.me
	state.tick = world.latestTick
	state.units = world.units
	if world.economy ~= api.seenEconomy then
		api.seenEconomy = world.economy
		local e = world.economy
		state.economy = if e then { supply = res(e.supply), power = res(e.power), wind = e.wind / 255, supplyShare = e.supplyShare or 100, powerShare = e.powerShare or 100, convertAt = e.convertAt or 50 } else nil
		api.changed.economy:Fire(state.economy)
	end
	-- own factories' queues and the selection's states, from the server (S-61)
	table.clear(state.factoryQueues)
	for id, u in world.units do
		if u.queue and u.team == world.me.team then
			state.factoryQueues[id] = u.queue
		end
	end
	state.fireState, state.moveState, state.retreat, state.selfDestructing = nil, nil, nil, false
	for _, id in sel.ids do
		local u = world.units[id]
		if u and u.fireState and state.fireState == nil then
			state.fireState, state.moveState = u.fireState, u.moveState
		end
		local def = u and World.def(world, u)
		if def and def.domain == "air" and state.retreat == nil and u.team == world.me.team then
			state.retreat = u.retreat or Schema.RetreatAt.AT_30 -- the server's default
		end
		if u and (u.selfDestruct or 0) > 0 then
			state.selfDestructing = true
		end
	end
	if world.joined then
		for _, alert in Alerts.step(api.alertState, world, now) do
			api.changed.alert:Fire(alert)
		end
	end
	if state.commandMode and #sel.ids == 0 then
		state.commandMode = nil
		api.changed.commandMode:Fire(nil)
	end
	if sel.version ~= api.seenSelection then
		api.seenSelection = sel.version
		api.changed.selection:Fire(sel.ids)
	end
end

return Api
