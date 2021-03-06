--- === plugins.finalcutpro.commands ===
---
--- The 'fcpx' command collection.
--- These are only active when FCPX is the active (ie. frontmost) application.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local commands                  = require("cp.commands")
local fcp                       = require("cp.apple.finalcutpro")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id              = "finalcutpro.commands",
    group           = "finalcutpro",
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init()

    --------------------------------------------------------------------------------
    -- New Final Cut Pro Command Collection:
    --------------------------------------------------------------------------------
    mod.cmds = commands.new("fcpx")

    --------------------------------------------------------------------------------
    -- Switch to Final Cut Pro to activate:
    --------------------------------------------------------------------------------
    mod.cmds:watch({
        activate    = function()
            fcp:launch()
        end,
    })

    --------------------------------------------------------------------------------
    -- Enable/Disable as Final Cut Pro becomes Active/Inactive:
    --------------------------------------------------------------------------------
    mod.isEnabled = fcp.isFrontmost:AND(fcp.isModalDialogOpen:NOT()):watch(function(enabled)
        mod.cmds:isEnabled(enabled)
    end):label("fcpxCommandsIsEnabled")

    return mod.cmds
end

--------------------------------------------------------------------------------
-- POST INITIALISATION:
--------------------------------------------------------------------------------
function plugin.postInit()
    mod.isEnabled:update()
end

return plugin
