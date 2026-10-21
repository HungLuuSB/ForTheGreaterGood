--!strict
-- Binary min-heap of (key1, key2, id) entries for A* and Dijkstra.
-- Ordered by key1, then key2, then id, so pops are deterministic.
--
-- Each entry keeps its own key snapshot. When a node's cost improves, push it
-- again; callers skip stale entries when popped (lazy deletion). Storage is
-- parallel arrays reused across clear() calls, so a reused heap allocates
-- nothing.
--
-- Push and pop move a "hole" instead of swapping pairs and compare inline
-- (S-60, the Normandy profile): the same comparisons in the same order as
-- swap-based sifting, so every pop returns exactly what it did before, at
-- about half the cost.

local Heap = {}

export type Heap = {
	id: { number },
	k1: { number },
	k2: { number },
	n: number,
}

function Heap.new(): Heap
	return { id = {}, k1 = {}, k2 = {}, n = 0 }
end

function Heap.clear(heap: Heap)
	heap.n = 0 -- arrays keep their slots; entries above n are ignored
end

function Heap.push(heap: Heap, id: number, k1: number, k2: number)
	local ids, k1s, k2s = heap.id, heap.k1, heap.k2
	local i = heap.n + 1
	heap.n = i
	-- sift up: parents larger than the new entry move down into the hole
	while i > 1 do
		local p = i // 2
		local pk1 = k1s[p]
		local smaller
		if k1 ~= pk1 then
			smaller = k1 < pk1
		else
			local pk2 = k2s[p]
			if k2 ~= pk2 then
				smaller = k2 < pk2
			else
				smaller = id < ids[p]
			end
		end
		if not smaller then
			break
		end
		ids[i], k1s[i], k2s[i] = ids[p], pk1, k2s[p]
		i = p
	end
	ids[i], k1s[i], k2s[i] = id, k1, k2
end

function Heap.pop(heap: Heap): (number, number)
	local ids, k1s, k2s = heap.id, heap.k1, heap.k2
	local topId, topK1 = ids[1], k1s[1]
	local n = heap.n
	-- the last entry fills the hole at the root, then sifts down
	local id, k1, k2 = ids[n], k1s[n], k2s[n]
	n -= 1
	heap.n = n
	local i = 1
	while true do
		local l = i * 2
		if l > n then
			break
		end
		-- the smaller child (left on ties, as before)
		local m = l
		local r = l + 1
		if r <= n then
			local lk1, rk1 = k1s[l], k1s[r]
			local rLess
			if rk1 ~= lk1 then
				rLess = rk1 < lk1
			else
				local lk2, rk2 = k2s[l], k2s[r]
				if rk2 ~= lk2 then
					rLess = rk2 < lk2
				else
					rLess = ids[r] < ids[l]
				end
			end
			if rLess then
				m = r
			end
		end
		-- stop when the moving entry is not larger than that child
		local mk1 = k1s[m]
		local childLess
		if mk1 ~= k1 then
			childLess = mk1 < k1
		else
			local mk2 = k2s[m]
			if mk2 ~= k2 then
				childLess = mk2 < k2
			else
				childLess = ids[m] < id
			end
		end
		if not childLess then
			break
		end
		ids[i], k1s[i], k2s[i] = ids[m], mk1, k2s[m]
		i = m
	end
	if n > 0 then
		ids[i], k1s[i], k2s[i] = id, k1, k2
	end
	return topId, topK1
end

function Heap.isEmpty(heap: Heap): boolean
	return heap.n == 0
end

return Heap
