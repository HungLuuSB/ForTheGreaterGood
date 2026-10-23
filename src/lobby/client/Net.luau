--!strict
-- The lobby client's link to its server: the latest view, toasts, the
-- stand-in match state, and requests out. Pages read `Net.view` and listen
-- with `Net.onView`; they never change state themselves (L-3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")
local request = remotes:WaitForChild("Request") :: RemoteEvent
local push = remotes:WaitForChild("Push") :: RemoteEvent
local getMaps = remotes:WaitForChild("GetMaps") :: RemoteFunction

Net.view = nil :: any
Net.standIn = nil :: any -- { matchId, mapId, endsAt } while in the Studio stand-in match
Net.maps = nil :: any -- { { id, name, starts, preview } } once loaded

local viewListeners: { (any) -> () } = {}
local toastListeners: { (string, string) -> () } = {}
local standInListeners: { (any) -> () } = {}

function Net.onView(f: (any) -> ())
	table.insert(viewListeners, f)
	if Net.view then
		task.spawn(f, Net.view)
	end
end

function Net.onToast(f: (string, string) -> ())
	table.insert(toastListeners, f)
end

function Net.onStandIn(f: (any) -> ())
	table.insert(standInListeners, f)
end

function Net.send(msg: any)
	request:FireServer(msg)
end

-- The map list with previews; waits for the server to finish loading them.
function Net.loadMaps(): any
	while Net.maps == nil do
		local ok, result = pcall(function()
			return getMaps:InvokeServer()
		end)
		if ok and type(result) == "table" and result.ready then
			Net.maps = result.maps
		else
			task.wait(1)
		end
	end
	return Net.maps
end

function Net.map(id: string): any?
	for _, m in Net.maps or {} do
		if m.id == id then
			return m
		end
	end
	return nil
end

push.OnClientEvent:Connect(function(msg: any)
	if type(msg) ~= "table" then
		return
	end
	if msg.kind == "view" then
		Net.view = msg.view
		for _, f in viewListeners do
			task.spawn(f, msg.view)
		end
	elseif msg.kind == "toast" then
		for _, f in toastListeners do
			task.spawn(f, tostring(msg.text), tostring(msg.style))
		end
	elseif msg.kind == "standIn" then
		Net.standIn = if msg.active then { matchId = msg.matchId, mapId = msg.mapId, endsAt = os.clock() + (msg.seconds or 0) } else nil
		for _, f in standInListeners do
			task.spawn(f, Net.standIn)
		end
	end
end)

return Net
