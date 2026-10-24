--!strict
-- The shared list of lobby servers' rooms (L-15): a MemoryStore sorted map,
-- one item per lobby server (key: its JobId, value: a Listing entry) with
-- an expiry, so a server that dies drops out by itself. A read takes the
-- whole map in one range call (a handful of lobby servers). Studio gets an
-- in-process stand-in with the same interface and expiry; the Studio
-- stand-in peer (StandInPeer) writes its fake server's entry into it.

local MemoryStoreService = game:GetService("MemoryStoreService")

local Config = require("../../shared/Config")

export type Index = {
	kind: string, -- "memorystore" | "stand-in"
	put: (jobId: string, value: any, ttl: number) -> (boolean, string?),
	remove: (jobId: string) -> boolean,
	list: () -> (boolean, { any }), -- ok, every live value
}

local RoomIndex = {}

local MAX_SERVERS = 200 -- one range call

function RoomIndex.real(): Index
	local map = MemoryStoreService:GetSortedMap(Config.ROOM_LIST)
	return {
		kind = "memorystore",
		put = function(jobId: string, value: any, ttl: number)
			local ok, err = pcall(function()
				map:SetAsync(jobId, value, ttl)
			end)
			if not ok then
				warn(`[Lobby] room list write: {err}`)
			end
			return ok, if ok then nil else tostring(err)
		end,
		remove = function(jobId: string)
			return (pcall(function()
				map:RemoveAsync(jobId)
			end))
		end,
		list = function()
			local ok, items = pcall(function()
				return map:GetRangeAsync(Enum.SortDirection.Ascending, MAX_SERVERS)
			end)
			if not ok then
				warn(`[Lobby] room list read: {items}`)
				return false, {}
			end
			local out = {}
			for _, item in items do
				table.insert(out, item.value)
			end
			return true, out
		end,
	}
end

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

local standIn: Index? = nil

-- One per server: the lobby and the Studio stand-in peer share it.
function RoomIndex.standIn(): Index
	if standIn then
		return standIn
	end
	local items: { [string]: { value: any, expires: number } } = {}
	local s: Index = {
		kind = "stand-in",
		put = function(jobId: string, value: any, ttl: number)
			items[jobId] = { value = copy(value), expires = os.clock() + ttl }
			return true, nil
		end,
		remove = function(jobId: string)
			items[jobId] = nil
			return true
		end,
		list = function()
			local out = {}
			for k, item in items do
				if os.clock() < item.expires then
					table.insert(out, copy(item.value))
				else
					items[k] = nil
				end
			end
			return true, out
		end,
	}
	standIn = s
	return s
end

return RoomIndex
