--!strict
-- Profiles on this server (L-8): loaded when a player joins, history added
-- by the server alone. Writes queue up and go out one at a time through
-- UpdateAsync, each waiting for request budget and retried with backoff;
-- adding a match is idempotent (Profile.addMatch), so a retry that already
-- landed changes nothing.

local Profile = require("../shared/Profile")
local ProfileStore = require("./Services/ProfileStore")

local Profiles = {}

local RETRIES = 5
local BUDGET_WAIT = 60 -- seconds a write waits for budget before it counts as a failed try

local store: ProfileStore.Store
local cache: { [number]: Profile.Record } = {}
local changed: (user: number) -> () = function() end

type Job = { user: number, transform: (Profile.Record) -> boolean, what: string }
local queue: { Job } = {}
local running = false

function Profiles.init(s: ProfileStore.Store, onChanged: (number) -> ())
	store = s
	changed = onChanged
end

function Profiles.get(user: number): Profile.Record?
	return cache[user]
end

function Profiles.load(user: number)
	for attempt = 1, 3 do
		local ok, value = store.get(user)
		if ok then
			cache[user] = Profile.migrate(value, os.time())
			changed(user)
			return
		end
		task.wait(attempt)
	end
	warn(`[Lobby] profile {user}: couldn't load; showing an empty one until a write succeeds`)
	cache[user] = Profile.new(os.time())
	changed(user)
end

function Profiles.unload(user: number)
	cache[user] = nil
end

local function waitForBudget(): boolean
	local waited = 0
	while store.budget() < 1 do
		if waited >= BUDGET_WAIT then
			return false
		end
		task.wait(1)
		waited += 1
	end
	return true
end

local function runOne(job: Job)
	for attempt = 1, RETRIES do
		if waitForBudget() then
			local ok, value = store.update(job.user, function(old: any): any
				local r = Profile.migrate(old, os.time())
				if not job.transform(r) then
					return nil -- nothing to change: UpdateAsync writes nothing
				end
				return r
			end)
			if ok then
				if value ~= nil and cache[job.user] then
					cache[job.user] = Profile.migrate(value, os.time())
				end
				changed(job.user)
				return
			end
			warn(`[Lobby] profile {job.user} {job.what}: try {attempt} failed: {value}`)
		end
		task.wait(2 ^ attempt)
	end
	warn(`[Lobby] profile {job.user} {job.what}: gave up after {RETRIES} tries`)
end

local function pump()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			runOne(table.remove(queue, 1) :: Job)
		end
		running = false
	end)
end

-- Adds a match to `user`'s history (written even if they've left).
function Profiles.addMatch(user: number, entry: Profile.Entry)
	-- show it at once; the store write follows
	local r = cache[user]
	if r and Profile.addMatch(r, entry) then
		changed(user)
	end
	table.insert(queue, {
		user = user,
		what = `match {entry.matchId}`,
		transform = function(rec: Profile.Record): boolean
			return Profile.addMatch(rec, entry)
		end,
	})
	pump()
end

return Profiles
