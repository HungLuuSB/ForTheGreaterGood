--!strict
-- Room chat (L-9): one TextChatService channel per room, holding exactly
-- its members. Roblox filters and delivers the messages; the client shows
-- the channel in the room panel and sends with TextChannel:SendAsync.

local TextChatService = game:GetService("TextChatService")

local Chat = {}

local folder = Instance.new("Folder")
folder.Name = "LobbyRooms"
folder.Parent = TextChatService

local sources: { [string]: { [number]: TextSource } } = {}

local function channelOf(roomId: string): TextChannel
	local name = `Room_{roomId}`
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("TextChannel") then
		return existing
	end
	local c = Instance.new("TextChannel")
	c.Name = name
	c.Parent = folder
	return c
end

function Chat.add(roomId: string, user: number)
	local channel = channelOf(roomId)
	sources[roomId] = sources[roomId] or {}
	if sources[roomId][user] then
		return
	end
	task.spawn(function()
		local ok, source = pcall(function()
			return channel:AddUserAsync(user)
		end)
		if ok and source then
			sources[roomId][user] = source
		end
	end)
end

function Chat.remove(roomId: string, user: number)
	local s = sources[roomId] and sources[roomId][user]
	if s then
		sources[roomId][user] = nil
		s:Destroy()
	end
end

function Chat.close(roomId: string)
	sources[roomId] = nil
	local channel = folder:FindFirstChild(`Room_{roomId}`)
	if channel then
		channel:Destroy()
	end
end

return Chat
