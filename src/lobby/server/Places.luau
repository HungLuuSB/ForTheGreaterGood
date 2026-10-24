--!strict
-- Which place runs the matches (L-14). Config.MATCH_PLACE_ID is the one
-- setting; 0 means "find it": the experience's only place besides this
-- one, or the one whose name contains "match". Found once at server start
-- (AssetService:GetGamePlacesAsync, retried) and logged, so a published
-- server's log says which place it will send matches to. Studio's stand-in
-- teleports ignore the place.

local AssetService = game:GetService("AssetService")

local Config = require("../shared/Config")

local Places = {}

local found: number? = nil
local why = "not looked up yet"

local function experiencePlaces(): ({ { id: number, name: string } }?, string?)
	local ok, pages = pcall(function()
		return AssetService:GetGamePlacesAsync()
	end)
	if not ok then
		return nil, tostring(pages)
	end
	local out = {}
	while true do
		for _, p in (pages :: any):GetCurrentPage() do
			table.insert(out, { id = p.PlaceId, name = p.Name })
		end
		if (pages :: any).IsFinished then
			break
		end
		local more, err = pcall(function()
			(pages :: any):AdvanceToNextPageAsync()
		end)
		if not more then
			return nil, tostring(err)
		end
	end
	return out, nil
end

-- The places of this experience other than this one: the match place if
-- it's the only one, else the one named like a match place.
local function pick(list: { { id: number, name: string } }): (number?, string)
	local others = {}
	for _, p in list do
		if p.id ~= game.PlaceId then
			table.insert(others, p)
		end
	end
	if #others == 1 then
		return others[1].id, `the experience's other place "{others[1].name}"`
	end
	local named = {}
	for _, p in others do
		if string.find(string.lower(p.name), "match", 1, true) then
			table.insert(named, p)
		end
	end
	if #named == 1 then
		return named[1].id, `the place named "{named[1].name}"`
	end
	if #others == 0 then
		return nil, "this experience has no other place: add the match place to it"
	end
	return nil, `{#others} other places and none (or several) named "match": set Config.MATCH_PLACE_ID`
end

-- Looks the match place up (once; Main calls it at start).
function Places.init(studio: boolean)
	if Config.MATCH_PLACE_ID ~= 0 then
		found, why = Config.MATCH_PLACE_ID, "Config.MATCH_PLACE_ID"
	elseif studio then
		found, why = 0, "Studio stand-in"
	else
		for attempt = 1, 5 do
			local list, err = experiencePlaces()
			if list then
				found, why = pick(list)
				break
			end
			why = `the place list failed ({err})`
			task.wait(attempt * 2)
		end
	end
	if found then
		print(`[Lobby] match place {found} ({why}); lobby place {game.PlaceId}, experience {game.GameId}`)
	else
		warn(`[Lobby] no match place: {why}. Matches can't start.`)
	end
end

-- The match place, or nil and why not.
function Places.match(): (number?, string)
	return found, why
end

return Places
