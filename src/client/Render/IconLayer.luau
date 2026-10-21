--!strict
-- Icons on screen (guide 15.4): a pooled screen-space layer of unit-type
-- glyphs in team colors (UI/Glyph, BAR style, C-71), no image assets.
-- Units without a model (radar blips, ghosts, strategic records in view)
-- always get an icon; at strategic zoom every unit does and the models are
-- hidden. Looks are placeholders: listed under "Needs my review".

local Players = game:GetService("Players")

local Icons = require("../Core/Icons")
local Glyph = require("../UI/Glyph")
local TeamColors = require("./TeamColors")

local IconLayer = {}

export type Layer = { gui: ScreenGui, slots: { Glyph.G }, used: number }

function IconLayer.new(): Layer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Icons"
	gui.IgnoreGuiInset = true -- viewport pixels, like WorldToViewportPoint
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, slots = {}, used = 0 }
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
		if slot == nil then
			slot = Glyph.new(layer.gui)
			layer.slots[n] = slot
		end
		slot.root.Visible = true
		slot.root.Position = UDim2.fromOffset(d.x, d.y)
		Glyph.apply(slot, d.style, TeamColors(d.style.team))
	end
	for i = n + 1, layer.used do
		layer.slots[i].root.Visible = false
	end
	layer.used = n
end

return IconLayer
