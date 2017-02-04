-- Imports

local settings			= require("hs.settings")
local chooser			= require("hs.chooser")
local screen			= require("hs.screen")
local drawing			= require("hs.drawing")
local timer				= require("hs.timer")
local inspect			= require("hs.inspect")

local fcp				= require("cp.finalcutpro")
local dialog			= require("cp.dialog")
local tools				= require("cp.tools")
local hacksconsole		= require("cp.fcpx10-3.hacksconsole")
local metadata			= require("cp.metadata")

local log				= require("hs.logger").new("generators")

-- Constants
local PRIORITY = 4000

local MAX_SHORTCUTS = 5

-- The Module

local mod = {}

function mod.getShortcuts()
	return settings.get(metadata.settingsPrefix .. "." .. fcp:getCurrentLanguage() .. ".generatorsShortcuts") or {}
end

function mod.setShortcut(number, value)
	assert(number >= 1 and number <= MAX_SHORTCUTS)
	local shortcuts = mod.getShortcuts()
	shortcuts[number] = value
	settings.set(metadata.settingsPrefix .. "." .. fcp:getCurrentLanguage() .. ".generatorsShortcuts", shortcuts)
end

function mod.getGenerators()
	return settings.get(metadata.settingsPrefix .. "." .. fcp:getCurrentLanguage() .. ".allGenerators")
end

--------------------------------------------------------------------------------
-- GENERATORS SHORTCUT PRESSED:
-- The shortcut may be a number from 1-5, in which case the 'assigned' shortcut is applied,
-- or it may be the name of the generator to apply in the current FCPX language.
--------------------------------------------------------------------------------
function mod.apply(shortcut)

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	if type(shortcut) == "number" then
		shortcut = mod.getShortcuts()[shortcut]
	end

	if shortcut == nil then
		dialog.displayMessage(i18n("noGeneratorShortcut"))
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Save the main Browser layout:
	--------------------------------------------------------------------------------
	local browser = fcp:browser()
	local browserLayout = browser:saveLayout()

	--------------------------------------------------------------------------------
	-- Get Generators Browser:
	--------------------------------------------------------------------------------
	local generators = fcp:generators()
	local generatorsShowing = generators:isShowing()
	local generatorsLayout = generators:saveLayout()


	--------------------------------------------------------------------------------
	-- Make sure FCPX is at the front.
	--------------------------------------------------------------------------------
	fcp:launch()

	--------------------------------------------------------------------------------
	-- Make sure the panel is open:
	--------------------------------------------------------------------------------
	generators:show()

	if not generators:isShowing() then
		dialog.displayErrorMessage("Unable to display the Generators panel.\n\nError occurred in generators.apply(...)")
		return false
	end

	--------------------------------------------------------------------------------
	-- Make sure there's nothing in the search box:
	--------------------------------------------------------------------------------
	generators:search():clear()

	--------------------------------------------------------------------------------
	-- Click 'All':
	--------------------------------------------------------------------------------
	generators:showAllGenerators()

	--------------------------------------------------------------------------------
	-- Make sure "Installed Generators" is selected:
	--------------------------------------------------------------------------------
	generators:showInstalledGenerators()

	--------------------------------------------------------------------------------
	-- Perform Search:
	--------------------------------------------------------------------------------
	generators:search():setValue(shortcut)

	--------------------------------------------------------------------------------
	-- Get the list of matching effects
	--------------------------------------------------------------------------------
	local matches = generators:currentItemsUI()
	if not matches or #matches == 0 then
		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		local index = string.find(shortcut, "-")
		if index ~= nil then
			local trimmedShortcut = string.sub(shortcut, index + 2)
			effects:search():setValue(trimmedShortcut)

			matches = generators:currentItemsUI()
			if not matches or #matches == 0 then
				dialog.displayErrorMessage("Unable to find a transition called '"..shortcut.."'.\n\nError occurred in generators.apply(...).")
				return "Fail"
			end
		end
	end

	local generator = matches[1]

	--------------------------------------------------------------------------------
	-- Apply the selected Transition:
	--------------------------------------------------------------------------------
	mod.touchbar.hide()

	generators:applyItem(generator)

	-- TODO: HACK: This timer exists to  work around a mouse bug in Hammerspoon Sierra
	timer.doAfter(0.1, function()
		mod.touchbar.show()

		generators:loadLayout(generatorsLayout)
		if browserLayout then browser:loadLayout(browserLayout) end
		if not generatorsShowing then generators:hide() end
	end)

