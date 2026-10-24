--!strict
-- Rebindable keys (C-159, the user's queue item 6): every single-key action
-- with its default, the player's bindings, conflicts (two actions on one
-- key) and keys that can't be bound (digits for groups and the build menu,
-- arrows for the camera, modifiers, Enter / slash for the cheat line, the
-- sim speed keys). Keys are Enum.KeyCode names, so this stays pure Luau
-- (C-7); Render applies them to the modules (Input/Controls, Camera, ...).
-- Saved per player on the server (Settings > Keys, src/roblox: DataStore).

local Keybinds = {}

-- `layer`: a key layer that takes its keys first while it's active (the
-- build menu's tabs while a builder's menu shows, C-203); keys conflict
-- only within one layer.
export type Action = { id: string, label: string, group: string, default: string, layer: string? }

Keybinds.ACTIONS = table.freeze({
	{ id = "attack", label = "Attack, then left click", group = "Orders", default = "A" },
	{ id = "fight", label = "Fight, then left click", group = "Orders", default = "F" },
	{ id = "move", label = "Move, then left click", group = "Orders", default = "M" },
	{ id = "patrol", label = "Patrol, then left click", group = "Orders", default = "Z" },
	{ id = "guard", label = "Guard / assist, then left click", group = "Orders", default = "G" },
	{ id = "reclaim", label = "Reclaim, then left click (builders)", group = "Orders", default = "E" },
	{ id = "resurrect", label = "Resurrect, then left click (T1 workers)", group = "Orders", default = "D" },
	{ id = "stop", label = "Stop", group = "Orders", default = "S" },
	{ id = "fireState", label = "Fire state", group = "Orders", default = "L" },
	{ id = "moveState", label = "Move state", group = "Orders", default = "K" },
	{ id = "repeat", label = "Repeat (factories)", group = "Orders", default = "Y" },
	{ id = "toggle", label = "On / off", group = "Orders", default = "U" },
	{ id = "cancel", label = "Cancel (factories, frames)", group = "Orders", default = "X" },
	{ id = "build", label = "Build menu: open, next tab", group = "Building", default = "B" },
	{ id = "rotate", label = "Rotate the structure", group = "Building", default = "R" },
	-- BAR's category keys (reference 3): over Patrol, Cancel, camera right and
	-- range rings while a builder's build menu shows
	{ id = "tabEconomy", label = "Build menu: Economy (a builder selected)", group = "Building", default = "Z", layer = "build" },
	{ id = "tabCombat", label = "Build menu: Combat (a builder selected)", group = "Building", default = "X", layer = "build" },
	{ id = "tabUtility", label = "Build menu: Utility (a builder selected)", group = "Building", default = "C", layer = "build" },
	{ id = "tabBuild", label = "Build menu: Build (a builder selected)", group = "Building", default = "V", layer = "build" },
	{ id = "rotateLeft", label = "Turn the camera left", group = "Camera and views", default = "Q" },
	-- E is BAR's reclaim (C-109), so the camera turns right on C
	{ id = "rotateRight", label = "Turn the camera right", group = "Camera and views", default = "C" },
	{ id = "ranges", label = "Range rings", group = "Camera and views", default = "V" },
	{ id = "missileView", label = "Missile sensor view", group = "Camera and views", default = "N" },
	{ id = "deposits", label = "Deposit view", group = "Camera and views", default = "F4" },
	{ id = "lastAlert", label = "Jump to the last alert", group = "Camera and views", default = "J" },
	{ id = "idle", label = "Next idle builder", group = "Camera and views", default = "I" },
	{ id = "settings", label = "This menu", group = "Camera and views", default = "O" },
	{ id = "follow", label = "Camera follows the selection (developer mode)", group = "Developer", default = "T" },
} :: { Action })

-- Keys that do something fixed (or are modifiers) and can't be bound.
Keybinds.RESERVED = table.freeze({
	Zero = true, One = true, Two = true, Three = true, Four = true, Five = true, Six = true, Seven = true, Eight = true, Nine = true,
	Up = true, Down = true, Left = true, Right = true,
	LeftShift = true, RightShift = true, LeftControl = true, RightControl = true, LeftAlt = true, RightAlt = true,
	Return = true, KeypadEnter = true, Slash = true, Escape = true, Backspace = true, Tab = true,
	Minus = true, Equals = true, P = true, F3 = true, Unknown = true, Space = true,
} :: { [string]: boolean })

export type Binds = { [string]: string } -- action id → KeyCode name

local byId: { [string]: Action } = {}
for _, a in Keybinds.ACTIONS do
	byId[a.id] = a
end

function Keybinds.defaults(): Binds
	local b: Binds = {}
	for _, a in Keybinds.ACTIONS do
		b[a.id] = a.default
	end
	return b
end

function Keybinds.label(id: string): string
	local a = byId[id]
	return if a then a.label else id
end

-- Binds action `id` to `key`. False (unchanged) for an unknown action or a
-- reserved key. A key another action has is allowed: it shows as a conflict.
function Keybinds.set(b: Binds, id: string, key: string): boolean
	if byId[id] == nil or Keybinds.RESERVED[key] or key == "" then
		return false
	end
	b[id] = key
	return true
end

-- Actions sharing a key with another in their layer: id → the other
-- actions' ids.
function Keybinds.conflicts(b: Binds): { [string]: { string } }
	local byKey: { [string]: { string } } = {}
	for _, a in Keybinds.ACTIONS do
		local key = b[a.id]
		if key then
			local k = (a.layer or "") .. ":" .. key
			byKey[k] = byKey[k] or {}
			table.insert(byKey[k], a.id)
		end
	end
	local out: { [string]: { string } } = {}
	for _, ids in byKey do
		if #ids > 1 then
			for _, id in ids do
				local others = {}
				for _, o in ids do
					if o ~= id then
						table.insert(others, o)
					end
				end
				out[id] = others
			end
		end
	end
	return out
end

-- Saving: only what differs from the defaults, "id=Key;id=Key".
function Keybinds.encode(b: Binds): string
	local parts = {}
	for _, a in Keybinds.ACTIONS do
		local key = b[a.id]
		if key and key ~= a.default then
			table.insert(parts, `{a.id}={key}`)
		end
	end
	return table.concat(parts, ";")
end

-- The defaults with a saved string's bindings on top (bad entries skipped).
function Keybinds.decode(text: string?): Binds
	local b = Keybinds.defaults()
	for id, key in string.gmatch(text or "", "([%w_]+)=([%w_]+)") do
		Keybinds.set(b, id, key)
	end
	return b
end

return Keybinds
