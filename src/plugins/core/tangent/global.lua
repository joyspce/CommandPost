--- === plugins.core.tangent.global ===
---
--- Global Group for the Tangent.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local i18n        = require("cp.i18n")

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id = "core.tangent.global",
    group = "core",
    dependencies = {
        ["core.tangent.manager"]    = "tangentManager",
    }
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)
    local globalMode = deps.tangentManager.addMode(0x0000000A, i18n("global"))
    return globalMode
end

return plugin