end

--------------------------------------------------------------------------------
-- ASSIGN GENERATORS SHORTCUT:
--------------------------------------------------------------------------------
function mod.assignGeneratorsShortcut(whichShortcut)

	--------------------------------------------------------------------------------
	-- Was Final Cut Pro Open?
	--------------------------------------------------------------------------------
	local wasFinalCutProOpen = fcp:isFrontmost()

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	local currentLanguage 			= fcp:getCurrentLanguage()
	local generatorsListUpdated 	= mod.isGeneratorsListUpdated()
	local allGenerators 			= mod.getGenerators()

	--------------------------------------------------------------------------------
	-- Error Checking:
	--------------------------------------------------------------------------------
	if not generatorsListUpdated
	   or allGenerators == nil
	   or next(allGenerators) == nil then
		dialog.displayMessage(i18n("assignGeneratorsShortcutError"))
		return "Failed"
	end

	--------------------------------------------------------------------------------
	-- Generators List:
	--------------------------------------------------------------------------------
	local choices = {}
	if allGenerators ~= nil and next(allGenerators) ~= nil then
		for i=1, #allGenerators do
			item = {
				["text"] = allGenerators[i],
				["subText"] = "Generator",
			}
			table.insert(choices, 1, item)
		end
	end

	--------------------------------------------------------------------------------
	-- Sort everything:
	--------------------------------------------------------------------------------
	table.sort(choices, function(a, b) return a.text < b.text end)

	--------------------------------------------------------------------------------
	-- Setup Chooser:
	--------------------------------------------------------------------------------
	local theChooser = nil
	theChooser = chooser.new(function(result)
		theChooser:hide()
		if result ~= nil then
			--------------------------------------------------------------------------------
			-- Save the selection:
			--------------------------------------------------------------------------------
			mod.setShortcut(whichShortcut, result.text)
		end

		--------------------------------------------------------------------------------
		-- Put focus back in Final Cut Pro:
		--------------------------------------------------------------------------------
		if wasFinalCutProOpen then fcp:launch() end
	end)

	theChooser:bgDark(true):choices(choices)

	--------------------------------------------------------------------------------
	-- Allow for Reduce Transparency:
	--------------------------------------------------------------------------------
	if screen.accessibilitySettings()["ReduceTransparency"] then
		theChooser:fgColor(nil)
		          :subTextColor(nil)
	else
		theChooser:fgColor(drawing.color.x11.snow)
 		          :subTextColor(drawing.color.x11.snow)
	end

	--------------------------------------------------------------------------------
	-- Show Chooser:
	--------------------------------------------------------------------------------
	theChooser:show()
end

