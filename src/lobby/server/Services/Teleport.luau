--!strict
-- Reserved servers and teleports (L-6; contract section 4). The real one
-- uses TeleportService; Studio can't reserve or teleport, so its stand-in
-- hands the players to the in-process stand-in match (StandInMatch), which
-- plays the match server's part of the contract. Failures can be staged in
-- Studio with the attribute `StandInFail` on ServerScriptService.Lobby:
-- "reserve", "teleport" (every attempt throws) or "player" (one player's
-- teleport fails, as TeleportInitFailed reports it).

local TeleportService = game:GetService("TeleportService")

export type Failure = (player: Player, message: string) -> ()

export type Teleport = {
	kind: string, -- "teleportservice" | "stand-in"
	reserve: (placeId: number) -> (string?, string?, string?), -- accessCode, privateServerId, error
	teleport: (players: { Player }, placeId: number, accessCode: string, data: any) -> (boolean, string?),
	onFailed: (callback: Failure) -> (),
}

local Teleport = {}

function Teleport.real(): Teleport
	local callbacks: { Failure } = {}
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		for _, cb in callbacks do
			task.spawn(cb, player, `{result.Name}: {message}`)
		end
	end)
	return {
		kind = "teleportservice",
		reserve = function(placeId: number)
			local ok, code, id = pcall(function()
				return TeleportService:ReserveServer(placeId)
			end)
			if not ok then
				return nil, nil, tostring(code)
			end
			return code, id, nil
		end,
		teleport = function(players: { Player }, placeId: number, accessCode: string, data: any)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			options:SetTeleportData(data)
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(placeId, players, options)
			end)
			return ok, if ok then nil else tostring(err)
		end,
		onFailed = function(callback: Failure)
			table.insert(callbacks, callback)
		end,
	}
end

-- `start(privateServerId, players, data)` is the stand-in match's entry.
function Teleport.standIn(start: (string, { Player }, any) -> (), flags: Instance): Teleport
	local callbacks: { Failure } = {}
	local reserved = 0
	return {
		kind = "stand-in",
		reserve = function(_placeId: number)
			if flags:GetAttribute("StandInFail") == "reserve" then
				return nil, nil, "HTTP 503 (staged in Studio)"
			end
			reserved += 1
			return `studio-code-{reserved}`, `studio-server-{reserved}`, nil
		end,
		teleport = function(players: { Player }, _placeId: number, accessCode: string, data: any)
			local fail = flags:GetAttribute("StandInFail")
			if fail == "teleport" then
				return false, "Teleport failed (staged in Studio)"
			end
			local going = table.clone(players)
			if fail == "player" and #going > 0 then
				local lost = table.remove(going) :: Player
				for _, cb in callbacks do
					task.spawn(cb, lost, "Unauthorized: staged in Studio")
				end
			end
			local id = string.gsub(accessCode, "code", "server")
			task.spawn(start, id, going, data)
			return true, nil
		end,
		onFailed = function(callback: Failure)
			table.insert(callbacks, callback)
		end,
	}
end

return Teleport
