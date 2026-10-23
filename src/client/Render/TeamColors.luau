--!strict
-- Team colors: the lobby's 12-colour palette (docs/contracts/match.md
-- section 3, C-173). In a lobby match each player picked a colour; the
-- match server publishes which palette entry each sim team uses as the
-- Remotes folder's "TeamColors" attribute (JSON { [team] = index }).
-- Without it (Studio profiles, the dev lobby) team n takes entry n.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PALETTE = {
	Color3.fromRGB(64, 132, 230), -- 1 Blue
	Color3.fromRGB(222, 70, 62), -- 2 Red
	Color3.fromRGB(82, 186, 92), -- 3 Green
	Color3.fromRGB(236, 200, 64), -- 4 Yellow
	Color3.fromRGB(156, 92, 214), -- 5 Purple
	Color3.fromRGB(238, 132, 46), -- 6 Orange
	Color3.fromRGB(60, 200, 210), -- 7 Cyan
	Color3.fromRGB(232, 110, 180), -- 8 Pink
	Color3.fromRGB(226, 229, 235), -- 9 White
	Color3.fromRGB(140, 150, 70), -- 10 Olive
	Color3.fromRGB(150, 100, 62), -- 11 Brown
	Color3.fromRGB(40, 130, 120), -- 12 Teal
}

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
