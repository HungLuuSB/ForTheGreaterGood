--!strict
-- The build menu's content (C-68, guide 15.7): what the selected builders
-- can build, split into category tabs. Mobile builders get structures,
-- factories get units. Pure Luau (C-7); UI/BuildMenu draws it.

local World = require("./World")

local BuildMenu = {}

-- BAR's build categories (reference 3, C-203): Economy, Combat, Utility,
-- Build (factories); a factory's menu is its Units.
BuildMenu.TABS = table.freeze({ "Economy", "Combat", "Utility", "Build", "Units" })
-- The Keybinds action that opens each structure tab (Z X C V by default).
BuildMenu.TAB_ACTIONS = table.freeze({ Economy = "tabEconomy", Combat = "tabCombat", Utility = "tabUtility", Build = "tabBuild" }) :: { [string]: string }

-- The tab a buildable def goes under.
function BuildMenu.category(def: any): string
	if def.domain ~= "structure" then
		return "Units"
	end
	if def.buildOptions and #def.buildOptions > 0 then
		return "Build"
	end
	if def.production or def.extractor or def.converter or def.storage or def.wind then
		return "Economy"
	end
	if #(def.weapons or {}) > 0 then
		return "Combat"
	end
	return "Utility" -- radars, jammers, sonar, pads
end

export type Menu = {
	builders: { number }, -- selected own builders (mobile and factories)
	factories: { number }, -- of which factories
	tabs: { string }, -- non-empty tabs, in TABS order
	items: { [string]: { string } }, -- tab → def IDs, in the builders' option order
}

-- The menu for the selection: the union of the selected own builders'
-- options (first builder's order first), by tab.
function BuildMenu.of(world: World.World, selection: { number }): Menu
	local menu: Menu = { builders = {}, factories = {}, tabs = {}, items = {} }
	local seen: { [string]: boolean } = {}
	for _, id in selection do
		local u = world.units[id]
		local def = u and World.def(world, u)
		if def and u.team == world.me.team and def.buildOptions and #def.buildOptions > 0 then
			table.insert(menu.builders, id)
			if def.domain == "structure" then
				table.insert(menu.factories, id)
			end
			for _, opt in def.buildOptions do
				local od = world.defs.units[opt]
				if od and not seen[opt] then
					seen[opt] = true
					local tab = BuildMenu.category(od)
					menu.items[tab] = menu.items[tab] or {}
					table.insert(menu.items[tab], opt)
				end
			end
		end
	end
	for _, tab in BuildMenu.TABS do
		if menu.items[tab] then
			table.insert(menu.tabs, tab)
		end
	end
	return menu
end

return BuildMenu
