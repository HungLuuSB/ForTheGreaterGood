--!strict
-- Icons on screen (guide 15.4): a pooled screen-space layer of unit-type
-- glyphs in team colors (UI/Glyph, BAR style, C-71), no image assets.
-- Units without a model (radar blips, ghosts, strategic records in view)
-- always get an icon; at strategic zoom every unit does and the models are
-- hidden. Each slot remembers the style and pixel it last showed, so a
-- frame only writes what changed (C-73: the icon layer was the client's
-- biggest cost at full zoom). Looks are placeholders: listed under "Needs
-- my review".

local Players = game:GetService("Players")

local Icons = require("../Core/Icons")
local Glyph = require("../UI/Glyph")
local TeamColors = require("./TeamColors")

local IconLayer = {}

-- what a slot last showed
type Shown = { shape: string?, size: number, team: number, alpha: number, selected: boolean, glyph: any, x: number, y: number, visible: boolean }

export type Layer = { gui: ScreenGui, slots: { Glyph.G }, shown: { Shown }, used: number, stats: { styled: number, moved: number } }

function IconLayer.new(): Layer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Icons"
	gui.IgnoreGuiInset = true -- viewport pixels, like WorldToViewportPoint
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, slots = {}, shown = {}, used = 0, stats = { styled = 0, moved = 0 } }
end

-- Draws this frame's icons. With `everything` false only units without a
-- model (not tactical) get one.
function IconLayer.step(layer: Layer, draws: { Icons.Draw }, tiers: { [number]: string }, everything: boolean)
	local n = 0
	for _, d in draws do
		if not everything and tiers[d.id] == "tactical" then
			continue
		end
		n += 1
		local slot = layer.slots[n]
		local shown = layer.shown[n]
		if slot == nil then
			slot = Glyph.new(layer.gui)
			layer.slots[n] = slot
			shown = { shape = nil, size = 0, team = 0, alpha = 0, selected = false, glyph = nil, x = -1, y = -1, visible = false }
			layer.shown[n] = shown
		end
		if not shown.visible then
			slot.root.Visible = true
			shown.visible = true
		end
		local x, y = math.floor(d.x + 0.5), math.floor(d.y + 0.5)
		if x ~= shown.x or y ~= shown.y then
			slot.root.Position = UDim2.fromOffset(x, y)
			shown.x, shown.y = x, y
			layer.stats.moved += 1
		end
		local st = d.style
		if st.shape ~= shown.shape or st.size ~= shown.size or st.team ~= shown.team or st.alpha ~= shown.alpha or st.selected ~= shown.selected or st.glyph ~= shown.glyph then
			Glyph.apply(slot, st, TeamColors(st.team))
			shown.shape, shown.size, shown.team, shown.alpha, shown.selected, shown.glyph = st.shape, st.size, st.team, st.alpha, st.selected, st.glyph
			layer.stats.styled += 1
		end
	end
	for i = n + 1, layer.used do
		if layer.shown[i].visible then
			layer.slots[i].root.Visible = false
			layer.shown[i].visible = false
		end
	end
	layer.used = n
end

return IconLayer
