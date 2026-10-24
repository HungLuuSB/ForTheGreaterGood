--!strict
-- The settings tree (C-202), pure Luau (C-7): sections, their sub-sections
-- and option rows, and which rows show for a view (BAR's settings panels,
-- references 4–5). Kit.options draws it; this decides:
--   * a section's rows, or with a search query every row that matches it
--     (all of the query's words, in the label, help, keywords or the
--     section / sub-section names), from every section;
--   * "Advanced" rows only with Advanced on (a search finds them anyway);
--   * a row whose parent (or any ancestor) is folded is hidden, unless
--     Unfold all is on or a search is running;
--   * a row is dimmed while any ancestor is off (`isOn(id)` false);
--   * a sub-section header shows when any of its rows does.

local OptionTree = {}

export type OptionSpec = {
	id: string,
	label: string,
	help: string?,
	keywords: string?, -- extra search words
	advanced: boolean?,
	parent: string?, -- a row above it in the same sub-section: indented under it, dimmed while it's off
	folded: boolean?, -- a parent starts folded
}
export type SubSpec = { name: string, options: { OptionSpec } }
export type SectionSpec = { name: string, subs: { SubSpec } }

export type Option = OptionSpec & { section: string, sub: string, level: number, order: number }

export type Tree = {
	sections: { SectionSpec },
	options: { Option }, -- every row, in order
	byId: { [string]: Option },
	children: { [string]: { string } },
}

export type View = {
	section: string,
	query: string,
	advanced: boolean,
	unfoldAll: boolean,
	folded: { [string]: boolean }, -- a parent's own fold (true: folded); nil: its spec's `folded`
}

export type Row = { visible: boolean, dimmed: boolean, level: number, foldable: boolean, open: boolean }
export type Shown = { rows: { [string]: Row }, subs: { [string]: boolean }, count: number }

-- The key of a sub-section header.
function OptionTree.subKey(section: string, sub: string): string
	return section .. "/" .. sub
end

function OptionTree.new(sections: { SectionSpec }): Tree
	local tree: Tree = { sections = sections, options = {}, byId = {}, children = {} }
	for _, sec in sections do
		for _, sub in sec.subs do
			for _, spec in sub.options do
				assert(tree.byId[spec.id] == nil, `OptionTree: option {spec.id} twice`)
				local level = 0
				if spec.parent then
					local p = tree.byId[spec.parent]
					assert(p ~= nil and p.section == sec.name and p.sub == sub.name, `OptionTree: {spec.id}'s parent {spec.parent} isn't above it in {sec.name} / {sub.name}`)
					level = p.level + 1
					local list = tree.children[spec.parent] or {}
					tree.children[spec.parent] = list
					table.insert(list, spec.id)
				end
				local o = table.clone(spec) :: any
				o.section, o.sub, o.level, o.order = sec.name, sub.name, level, #tree.options + 1
				table.insert(tree.options, o)
				tree.byId[spec.id] = o
			end
		end
	end
	return tree
end

function OptionTree.view(section: string): View
	return { section = section, query = "", advanced = false, unfoldAll = false, folded = {} }
end

-- The query's words, lower case.
local function words(query: string): { string }
	local out = {}
	for w in string.gmatch(string.lower(query), "%S+") do
		table.insert(out, w)
	end
	return out
end

function OptionTree.matches(o: Option, query: string): boolean
	local ws = words(query)
	if #ws == 0 then
		return false
	end
	local hay = string.lower(table.concat({ o.label, o.help or "", o.keywords or "", o.section, o.sub }, " "))
	for _, w in ws do
		if string.find(hay, w, 1, true) == nil then
			return false
		end
	end
	return true
end

function OptionTree.isFolded(tree: Tree, view: View, id: string): boolean
	local own = view.folded[id]
	if own == nil then
		own = tree.byId[id].folded == true
	end
	return own
end

-- Which rows and headers show; `isOn(id)` says whether a parent is on.
function OptionTree.shown(tree: Tree, view: View, isOn: (string) -> boolean): Shown
	local searching = #words(view.query) > 0
	local out: Shown = { rows = {}, subs = {}, count = 0 }
	for _, o in tree.options do
		local visible, dimmed = false, false
		local open = view.unfoldAll or searching or not OptionTree.isFolded(tree, view, o.id)
		if searching then
			visible = OptionTree.matches(o, view.query)
		else
			visible = o.section == view.section and (view.advanced or not o.advanced)
		end
		local p = o.parent
		while p do
			local parent = tree.byId[p]
			local pr = out.rows[p]
			if not searching and not pr.visible then
				visible = false -- under a hidden (advanced) parent
			end
			if not searching and not view.unfoldAll and OptionTree.isFolded(tree, view, p) then
				visible = false
			end
			if not isOn(p) then
				dimmed = true
			end
			p = parent.parent
		end
		out.rows[o.id] = { visible = visible, dimmed = dimmed, level = o.level, foldable = tree.children[o.id] ~= nil, open = open }
		if visible then
			out.count += 1
			out.subs[OptionTree.subKey(o.section, o.sub)] = true
		end
	end
	return out
end

-- The sub-section a scroll position is in: the last header at or above
-- `top` (header offsets in content order); the first if none is.
function OptionTree.activeSub(headers: { { key: string, y: number } }, top: number): string?
	local active = if headers[1] then headers[1].key else nil
	for _, h in headers do
		if h.y <= top + 1 then
			active = h.key
		end
	end
	return active
end

return OptionTree
