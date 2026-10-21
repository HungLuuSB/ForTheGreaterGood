--!strict
-- Every unit def's icon facts as JSON on stdout, for tools/icons/render.mjs
-- (C-74): id, def index, icon family, domain, tier, name.

local serde = require("@lune/serde")
local Defs = require("@shared/Defs/Defs")

local out = {}
for index, def in Defs.load().unitByIndex do
	table.insert(out, { id = def.id, index = index, family = def.icon, domain = def.domain, tier = def.tier or 1, name = def.name })
end
print(serde.encode("json", out))
