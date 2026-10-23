--!strict
-- Lobby settings (L-11): interface scale and the background scene. They
-- last for this session; keys, graphics and sound live in the match's own
-- Settings (Esc in a match).

local Scene = require("../Scene")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Settings = {}

function Settings.new(frame: Frame, _router: any): any
	local title = Kit.text(frame, "Settings", "title")
	title.TextSize = 40
	title.Size = UDim2.new(0, 400, 0, 52)
	local card = Ui.card(frame, "Card", UDim2.fromOffset(640, 300), UDim2.fromOffset(0, 70), 0.1)
	Kit.pad(card, Kit.SPACE.xl, Kit.SPACE.l)
	Kit.list(card, Kit.SPACE.xs)
	Kit.section(card, "Interface", 0)
	local gui = frame:FindFirstAncestorOfClass("ScreenGui")
	local scale = gui and gui:FindFirstChild("SettingsScale") :: UIScale?
	Kit.slider(Kit.row(card, "Interface scale", 1), 0.75, 1.25, 0.05, 1, "%.2f×", function(v)
		if scale then
			scale.Scale = v
		end
	end, 180)
	Kit.section(card, "Background", 2)
	Kit.toggle(Kit.row(card, "Battle scene", 3), true, function(on)
		Scene.setEnabled(on)
	end)
	Kit.toggle(Kit.row(card, "Camera follows the mouse", 4), true, function(on)
		Scene.setParallax(on)
	end)
	local note = Kit.text(card, "Keys, graphics and sound are in the match's Settings (Esc during a match).", "small", Kit.COLOR.faint)
	note.LayoutOrder = 5
	note.Size = UDim2.new(1, 0, 0, 40)
	note.TextWrapped = true
	return {}
end

return Settings
