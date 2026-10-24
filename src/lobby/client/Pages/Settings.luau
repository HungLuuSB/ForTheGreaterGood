--!strict
-- Lobby settings (L-11, L-16) on client-B's settings body (Kit.options,
-- C-202): the search box, the section tree, sub-section headers and the
-- hover help, as in the match's Settings. Interface scale and the
-- background scene; they're saved on your profile, so they follow you to
-- any lobby server: applied once the profile arrives, sent back after each
-- change (the slider once it rests). Keys, graphics and sound live in the
-- match's own Settings (Esc in a match).

local Net = require("../Net")
local Scene = require("../Scene")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Settings = {}

local SEND_AFTER = 0.6 -- seconds a slider rests before its value is sent

function Settings.new(frame: Frame, _router: any): any
	local gui = frame:FindFirstAncestorOfClass("ScreenGui")
	local scale = gui and gui:FindFirstChild("SettingsScale") :: UIScale?

	local values = { uiScale = 1, scene = true, parallax = true }
	local applied = false -- the profile's values arrived and are shown
	local pending = 0
	local function save(delay: number)
		pending += 1
		local mine = pending
		task.delay(delay, function()
			if mine == pending then
				Net.send({ op = "settings", values = table.clone(values) })
			end
		end)
	end

	local function apply()
		if scale then
			scale.Scale = values.uiScale
		end
		Scene.setEnabled(values.scene)
		Scene.setParallax(values.parallax)
	end

	local slider: Kit.Slider? = nil
	local sceneToggle: Kit.Toggle? = nil
	local parallaxToggle: Kit.Toggle? = nil
	local options: Kit.Options

	local sections: { Kit.OptionSection } = {
		{ name = "Interface", subs = {
			{ name = "Display", options = {
				{ id = "uiScale", label = "Interface scale", keywords = "size ui zoom", help = "How big the lobby's menus are. Saved on your profile.",
					build = function(c)
						slider = Kit.slider(c, 0.75, 1.25, 0.05, values.uiScale, "%.2f×", function(v)
							values.uiScale = v
							apply()
							save(SEND_AFTER)
						end, 180)
					end },
			} },
			{ name = "In a match", options = {
				{ id = "matchSettings", label = "Keys, graphics and sound", keywords = "controls audio quality hotkeys", help = "The match has its own Settings: press Esc during a match. These lobby settings are saved on your profile.",
					build = function(c)
						Ui.label(c, "Esc during a match", "label", Kit.COLOR.dim)
					end },
			} },
		} },
		{ name = "Background", subs = {
			{ name = "Battle scene", options = {
				{ id = "scene", label = "Battle scene", keywords = "3d tanks background performance", help = "The battle behind the menus. Off: just the sky, lighter on slow computers.",
					isOn = function()
						return values.scene
					end,
					build = function(c)
						sceneToggle = Kit.toggle(c, values.scene, function(on)
							values.scene = on
							apply()
							save(0)
							options.refresh()
						end)
					end },
				{ id = "parallax", label = "Camera follows the mouse", parent = "scene", keywords = "parallax motion", help = "The battle's camera leans toward the mouse a little.",
					build = function(c)
						parallaxToggle = Kit.toggle(c, values.parallax, function(on)
							values.parallax = on
							apply()
							save(0)
						end)
					end },
			} },
		} },
	}

	local panel = Kit.panel(frame, "Settings", Vector2.new(820, 460))
	panel.scrim.Visible = false -- a page, not a modal: the battle shows around it
	options = Kit.options(panel, sections)

	return {
		update = function(v: any)
			local saved = v.profile and v.profile.settings
			if applied or type(saved) ~= "table" then
				return
			end
			-- once per session: later views echo what this page sent
			applied = true
			values.uiScale = if type(saved.uiScale) == "number" then saved.uiScale else 1
			values.scene = saved.scene ~= false
			values.parallax = saved.parallax ~= false
			if slider then
				slider.set(values.uiScale)
			end
			if sceneToggle then
				sceneToggle.set(values.scene)
			end
			if parallaxToggle then
				parallaxToggle.set(values.parallax)
			end
			apply()
			options.refresh()
		end,
	}
end

return Settings
