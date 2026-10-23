--!strict
-- Team colors: the lobby's 12-colour palette (docs/contracts/match.md
-- section 3, C-173). In a lobby match each player picked a colour; the
-- match server publishes which palette entry each sim team uses as the
-- Remotes folder's "TeamColors" attribute (JSON { [team] = index }).
-- Without it (Studio profiles, the dev lobby) team n takes entry n.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require("@shared/Match/MatchConfig")

-- the palette, shared with the lobby place (S-145)
local PALETTE: { Color3 } = {}
for i, c in MatchConfig.COLORS do
	PALETTE[i] = Color3.fromRGB(c.rgb[1], c.rgb[2], c.rgb[3])
end

local byTeam: { [number]: number } = {} -- the match's palette index per team
local watching = false

local function read(remotes: Instance)
	table.clear(byTeam)
	local json = remotes:GetAttribute("TeamColors")
	if type(json) ~= "string" then
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if ok and type(data) == "table" then
		for team, index in data do
			local t, i = tonumber(team), tonumber(index)
			if t and i and PALETTE[i] then
				byTeam[t] = i
			end
		end
	end
end

local function watch()
	watching = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		read(remotes)
		remotes:GetAttributeChangedSignal("TeamColors"):Connect(function()
			read(remotes)
		end)
	else
		watching = false -- not there yet: try again next call
	end
end

return function(team: number): Color3
	if not watching then
		watch()
	end
	return PALETTE[byTeam[team] or team] or Color3.fromRGB(200, 200, 200)
end
