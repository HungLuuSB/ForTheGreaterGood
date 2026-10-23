--!strict
-- Profile storage (L-8; contract section 7): a DataStore written only by
-- lobby servers, through UpdateAsync. Studio gets an in-memory stand-in
-- (DataStores refuse Studio without API access, and a playtest shouldn't
-- write live profiles).

local DataStoreService = game:GetService("DataStoreService")

local Config = require("../../shared/Config")

export type Store = {
	kind: string, -- "datastore" | "stand-in"
	get: (user: number) -> (boolean, any),
	update: (user: number, transform: (any) -> any) -> (boolean, any), -- ok, new value or error
	budget: () -> number, -- UpdateAsync requests left now
}

local ProfileStore = {}

local function key(user: number): string
	return `p/{user}`
end

function ProfileStore.real(): Store
	local store = DataStoreService:GetDataStore(Config.PROFILE_STORE)
	return {
		kind = "datastore",
		get = function(user: number)
			return pcall(function()
				return store:GetAsync(key(user))
			end)
		end,
		update = function(user: number, transform: (any) -> any)
			return pcall(function()
				return store:UpdateAsync(key(user), function(old: any)
					return transform(old), { user }
				end)
			end)
		end,
		budget = function()
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		end,
	}
end

function ProfileStore.standIn(): Store
	local data: { [number]: any } = {}
	return {
		kind = "stand-in",
		get = function(user: number)
			return true, data[user]
		end,
		update = function(user: number, transform: (any) -> any)
			local new = transform(data[user])
			if new ~= nil then
				data[user] = new
			end
			return true, data[user]
		end,
		budget = function()
			return 100
		end,
	}
end

return ProfileStore
