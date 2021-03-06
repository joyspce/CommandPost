--- === cp ===
---
--- Core CommandPost functionality.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
local require = require
local logger = require("hs.logger")
logger.defaultLogLevel = "verbose"

--------------------------------------------------------------------------------
-- Hammerspoon Extensions:
--------------------------------------------------------------------------------
local application               = require("hs.application")
local console                   = require("hs.console")
local crash                     = require("hs.crash")
local image                     = require("hs.image")
local keycodes                  = require("hs.keycodes")
local settings                  = require("hs.settings")
local styledtext                = require("hs.styledtext")
local toolbar                   = require("hs.webview.toolbar")
local window                    = require("hs.window")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local config                    = require("cp.config")
local fcp                       = require("cp.apple.finalcutpro")
local feedback                  = require("cp.feedback")
local i18n                      = require("cp.i18n")
local plugins                   = require("cp.plugins")
local tools                     = require("cp.tools")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- cp.init()
--- Function
--- Initialise CommandPost
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.init()

    --------------------------------------------------------------------------------
    -- Get Garbage Stats:
    --------------------------------------------------------------------------------
    local floor = math.floor
    local beforeRS = crash.residentSize()
    local beforeGC = floor(collectgarbage("count")*1024)

    --------------------------------------------------------------------------------
    -- Setup Logger:
    --------------------------------------------------------------------------------
    local log = logger.new("cp")

    --------------------------------------------------------------------------------
    -- Show Dock Icon:
    --------------------------------------------------------------------------------
    hs.dockIcon(true)

    --------------------------------------------------------------------------------
    -- Not used in `init.lua`, but is required to "jump start" the CLI support:
    --------------------------------------------------------------------------------
    require("hs.ipc")

    --------------------------------------------------------------------------------
    -- Save Error Log History across sessions:
    --------------------------------------------------------------------------------
    hs._consoleHistory = require("cp.console.history")

    --------------------------------------------------------------------------------
    -- Disable Spotlight for Name Searches:
    --------------------------------------------------------------------------------
    application.enableSpotlightForNameSearches(false)

    --------------------------------------------------------------------------------
    -- Disable Window Animations:
    --------------------------------------------------------------------------------
    window.animationDuration = 0

    --------------------------------------------------------------------------------
    -- Console Colour Scheme:
    --------------------------------------------------------------------------------
    console.consoleCommandColor{hex = "#999999", alpha = 1}
    console.outputBackgroundColor{hex = "#161616", alpha = 1}

    --------------------------------------------------------------------------------
    -- Debug Mode:
    --------------------------------------------------------------------------------
    local debugMode = config.developerMode()
    if debugMode then
        logger.defaultLogLevel = 'debug'
        require("cp.developer")
    --else
        --------------------------------------------------------------------------------
        -- NOTE: For now, whilst we're in beta, it's probably better if our error
        --       logs contain all the debug message we write to the console, so we can
        --       refer to them if users submit feedback.
        --------------------------------------------------------------------------------
        --logger.defaultLogLevel = 'warning'
    end

    --------------------------------------------------------------------------------
    -- Add Toolbar To Error Log:
    --------------------------------------------------------------------------------
    local function consoleOnTopIcon()
        if hs.consoleOnTop() then
            return image.imageFromName("NSStatusAvailable")
        else
            return image.imageFromName("NSStatusUnavailable")
        end
    end
    local function autoReloadIcon()
        if config.automaticScriptReloading() then
            return image.imageFromName("NSStatusAvailable")
        else
            return image.imageFromName("NSStatusUnavailable")
        end
    end
    console.toolbar(toolbar.new("myConsole", {
            { id = i18n("reload"), image = image.imageFromName("NSSynchronize"),
                fn = function()
                    console.clearConsole()
                    print("Reloading CommandPost...")
                    hs.reload()
                end
            },
            { id = i18n("clearLog"), image = image.imageFromName("NSTrashFull"),
                fn = function()
                    console.clearConsole()
                end
            },
            { id = i18n("alwaysOnTop"), image = consoleOnTopIcon(),
                fn = function(object)
                    hs.consoleOnTop(not hs.consoleOnTop())
                    object:modifyItem({id = i18n("alwaysOnTop"), image = consoleOnTopIcon()})
                end
            },
            { id = i18n("toggleAutomaticScriptReloading"), image = autoReloadIcon(),
                fn = function(object)
                    config.automaticScriptReloading:toggle()
                    object:modifyItem({id = i18n("toggleAutomaticScriptReloading"), image = autoReloadIcon()})
                end
            },
            { id = "NSToolbarFlexibleSpaceItem" },
            { id = i18n("preferences"), image = image.imageFromName("NSPreferencesGeneral"),
                fn = function()
                    plugins("core.preferences.manager").show()
                end
            },
            { id = i18n("feedback"), image = image.imageFromName("NSInfo"),
                fn = function()
                    feedback.showFeedback()
                end
            },
        })
        :canCustomize(true)
        :autosaves(true)
    )

    --------------------------------------------------------------------------------
    -- Open Error Log:
    --------------------------------------------------------------------------------
    local errorLogOpenOnClose = config.get("errorLogOpenOnClose", false)
    if errorLogOpenOnClose then hs.openConsole() end

    --------------------------------------------------------------------------------
    -- Setup Global Shutdown Callback:
    --------------------------------------------------------------------------------
    hs.shutdownCallback = function()
        local shutdownCallbacks = config.shutdownCallback:getAll()
        if shutdownCallbacks and type(shutdownCallbacks) == "table" then
            for _, v in pairs(shutdownCallbacks) do
                local fn = v:callbackFn()
                if fn and type(fn) == "function" then
                    fn()
                end
            end
        end
    end

    --------------------------------------------------------------------------------
    -- Setup Global Text Dropped to Dock Icon Callback:
    --------------------------------------------------------------------------------
    hs.textDroppedToDockIconCallback = function(value)
        local textDroppedToDockIconCallbacks = config.textDroppedToDockIconCallback:getAll()
        if textDroppedToDockIconCallbacks and type(textDroppedToDockIconCallbacks) == "table" then
            for _, v in pairs(textDroppedToDockIconCallbacks) do
                local fn = v:callbackFn()
                if fn and type(fn) == "function" then
                    fn(value)
                end
            end
        end
    end

    --------------------------------------------------------------------------------
    -- Setup Global File Dropped to Dock Icon Callback:
    --------------------------------------------------------------------------------
    hs.fileDroppedToDockIconCallback = function(value)
        local fileDroppedToDockIconCallbacks = config.fileDroppedToDockIconCallback:getAll()
        if fileDroppedToDockIconCallbacks and type(fileDroppedToDockIconCallbacks) == "table" then
            for _, v in pairs(fileDroppedToDockIconCallbacks) do
                local fn = v:callbackFn()
                if fn and type(fn) == "function" then
                    fn(value)
                end
            end
        end
    end

    --------------------------------------------------------------------------------
    -- Setup Global Dock Icon Click Callback:
    --------------------------------------------------------------------------------
    hs.dockIconClickCallback = function(value)
        local dockIconClickCallbacks = config.dockIconClickCallback:getAll()
        if dockIconClickCallbacks and type(dockIconClickCallbacks) == "table" then
            for _, v in pairs(dockIconClickCallbacks) do
                local fn = v:callbackFn()
                if fn and type(fn) == "function" then
                    fn(value)
                end
            end
        end
    end

    --------------------------------------------------------------------------------
    -- Create CommandPost Shutdown Callback:
    --------------------------------------------------------------------------------
    hs.shuttingDown = false
    config.shutdownCallback:new("cp", function()
        hs.shuttingDown = true
        if console.hswindow() then
            config.set("errorLogOpenOnClose", true)
        else
            config.set("errorLogOpenOnClose", false)
        end
        console.clearConsole()
    end)

    --------------------------------------------------------------------------------
    -- Enable "Launch at Startup" by default:
    --------------------------------------------------------------------------------
    if not config.get("hasRunOnce", false) then
        --------------------------------------------------------------------------------
        -- Enable Automatic Launch by default:
        --------------------------------------------------------------------------------
        hs.autoLaunch(true)

        --------------------------------------------------------------------------------
        -- Set Log Level to Verbose for Debugging:
        --------------------------------------------------------------------------------
        settings.set("hs._asm.axuielement.logLevel", "verbose")

        --------------------------------------------------------------------------------
        -- Don't do this again unless you trash preferences:
        --------------------------------------------------------------------------------
        config.set("hasRunOnce", true)
    end

    --------------------------------------------------------------------------------
    -- Check Versions & Language:
    --------------------------------------------------------------------------------
    local fcpVersion            = fcp:version() or "Unknown"
    local fcpPath               = fcp:getPath() or "Unknown"
    local osVersion             = tools.macOSVersion() or "Unknown"
    local fcpLocale             = fcp:currentLocale()
    local fcpLanguage           = fcpLocale and fcpLocale.code or "Unknown"

    --------------------------------------------------------------------------------
    -- Clear The Console:
    --------------------------------------------------------------------------------
    local consoleLoadingContent = console.getConsole()
    console.clearConsole()

    --------------------------------------------------------------------------------
    -- Display Welcome Message In The Console:
    --------------------------------------------------------------------------------
    console.printStyledtext(styledtext.new(config.appName .. " v" .. config.appVersion, {
        color = {hex = "#999999", alpha = 1},
        font = { name = "Helvetica", size = 18 },
    }))

    --------------------------------------------------------------------------------
    -- Write To Console For Debug Messages:
    --------------------------------------------------------------------------------
    local writeToConsoleDebug = function(value)
        console.printStyledtext(styledtext.new(value, {
            color = {hex = "#999999", alpha = 1},
            font = { name = "Menlo", size = 12 },
        }))
    end

    --------------------------------------------------------------------------------
    -- Display Useful Debugging Information in Console:
    --------------------------------------------------------------------------------
    console.printStyledtext("")
                                                writeToConsoleDebug("Date Built:                     " .. hs.processInfo.buildTime)
    if osVersion ~= nil then                    writeToConsoleDebug("macOS Version:                  " .. tostring(osVersion),                   true) end
                                                writeToConsoleDebug(config.appName .. " Locale:             " .. tostring(i18n.getLocale()),     true)
    if keycodes.currentLayout() ~= nil then     writeToConsoleDebug("Current Keyboard Layout:        " .. tostring(keycodes.currentLayout()),    true) end
    if fcpPath ~= nil then                      writeToConsoleDebug("Final Cut Pro Path:             " .. tostring(fcpPath),                     true) end
    if fcpVersion ~= nil then                   writeToConsoleDebug("Final Cut Pro Version:          " .. tostring(fcpVersion),                  true) end
    if fcpLanguage ~= nil then                  writeToConsoleDebug("Final Cut Pro Language:         " .. tostring(fcpLanguage),                 true) end
                                                writeToConsoleDebug("Developer Mode:                 " .. tostring(debugMode))
    console.printStyledtext("")

    --------------------------------------------------------------------------------
    -- Display the content that was displayed before loading...
    --------------------------------------------------------------------------------
    print(tools.trim(consoleLoadingContent))

    --------------------------------------------------------------------------------
    -- Setup Automatic Script Reloading:
    --------------------------------------------------------------------------------
    config.automaticScriptReloading:update()

    --------------------------------------------------------------------------------
    -- Global Variable to confirm CommandPost has successfully loaded:
    --------------------------------------------------------------------------------
    hs._cpLoaded = true

    --------------------------------------------------------------------------------
    -- Load Plugins:
    --------------------------------------------------------------------------------
    log.df("Loading Plugins...")
    plugins.init(config.pluginPaths)
    log.df("Plugins Loaded.")

    --------------------------------------------------------------------------------
    -- GARBAGE COLLECTOR PAUSE:
    --
    -- Garbage collector pause is used for controlling how long the garbage
    -- collector needs to wait, before; it is called again by the Lua's automatic
    -- memory management. Values less than 100 would mean that Lua will not wait for
    -- the next cycle. Similarly, higher values of this value would result in the
    -- garbage collector being slow and less aggressive in nature. A value of 200,
    -- means that the collector waits for the total memory in use to double before
    -- starting a new cycle. Hence, depending on the nature and speed of
    -- application, there may be a requirement to alter this value to get best
    -- performance in Lua applications.
    --------------------------------------------------------------------------------
    -- NOTE: Disabled by David due to causing constant pausing with Scrolling Timeline
    -- collectgarbage("setpause",100)

    --------------------------------------------------------------------------------
    -- GARBAGE COLLECTOR STEP MULTIPLIER:
    --
    -- This step multiplier controls the relative speed of garbage collector to
    -- that of memory allocation in Lua program. Larger step values will lead to
    -- garbage collector to be more aggressive and it also increases the step size
    -- of each incremental step of garbage collection. Values less than 100 could
    -- often lead to avoid the garbage collector not to complete its cycle and its
    -- not generally preferred. The default value is 200, which means the garbage
    -- collector runs twice as the speed of memory allocation.
    --------------------------------------------------------------------------------
    -- collectgarbage("setstepmul",200)

    --------------------------------------------------------------------------------
    -- Collect Garbage because we love a fresh slate:
    --------------------------------------------------------------------------------
    collectgarbage("collect")
    collectgarbage("collect")
    local afterRS = crash.residentSize()
    local afterGC = floor(collectgarbage("count")*1024)
    log.df("---------------------------------------------------------")
    log.df("GARBAGE COLLECTION STATS:")
    log.df("Process resident size: %s - %s = %s", beforeRS, afterRS, beforeRS-afterRS)
    log.df("Lua state size: %s - %s = %s", beforeGC, afterGC, beforeGC-afterGC)
    log.df("---------------------------------------------------------")

    --------------------------------------------------------------------------------
    -- Return the module:
    --------------------------------------------------------------------------------
    return mod
end

return mod.init()
