--!strict
-- Who has authority in the lobby (G11): the experience's owner (for a
-- group's experience, rank Config.ADMIN_RANK and up), the user IDs in
-- Config.ADMINS, and anyone in Studio. Only they set a room's cap (every
-- other room holds Config.DEFAULT_PLAYERS people, AIs included). Asked
-- once per player and remembered.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("../shared/Config")

local Authority = {}

local known: { [number]: boolean } = {}

function Authority.has(player: Player): boolean
	local cached = known[player.UserId]
	if cached ~= nil then
		return cached
	end
	local yes = RunService:IsStudio() or table.find(Config.ADMINS, player.UserId) ~= nil
	if not yes then
		if game.CreatorType == Enum.CreatorType.User then
			yes = player.UserId == game.CreatorId
		elseif game.CreatorType == Enum.CreatorType.Group then
			local ok, rank = pcall(function()
				return player:GetRankInGroup(game.CreatorId)
			end)
			yes = ok and rank >= Config.ADMIN_RANK
		end
	end
	known[player.UserId] = yes
	return yes
end

Players.PlayerRemoving:Connect(function(player)
	known[player.UserId] = nil
end)

return Authority
