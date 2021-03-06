--- === plugins.finalcutpro.timeline.playback ===
---
--- Playback Plugin.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local fcp							= require("cp.apple.finalcutpro")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- plugins.finalcutpro.timeline.playback.play() -> none
--- Function
--- 'Play' in Final Cut Pro
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.play()
    if not fcp:viewer():isPlaying() and not fcp:eventViewer():isPlaying() then
        fcp:performShortcut("PlayPause")
    end
end

--- plugins.finalcutpro.timeline.playback.pause() -> none
--- Function
--- 'Pause' in Final Cut Pro
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.pause()
    if fcp:viewer():isPlaying() or fcp:eventViewer():isPlaying() then
        fcp:performShortcut("PlayPause")
    end
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id = "finalcutpro.timeline.playback",
    group = "finalcutpro",
    dependencies = {
        ["finalcutpro.commands"]	= "fcpxCmds",
    }
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)

    --------------------------------------------------------------------------------
    -- Setup Commands:
    --------------------------------------------------------------------------------
    if deps.fcpxCmds then
        local cmds = deps.fcpxCmds
        cmds:add("cpPlay")
            :whenActivated(mod.play)

        cmds:add("cpPause")
            :whenActivated(mod.pause)
    end

    return mod
end

return plugin
