--!strict
-- Binary min-heap of (key1, key2, id) entries for A* and Dijkstra.
-- Ordered by key1, then key2, then id, so pops are deterministic.
--
-- Each entry keeps its own key snapshot. When a node's cost improves, push it
-- again; callers skip stale entries when popped (lazy deletion). Storage is
-- parallel arrays reused across clear() calls, so a reused heap allocates
-- nothing.

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

local function less(heap: Heap, a: number, b: number): boolean
	local x, y = heap.k1[a], heap.k1[b]
	if x ~= y then
		return x < y
	end
	x, y = heap.k2[a], heap.k2[b]
	if x ~= y then
		return x < y
	end
	return heap.id[a] < heap.id[b]
end

local function swap(heap: Heap, a: number, b: number)
	local id, k1, k2 = heap.id, heap.k1, heap.k2
	id[a], id[b] = id[b], id[a]
	k1[a], k1[b] = k1[b], k1[a]
	k2[a], k2[b] = k2[b], k2[a]
end

function Heap.push(heap: Heap, id: number, k1: number, k2: number)
	local i = heap.n + 1
	heap.n = i
	heap.id[i], heap.k1[i], heap.k2[i] = id, k1, k2
	while i > 1 do
		local p = i // 2
		if less(heap, i, p) then
			swap(heap, i, p)
			i = p
		else
			break
		end
	end
end

-- Removes and returns the smallest entry's id and first key.
function Heap.pop(heap: Heap): (number, number)
	local id, k1 = heap.id[1], heap.k1[1]
	local n = heap.n
	swap(heap, 1, n)
	n -= 1
	heap.n = n
	local i = 1
	while true do
		local l, r = i * 2, i * 2 + 1
		local m = i
		if l <= n and less(heap, l, m) then
			m = l
		end
		if r <= n and less(heap, r, m) then
			m = r
		end
		if m == i then
			break
		end
		swap(heap, i, m)
		i = m
	end
	return id, k1
end

function Heap.isEmpty(heap: Heap): boolean
	return heap.n == 0
end

return Heap
