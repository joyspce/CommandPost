local metadata					= require("cp.metadata")

--- The AUTOMATION menu section.

local PRIORITY = 5000

local SETTING = metadata.settingsPrefix .. ".menubarAdministratorEnabled"

local function isSectionDisabled()
	local setting = metadata.get(SETTING)
	if setting ~= nil then
		return not setting
	else
		return false
	end
end

local function toggleSectionDisabled()
	local menubarEnabled = metadata.get(SETTING)
	metadata.set(SETTING, not menubarEnabled)
end

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["cp.plugins.menu.manager"] 				= "manager",
	["cp.plugins.menu.preferences.menubar"] 	= "menubar",
}

function plugin.init(dependencies)
	-- Create the 'SHORTCUTS' section
	local shortcuts = dependencies.manager.addSection(PRIORITY)

	-- Disable the section if the shortcuts option is disabled
	shortcuts:setDisabledFn(isSectionDisabled)

	-- Add the separator and title for the section.
	shortcuts:addSeparator(0)
		:addItem(1, function()
			return { title = string.upper(i18n("adminTools")) .. ":", disabled = true }
		end)

	-- Create the menubar preferences item
	dependencies.menubar:addItem(PRIORITY, function()
		return { title = i18n("showAdminTools"),	fn = toggleSectionDisabled, checked = not isSectionDisabled()}
	end)

	return shortcuts
end

return plugin