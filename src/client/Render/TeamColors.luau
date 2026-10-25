--!strict
-- Team colors by side, as this viewer sees them (S-172, C-217): the player
-- is Blue, its allies cold colours, every enemy a warm one
-- (Shared/Match/TeamColors.forViewer, which the lobby uses too, so a player
-- keeps its colour from the room into the match). The match server
-- publishes every sim player as the Remotes folder's "Players" attribute
-- (JSON [{ id, team, allyTeam, name? }]); colours are by player, drawn by
-- team (one player per team). Without it (an older server) each team counts
-- as one player, from the WELCOME's ally teams. Main calls
-- TeamColors.setViewer on every WELCOME.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByViewer = require("@shared/Match/TeamColors")

local TeamColors = {}

export type Player = { id: number, team: number, allyTeam: number, name: string? }

local GREY = Color3.fromRGB(200, 200, 200) -- a team not in the match (yet)

local listed: { Player } = {} -- the Players attribute
local viewer = { player = 0, team = 0 }
local teamAllies: { [number]: number } = {}
local byTeam: { [number]: Color3 } = {}
local byPlayer: { [number]: Color3 } = {}
local dirty = true
local watching = false

TeamColors.version = 0 -- bumps when the colours change (a new match, another viewer)

local function read(remotes: Instance)
	table.clear(listed)
	dirty = true
	local json = remotes:GetAttribute("Players")
	if type(json) ~= "string" then
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if ok and type(data) == "table" then
		for _, p in data do
			local id, team, ally = tonumber(p.id), tonumber(p.team), tonumber(p.allyTeam)
			if id and team and ally then
				table.insert(listed, { id = id, team = team, allyTeam = ally, name = if type(p.name) == "string" then p.name else nil })
			end
		end
	end
end

local function watch()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		watching = true
		read(remotes)
		remotes:GetAttributeChangedSignal("Players"):Connect(function()
			read(remotes)
		end)
	end
end

-- Every sim player in the match (the attribute's list, or one per team).
function TeamColors.players(): { Player }
	if not watching then
		watch()
	end
	if #listed > 0 then
		return listed
	end
	local out = {}
	for team, ally in teamAllies do
		if ally ~= 0 then
			table.insert(out, { id = team, team = team, allyTeam = ally })
		end
	end
	return out
end

local function rebuild()
	dirty = false
	TeamColors.version += 1
	table.clear(byTeam)
	table.clear(byPlayer)
	local players = TeamColors.players()
	-- one player per team without the list: the viewer is its team
	local me = if #listed > 0 then viewer.player elseif viewer.player == 0 then 0 else viewer.team
	local colors = ByViewer.forViewer(me, players :: any)
	for _, p in players do
		local c = colors[p.id]
		if c then
			local rgb = Color3.fromRGB(c.rgb[1], c.rgb[2], c.rgb[3])
			byTeam[p.team] = rgb
			byPlayer[p.id] = rgb
		end
	end
end

-- Who is looking: the WELCOME's player (0 a spectator) and team, and every
-- team's ally team.
function TeamColors.setViewer(player: number, team: number, allies: { [number]: number })
	viewer.player, viewer.team = player, team
	teamAllies = allies
	dirty = true
end

-- A sim team's colour.
function TeamColors.of(team: number): Color3
	if not watching then
		watch()
	end
	if dirty then
		rebuild()
	end
	return byTeam[team] or GREY
end

-- A sim player's colour (the pre-game's picks).
function TeamColors.ofPlayer(player: number): Color3
	if not watching then
		watch()
	end
	if dirty then
		rebuild()
	end
	return byPlayer[player] or GREY
end

return TeamColors
