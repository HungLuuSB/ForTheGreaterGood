--!strict
-- The client API a UI reads and calls (docs/contracts/client-state.md, C-5):
-- `state` (read-only tables), `changed` (signals), `actions` (validated,
-- then sent as Cmd payloads). Input code uses the same actions. Pure Luau
-- (C-7): `send` is injected (the Cmd remote in Roblox, a Sim in tests).

local Alerts = require("./Core/Alerts")
local Orders = require("./Core/Orders")
local Placement = require("./Core/Placement")
local Schema = require("@shared/Net/Schema")
local Selection = require("./Core/Selection")
local Signal = require("./Core/Signal")
local Waypoints = require("./Core/Waypoints")
local World = require("./Core/World")

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
}

export type Res = { stored: number, storage: number, income: number, demand: number, ratio: number }

export type State = {
	player: World.Me,
	tick: number,
	units: { [number]: World.Unit },
	selection: { number },
	groups: { [number]: { number } },
	camera: { x: number, z: number, zoom: number, strategic: boolean, rect: { number } },
	hover: { unit: number?, x: number, z: number }?,
	placement: PlacementState?,
	economy: { supply: Res, power: Res, wind: number }?,
	alerts: { Alerts.Alert }, -- recent alerts, newest last (C-68)
	-- the command a left click gives (C-68): "attack", "fight", "move",
	-- "patrol" or "guard"; nil = normal selection clicks
	commandMode: string?,
	-- the selection's fire / move state as the server has them (protocol 20,
	-- S-61): the first selected unit that has one; nil when none does
	fireState: number?,
	moveState: number?,
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
		moveState = nil,
		factoryQueues = {},
	}
	local alertState = Alerts.new()
	state.alerts = alertState.list

	local function issue(intent: Orders.Intent, ids: { number }?): (boolean, string?)
		local targets = ids or sel.ids
		if #targets == 0 then
			return false, "nothing selected"
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

	function actions.order(kind: string, target: any, queue: boolean?)
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
		return issue({ cmdType = cmdType, queue = queue == true, x = target.x, z = target.z })
	end

	function actions.smartOrder(x: number, z: number, unitId: number?, queue: boolean?)
		return issue(Orders.smart(world, x, z, unitId, queue))
	end

	function actions.lineMove(x1: number, z1: number, x2: number, z2: number, queue: boolean?)
		return issue({ cmdType = CT.MOVE, queue = queue == true, x = x1, z = z1, x2 = x2, z2 = z2 })
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

	-- Factories: repeat the queue on / off (REPEAT, S-13).
	function actions.setRepeat(on: boolean)
		return issue({ cmdType = CT.REPEAT, queue = false, value = if on then 1 else 0 })
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
	function actions.commandAt(x: number, z: number, unitId: number?, queue: boolean?, keep: boolean?)
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
		else
			ok, why = actions.order(kind, { x = x, z = z }, queue)
		end
		if not keep then
			actions.setCommandMode(nil)
		end
		return ok, why
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

	function actions.beginPlacement(defId: string)
		local def = defOf(defId)
		if def == nil or def.domain ~= "structure" then
			return false, "not a structure"
		end
		if #buildersOf(defId) == 0 then
			return false, "no selected builder can build it"
		end
		local facing = if state.placement then state.placement.facing else 0
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
		local r = Placement.check(world, def, x, z)
		p.x, p.z, p.valid, p.reason = r.x, r.z, r.ok, r.reason
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
			local r = Placement.check(world, def, spot[1], spot[2])
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
		seenEconomy = nil,
	}
	return api
end

-- Once per frame, after packets and before drawing (and before the frame
-- clears world.died): prunes the selection, follows waypoints and factory
-- queues, raises alerts (`warnings`: Core/Effects' launch warnings),
-- refreshes the state and fires the signals.
function Api.frame(api: Api, now: number, warnings: { any }?)
	local world, sel, state = api.world, api.selection, api.state
	Selection.prune(sel, world)
	Waypoints.update(api.waypoints, world, now)
	state.player = world.me
	state.tick = world.latestTick
	state.units = world.units
	if world.economy ~= api.seenEconomy then
		api.seenEconomy = world.economy
		local e = world.economy
		state.economy = if e then { supply = res(e.supply), power = res(e.power), wind = e.wind / 255 } else nil
		api.changed.economy:Fire(state.economy)
	end
	-- own factories' queues and the selection's states, from the server (S-61)
	table.clear(state.factoryQueues)
	for id, u in world.units do
		if u.queue and u.team == world.me.team then
			state.factoryQueues[id] = u.queue
		end
	end
	state.fireState, state.moveState = nil, nil
	for _, id in sel.ids do
		local u = world.units[id]
		if u and u.fireState then
			state.fireState, state.moveState = u.fireState, u.moveState
			break
		end
	end
	if world.joined then
		for _, alert in Alerts.step(api.alertState, world, now, warnings, state.economy) do
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