--------------------------------------------------------------------------------
-- GET LIST OF GENERATORS:
--------------------------------------------------------------------------------
function mod.updateGeneratorsList()

	--------------------------------------------------------------------------------
	-- Make sure Final Cut Pro is active:
	--------------------------------------------------------------------------------
	fcp:launch()

	--------------------------------------------------------------------------------
	-- Warning message:
	--------------------------------------------------------------------------------
	dialog.displayMessage(i18n("updateGeneratorsListWarning"))

	local generators = fcp:generators()

	local browserLayout = fcp:browser():saveLayout()

	--------------------------------------------------------------------------------
	-- Make sure Generators and Generators panel is open:
	--------------------------------------------------------------------------------
	if not generators:show():isShowing() then
		dialog.displayErrorMessage("Unable to activate the Generators and Generators panel.\n\nError occurred in updateGeneratorsList().")
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Make sure there's nothing in the search box:
	--------------------------------------------------------------------------------
	generators:search():clear()

	--------------------------------------------------------------------------------
	-- Click 'Generators':
	--------------------------------------------------------------------------------
	generators:showAllGenerators()

	--------------------------------------------------------------------------------
	-- Make sure "Installed Generators" is selected:
	--------------------------------------------------------------------------------
	generators:group():selectItem(1)

	--------------------------------------------------------------------------------
	-- Get list of All Transitions:
	--------------------------------------------------------------------------------
	local effectsList = generators:contents():childrenUI()
	local allGenerators = {}
	if effectsList ~= nil then
		for i=1, #effectsList do
			allGenerators[i] = effectsList[i]:attributeValue("AXTitle")
		end
	else
		dialog.displayErrorMessage("Unable to get list of all generators.\n\nError occurred in updateGeneratorsList().")
		return "Fail"
	end

	--------------------------------------------------------------------------------
	-- Restore Effects or Transitions Panel:
	--------------------------------------------------------------------------------
	fcp:browser():loadLayout(browserLayout)

	--------------------------------------------------------------------------------
	-- Save Results to Settings:
	--------------------------------------------------------------------------------
	local currentLanguage = fcp:getCurrentLanguage()
	settings.set(metadata.settingsPrefix .. "." .. currentLanguage .. ".allGenerators", allGenerators)
	settings.set(metadata.settingsPrefix .. "." .. currentLanguage .. ".generatorsListUpdated", true)

	--------------------------------------------------------------------------------
	-- Update Chooser:
	--------------------------------------------------------------------------------
	hacksconsole.refresh()

	--------------------------------------------------------------------------------
	-- Let the user know everything's good:
	--------------------------------------------------------------------------------
	dialog.displayMessage(i18n("updateGeneratorsListDone"))
end

function mod.isGeneratorsListUpdated()
	return settings.get(metadata.settingsPrefix .. "." .. fcp:getCurrentLanguage() .. ".generatorsListUpdated") or false
end

-- The Plugin
local plugin = {}

plugin.dependencies = {
	["cp.plugins.menu.timeline.assignshortcuts"]	= "automation",
	["cp.plugins.commands.fcpx"]		= "fcpxCmds",
	["cp.plugins.os.touchbar"]		= "touchbar",
}

function plugin.init(deps)
	local fcpxRunning = fcp:isRunning()
	mod.touchbar = deps.touchbar

	-- The 'Assign Shortcuts' menu
	local menu = deps.automation:addMenu(PRIORITY, function() return i18n("assignGeneratorsShortcuts") end)

	-- The 'Update' menu
	menu:addItem(1000, function()
		return { title = i18n("updateGeneratorsList"),	fn = mod.updateGeneratorsList, disabled = not fcpxRunning }
	end)
	menu:addSeparator(2000)

	menu:addItems(3000, function()
		--------------------------------------------------------------------------------
		-- Shortcuts:
		--------------------------------------------------------------------------------
		local listUpdated 	= mod.isGeneratorsListUpdated()
		local shortcuts		= mod.getShortcuts()

		local items = {}

		for i = 1, MAX_SHORTCUTS do
			local shortcutName = shortcuts[i] or i18n("unassignedTitle")
			items[i] = { title = i18n("generatorShortcutTitle", { number = i, title = shortcutName}), fn = function() mod.assignGeneratorsShortcut(i) end,	disabled = not listUpdated }
		end

		return items
	end)

	-- Commands

	for i = 1, MAX_SHORTCUTS do
		deps.fcpxCmds:add("FCPXHackGenerators"..tools.numberToWord(i)):whenActivated(function() mod.apply(i) end)
	end

	return mod
end

return plugin