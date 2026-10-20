--!strict
-- LRU cache of flow fields keyed by (move class, clearance need, goal cell)
-- (guide 6.4: ~32 entries; a 256×256 direction field is 64 KB).
--
-- Recency is a monotonically increasing use counter, never a clock, so
-- eviction order is deterministic. With ~32 entries a linear scan to find
-- the least recently used entry is cheaper than maintaining a linked list.

local FlowField = require("./FlowField")

local FieldCache = {}

FieldCache.DEFAULT_CAPACITY = 32

export type Cache = {
	capacity: number,
	entries: { [string]: FlowField.Field },
	lastUse: { [string]: number },
	keys: { string }, -- insertion order; used only to scan deterministically
	useCounter: number,
	hits: number,
	misses: number,
	evictions: number,
}

function FieldCache.new(capacity: number?): Cache
	return {
		capacity = capacity or FieldCache.DEFAULT_CAPACITY,
		entries = {},
		lastUse = {},
		keys = {},
		useCounter = 0,
		hits = 0,
		misses = 0,
		evictions = 0,
	}
end

function FieldCache.key(moveClass: string, need: number, goalCell: number): string
	return `{moveClass}:{need}:{goalCell}`
end

local function touch(cache: Cache, key: string)
	cache.useCounter += 1
	cache.lastUse[key] = cache.useCounter
end

-- The cached field, marking it most recently used; nil on a miss.
function FieldCache.get(cache: Cache, key: string): FlowField.Field?
	local field = cache.entries[key]
	if field == nil then
		cache.misses += 1
		return nil
	end
	cache.hits += 1
	touch(cache, key)
	return field
end

-- Stores a field (replacing any field under the same key), evicting the
-- least recently used entry when full. Returns the evicted key, if any.
function FieldCache.put(cache: Cache, key: string, field: FlowField.Field): string?
	local evicted: string? = nil
	if cache.entries[key] == nil then
		if #cache.keys >= cache.capacity then
			local oldestIndex, oldestUse = 1, math.huge
			for i, k in cache.keys do
				local use = cache.lastUse[k]
				if use < oldestUse then
					oldestIndex, oldestUse = i, use
				end
			end
			local k = table.remove(cache.keys, oldestIndex) :: string
			cache.entries[k] = nil
			cache.lastUse[k] = nil
			cache.evictions += 1
			evicted = k
		end
		table.insert(cache.keys, key)
	end
	cache.entries[key] = field
	touch(cache, key)
	return evicted
end

-- Drops every field whose corridor contains `cell` (e.g. a structure was
-- placed there, guide 6.4 invalidation). Returns how many were dropped.
function FieldCache.invalidateCell(cache: Cache, cell: number): number
	local dropped = 0
	local i = 1
	while i <= #cache.keys do
		local k = cache.keys[i]
		if buffer.readu8(cache.entries[k].corridor.mask, cell) == 1 then
			table.remove(cache.keys, i)
			cache.entries[k] = nil
			cache.lastUse[k] = nil
			dropped += 1
		else
			i += 1
		end
	end
	return dropped
end

function FieldCache.size(cache: Cache): number
	return #cache.keys
end

return FieldCache
