--!strict
-- Text filtering and friendships (L-6). Room names are shown to everyone in
-- the browser, so they go through TextService's broadcast filter. Studio's
-- stand-in passes text through unchanged (the live filter needs a published
-- place to be meaningful). Friendship checks are cached for a minute.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

export type Social = {
	kind: string, -- "live" | "stand-in"
	filterName: (text: string, from: number) -> (string?, string?), -- filtered text, or error
	isFriend: (a: number, b: number) -> boolean,
}

local Social = {}

local FRIEND_CACHE_SECONDS = 60

local function friends(): (number, number) -> boolean
	local cache: { [string]: { value: boolean, at: number } } = {}
	return function(a: number, b: number): boolean
		if a == b then
			return true
		end
		local k = if a < b then `{a}:{b}` else `{b}:{a}`
		local c = cache[k]
		if c and os.clock() - c.at < FRIEND_CACHE_SECONDS then
			return c.value
		end
		local player = Players:GetPlayerByUserId(a) or Players:GetPlayerByUserId(b)
		local other = if player and player.UserId == a then b else a
		local value = false
		if player and a > 0 and b > 0 then
			local ok, result = pcall(function()
				return player:IsFriendsWith(other)
			end)
			value = ok and result == true
		end
		cache[k] = { value = value, at = os.clock() }
		return value
	end
end

function Social.real(): Social
	return {
		kind = "live",
		filterName = function(text: string, from: number)
			local ok, result = pcall(function()
				return TextService:FilterStringAsync(text, from):GetNonChatStringForBroadcastAsync()
			end)
			if not ok then
				return nil, "The name filter is busy: try again"
			end
			return result, nil
		end,
		isFriend = friends(),
	}
end

function Social.standIn(): Social
	return {
		kind = "stand-in",
		filterName = function(text: string, _from: number)
			return text, nil
		end,
		isFriend = friends(),
	}
end

return Social
