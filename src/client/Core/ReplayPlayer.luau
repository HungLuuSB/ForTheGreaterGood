--!strict
-- Replay playback (C-79, guide 17.1): plays a PlayerReplay (S-18: the
-- stream the server sent one viewer) into the client through the same
-- NetIn path as the live stream, with pause, speed and seeking. Pure Luau
-- (C-7). `deliver(tick, outbox)` gets each tick's messages per channel, as
-- the live client got them. Seeking back starts over from the first tick:
-- the stream opens with a WELCOME, which resets the client's view, then
-- every tick up to the target is delivered at once (NetIn is fast enough
-- for that; no keyframes needed).

local PlayerReplay = require("@shared/Net/PlayerReplay")

local ReplayPlayer = {}

ReplayPlayer.TICK_RATE = 15
ReplayPlayer.SPEEDS = { 0.25, 0.5, 1, 2, 4, 8 }
ReplayPlayer.MAX_PER_FRAME = 240 -- ticks delivered in one frame at most (8× at 30 fps)

export type Deliver = (tick: number, outbox: { [string]: { buffer } }) -> ()

export type Player = {
	replay: PlayerReplay.Replay,
	tick: number, -- the last tick delivered (firstTick - 1 before any)
	frame: number, -- the next frame to look at
	paused: boolean,
	speed: number,
	acc: number, -- ticks owed, fractional
	restarts: number, -- how many times playback started over (a seek back): the view was rebuilt
}

function ReplayPlayer.new(replay: PlayerReplay.Replay): Player
	return { replay = replay, tick = replay.firstTick - 1, frame = 1, paused = false, speed = 1, acc = 0, restarts = 0 }
end

local function outboxAt(p: Player, tick: number): { [string]: { buffer } }
	local outbox: { [string]: { buffer } } = {}
	for _, name in PlayerReplay.CHANNELS do
		outbox[name] = {}
	end
	local f = p.replay.frames[p.frame]
	if f and f.tick == tick then
		for _, m in f.messages do
			table.insert(outbox[m.channel], m.data)
		end
		p.frame += 1
	end
	return outbox
end

local function deliverNext(p: Player, deliver: Deliver)
	local tick = p.tick + 1
	deliver(tick, outboxAt(p, tick))
	p.tick = tick
end

function ReplayPlayer.done(p: Player): boolean
	return p.tick >= p.replay.lastTick
end

-- Plays `dt` seconds at the current speed (nothing while paused or at the end).
function ReplayPlayer.advance(p: Player, dt: number, deliver: Deliver)
	if p.paused or ReplayPlayer.done(p) then
		p.acc = 0
		return
	end
	p.acc += dt * ReplayPlayer.TICK_RATE * p.speed
	local n = 0
	while p.acc >= 1 and not ReplayPlayer.done(p) and n < ReplayPlayer.MAX_PER_FRAME do
		deliverNext(p, deliver)
		p.acc -= 1
		n += 1
	end
	if n == ReplayPlayer.MAX_PER_FRAME then
		p.acc = 0 -- don't build up a debt after a hitch
	end
end

-- Jumps to `target` (clamped to the replay): forward by delivering every
-- tick in between, back by starting over from the first tick.
function ReplayPlayer.seek(p: Player, target: number, deliver: Deliver)
	local first, last = p.replay.firstTick, p.replay.lastTick
	target = math.clamp(math.floor(target), first, last)
	if target <= p.tick then
		p.tick, p.frame = first - 1, 1
		p.restarts += 1
	end
	while p.tick < target do
		deliverNext(p, deliver)
	end
	p.acc = 0
end

-- Seconds played and the replay's length.
function ReplayPlayer.progress(p: Player): (number, number)
	local first = p.replay.firstTick
	return (p.tick - first + 1) / ReplayPlayer.TICK_RATE, (p.replay.lastTick - first + 1) / ReplayPlayer.TICK_RATE
end

-- The next speed up or down the list.
function ReplayPlayer.faster(p: Player, up: boolean)
	local i = table.find(ReplayPlayer.SPEEDS, p.speed) or 3
	p.speed = ReplayPlayer.SPEEDS[math.clamp(i + (if up then 1 else -1), 1, #ReplayPlayer.SPEEDS)]
end

return ReplayPlayer
