--!strict
-- The match records' store (L-6; contract section 4): a MemoryStore HashMap
-- shared by the lobby and the match servers of the experience. Studio gets
-- an in-process stand-in with the same interface and expiry, since
-- MemoryStore needs a published place.

local MemoryStoreService = game:GetService("MemoryStoreService")

local Config = require("../../shared/Config")

export type Store = {
	kind: string, -- "memorystore" | "stand-in"
	get: (key: string) -> (boolean, any), -- ok, value (nil if absent)
	set: (key: string, value: any, ttl: number) -> (boolean, string?),
	remove: (key: string) -> boolean,
}

local RETRIES = 3

local function withRetries<T>(what: string, fn: () -> T): (boolean, any)
	local err
	for attempt = 1, RETRIES do
		local ok, value = pcall(fn)
		if ok then
			return true, value
		end
		err = value
		if attempt < RETRIES then
			task.wait(0.5 * 2 ^ (attempt - 1))
		end
	end
	warn(`[Lobby] MatchStore {what}: {err}`)
	return false, tostring(err)
end

local MatchStore = {}

function MatchStore.real(): Store
	local map = MemoryStoreService:GetHashMap(Config.MATCH_MAP)
	return {
		kind = "memorystore",
		get = function(key: string)
			return withRetries(`get {key}`, function()
				return map:GetAsync(key)
			end)
		end,
		set = function(key: string, value: any, ttl: number)
			local ok, err = withRetries(`set {key}`, function()
				return map:SetAsync(key, value, ttl)
			end)
			return ok, if ok then nil else err
		end,
		remove = function(key: string)
			return (withRetries(`remove {key}`, function()
				map:RemoveAsync(key)
				return true
			end))
		end,
	}
end

-- Values are deep-copied in and out, as MemoryStore's JSON round trip does,
-- so nobody shares a table with the store.
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

local standIn: Store? = nil

-- One stand-in per server: the lobby and the Studio stand-in match server
-- read and write the same one.
function MatchStore.standIn(): Store
	if standIn then
		return standIn
	end
	local items: { [string]: { value: any, expires: number } } = {}
	local s: Store = {
		kind = "stand-in",
		get = function(key: string)
			local item = items[key]
			if item and os.clock() < item.expires then
				return true, copy(item.value)
			end
			items[key] = nil
			return true, nil
		end,
		set = function(key: string, value: any, ttl: number)
			items[key] = { value = copy(value), expires = os.clock() + ttl }
			return true, nil
		end,
		remove = function(key: string)
			items[key] = nil
			return true
		end,
	}
	standIn = s
	return s
end

return MatchStore
