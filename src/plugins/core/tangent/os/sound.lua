--- === plugins.core.tangent.os.sound ===
---
--- Tangent Display Functions.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- Hammerspoon Extensions:
--------------------------------------------------------------------------------
local audiodevice           = require("hs.audiodevice")
local audiowatcher          = require("hs.audiodevice.watcher")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local prop                  = require("cp.prop")
local i18n                  = require("cp.i18n")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- plugins.core.tangent.os.sound.currentOutputDevice <cp.prop: audio>
--- Variable
--- Current Output Device.
mod.currentOutputDevice = prop(function()
    return audiodevice.defaultOutputDevice()
end)

--- plugins.core.tangent.os.sound.group <cp.prop: audio>
--- Variable
--- Tangent Sound Group.
mod.group = nil

--- plugins.core.tangent.os.sound.init() -> none
--- Function
--- Initialise the module.
---
--- Parameters:
---  * osGroup - The Tangent Sound Group.
---
--- Returns:
---  * None
function mod.init(osGroup)
    local soundGroup = osGroup:group(i18n("sound"))
    mod.group = soundGroup

    local toggleMute = function()
        local output = mod.currentOutputDevice()
        if output then
            output:setOutputMuted(not output:outputMuted())
        end
    end

    local volume = soundGroup:parameter(0x0AA00001)
        :name(i18n("volume"))
        :name9(i18n("volume9"))
        :name10(i18n("volume10"))
        :minValue(0)
        :maxValue(100)
        :stepSize(5)
        :onGet(function()
            local output = mod.currentOutputDevice()
            if output then
                return output:outputVolume()
            end
        end)
        :onChange(function(increment)
            local output = mod.currentOutputDevice()
            if output then
                local volume = output:outputVolume()
                if volume ~= nil then
                    output:setOutputVolume(volume + increment)
                end
            end
        end)
        :onReset(toggleMute)

    local iOn, iOff = i18n("on"), i18n("off")
    local mute = soundGroup:menu(0x0AA00002)
        :name(i18n("mute"))
        :name9(i18n("mute9"))
        :name10(i18n("mute10"))
        :onGet(function()
            local output = mod.currentOutputDevice()
            if output then
                return output:outputMuted() and iOn or iOff
            end
        end)
        :onNext(toggleMute)
        :onPrev(toggleMute)

    mod.currentOutputDevice:watch(function(device)
        if device then
            volume:update()
            mute:update()
            device:watcherCallback(function(_, name, scope, _)
                -- log.df("audio device '%s' event: %s; %s; %s", uid, name, scope, element)
                if scope and scope == "outp" then
                    if name and name == "vmvc" and volume then
                        volume:update()
                    elseif name and name == "mute" and mute then
                        mute:update()
                    end
                end
            end)
            if not device:watcherIsRunning() then
                device:watcherStart()
            end
        end
    end, true)

    audiowatcher.setCallback(function(event)
        if event and event == "dOut" then
            mod.currentOutputDevice:update()
        end
    end)
    if not audiowatcher.isRunning() then
        audiowatcher.start()
    end
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id = "core.tangent.os.sound",
    group = "core",
    dependencies = {
        ["core.tangent.os"] = "osGroup",
    }
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)
    mod.init(deps.osGroup)
    return mod
end

return plugin
