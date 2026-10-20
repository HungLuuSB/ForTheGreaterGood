--!strict
-- The client API a UI reads and calls (docs/contracts/client-state.md, C-5):
-- `state` (read-only tables), `changed` (signals), `actions` (validated,
-- then sent as Cmd payloads). Input code uses the same actions. Pure Luau
-- (C-7): `send` is injected (the Cmd remote in Roblox, a Sim in tests).

local Orders = require("./Core/Orders")
local Schema = require("@shared/Net/Schema")
local Selection = require("./Core/Selection")
local Signal = require("./Core/Signal")
local Waypoints = require("./Core/Waypoints")
local World = require("./Core/World")

local Api = {}

local CT = Schema.CmdType

export type Res = { stored: number, storage: number, income: number, demand: number, ratio: number }

export type State = {
	player: World.Me,
	tick: number,
	units: { [number]: World.Unit },
	selection: { number },
	groups: { [number]: { number } },
	camera: { x: number, z: number, zoom: number, strategic: boolean, rect: { number } },
	hover: { unit: number?, x: number, z: number }?,
	placement: any?, -- client task 6
	economy: { supply: Res, power: Res, wind: number }?,
	alerts: { any },
}

export type Api = {
	state: State,
	changed: {
		selection: Signal.Signal<{ number }>,
		economy: Signal.Signal<any>,
		focus: Signal.Signal<{ number }>, -- camera jump requests { x, z }
		orders: Signal.Signal<Orders.Intent>, -- every order sent (markers)
	},
	actions: { [string]: any },
	world: World.World,
	selection: Selection.Selection,
	waypoints: Waypoints.Waypoints,
	send: (buffer) -> (),
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
	}

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

	function actions.toggle(on: boolean)
		return issue({ cmdType = CT.TOGGLE, queue = false, value = if on then 1 else 0 })
	end

	function actions.focusCamera(x: number, z: number)
		api.changed.focus:Fire({ x, z })
		return true
	end

	api = {
		state = state,
		changed = {
			selection = Signal.new(),
			economy = Signal.new(),
			focus = Signal.new(),
			orders = Signal.new(),
		},
		actions = actions,
		world = world,
		selection = sel,
		waypoints = Waypoints.new(),
		send = send,
		seenSelection = 0,
		seenEconomy = nil,
	}
	return api
end

-- Once per frame, after packets and before drawing: prunes the selection,
-- follows waypoints, refreshes the state and fires the signals.
function Api.frame(api: Api, now: number)
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
	if sel.version ~= api.seenSelection then
		api.seenSelection = sel.version
		api.changed.selection:Fire(sel.ids)
	end
end

return Api
