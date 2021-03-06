--- === plugins.finalcutpro.bugfix.clipselection ===
---
--- Fixes a bug in Final Cut Pro 10.4.1 that selects unwanted clips when
--- making a selection of multiple clips using your mouse as a "lasso".

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
local log                   = require("hs.logger").new("fix_clipselect")

--------------------------------------------------------------------------------
-- Hammerspoon Extensions:
--------------------------------------------------------------------------------
local eventtap              = require("hs.eventtap")
local geometry              = require("hs.geometry")
local timer                 = require("hs.timer")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local fcp                   = require("cp.apple.finalcutpro")
local config                = require("cp.config")

--------------------------------------------------------------------------------
-- Local Lua Functions:
--------------------------------------------------------------------------------
local insert                = table.insert

local eventTypes            = eventtap.event.types
local eventProperties       = eventtap.event.properties

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {
    inTimeline = false,
    dragging = false,
}

--- plugins.finalcutpro.bugfix.clipselection.init() -> none
--- Function
--- Initialises the module.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.init()
    mod.timelineContents = fcp:timeline():contents()

    fcp.application:watch(function(app)
        mod.fcpPID = app and app:pid() or nil
    end, true)

    return mod
end

-- isPointInsideTimeline(point) -> boolean
-- Function
-- Is the specified point inside the timeline?
--
-- Parameters:
--  * point - The point to check.
--
-- Returns:
--  * `true` if the point is inside the timeline, otherwise `false`.
local function isPointInsideTimeline(point)
    local viewFrame = mod.timelineContents:viewFrame()
    if viewFrame and point then
        return geometry.inside(point, viewFrame)
    end
    return false
end

-- mouseClickHandler(event) -> none
-- Function
-- Mouse Click Handler.
--
-- Parameters:
--  * event - The Event.
--
-- Returns:
--  * None
local function mouseClickHandler(event)
    local fcpPID = mod.fcpPID
    if fcpPID then
        local targetPID = event:getProperty(eventProperties.eventTargetUnixProcessID)
        if targetPID == fcpPID then
            local location = event:location()

            local type = event:getType()
            if type == eventTypes.leftMouseDown then
                -- log.df("leftMouseDown: %s", inspect(event:location()))
                mod.dragging = false
                mod.inTimeline = isPointInsideTimeline(location)
                if mod.inTimeline then
                    mod.startLocation = location
                    mod.previousClips = mod.timelineContents:selectedClipsUI()
                end
            elseif type == eventTypes.leftMouseDragged then
                -- log.df("leftMouseDragged: %s", inspect(event:location()))
                if mod.inTimeline then
                    mod.dragging = true
                end
            elseif type == eventTypes.leftMouseUp then
                -- log.df("leftMouseUp: %s", inspect(event:location()))
                if mod.dragging then
                    local flags = event:getFlags()
                    local startLocation = mod.startLocation
                    timer.doAfter(0.0001, function()
                        local selectionRect = geometry.rect({
                            x=startLocation.x, y = startLocation.y,
                            w=location.x - startLocation.x, h=location.y - startLocation.y
                        })
                        -- only select clips that intersect with the selection range.
                        local allSelectedClips = mod.timelineContents:selectedClipsUI()
                        local selectedClips = {}
                        if allSelectedClips then
                            for _,clipUI in ipairs(allSelectedClips) do
                                local clipFrame = clipUI:attributeValue("AXFrame")
                                if clipFrame ~= nil then
                                    local intersect = selectionRect:intersect(clipFrame)
                                    if intersect ~= nil and intersect.w > 0 and intersect.h > 0 then
                                        insert(selectedClips, clipUI)
                                    end
                                end
                            end
                            if selectedClips then
                                if flags.cmd or flags.shift then
                                    for _,clip in ipairs(mod.previousClips) do
                                        insert(selectedClips, clip)
                                    end
                                end
                                mod.timelineContents:selectClips(selectedClips)
                                local selectedCount, allCount = #selectedClips, #allSelectedClips
                                local prevCount = mod.previousClips and #mod.previousClips
                                if selectedCount ~= allCount and selectedCount + prevCount ~= allCount then
                                    log.df("FCPX BUGFIX: Ignored %s rogue clips.", #allSelectedClips - #selectedClips)
                                end
                            end
                        end
                    end)
                    mod.dragging = false
                end
            end
            -- log.df("inTimeline: %s; dragging: %s", mod.inTimeline, mod.dragging)
        end
    end
end

--- plugins.finalcutpro.bugfix.clipselection.activate() -> none
--- Function
--- Activates the module.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.activate()
    local watcher = mod._watcher
    if not watcher then
        watcher = eventtap.new(
            {eventTypes.leftMouseDown, eventTypes.leftMouseUp, eventTypes.leftMouseDragged},
            mouseClickHandler
        )
        mod._watcher = watcher
    end

    if not watcher:isEnabled() then
        watcher:start()
    end
end

--- plugins.finalcutpro.bugfix.clipselection.deactivate() -> none
--- Function
--- Deactivates the module.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.deactivate()
    local watcher = mod._watcher
    if watcher and watcher:isEnabled() then
        watcher:stop()
    end
end

--- plugins.finalcutpro.bugfix.clipselection.enabled <cp.prop: boolean>
--- Variable
--- Allows the fix to be enabled/disabled by setting the `bugfix_clipselection'
--- configuration property to `true` or `false`.
mod.enabled = config.prop("bugfix_clipselection", true)

--- plugins.finalcutpro.bugfix.clipselection.active <cp.prop: boolean>
--- Variable
--- Checks if the plugin is currently active, depending on `enabled` and which
--- version of Final Cut Pro is currently installed.
mod.active = mod.enabled:AND(fcp.isRunning):AND(fcp.versionString:IS("10.4.1")):watch(
    function(active)
        if active then
            mod.activate()
        else
            mod.deactivate()
        end
    end, true
)

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id = "finalcutpro.bugfix.clipselection",
    group = "finalcutpro",
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init()
    return mod.init()
end

return plugin
