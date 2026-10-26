--!strict
-- Map features (S-197, the user: "environmental resources"; BAR's map
-- features): trees reclaimed for power, rocks reclaimed for supply. Each map
-- lists its own (Layers.features: kind, position, value); these are the
-- kinds and their defaults.
--
--   resource   what reclaiming it gives ("power" or "supply")
--   value      how much it holds when the map lists no value
--   blocks     rocks are solid: no ground or naval unit enters their cell and
--              nothing is built on it until reclaimed; trees are scenery
--              units pass through
--   model      what the client draws (models-C's)

local Features = {}

export type Kind = {
	id: number, -- on the wire (WRECK featureKind; 0 = a unit's wreck)
	name: string,
	resource: "power" | "supply",
	value: number,
	blocks: boolean,
	model: string,
}

Features.TREE = 1
Features.ROCK = 2

Features.KINDS = table.freeze({
	tree = table.freeze({ id = Features.TREE, name = "tree", resource = "power", value = 150, blocks = false, model = "feature_tree" }) :: Kind,
	rock = table.freeze({ id = Features.ROCK, name = "rock", resource = "supply", value = 30, blocks = true, model = "feature_rock" }) :: Kind,
})

-- By wire id.
Features.BY_ID = table.freeze({ [Features.TREE] = Features.KINDS.tree, [Features.ROCK] = Features.KINDS.rock })

return Features
