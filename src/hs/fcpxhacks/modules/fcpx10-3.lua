--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  			  ===========================================
--
--  			             F C P X    H A C K S
--
--			      ===========================================
--
--
--  Thrown together by Chris Hocking @ LateNite Films
--  https://latenitefilms.com
--
--  You can download the latest version here:
--  https://latenitefilms.com/blog/final-cut-pro-hacks/
--
--  Please be aware that I'm a filmmaker, not a programmer, so... apologies!
--
--------------------------------------------------------------------------------
--  LICENSE:
--------------------------------------------------------------------------------
--
-- The MIT License (MIT)
--
-- Copyright (c) 2016 Chris Hocking.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local mod = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   T H E    M A I N    S C R I P T                          --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- STANDARD EXTENSIONS:
--------------------------------------------------------------------------------

local alert										= require("hs.alert")
local application								= require("hs.application")
local chooser									= require("hs.chooser")
local console									= require("hs.console")
local distributednotifications					= require("hs.distributednotifications")
local drawing 									= require("hs.drawing")
local eventtap									= require("hs.eventtap")
local fnutils 									= require("hs.fnutils")
local fs										= require("hs.fs")
local geometry									= require("hs.geometry")
local host										= require("hs.host")
local hotkey									= require("hs.hotkey")
local http										= require("hs.http")
local image										= require("hs.image")
local keycodes									= require("hs.keycodes")
local menubar									= require("hs.menubar")
local mouse										= require("hs.mouse")
local notify									= require("hs.notify")
local osascript									= require("hs.osascript")
local pasteboard								= require("hs.pasteboard")
local pathwatcher								= require("hs.pathwatcher")
local screen									= require("hs.screen")
local settings									= require("hs.settings")
local sharing									= require("hs.sharing")
local timer										= require("hs.timer")
local window									= require("hs.window")
window.filter									= require("hs.window.filter")

--------------------------------------------------------------------------------
-- EXTERNAL EXTENSIONS:
--------------------------------------------------------------------------------

local ax 										= require("hs._asm.axuielement")
local touchbar 									= require("hs._asm.touchbar")

--------------------------------------------------------------------------------
-- INTERNAL EXTENSIONS:
--------------------------------------------------------------------------------

local fcp										= require("hs.finalcutpro")
local plist										= require("hs.plist")
local clipboard									= require("hs.fcpxhacks.modules.clipboard")
local dialog									= require("hs.fcpxhacks.modules.dialog")
local tools										= require("hs.fcpxhacks.modules.tools")

--------------------------------------------------------------------------------
-- CONSTANTS:
--------------------------------------------------------------------------------

mod.commonErrorMessageStart 					= "I'm sorry, but the following error has occurred:\n\n"
mod.commonErrorMessageEnd 						= "\n\nWould you like to email this bug to Chris so that he can try and come up with a fix?"
mod.commonErrorMessageAppleScript 				= 'set fcpxIcon to (((POSIX path of ((path to home folder as Unicode text) & ".hammerspoon:hs:fcpxhacks:assets:fcpxhacks.icns")) as Unicode text) as POSIX file)\n\nset commonErrorMessageStart to "' .. mod.commonErrorMessageStart .. '"\nset commonErrorMessageEnd to "' .. mod.commonErrorMessageEnd .. '"\n'

--------------------------------------------------------------------------------
-- VARIABLES:
--------------------------------------------------------------------------------

local execute									= hs.execute									-- Execute!
local touchBarSupported					 		= touchbar.supported()							-- Touch Bar Supported?

mod.debugMode									= false											-- Debug Mode is off by default.
mod.scrollingTimelineSpacebarPressed			= false											-- Was spacebar pressed?
mod.scrollingTimelineWatcherWorking 			= false											-- Is Scrolling Timeline Spacebar Held Down?
mod.isCommandEditorOpen 						= false 										-- Is Command Editor Open?
mod.releaseColorBoardDown						= false											-- Color Board Shortcut Currently Being Pressed
mod.releaseMouseColorBoardDown 					= false											-- Color Board Mouse Shortcut Currently Being Pressed
mod.mouseInsideTouchbar							= false											-- Mouse Inside Touch Bar?
mod.shownUpdateNotification		 				= false											-- Shown Update Notification Already?

mod.fcpxChooserActive							= false											-- Chooser Active?
mod.fcpxChooserChoices							= {}											-- Chooser Choices
mod.fcpxChooser									= nil											-- Chooser

mod.touchBarWindow 								= nil			 								-- Touch Bar Window

mod.browserHighlight 							= nil											-- Used for Highlight Browser Playhead
mod.browserHighlightTimer 						= nil											-- Used for Highlight Browser Playhead
mod.browserHighlight							= nil											-- Scrolling Timeline Timer

mod.scrollingTimelineTimer						= nil											-- Scrolling Timeline Timer
mod.scrollingTimelineScrollbarTimer				= nil											-- Scrolling Timeline Scrollbar Timer

mod.finalCutProShortcutKey 						= nil											-- Table of all Final Cut Pro Shortcuts
mod.finalCutProShortcutKeyPlaceholders 			= nil											-- Table of all needed Final Cut Pro Shortcuts
mod.newDeviceMounted 							= nil											-- New Device Mounted Volume Watcher
mod.lastCommandSet								= nil											-- Last Keyboard Shortcut Command Set
mod.FFImportCreateProxyMedia 					= nil											-- Used in refreshMenuBar
mod.allowMovingMarkers							= nil											-- Used in refreshMenuBar
mod.FFPeriodicBackupInterval 					= nil											-- Used in refreshMenuBar
mod.FFSuspendBGOpsDuringPlay 					= nil											-- Used in refreshMenuBar
mod.FFEnableGuards								= nil											-- Used in refreshMenuBar
mod.FFCreateOptimizedMediaForMulticamClips 		= nil											-- Used in refreshMenuBar
mod.FFAutoStartBGRender 						= nil											-- Used in refreshMenuBar
mod.FFAutoRenderDelay							= nil											-- Used in refreshMenuBar
mod.FFImportCopyToMediaFolder 					= nil											-- Used in refreshMenuBar
mod.FFImportCreateOptimizeMedia 				= nil											-- Used in refreshMenuBar

--------------------------------------------------------------------------------
-- LOAD SCRIPT:
--------------------------------------------------------------------------------
function loadScript()

	--------------------------------------------------------------------------------
	-- Debug Mode:
	--------------------------------------------------------------------------------
	mod.debugMode = settings.get("fcpxHacks.debugMode") or false
	debugMessage("Debug Mode Activated.")

	--------------------------------------------------------------------------------
	-- Need Accessibility Activated:
	--------------------------------------------------------------------------------
	hs.accessibilityState(true)

	--------------------------------------------------------------------------------
	-- Limit Error Messages for a clean console:
	--------------------------------------------------------------------------------
	console.titleVisibility("hidden")
	hotkey.setLogLevel("warning")
	window.filter.setLogLevel(1)
	window.filter.ignoreAlways['System Events'] = true

	--------------------------------------------------------------------------------
	-- First time running 10.3? Trash settings:
	--------------------------------------------------------------------------------
	if settings.get("fcpxHacks.firstTimeRunning103") == nil then

		writeToConsole("First time running Final Cut Pro 10.3.")

		--------------------------------------------------------------------------------
		-- Trash all FCPX Hacks Settings:
		--------------------------------------------------------------------------------
		for i, v in ipairs(settings.getKeys()) do
			if (v:sub(1,10)) == "fcpxHacks." then
				settings.set(v, nil)
			end
		end

		settings.set("fcpxHacks.firstTimeRunning103", false)

	end

	--------------------------------------------------------------------------------
	-- Set Up Default Settings:
	--------------------------------------------------------------------------------
	local defaultSettings = {
		["enableShortcutsDuringFullscreenPlayback"] 	= false,
		["scrollingTimelineActive"] 					= false,
		["enableHacksShortcutsInFinalCutPro"] 			= false,
		["chooserShowAutomation"] 						= true,
		["chooserShowShortcuts"] 						= true,
		["chooserShowHacks"] 							= true,
		["chooserShowVideoEffects"] 					= true,
		["chooserShowAudioEffects"] 					= true,
		["chooserShowTransitions"] 						= true,
		["chooserShowTitles"] 							= true,
		["chooserShowGenerators"] 						= true,
		["menubarShortcutsEnabled"] 					= true,
		["menubarAutomationEnabled"] 					= true,
		["menubarToolsEnabled"] 						= true,
		["menubarHacksEnabled"] 						= true,
		["enableCheckForUpdates"]						= true,
		["checkForUpdatesInterval"]						= 600,
	}
	for k, v in pairs(defaultSettings) do
		if settings.get("fcpxHacks." .. k) == nil then
			settings.set("fcpxHacks." .. k, v)
		end
	end

	--------------------------------------------------------------------------------
	-- Check if we need to update the Final Cut Pro Shortcut Files:
	--------------------------------------------------------------------------------
	if settings.get("fcpxHacks.lastVersion") == nil then
		settings.set("fcpxHacks.lastVersion", fcpxhacks.scriptVersion)
		settings.set("fcpxHacks.enableHacksShortcutsInFinalCutPro", false)
	else
		if tonumber(settings.get("fcpxHacks.lastVersion")) < tonumber(fcpxhacks.scriptVersion) then
			if settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro") then
				local finalCutProRunning = fcp.running()
				if finalCutProRunning then
					dialog.displayMessage("This latest version of FCPX Hacks may contain new keyboard shortcuts.\n\nFor these shortcuts to appear in the Final Cut Pro Command Editor, we'll need to update the shortcut files.\n\nYou will need to enter your Administrator password and restart Final Cut Pro.")
					updateKeyboardShortcuts()
					if not fcp.restart() then
						--------------------------------------------------------------------------------
						-- Failed to restart Final Cut Pro:
						--------------------------------------------------------------------------------
						dialog.displayErrorMessage("Failed to restart Final Cut Pro. You will need to restart manually.")
						return "Failed"
					end
				else
					dialog.displayMessage("This latest version of FCPX Hacks may contain new keyboard shortcuts.\n\nFor these shortcuts to appear in the Final Cut Pro Command Editor, we'll need to update the shortcut files.\n\nYou will need to enter your Administrator password.")
					updateKeyboardShortcuts()
				end
			end
		end
		settings.set("fcpxHacks.lastVersion", fcpxhacks.scriptVersion)
	end

	--------------------------------------------------------------------------------
	-- Setup Touch Bar:
	--------------------------------------------------------------------------------
	if touchBarSupported then

		--------------------------------------------------------------------------------
		-- New Touch Bar:
		--------------------------------------------------------------------------------
		mod.touchBarWindow = touchbar.new()

		--------------------------------------------------------------------------------
		-- Touch Bar Watcher:
		--------------------------------------------------------------------------------
		mod.touchBarWindow:setCallback(touchbarWatcher)

		--------------------------------------------------------------------------------
		-- Get last Touch Bar Location from Settings:
		--------------------------------------------------------------------------------
		local lastTouchBarLocation = settings.get("fcpxHacks.lastTouchBarLocation")
		if lastTouchBarLocation ~= nil then	mod.touchBarWindow:topLeft(lastTouchBarLocation) end

		--------------------------------------------------------------------------------
		-- Draggable Touch Bar:
		--------------------------------------------------------------------------------
		local events = eventtap.event.types
		touchbarKeyboardWatcher = eventtap.new({events.flagsChanged, events.keyDown, events.leftMouseDown}, function(ev)
			if mod.mouseInsideTouchbar then
				if ev:getType() == events.flagsChanged and ev:getRawEventData().CGEventData.flags == 524576 then
					mod.touchBarWindow:backgroundColor{ red = 1 }
								  	:movable(true)
								  	:acceptsMouseEvents(false)
				elseif ev:getType() ~= events.leftMouseDown then
					mod.touchBarWindow:backgroundColor{ white = 0 }
								  :movable(false)
								  :acceptsMouseEvents(true)
					settings.set("fcpxHacks.lastTouchBarLocation", mod.touchBarWindow:topLeft())
				end
			end
			return false
		end):start()

	end

	--------------------------------------------------------------------------------
	-- Setup Watches:
	--------------------------------------------------------------------------------

		--------------------------------------------------------------------------------
		-- Create and start the application event watcher:
		--------------------------------------------------------------------------------
		watcher = application.watcher.new(finalCutProWatcher):start()

		--------------------------------------------------------------------------------
		-- Watch For Hammerspoon Script Updates:
		--------------------------------------------------------------------------------
		hammerspoonWatcher = pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hammerspoonConfigWatcher):start()

		--------------------------------------------------------------------------------
		-- Watch for Final Cut Pro plist Changes:
		--------------------------------------------------------------------------------
		preferencesWatcher = pathwatcher.new("~/Library/Preferences/", finalCutProSettingsWatcher):start()

		--------------------------------------------------------------------------------
		-- Watch for Shared Clipboard Changes:
		--------------------------------------------------------------------------------
		local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
		if sharedClipboardPath ~= nil then
			if tools.doesDirectoryExist(sharedClipboardPath) then
				sharedClipboardWatcher = pathwatcher.new(sharedClipboardPath, sharedClipboardFileWatcher):start()
			else
				writeToConsole("The Shared Clipboard Directory could not be found, so disabling.")
				settings.set("fcpxHacks.sharedClipboardPath", nil)
				settings.set("fcpxHacks.enableSharedClipboard", false)
			end
		end

		--------------------------------------------------------------------------------
		-- Watch for Shared XML Changes:
		--------------------------------------------------------------------------------
		local enableXMLSharing = settings.get("fcpxHacks.enableXMLSharing") or false
		if enableXMLSharing then
			local xmlSharingDropboxPath = settings.get("fcpxHacks.xmlSharingDropboxPath")
			local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
			if xmlSharingDropboxPath ~= nil and xmlSharingPath ~= nil then
				if tools.doesDirectoryExist(xmlSharingDropboxPath) and tools.doesDirectoryExist(xmlSharingPath) then
					xmlDropboxWatcher = pathwatcher.new(xmlSharingDropboxPath, xmlDropboxFileWatcher):start()
					sharedXMLWatcher = pathwatcher.new(xmlSharingPath, sharedXMLFileWatcher):start()
				else
					writeToConsole("The Shared XML Folder(s) could not be found, so disabling.")
					settings.set("fcpxHacks.xmlSharingPath", nil)
					settings.set("fcpxHacks.xmlSharingDropboxPath", nil)
					settings.set("fcpxHacks.enableXMLSharing", false)
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Full Screen Keyboard Watcher:
		--------------------------------------------------------------------------------
		fullscreenKeyboardWatcher()

		--------------------------------------------------------------------------------
		-- Command Editor Watcher:
		--------------------------------------------------------------------------------
		commandEditorWatcher()

		--------------------------------------------------------------------------------
		-- Scrolling Timeline Watcher:
		--------------------------------------------------------------------------------
		scrollingTimelineWatcher()

		--------------------------------------------------------------------------------
		-- Clipboard Watcher:
		--------------------------------------------------------------------------------
		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false
		if enableClipboardHistory then clipboard.startWatching() end

		--------------------------------------------------------------------------------
		-- Notification Watcher:
		--------------------------------------------------------------------------------
		local enableMobileNotifications = settings.get("fcpxHacks.enableMobileNotifications") or false
		if enableMobileNotifications then notificationWatcher() end

		--------------------------------------------------------------------------------
		-- Media Import Watcher:
		--------------------------------------------------------------------------------
		local enableMediaImportWatcher = settings.get("fcpxHacks.enableMediaImportWatcher") or false
		if enableMediaImportWatcher then mediaImportWatcher() end

		--------------------------------------------------------------------------------
		-- Resize Watcher:
		--------------------------------------------------------------------------------
		finalCutProResizeWatcher()

	--------------------------------------------------------------------------------
	-- Bind Keyboard Shortcuts:
	--------------------------------------------------------------------------------
	mod.lastCommandSet = fcp.getActiveCommandSetPath()
	bindKeyboardShortcuts()

	--------------------------------------------------------------------------------
	-- Activate the correct modal state:
	--------------------------------------------------------------------------------
	if fcp.frontmost() then

		--------------------------------------------------------------------------------
		-- Enable Final Cut Pro Shortcut Keys:
		--------------------------------------------------------------------------------
		hotkeys:enter()

		--------------------------------------------------------------------------------
		-- Enable Fullscreen Playback Shortcut Keys:
		--------------------------------------------------------------------------------
		if settings.get("fcpxHacks.enableShortcutsDuringFullscreenPlayback") then
			fullscreenKeyboardWatcherUp:start()
			fullscreenKeyboardWatcherDown:start()
		end

		--------------------------------------------------------------------------------
		-- Enable Scrolling Timeline:
		--------------------------------------------------------------------------------
		if settings.get("fcpxHacks.scrollingTimelineActive") then
			scrollingTimelineWatcherUp:start()
			scrollingTimelineWatcherDown:start()
		end

	else

		--------------------------------------------------------------------------------
		-- Disable Final Cut Pro Shortcut Keys:
		--------------------------------------------------------------------------------
		hotkeys:exit()

		--------------------------------------------------------------------------------
		-- Disable Fullscreen Playback Shortcut Keys:
		--------------------------------------------------------------------------------
		if fullscreenKeyboardWatcherUp ~= nil then
			fullscreenKeyboardWatcherUp:stop()
			fullscreenKeyboardWatcherDown:stop()
		end

		--------------------------------------------------------------------------------
		-- Disable Scrolling Timeline:
		--------------------------------------------------------------------------------
		if scrollingTimelineWatcherUp ~= nil then
			scrollingTimelineWatcherUp:stop()
			scrollingTimelineWatcherDown:stop()
		end

	end

	-------------------------------------------------------------------------------
	-- Set up Menubar:
	--------------------------------------------------------------------------------
	fcpxMenubar = menubar.newWithPriority(1)

		--------------------------------------------------------------------------------
		-- Set Tool Tip:
		--------------------------------------------------------------------------------
		fcpxMenubar:setTooltip("FCPX Hacks Version " .. fcpxhacks.scriptVersion)

		--------------------------------------------------------------------------------
		-- Work out Menubar Display Mode:
		--------------------------------------------------------------------------------
		updateMenubarIcon()

		--------------------------------------------------------------------------------
		-- Populate the Menubar for the first time:
		--------------------------------------------------------------------------------
		refreshMenuBar(true)

	-------------------------------------------------------------------------------
	-- Set up Chooser:
	-------------------------------------------------------------------------------
	setupChooser()

	--------------------------------------------------------------------------------
	-- All loaded!
	--------------------------------------------------------------------------------
	writeToConsole("Successfully loaded.")
	alert.closeAll(0)
	alert.show("FCPX Hacks (v" .. fcpxhacks.scriptVersion .. ") has loaded")

	--------------------------------------------------------------------------------
	-- Check for Script Updates:
	--------------------------------------------------------------------------------
	local checkForUpdatesInterval = settings.get("fcpxHacks.checkForUpdatesInterval")
	checkForUpdatesTimer = timer.doEvery(checkForUpdatesInterval, checkForUpdates)
	checkForUpdatesTimer:fire()

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   D E V E L O P M E N T      T O O L S                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- TESTING GROUND (CONTROL + OPTION + COMMAND + Q):
--------------------------------------------------------------------------------
function testingGround()

	--------------------------------------------------------------------------------
	-- Clear Console:
	--------------------------------------------------------------------------------
	--console.clearConsole()

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                    K E Y B O A R D     S H O R T C U T S                   --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- BIND KEYBOARD SHORTCUTS:
--------------------------------------------------------------------------------
function bindKeyboardShortcuts()

	--------------------------------------------------------------------------------
	-- Get Enable Hacks Shortcuts in Final Cut Pro from Settings:
	--------------------------------------------------------------------------------
	local enableHacksShortcutsInFinalCutPro = settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro")
	if enableHacksShortcutsInFinalCutPro == nil then enableHacksShortcutsInFinalCutPro = false end

	--------------------------------------------------------------------------------
	-- Table of built-in FCPX Shortcuts we'll use for various things:
	--------------------------------------------------------------------------------
	local requiredBuiltInShortcuts = {
			["ColorBoard-NudgePuckUp"]									= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["ColorBoard-NudgePuckDown"]								= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["ColorBoard-NudgePuckLeft"]								= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["ColorBoard-NudgePuckRight"]								= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["SetSelectionStart"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["SetSelectionEnd"]											= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["AnchorWithSelectedMedia"]									= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["AnchorWithSelectedMediaBacktimed"]						= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["InsertMedia"]												= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["AppendWithSelectedMedia"]									= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["ToggleEventLibraryBrowser"]								= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["PlayFullscreen"]											= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["ShowTimecodeEntryPlayhead"]								= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["ShareDefaultDestination"]									= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["Paste"]													= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["ToggleKeywordEditor"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["Cut"]														= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["MultiAngleEditStyleAudio"]								= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["MultiAngleEditStyleAudioVideo"]							= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["MultiAngleEditStyleVideo"]								= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle01"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle02"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle03"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle04"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle05"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle06"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle07"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle08"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle09"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle10"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle11"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle12"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle13"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle14"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle15"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["CutSwitchAngle16"]										= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["IncreaseThumbnailSize"]									= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
			["DecreaseThumbnailSize"]									= { characterString = "", modifiers = {}, fn = nil, releasedFn = nil, repeatFn = nil },
	}

	if enableHacksShortcutsInFinalCutPro then
		--------------------------------------------------------------------------------
		-- Get Shortcut Keys from plist:
		--------------------------------------------------------------------------------
		mod.finalCutProShortcutKey = nil
		mod.finalCutProShortcutKey = {}
		mod.finalCutProShortcutKeyPlaceholders = nil
		mod.finalCutProShortcutKeyPlaceholders =
		{
			FCPXHackLaunchFinalCutPro									= { characterString = "", 							modifiers = {}, 									fn = function() fcp.launch() end, 							releasedFn = nil, 														repeatFn = nil, 		global = true },
			FCPXHackShowListOfShortcutKeys 								= { characterString = "", 							modifiers = {}, 									fn = function() displayShortcutList() end, 							releasedFn = nil, 														repeatFn = nil, 		global = true },

			FCPXHackHighlightBrowserPlayhead 							= { characterString = "", 							modifiers = {}, 									fn = function() highlightFCPXBrowserPlayhead() end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackRevealInBrowserAndHighlight 						= { characterString = "", 							modifiers = {}, 									fn = function() matchFrameThenHighlightFCPXBrowserPlayhead() end, 	releasedFn = nil, 														repeatFn = nil },

			FCPXHackSingleMatchFrameAndHighlight 						= { characterString = "", 							modifiers = {}, 									fn = function() singleMatchFrame() end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackRevealMulticamClipInBrowserAndHighlight 			= { characterString = "", 							modifiers = {}, 									fn = function() multicamMatchFrame(true) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackRevealMulticamClipInAngleEditorAndHighlight 		= { characterString = "", 							modifiers = {}, 									fn = function() multicamMatchFrame(false) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackBatchExportFromBrowser 								= { characterString = "", 							modifiers = {}, 									fn = function() batchExportToCompressor() end, 						releasedFn = nil, 														repeatFn = nil },

			FCPXHackChangeBackupInterval 								= { characterString = "", 							modifiers = {}, 									fn = function() changeBackupInterval() end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackToggleTimecodeOverlays 								= { characterString = "", 							modifiers = {}, 									fn = function() toggleTimecodeOverlay() end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackToggleMovingMarkers 								= { characterString = "", 							modifiers = {}, 									fn = function() toggleMovingMarkers() end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackAllowTasksDuringPlayback 							= { characterString = "", 							modifiers = {}, 									fn = function() togglePerformTasksDuringPlayback() end, 			releasedFn = nil, 														repeatFn = nil },

			FCPXHackSelectColorBoardPuckOne 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectColorBoardPuckTwo 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectColorBoardPuckThree 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectColorBoardPuckFour 							= { characterString = "", 							modifiers = {},									 	fn = function() colorBoardSelectPuck(4) end, 						releasedFn = nil, 														repeatFn = nil },

			FCPXHackRestoreKeywordPresetOne 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetTwo 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetThree 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetFour 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(4) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetFive 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(5) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetSix 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(6) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetSeven 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(7) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetEight 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(8) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetNine 							= { characterString = "", 							modifiers = {}, 									fn = function() restoreKeywordSearches(9) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackSaveKeywordPresetOne 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetTwo 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetThree 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetFour 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(4) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetFive 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(5) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetSix 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(6) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetSeven 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(7) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetEight 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(8) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetNine 								= { characterString = "", 							modifiers = {}, 									fn = function() saveKeywordSearches(9) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackEffectsOne			 								= { characterString = "", 							modifiers = {}, 									fn = function() effectsShortcut(1) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsTwo			 								= { characterString = "", 							modifiers = {}, 									fn = function() effectsShortcut(2) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsThree			 							= { characterString = "", 							modifiers = {}, 									fn = function() effectsShortcut(3) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsFour			 								= { characterString = "", 							modifiers = {}, 									fn = function() effectsShortcut(4) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsFive			 								= { characterString = "", 							modifiers = {}, 									fn = function() effectsShortcut(5) end, 							releasedFn = nil, 														repeatFn = nil },

			FCPXHackTransitionsOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(1) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(2) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsThree			 						= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(3) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsFour			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(4) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsFive			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(5) end, 						releasedFn = nil, 														repeatFn = nil },

			FCPXHackTitlesOne			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(1) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesTwo			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(2) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesThree			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(3) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesFour			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(4) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesFive			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(5) end, 								releasedFn = nil, 														repeatFn = nil },

			FCPXHackGeneratorsOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(1) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(2) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsThree			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(3) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsFour			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(4) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsFive			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(5) end, 							releasedFn = nil, 														repeatFn = nil },

			FCPXHackScrollingTimeline	 								= { characterString = "", 							modifiers = {}, 									fn = function() toggleScrollingTimeline() end, 						releasedFn = nil, 														repeatFn = nil },

			FCPXHackColorPuckOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackColorPuckTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackColorPuckThree			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackColorPuckFour			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackSaturationPuckOne			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaturationPuckTwo			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaturationPuckThree			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaturationPuckFour			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 2) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackExposurePuckOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackExposurePuckTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackExposurePuckThree			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackExposurePuckFour			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 3) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackColorPuckOneUp			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoUp			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeUp		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourUp		 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackColorPuckOneDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourDown	 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackColorPuckOneLeft		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoLeft		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeLeft		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourLeft	 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackColorPuckOneRight		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoRight		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeRight		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourRight	 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackSaturationPuckOneUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckTwoUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckThreeUp		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckFourUp		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackSaturationPuckOneDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckTwoDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckThreeDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckFourDown	 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackExposurePuckOneUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckTwoUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckThreeUp		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckFourUp		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackExposurePuckOneDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckTwoDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckThreeDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckFourDown	 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackChangeTimelineClipHeightUp 							= { characterString = "", 							modifiers = {}, 									fn = function() changeTimelineClipHeight("up") end, 				releasedFn = function() changeTimelineClipHeightRelease() end, 			repeatFn = nil },
			FCPXHackChangeTimelineClipHeightDown						= { characterString = "", 							modifiers = {}, 									fn = function() changeTimelineClipHeight("down") end, 				releasedFn = function() changeTimelineClipHeightRelease() end, 			repeatFn = nil },

			FCPXHackCreateOptimizedMediaOn								= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateOptimizedMedia(true) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateOptimizedMediaOff								= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateOptimizedMedia(false) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateMulticamOptimizedMediaOn						= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateMulticamOptimizedMedia(true) end, 		releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateMulticamOptimizedMediaOff						= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateMulticamOptimizedMedia(false) end, 		releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateProxyMediaOn									= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateProxyMedia(true) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateProxyMediaOff									= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateProxyMedia(false) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackLeaveInPlaceOn										= { characterString = "", 							modifiers = {}, 									fn = function() toggleLeaveInPlace(true) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackLeaveInPlaceOff										= { characterString = "", 							modifiers = {}, 									fn = function() toggleLeaveInPlace(false) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackBackgroundRenderOn									= { characterString = "", 							modifiers = {}, 									fn = function() toggleBackgroundRender(true) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackBackgroundRenderOff									= { characterString = "", 							modifiers = {}, 									fn = function() toggleBackgroundRender(false) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackChangeSmartCollectionsLabel							= { characterString = "", 							modifiers = {}, 									fn = function() changeSmartCollectionsLabel() end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackSelectClipAtLaneOne									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(1) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneTwo									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(2) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneThree								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(3) end,							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneFour								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(4) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneFive								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(5) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneSix									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(6) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneSeven								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(7) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneEight								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(8) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneNine								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(9) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneTen									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(10) end, 							releasedFn = nil, 														repeatFn = nil },

			FCPXHackColorPuckOneMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(1, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(2, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(3, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(4, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },

			FCPXHackSaturationPuckOneMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(1, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckTwoMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(2, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckThreeMouse							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(3, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckFourMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(4, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },

			FCPXHackExposurePuckOneMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(1, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckTwoMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(2, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckThreeMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(3, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckFourMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(4, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },

			FCPXHackMoveToPlayhead										= { characterString = "", 							modifiers = {}, 									fn = function() moveToPlayhead() end, 								releasedFn = nil, 														repeatFn = nil },

			FCPXHackCutSwitchAngle01Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 1) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle02Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 2) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle03Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 3) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle04Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 4) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle05Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 5) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle06Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 6) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle07Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 7) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle08Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 8) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle09Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 9) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle10Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 10) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle11Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 11) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle12Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 12) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle13Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 13) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle14Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 14) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle15Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 15) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle16Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 16) end, 				releasedFn = nil, 														repeatFn = nil },

			FCPXHackCutSwitchAngle01Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 1) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle02Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 2) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle03Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 3) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle04Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 4) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle05Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 5) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle06Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 6) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle07Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 7) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle08Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 8) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle09Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 9) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle10Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 10) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle11Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 11) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle12Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 12) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle13Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 13) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle14Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 14) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle15Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 15) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle16Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 16) end, 				releasedFn = nil, 														repeatFn = nil },

			FCPXHackCutSwitchAngle01Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 1) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle02Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 2) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle03Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 3) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle04Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 4) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle05Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 5) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle06Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 6) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle07Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 7) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle08Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 8) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle09Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 9) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle10Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 10) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle11Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 11) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle12Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 12) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle13Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 13) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle14Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 14) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle15Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 15) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle16Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 16) end, 				releasedFn = nil, 														repeatFn = nil },

			FCPXHackConsole				 								= { characterString = "", 							modifiers = {}, 									fn = function() showChooser() end, 									releasedFn = nil, 														repeatFn = nil },

			FCPXHackToggleTouchBar				 						= { characterString = keyCodeTranslator("z"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() toggleTouchBar() end, 								releasedFn = nil, 														repeatFn = nil },
		}

		--------------------------------------------------------------------------------
		-- Merge Above Table with Built-in Final Cut Pro Shortcuts Table:
		--------------------------------------------------------------------------------
		for k, v in pairs(requiredBuiltInShortcuts) do
			mod.finalCutProShortcutKeyPlaceholders[k] = requiredBuiltInShortcuts[k]
		end

		if getShortcutsFromActiveCommandSet() ~= true then
			dialog.displayMessage("Something went wrong when we were reading your custom keyboard shortcuts. As a fail-safe, we are going back to use using the default keyboard shortcuts, sorry!")
			writeToConsole("ERROR: Something went wrong during the plist reading process. Falling back to default shortcut keys.")
			enableHacksShortcutsInFinalCutPro = false
		end
	end

	if not enableHacksShortcutsInFinalCutPro then
		--------------------------------------------------------------------------------
		-- Use Default Shortcuts Keys:
		--------------------------------------------------------------------------------
		mod.finalCutProShortcutKey = nil
		mod.finalCutProShortcutKey =
		{
			FCPXHackLaunchFinalCutPro									= { characterString = keyCodeTranslator("l"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() fcp.launch() end, 				 			releasedFn = nil,														repeatFn = nil, 		global = true },
			FCPXHackShowListOfShortcutKeys 								= { characterString = keyCodeTranslator("f1"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() displayShortcutList() end, 							releasedFn = nil, 														repeatFn = nil, 		global = true },

			FCPXHackHighlightBrowserPlayhead 							= { characterString = keyCodeTranslator("h"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() highlightFCPXBrowserPlayhead() end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackRevealInBrowserAndHighlight 						= { characterString = keyCodeTranslator("f"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() matchFrameThenHighlightFCPXBrowserPlayhead() end, 	releasedFn = nil, 														repeatFn = nil },
			FCPXHackSingleMatchFrameAndHighlight 						= { characterString = keyCodeTranslator("s"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() singleMatchFrame() end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackRevealMulticamClipInBrowserAndHighlight 			= { characterString = keyCodeTranslator("d"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() multicamMatchFrame(true) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackRevealMulticamClipInAngleEditorAndHighlight 		= { characterString = keyCodeTranslator("g"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() multicamMatchFrame(false) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackBatchExportFromBrowser 								= { characterString = keyCodeTranslator("e"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() batchExportToCompressor() end, 						releasedFn = nil,														repeatFn = nil },
			FCPXHackChangeBackupInterval 								= { characterString = keyCodeTranslator("b"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() changeBackupInterval() end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackToggleTimecodeOverlays 								= { characterString = keyCodeTranslator("t"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() toggleTimecodeOverlay() end,						releasedFn = nil, 														repeatFn = nil },
			FCPXHackToggleMovingMarkers 								= { characterString = keyCodeTranslator("y"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() toggleMovingMarkers() end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackAllowTasksDuringPlayback 							= { characterString = keyCodeTranslator("p"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() togglePerformTasksDuringPlayback() end, 			releasedFn = nil, 														repeatFn = nil },

			FCPXHackSelectColorBoardPuckOne 							= { characterString = keyCodeTranslator("m"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() colorBoardSelectPuck(1) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectColorBoardPuckTwo 							= { characterString = keyCodeTranslator(","), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() colorBoardSelectPuck(2) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectColorBoardPuckThree 							= { characterString = keyCodeTranslator("."), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() colorBoardSelectPuck(3) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectColorBoardPuckFour 							= { characterString = keyCodeTranslator("/"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() colorBoardSelectPuck(4) end, 						releasedFn = nil, 														repeatFn = nil },

			FCPXHackRestoreKeywordPresetOne 							= { characterString = keyCodeTranslator("1"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetTwo 							= { characterString = keyCodeTranslator("2"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetThree 							= { characterString = keyCodeTranslator("3"),		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetFour 							= { characterString = keyCodeTranslator("4"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(4) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetFive 							= { characterString = keyCodeTranslator("5"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(5) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetSix 							= { characterString = keyCodeTranslator("6"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(6) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetSeven 							= { characterString = keyCodeTranslator("7"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(7) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetEight 							= { characterString = keyCodeTranslator("8"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(8) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackRestoreKeywordPresetNine 							= { characterString = keyCodeTranslator("9"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() restoreKeywordSearches(9) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackSaveKeywordPresetOne 								= { characterString = keyCodeTranslator("1"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetTwo 								= { characterString = keyCodeTranslator("2"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(2) end,						releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetThree 								= { characterString = keyCodeTranslator("3"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetFour 								= { characterString = keyCodeTranslator("4"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(4) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetFive 								= { characterString = keyCodeTranslator("5"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(5) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetSix 								= { characterString = keyCodeTranslator("6"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(6) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetSeven 								= { characterString = keyCodeTranslator("7"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(7) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetEight 								= { characterString = keyCodeTranslator("8"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(8) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaveKeywordPresetNine 								= { characterString = keyCodeTranslator("9"), 		modifiers = {"ctrl", "option", "command", "shift"}, fn = function() saveKeywordSearches(9) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackEffectsOne			 								= { characterString = keyCodeTranslator("1"), 		modifiers = {"ctrl", "shift"}, 						fn = function() effectsShortcut(1) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsTwo			 								= { characterString = keyCodeTranslator("2"), 		modifiers = {"ctrl", "shift"}, 						fn = function() effectsShortcut(2) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsThree			 							= { characterString = keyCodeTranslator("3"), 		modifiers = {"ctrl", "shift"}, 						fn = function() effectsShortcut(3) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsFour			 								= { characterString = keyCodeTranslator("4"), 		modifiers = {"ctrl", "shift"}, 						fn = function() effectsShortcut(4) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackEffectsFive			 								= { characterString = keyCodeTranslator("5"), 		modifiers = {"ctrl", "shift"}, 						fn = function() effectsShortcut(5) end, 							releasedFn = nil, 														repeatFn = nil },

			FCPXHackTransitionsOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(1) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(2) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsThree			 						= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(3) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsFour			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(4) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackTransitionsFive			 							= { characterString = "", 							modifiers = {}, 									fn = function() transitionsShortcut(5) end, 						releasedFn = nil, 														repeatFn = nil },

			FCPXHackTitlesOne			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(1) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesTwo			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(2) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesThree			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(3) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesFour			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(4) end, 								releasedFn = nil, 														repeatFn = nil },
			FCPXHackTitlesFive			 								= { characterString = "", 							modifiers = {}, 									fn = function() titlesShortcut(5) end, 								releasedFn = nil, 														repeatFn = nil },

			FCPXHackGeneratorsOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(1) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(2) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsThree			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(3) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsFour			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(4) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackGeneratorsFive			 							= { characterString = "", 							modifiers = {}, 									fn = function() generatorsShortcut(5) end, 							releasedFn = nil, 														repeatFn = nil },

			FCPXHackScrollingTimeline	 								= { characterString = keyCodeTranslator("w"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() toggleScrollingTimeline() end, 						releasedFn = nil, 														repeatFn = nil },

			FCPXHackColorPuckOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackColorPuckTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackColorPuckThree			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackColorPuckFour			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackSaturationPuckOne			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaturationPuckTwo			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaturationPuckThree			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 2) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackSaturationPuckFour			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 2) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackExposurePuckOne			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackExposurePuckTwo			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackExposurePuckThree			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 3) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackExposurePuckFour			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 3) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackColorPuckOneUp			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoUp			 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeUp		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourUp		 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackColorPuckOneDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourDown	 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackColorPuckOneLeft		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoLeft		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeLeft		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourLeft	 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "left") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackColorPuckOneRight		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoRight		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeRight		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourRight	 								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 1, "right") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackSaturationPuckOneUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckTwoUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckThreeUp		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckFourUp		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 2, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackSaturationPuckOneDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckTwoDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckThreeDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckFourDown	 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 2, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackExposurePuckOneUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckTwoUp			 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckThreeUp		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckFourUp		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 3, "up") end, 				releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackExposurePuckOneDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(1, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckTwoDown		 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(2, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckThreeDown		 						= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(3, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckFourDown	 							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardSelectPuck(4, 3, "down") end, 			releasedFn = function() colorBoardSelectPuckRelease() end, 				repeatFn = nil },

			FCPXHackChangeTimelineClipHeightUp 							= { characterString = keyCodeTranslator("="),		modifiers = {"ctrl", "option", "command"}, 			fn = function() changeTimelineClipHeight("up") end, 						releasedFn = function() writeToConsole("release") end, 					repeatFn = function() changeTimelineClipHeightRepeat("up") end },
			FCPXHackChangeTimelineClipHeightDown						= { characterString = keyCodeTranslator("-"),		modifiers = {"ctrl", "option", "command"}, 			fn = function() changeTimelineClipHeight("down") end, 						releasedFn = function() writeToConsole("release") end, 					repeatFn = function() changeTimelineClipHeightRepeat("down") end },

			FCPXHackCreateOptimizedMediaOn								= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateOptimizedMedia(true) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateOptimizedMediaOff								= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateOptimizedMedia(false) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateMulticamOptimizedMediaOn						= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateMulticamOptimizedMedia(true) end, 		releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateMulticamOptimizedMediaOff						= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateMulticamOptimizedMedia(false) end, 		releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateProxyMediaOn									= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateProxyMedia(true) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackCreateProxyMediaOff									= { characterString = "", 							modifiers = {}, 									fn = function() toggleCreateProxyMedia(false) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackLeaveInPlaceOn										= { characterString = "", 							modifiers = {}, 									fn = function() toggleLeaveInPlace(true) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackLeaveInPlaceOff										= { characterString = "", 							modifiers = {}, 									fn = function() toggleLeaveInPlace(false) end, 						releasedFn = nil, 														repeatFn = nil },
			FCPXHackBackgroundRenderOn									= { characterString = "", 							modifiers = {}, 									fn = function() toggleBackgroundRender(true) end, 					releasedFn = nil, 														repeatFn = nil },
			FCPXHackBackgroundRenderOff									= { characterString = "", 							modifiers = {}, 									fn = function() toggleBackgroundRender(false) end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackChangeSmartCollectionsLabel							= { characterString = "", 							modifiers = {}, 									fn = function() changeSmartCollectionsLabel() end, 					releasedFn = nil, 														repeatFn = nil },

			FCPXHackSelectClipAtLaneOne									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(1) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneTwo									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(2) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneThree								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(3) end,							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneFour								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(4) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneFive								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(5) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneSix									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(6) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneSeven								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(7) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneEight								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(8) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneNine								= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(9) end, 							releasedFn = nil, 														repeatFn = nil },
			FCPXHackSelectClipAtLaneTen									= { characterString = "", 							modifiers = {}, 									fn = function() selectClipAtLane(10) end, 							releasedFn = nil, 														repeatFn = nil },

			FCPXHackColorPuckOneMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(1, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckTwoMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(2, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckThreeMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(3, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackColorPuckFourMouse									= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(4, 1) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },

			FCPXHackSaturationPuckOneMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(1, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckTwoMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(2, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckThreeMouse							= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(3, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackSaturationPuckFourMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(4, 2) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },

			FCPXHackExposurePuckOneMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(1, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckTwoMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(2, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckThreeMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(3, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },
			FCPXHackExposurePuckFourMouse								= { characterString = "", 							modifiers = {}, 									fn = function() colorBoardMousePuck(4, 3) end, 						releasedFn = function() colorBoardMousePuckRelease() end, 				repeatFn = nil },

			FCPXHackMoveToPlayhead										= { characterString = "", 							modifiers = {}, 									fn = function() moveToPlayhead() end, 								releasedFn = nil, 														repeatFn = nil },

			FCPXHackCutSwitchAngle01Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 1) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle02Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 2) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle03Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 3) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle04Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 4) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle05Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 5) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle06Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 6) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle07Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 7) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle08Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 8) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle09Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 9) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle10Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 10) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle11Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 11) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle12Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 12) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle13Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 13) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle14Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 14) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle15Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 15) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle16Video								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Video", 16) end, 				releasedFn = nil, 														repeatFn = nil },

			FCPXHackCutSwitchAngle01Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 1) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle02Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 2) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle03Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 3) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle04Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 4) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle05Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 5) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle06Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 6) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle07Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 7) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle08Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 8) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle09Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 9) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle10Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 10) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle11Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 11) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle12Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 12) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle13Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 13) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle14Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 14) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle15Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 15) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle16Audio								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Audio", 16) end, 				releasedFn = nil, 														repeatFn = nil },

			FCPXHackCutSwitchAngle01Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 1) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle02Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 2) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle03Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 3) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle04Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 4) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle05Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 5) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle06Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 6) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle07Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 7) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle08Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 8) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle09Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 9) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle10Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 10) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle11Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 11) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle12Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 12) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle13Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 13) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle14Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 14) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle15Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 15) end, 				releasedFn = nil, 														repeatFn = nil },
			FCPXHackCutSwitchAngle16Both								= { characterString = "", 							modifiers = {}, 									fn = function() cutAndSwitchMulticam("Both", 16) end, 				releasedFn = nil, 														repeatFn = nil },

			FCPXHackConsole				 								= { characterString = keyCodeTranslator("space"), 	modifiers = {"ctrl"}, 								fn = function() showChooser() end, 									releasedFn = nil, 														repeatFn = nil },

			FCPXHackToggleTouchBar				 						= { characterString = keyCodeTranslator("z"), 		modifiers = {"ctrl", "option", "command"}, 			fn = function() toggleTouchBar() end, 								releasedFn = nil, 														repeatFn = nil },
		}

		--------------------------------------------------------------------------------
		-- Get Values of Shortcuts built into Final Cut Pro:
		--------------------------------------------------------------------------------
		mod.finalCutProShortcutKeyPlaceholders = requiredBuiltInShortcuts
		if getShortcutsFromActiveCommandSet() ~= true then
			dialog.displayErrorMessage("Something went wrong whilst attempting to read the Active Command Set.")
			return "Fail"
		end
	end

	--------------------------------------------------------------------------------
	-- Reset Modal Hotkey for Final Cut Pro Commands:
	--------------------------------------------------------------------------------
	hotkeys = nil

	--------------------------------------------------------------------------------
	-- Reset Global Hotkeys:
	--------------------------------------------------------------------------------
	local currentHotkeys = hotkey.getHotkeys()
	for i=1, #currentHotkeys do
		result = currentHotkeys[i]:delete()
	end

	--------------------------------------------------------------------------------
	-- Create a modal hotkey object with an absurd triggering hotkey:
	--------------------------------------------------------------------------------
	hotkeys = hotkey.modal.new({"command", "shift", "alt", "control"}, "F19")

	--------------------------------------------------------------------------------
	-- Enable Hotkeys Loop:
	--------------------------------------------------------------------------------
	for k, v in pairs(mod.finalCutProShortcutKey) do
		if mod.finalCutProShortcutKey[k]['characterString'] ~= "" and mod.finalCutProShortcutKey[k]['fn'] ~= nil then
			if mod.finalCutProShortcutKey[k]['global'] == true then
				--------------------------------------------------------------------------------
				-- Global Shortcut:
				--------------------------------------------------------------------------------
				hotkey.bind(mod.finalCutProShortcutKey[k]['modifiers'], mod.finalCutProShortcutKey[k]['characterString'], mod.finalCutProShortcutKey[k]['fn'], mod.finalCutProShortcutKey[k]['releasedFn'], mod.finalCutProShortcutKey[k]['repeatFn'])
			else
				--------------------------------------------------------------------------------
				-- Final Cut Pro Specific Shortcut:
				--------------------------------------------------------------------------------
				hotkeys:bind(mod.finalCutProShortcutKey[k]['modifiers'], mod.finalCutProShortcutKey[k]['characterString'], mod.finalCutProShortcutKey[k]['fn'], mod.finalCutProShortcutKey[k]['releasedFn'], mod.finalCutProShortcutKey[k]['repeatFn'])
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Development Shortcut:
	--------------------------------------------------------------------------------
	if mod.debugMode then
		hotkey.bind({"ctrl", "option", "command"}, "q", function() testingGround() end)
	end

	--------------------------------------------------------------------------------
	-- Enable Hotkeys:
	--------------------------------------------------------------------------------
	hotkeys:enter()

	--------------------------------------------------------------------------------
	-- Let user know that keyboard shortcuts have loaded:
	--------------------------------------------------------------------------------
	alert.closeAll(0)
	alert.show("Keyboard Shortcuts Updated")

end

--------------------------------------------------------------------------------
-- UPDATE KEYBOARD SHORTCUTS:
--------------------------------------------------------------------------------
function updateKeyboardShortcuts()
	--------------------------------------------------------------------------------
	-- Revert back to default keyboard layout:
	--------------------------------------------------------------------------------
	local result = fcp.setPreference("Active Command Set", "/Applications/Final Cut Pro.app/Contents/Resources/en.lproj/Default.commandset")
	if result == false then
		dialog.displayErrorMessage("Failed to reset the Active Command Set.")
		return "Failed"
	end

	--------------------------------------------------------------------------------
	-- Update Keyboard Settings:
	--------------------------------------------------------------------------------
	local appleScriptA = [[
		--------------------------------------------------------------------------------
		-- Replace Files:
		--------------------------------------------------------------------------------
		try
			tell me to activate
			do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/NSProCommandGroups.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommandGroups.plist'" with administrator privileges
		on error
			display dialog commonErrorMessageStart & "Failed to replace NSProCommandGroups.plist." & commonErrorMessageEnd buttons {"Close"} with icon caution
			return "Failed"
		end try
		try
			do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/NSProCommands.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommands.plist'" with administrator privileges
		on error
			display dialog commonErrorMessageStart & "Failed to replace NSProCommands.plist." & commonErrorMessageEnd buttons {"Close"} with icon caution
			return "Failed"
		end try

		set finalCutProLanguages to {"de", "en", "es", "fr", "ja", "zh_CN"}
		repeat with whichLanguage in finalCutProLanguages
			try
				do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/" & whichLanguage & ".lproj/Default.commandset '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/Default.commandset'" with administrator privileges
			on error
				display dialog commonErrorMessageStart & "Failed to replace Default.commandset." & commonErrorMessageEnd buttons {"Close"} with icon caution
				return "Failed"
			end try
			try
				do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings'" with administrator privileges
			on error
				display dialog commonErrorMessageStart & "Failed to replace NSProCommandDescriptions.strings." & commonErrorMessageEnd buttons {"Close"} with icon caution
				return "Failed"
			end try
			try
				do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/" & whichLanguage & ".lproj/NSProCommandNames.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandNames.strings'" with administrator privileges
			on error
				display dialog commonErrorMessageStart & "Failed to replace NSProCommandNames.strings." & commonErrorMessageEnd buttons {"Close"} with icon caution
				return "Failed"
			end try
		end repeat
		return "Done"
	]]
	ok,toggleEnableHacksShortcutsInFinalCutProResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA)
	return toggleEnableHacksShortcutsInFinalCutProResult
end

--------------------------------------------------------------------------------
-- READ SHORTCUT KEYS FROM FINAL CUT PRO PLIST:
--------------------------------------------------------------------------------
function getShortcutsFromActiveCommandSet()

	local activeCommandSetTable = fcp.getActiveCommandSetAsTable()

	if activeCommandSetTable ~= nil then
		for k, v in pairs(mod.finalCutProShortcutKeyPlaceholders) do

			if activeCommandSetTable[k] ~= nil then

				--------------------------------------------------------------------------------
				-- Multiple keyboard shortcuts for single function:
				--------------------------------------------------------------------------------
				if type(activeCommandSetTable[k][1]) == "table" then
					for x=1, #activeCommandSetTable[k] do

						local tempModifiers = nil
						local tempCharacterString = nil
						local keypadModifier = false

						if activeCommandSetTable[k][x]["modifiers"] ~= nil then
							if string.find(activeCommandSetTable[k][x]["modifiers"], "keypad") then keypadModifier = true end
							tempModifiers = translateKeyboardModifiers(activeCommandSetTable[k][x]["modifiers"])
						end

						if activeCommandSetTable[k][x]["modifierMask"] ~= nil then
							tempModifiers = translateModifierMask(activeCommandSetTable[k][x]["modifierMask"])
						end

						if activeCommandSetTable[k][x]["characterString"] ~= nil then
							tempCharacterString = translateKeyboardCharacters(activeCommandSetTable[k][x]["characterString"])
						end

						if activeCommandSetTable[k][x]["character"] ~= nil then
							if keypadModifier then
								tempCharacterString = translateKeyboardKeypadCharacters(activeCommandSetTable[k][x]["character"])
							else
								tempCharacterString = translateKeyboardCharacters(activeCommandSetTable[k][x]["character"])
							end
						end

						local tempGlobalShortcut = mod.finalCutProShortcutKeyPlaceholders[k]['global'] or false

						mod.finalCutProShortcutKey[k .. tostring(x)] = {
							characterString 	= 		tempCharacterString,
							modifiers 			= 		tempModifiers,
							fn 					= 		mod.finalCutProShortcutKeyPlaceholders[k]['fn'],
							releasedFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['releasedFn'],
							repeatFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['repeatFn'],
							global 				= 		tempGlobalShortcut,
						}

					end
				--------------------------------------------------------------------------------
				-- Single keyboard shortcut for a single function:
				--------------------------------------------------------------------------------
				else

					local tempModifiers = nil
					local tempCharacterString = nil
					local keypadModifier = false

					if activeCommandSetTable[k]["modifiers"] ~= nil then
						tempModifiers = translateKeyboardModifiers(activeCommandSetTable[k]["modifiers"])
					end

					if activeCommandSetTable[k]["modifierMask"] ~= nil then
						tempModifiers = translateModifierMask(activeCommandSetTable[k]["modifierMask"])
					end

					if activeCommandSetTable[k]["characterString"] ~= nil then
						tempCharacterString = translateKeyboardCharacters(activeCommandSetTable[k]["characterString"])
					end

					if activeCommandSetTable[k]["character"] ~= nil then
						if keypadModifier then
							tempCharacterString = translateKeyboardKeypadCharacters(activeCommandSetTable[k]["character"])
						else
							tempCharacterString = translateKeyboardCharacters(activeCommandSetTable[k]["character"])
						end
					end

					local tempGlobalShortcut = mod.finalCutProShortcutKeyPlaceholders[k]['global'] or false

					mod.finalCutProShortcutKey[k] = {
						characterString 	= 		tempCharacterString,
						modifiers 			= 		tempModifiers,
						fn 					= 		mod.finalCutProShortcutKeyPlaceholders[k]['fn'],
						releasedFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['releasedFn'],
						repeatFn 			= 		mod.finalCutProShortcutKeyPlaceholders[k]['repeatFn'],
						global 				= 		tempGlobalShortcut,
					}

				end
			end
		end
		return true
	else
		return false
	end

end

--------------------------------------------------------------------------------
-- TRANSLATE KEYBOARD CHARACTER STRINGS FROM PLIST TO HS FORMAT:
--------------------------------------------------------------------------------
function translateKeyboardCharacters(input)

	local result = tostring(input)

	if input == " " 									then result = "space"		end
	if string.find(input, "NSF1FunctionKey") 			then result = "f1" 			end
	if string.find(input, "NSF2FunctionKey") 			then result = "f2" 			end
	if string.find(input, "NSF3FunctionKey") 			then result = "f3" 			end
	if string.find(input, "NSF4FunctionKey") 			then result = "f4" 			end
	if string.find(input, "NSF5FunctionKey") 			then result = "f5" 			end
	if string.find(input, "NSF6FunctionKey") 			then result = "f6" 			end
	if string.find(input, "NSF7FunctionKey") 			then result = "f7" 			end
	if string.find(input, "NSF8FunctionKey") 			then result = "f8" 			end
	if string.find(input, "NSF9FunctionKey") 			then result = "f9" 			end
	if string.find(input, "NSF10FunctionKey") 			then result = "f10" 		end
	if string.find(input, "NSF11FunctionKey") 			then result = "f11" 		end
	if string.find(input, "NSF12FunctionKey") 			then result = "f12" 		end
	if string.find(input, "NSF13FunctionKey") 			then result = "f13" 		end
	if string.find(input, "NSF14FunctionKey") 			then result = "f14" 		end
	if string.find(input, "NSF15FunctionKey") 			then result = "f15" 		end
	if string.find(input, "NSF16FunctionKey") 			then result = "f16" 		end
	if string.find(input, "NSF17FunctionKey") 			then result = "f17" 		end
	if string.find(input, "NSF18FunctionKey") 			then result = "f18" 		end
	if string.find(input, "NSF19FunctionKey") 			then result = "f19" 		end
	if string.find(input, "NSF20FunctionKey") 			then result = "f20" 		end
	if string.find(input, "NSUpArrowFunctionKey") 		then result = "up" 			end
	if string.find(input, "NSDownArrowFunctionKey") 	then result = "down" 		end
	if string.find(input, "NSLeftArrowFunctionKey") 	then result = "left" 		end
	if string.find(input, "NSRightArrowFunctionKey") 	then result = "right" 		end
	if string.find(input, "NSDeleteFunctionKey") 		then result = "delete" 		end
	if string.find(input, "NSHomeFunctionKey") 			then result = "home" 		end
	if string.find(input, "NSEndFunctionKey") 			then result = "end" 		end
	if string.find(input, "NSPageUpFunctionKey") 		then result = "pageup" 		end
	if string.find(input, "NSPageDownFunctionKey") 		then result = "pagedown" 	end

	--------------------------------------------------------------------------------
	-- Convert to lowercase:
	--------------------------------------------------------------------------------
	result = string.lower(result)

	local convertedToKeycode = keyCodeTranslator(result)
	if convertedToKeycode == nil then
		writeToConsole("NON-FATAL ERROR: Failed to translate keyboard character (" .. tostring(input) .. ").")
		result = ""
	else
		result = convertedToKeycode
	end

	return result

end

--------------------------------------------------------------------------------
-- TRANSLATE KEYBOARD CHARACTER STRINGS FROM PLIST TO HS FORMAT:
--------------------------------------------------------------------------------
function translateKeyboardKeypadCharacters(input)

	local result = nil
	local padKeys = { "*", "+", "/", "-", "=", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "clear", "enter" }
	for i=1, #padKeys do
		if input == padKeys[i] then result = "pad" .. input end
	end

	return translateKeyboardCharacters(result)

end

--------------------------------------------------------------------------------
-- TRANSLATE KEYBOARD MODIFIERS FROM PLIST STRING TO HS TABLE FORMAT:
--------------------------------------------------------------------------------
function translateKeyboardModifiers(input)

	local result = {}
	if string.find(input, "command") then result[#result + 1] = "command" end
	if string.find(input, "control") then result[#result + 1] = "control" end
	if string.find(input, "option") then result[#result + 1] = "option" end
	if string.find(input, "shift") then result[#result + 1] = "shift" end
	return result

end

--------------------------------------------------------------------------------
-- TRANSLATE KEYBOARD MODIFIERS FROM PLIST STRING TO HS TABLE FORMAT:
--------------------------------------------------------------------------------
function translateModifierMask(value)

	local modifiers = {
		--AlphaShift = 1 << 16,
		shift      = 1 << 17,
		control    = 1 << 18,
		option	   = 1 << 19,
		command    = 1 << 20,
		--NumericPad = 1 << 21,
		--Help       = 1 << 22,
		--Function   = 1 << 23,
	}

	local answer = {}

	for k, v in pairs(modifiers) do
		if (value & v) == v then
			table.insert(answer, k)
		end
	end

	return answer

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                     C H O O S E R    /  C O N S O L E                      --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- SETUP CHOOSER:
--------------------------------------------------------------------------------
function setupChooser()

	mod.fcpxChooser = chooser.new(chooserAction):bgDark(true)
											:fgColor(drawing.color.x11.snow)
											:subTextColor(drawing.color.x11.snow)
											:rightClickCallback(chooserRightClick)
											:choices(chooserChoices)

end

--------------------------------------------------------------------------------
-- SHOW CHOOSER:
--------------------------------------------------------------------------------
function showChooser()
	mod.fcpxChooserActive = true
	mod.fcpxChooser:show()
end

--------------------------------------------------------------------------------
-- CHOOSER CHOICES:
--------------------------------------------------------------------------------
function chooserChoices()

	--------------------------------------------------------------------------------
	-- Debug Mode:
	--------------------------------------------------------------------------------
	debugMessage("Updating Chooser Choices.")

	--------------------------------------------------------------------------------
	-- Reset Choices:
	--------------------------------------------------------------------------------
	mod.fcpxChooserChoices = nil
	mod.fcpxChooserChoices = {}

	--------------------------------------------------------------------------------
	-- Settings:
	--------------------------------------------------------------------------------
	local chooserShowAutomation 		= settings.get("fcpxHacks.chooserShowAutomation")
	local chooserShowShortcuts 			= settings.get("fcpxHacks.chooserShowShortcuts")
	local chooserShowHacks 				= settings.get("fcpxHacks.chooserShowHacks")
	local chooserShowVideoEffects 		= settings.get("fcpxHacks.chooserShowVideoEffects")
	local chooserShowAudioEffects 		= settings.get("fcpxHacks.chooserShowAudioEffects")
	local chooserShowTransitions 		= settings.get("fcpxHacks.chooserShowTransitions")
	local chooserShowTitles 			= settings.get("fcpxHacks.chooserShowTitles")
	local chooserShowGenerators 		= settings.get("fcpxHacks.chooserShowGenerators")

	--------------------------------------------------------------------------------
	-- Hardcoded Choices:
	--------------------------------------------------------------------------------
	local chooserAutomation = {
		{
			["text"] = "Toggle Scrolling Timeline",
			["subText"] = "Automation",
			["function"] = "toggleScrollingTimeline",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Highlight Browser Playhead",
			["subText"] = "Automation",
			["function"] = "highlightFCPXBrowserPlayhead",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Reveal in Browser & Highlight",
			["subText"] = "Automation",
			["function"] = "matchFrameThenHighlightFCPXBrowserPlayhead",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 1",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 1,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 2",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 2,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 3",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 3,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 4",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 4,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 5",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 5,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 6",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 6,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 7",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 7,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 8",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 8,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 9",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 9,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Clip At Lane 10",
			["subText"] = "Automation",
			["function"] = "selectClipAtLane",
			["function1"] = 10,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Single Match Frame & Highlight",
			["subText"] = "Automation",
			["function"] = "singleMatchFrame",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Reveal Multicam in Browser & Highlight",
			["subText"] = "Automation",
			["function"] = "multicamMatchFrame",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Reveal Multicam in Angle Editor & Highlight",
			["subText"] = "Automation",
			["function"] = "multicamMatchFrame",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 1",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 1,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 2",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 2,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 3",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 3,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Select Color Board Puck 4",
			["subText"] = "Automation",
			["function"] = "colorBoardSelectPuck",
			["function1"] = 4,
			["function2"] = nil,
			["function3"] = nil,
		},
	}
	local chooserShortcuts = {
		{
			["text"] = "Create Optimized Media (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateOptimizedMedia",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Optimized Media (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateOptimizedMedia",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Multicam Optimized Media (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateMulticamOptimizedMedia",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Multicam Optimized Media (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateMulticamOptimizedMedia",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Proxy Media (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateProxyMedia",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Create Proxy Media (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleCreateProxyMedia",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Leave Files In Place On Import (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleLeaveInPlace",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Leave Files In Place On Import (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleLeaveInPlace",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Background Render (Activate)",
			["subText"] = "Shortcut",
			["function"] = "toggleBackgroundRender",
			["function1"] = true,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Background Render (Deactivate)",
			["subText"] = "Shortcut",
			["function"] = "toggleBackgroundRender",
			["function1"] = false,
			["function2"] = nil,
			["function3"] = nil,
		},
	}
	local chooserHacks = {
		{
			["text"] = "Change Backup Interval",
			["subText"] = "Hack",
			["function"] = "changeBackupInterval",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Toggle Timecode Overlay",
			["subText"] = "Hack",
			["function"] = "toggleTimecodeOverlay",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Toggle Moving Markers",
			["subText"] = "Hack",
			["function"] = "toggleMovingMarkers",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
		{
			["text"] = "Toggle Enable Rendering During Playback",
			["subText"] = "Hack",
			["function"] = "togglePerformTasksDuringPlayback",
			["function1"] = nil,
			["function2"] = nil,
			["function3"] = nil,
		},
	}

	if chooserShowAutomation then fnutils.concat(mod.fcpxChooserChoices, chooserAutomation) end
	if chooserShowShortcuts then fnutils.concat(mod.fcpxChooserChoices, chooserShortcuts) end
	if chooserShowHacks then fnutils.concat(mod.fcpxChooserChoices, chooserHacks) end

	--------------------------------------------------------------------------------
	-- Video Effects List:
	--------------------------------------------------------------------------------
	if chooserShowVideoEffects then
		local allVideoEffects = settings.get("fcpxHacks.allVideoEffects")
		if allVideoEffects ~= nil and next(allVideoEffects) ~= nil then
			for i=1, #allVideoEffects do
				individualEffect = {
					["text"] = allVideoEffects[i],
					["subText"] = "Video Effect",
					["function"] = "effectsShortcut",
					["function1"] = allVideoEffects[i],
					["function2"] = "",
					["function3"] = "",
				}
				table.insert(mod.fcpxChooserChoices, 1, individualEffect)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Audio Effects List:
	--------------------------------------------------------------------------------
	if chooserShowAudioEffects then
		local allAudioEffects = settings.get("fcpxHacks.allAudioEffects")
		if allAudioEffects ~= nil and next(allAudioEffects) ~= nil then
			for i=1, #allAudioEffects do
				individualEffect = {
					["text"] = allAudioEffects[i],
					["subText"] = "Audio Effect",
					["function"] = "effectsShortcut",
					["function1"] = allAudioEffects[i],
					["function2"] = "",
					["function3"] = "",
				}
				table.insert(mod.fcpxChooserChoices, 1, individualEffect)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Transitions List:
	--------------------------------------------------------------------------------
	if chooserShowTransitions then
		local allTransitions = settings.get("fcpxHacks.allTransitions")
		if allTransitions ~= nil and next(allTransitions) ~= nil then
			for i=1, #allTransitions do
				local individualEffect = {
					["text"] = allTransitions[i],
					["subText"] = "Transition",
					["function"] = "transitionsShortcut",
					["function1"] = allTransitions[i],
					["function2"] = "",
					["function3"] = "",
				}
				table.insert(mod.fcpxChooserChoices, 1, individualEffect)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Titles List:
	--------------------------------------------------------------------------------
	if chooserShowTitles then
		local allTitles = settings.get("fcpxHacks.allTitles")
		if allTitles ~= nil and next(allTitles) ~= nil then
			for i=1, #allTitles do
				individualEffect = {
					["text"] = allTitles[i],
					["subText"] = "Title",
					["function"] = "titlesShortcut",
					["function1"] = allTitles[i],
					["function2"] = "",
					["function3"] = "",
				}
				table.insert(mod.fcpxChooserChoices, 1, individualEffect)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Generators List:
	--------------------------------------------------------------------------------
	if chooserShowGenerators then
		local allGenerators = settings.get("fcpxHacks.allGenerators")
		if allGenerators ~= nil and next(allGenerators) ~= nil then
			for i=1, #allGenerators do
				local individualEffect = {
					["text"] = allGenerators[i],
					["subText"] = "Generator",
					["function"] = "generatorsShortcut",
					["function1"] = allGenerators[i],
					["function2"] = "",
					["function3"] = "",
				}
				table.insert(mod.fcpxChooserChoices, 1, individualEffect)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Sort everything:
	--------------------------------------------------------------------------------
	table.sort(mod.fcpxChooserChoices, function(a, b) return a.text < b.text end)

	--------------------------------------------------------------------------------
	-- Return Choices:
	--------------------------------------------------------------------------------
	return mod.fcpxChooserChoices

end

--------------------------------------------------------------------------------
-- CHOOSER COMPLETE:
--------------------------------------------------------------------------------
function chooserAction(result)

	--------------------------------------------------------------------------------
	-- Hide Chooser:
	--------------------------------------------------------------------------------
	mod.fcpxChooser:hide()

	--------------------------------------------------------------------------------
	-- Perform Specific Function:
	--------------------------------------------------------------------------------
	if result ~= nil then
		timer.doAfter(0.0000000001, function() _G[result["function"]](result["function1"], result["function2"], result["function3"]) end )
	end

	--------------------------------------------------------------------------------
	-- Put focus back in Final Cut Pro:
	--------------------------------------------------------------------------------
	fcp.launch()

	--------------------------------------------------------------------------------
	-- Re-activate the Scrolling Timeline:
	--------------------------------------------------------------------------------
	mod.fcpxChooserActive = false
	mod.scrollingTimelineWatcherWorking = false

end

--------------------------------------------------------------------------------
-- CHOOSER RIGHT CLICK:
--------------------------------------------------------------------------------
function chooserRightClick()

	--------------------------------------------------------------------------------
	-- Settings:
	--------------------------------------------------------------------------------
	local chooserShowAutomation 		= settings.get("fcpxHacks.chooserShowAutomation")
	local chooserShowShortcuts 			= settings.get("fcpxHacks.chooserShowShortcuts")
	local chooserShowHacks 				= settings.get("fcpxHacks.chooserShowHacks")
	local chooserShowVideoEffects 		= settings.get("fcpxHacks.chooserShowVideoEffects")
	local chooserShowAudioEffects 		= settings.get("fcpxHacks.chooserShowAudioEffects")
	local chooserShowTransitions 		= settings.get("fcpxHacks.chooserShowTransitions")
	local chooserShowTitles				= settings.get("fcpxHacks.chooserShowTitles")
	local chooserShowGenerators 		= settings.get("fcpxHacks.chooserShowGenerators")

	--------------------------------------------------------------------------------
	-- 'Show All' Display Option:
	--------------------------------------------------------------------------------
	local chooserShowAll = false
	if chooserShowAutomation and chooserShowShortcuts and chooserShowHacks and chooserShowVideoEffects and chooserShowAudioEffects and chooserShowTransitions and chooserShowTitles and chooserShowGenerators then
		chooserShowAll = true
	end

	--------------------------------------------------------------------------------
	-- Menubar:
	--------------------------------------------------------------------------------
	fcpxRightClickMenubar = menubar.new(false)
	local rightClickMenu = {
		--{ title = "SELECTED ITEM:",	 	disabled = true },
		--{ title = "Favourite Selected Item", disabled = true },
		--{ title = "Hide Selected Item", 	 disabled = true },
     	--{ title = "-" },
     	{ title = "DISPLAY OPTIONS:",	 	disabled = true },
     	{ title = "Show None", fn = function()
     		settings.set("fcpxHacks.chooserShowAutomation", false)
     		settings.set("fcpxHacks.chooserShowShortcuts", false)
     		settings.set("fcpxHacks.chooserShowHacks", false)
     		settings.set("fcpxHacks.chooserShowVideoEffects", false)
     		settings.set("fcpxHacks.chooserShowAudioEffects", false)
     		settings.set("fcpxHacks.chooserShowTransitions", false)
     		settings.set("fcpxHacks.chooserShowTitles", false)
     		settings.set("fcpxHacks.chooserShowGenerators", false)
     		mod.fcpxChooser:refreshChoicesCallback()
     	end },
     	{ title = "Show All", 				checked = chooserShowAll,	fn = function()
     		settings.set("fcpxHacks.chooserShowAutomation", true)
     		settings.set("fcpxHacks.chooserShowShortcuts", true)
     		settings.set("fcpxHacks.chooserShowHacks", true)
     		settings.set("fcpxHacks.chooserShowVideoEffects", true)
     		settings.set("fcpxHacks.chooserShowAudioEffects", true)
     		settings.set("fcpxHacks.chooserShowTransitions", true)
     		settings.set("fcpxHacks.chooserShowTitles", true)
     		settings.set("fcpxHacks.chooserShowGenerators", true)
     		mod.fcpxChooser:refreshChoicesCallback()
     	end },
       	{ title = "Show Automation", 		checked = chooserShowAutomation,	fn = function() settings.set("fcpxHacks.chooserShowAutomation", not chooserShowAutomation); 			mod.fcpxChooser:refreshChoicesCallback() end },
       	{ title = "Show Hacks", 			checked = chooserShowHacks,			fn = function() settings.set("fcpxHacks.chooserShowHacks", not chooserShowHacks); 						mod.fcpxChooser:refreshChoicesCallback() end },
       	{ title = "Show Shortcuts", 		checked = chooserShowShortcuts,		fn = function() settings.set("fcpxHacks.chooserShowShortcuts", not chooserShowShortcuts); 				mod.fcpxChooser:refreshChoicesCallback() end },
     	{ title = "Show Video Effects", 	checked = chooserShowVideoEffects,	fn = function() settings.set("fcpxHacks.chooserShowVideoEffects", not chooserShowVideoEffects); 		mod.fcpxChooser:refreshChoicesCallback() end },
       	{ title = "Show Audio Effects", 	checked = chooserShowAudioEffects,	fn = function() settings.set("fcpxHacks.chooserShowAudioEffects", not chooserShowAudioEffects); 		mod.fcpxChooser:refreshChoicesCallback() end },
       	{ title = "Show Transitions", 		checked = chooserShowTransitions,	fn = function() settings.set("fcpxHacks.chooserShowTransitions", not chooserShowTransitions); 			mod.fcpxChooser:refreshChoicesCallback() end },
       	{ title = "Show Titles", 			checked = chooserShowTitles,		fn = function() settings.set("fcpxHacks.chooserShowTitles", not chooserShowTitles); 					mod.fcpxChooser:refreshChoicesCallback() end },
       	{ title = "Show Generators", 		checked = chooserShowGenerators,	fn = function() settings.set("fcpxHacks.chooserShowGenerators", not chooserShowGenerators); 			mod.fcpxChooser:refreshChoicesCallback() end },
	}
	fcpxRightClickMenubar:setMenu(rightClickMenu)
	fcpxRightClickMenubar:popupMenu(mouse.getAbsolutePosition())

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                     M E N U B A R    F E A T U R E S                       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- REFRESH MENUBAR:
--------------------------------------------------------------------------------
function refreshMenuBar(refreshPlistValues)

	--------------------------------------------------------------------------------
	-- Assume FCPX is closed if not told otherwise:
	--------------------------------------------------------------------------------
	local fcpxActive = fcp.frontmost()
	local fcpxRunning = fcp.running()

	--------------------------------------------------------------------------------
	-- We only refresh plist values if necessary as this takes time:
	--------------------------------------------------------------------------------
	if refreshPlistValues == true then

		--------------------------------------------------------------------------------
		-- Used for debugging:
		--------------------------------------------------------------------------------
		debugMessage("Menubar refreshed with latest plist values.")

		--------------------------------------------------------------------------------
		-- Read Final Cut Pro Preferences:
		--------------------------------------------------------------------------------
		local preferences = fcp.getPreferencesAsTable()
		if preferences == nil then
			dialog.displayErrorMessage("Failed to read Final Cut Pro Preferences")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get plist values for Allow Moving Markers:
		--------------------------------------------------------------------------------
		mod.allowMovingMarkers = false
		local result = plist.fileToTable("/Applications/Final Cut Pro.app/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist")
		if result ~= nil then
			if result["TLKMarkerHandler"] ~= nil then
				if result["TLKMarkerHandler"]["Configuration"] ~= nil then
					if result["TLKMarkerHandler"]["Configuration"]["Allow Moving Markers"] ~= nil then
						mod.allowMovingMarkers = result["TLKMarkerHandler"]["Configuration"]["Allow Moving Markers"]
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFPeriodicBackupInterval:
		--------------------------------------------------------------------------------
		if preferences["FFPeriodicBackupInterval"] == nil then
			mod.FFPeriodicBackupInterval = "15"
		else
			mod.FFPeriodicBackupInterval = preferences["FFPeriodicBackupInterval"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFSuspendBGOpsDuringPlay:
		--------------------------------------------------------------------------------
		if preferences["FFSuspendBGOpsDuringPlay"] == nil then
			mod.FFSuspendBGOpsDuringPlay = false
		else
			mod.FFSuspendBGOpsDuringPlay = preferences["FFSuspendBGOpsDuringPlay"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFEnableGuards:
		--------------------------------------------------------------------------------
		if preferences["FFEnableGuards"] == nil then
			mod.FFEnableGuards = false
		else
			mod.FFEnableGuards = preferences["FFEnableGuards"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFCreateOptimizedMediaForMulticamClips:
		--------------------------------------------------------------------------------
		if preferences["FFCreateOptimizedMediaForMulticamClips"] == nil then
			mod.FFCreateOptimizedMediaForMulticamClips = true
		else
			mod.FFCreateOptimizedMediaForMulticamClips = preferences["FFCreateOptimizedMediaForMulticamClips"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFAutoStartBGRender:
		--------------------------------------------------------------------------------
		if preferences["FFAutoStartBGRender"] == nil then
			mod.FFAutoStartBGRender = true
		else
			mod.FFAutoStartBGRender = preferences["FFAutoStartBGRender"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFAutoRenderDelay:
		--------------------------------------------------------------------------------
		if preferences["FFAutoRenderDelay"] == nil then
			mod.FFAutoRenderDelay = "0.3"
		else
			mod.FFAutoRenderDelay = preferences["FFAutoRenderDelay"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFImportCopyToMediaFolder:
		--------------------------------------------------------------------------------
		if preferences["FFImportCopyToMediaFolder"] == nil then
			mod.FFImportCopyToMediaFolder = true
		else
			mod.FFImportCopyToMediaFolder = preferences["FFImportCopyToMediaFolder"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFImportCreateOptimizeMedia:
		--------------------------------------------------------------------------------
		if preferences["FFImportCreateOptimizeMedia"] == nil then
			mod.FFImportCreateOptimizeMedia = false
		else
			mod.FFImportCreateOptimizeMedia = preferences["FFImportCreateOptimizeMedia"]
		end

		--------------------------------------------------------------------------------
		-- Get plist values for FFImportCreateProxyMedia:
		--------------------------------------------------------------------------------
		if preferences["FFImportCreateProxyMedia"] == nil then
			mod.FFImportCreateProxyMedia = false
		else
			mod.FFImportCreateProxyMedia = preferences["FFImportCreateProxyMedia"]
		end

	end

	--------------------------------------------------------------------------------
	-- Get Menubar Display Mode from Settings:
	--------------------------------------------------------------------------------
	local displayMenubarAsIcon = settings.get("fcpxHacks.displayMenubarAsIcon") or false

	--------------------------------------------------------------------------------
	-- Get Sizing Preferences:
	--------------------------------------------------------------------------------
	local displayHighlightShape = nil
	displayHighlightShape = settings.get("fcpxHacks.displayHighlightShape")
	local displayHighlightShapeRectangle = false
	local displayHighlightShapeCircle = false
	local displayHighlightShapeDiamond = false
	if displayHighlightShape == nil then 			displayHighlightShapeRectangle = true		end
	if displayHighlightShape == "Rectangle" then 	displayHighlightShapeRectangle = true		end
	if displayHighlightShape == "Circle" then 		displayHighlightShapeCircle = true			end
	if displayHighlightShape == "Diamond" then 		displayHighlightShapeDiamond = true			end

	--------------------------------------------------------------------------------
	-- Get Highlight Colour Preferences:
	--------------------------------------------------------------------------------
	local displayHighlightColour = nil
	displayHighlightColour = settings.get("fcpxHacks.displayHighlightColour")
	local displayHighlightColourRed = false
	local displayHighlightColourBlue = false
	local displayHighlightColourGreen = false
	local displayHighlightColourYellow = false
	if displayHighlightColour == nil then 		displayHighlightColourRed 		= true 		end
	if displayHighlightColour == "Red" then 	displayHighlightColourRed 		= true 		end
	if displayHighlightColour == "Blue" then 	displayHighlightColourBlue 		= true 		end
	if displayHighlightColour == "Green" then 	displayHighlightColourGreen 	= true 		end
	if displayHighlightColour == "Yellow" then 	displayHighlightColourYellow	= true 		end

	--------------------------------------------------------------------------------
	-- Get Enable Shortcuts During Fullscreen Playback from Settings:
	--------------------------------------------------------------------------------
	local enableShortcutsDuringFullscreenPlayback = settings.get("fcpxHacks.enableShortcutsDuringFullscreenPlayback") or false

	--------------------------------------------------------------------------------
	-- Get Enable Hacks Shortcuts in Final Cut Pro from Settings:
	--------------------------------------------------------------------------------
	local enableHacksShortcutsInFinalCutPro = settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro") or false

	--------------------------------------------------------------------------------
	-- Get Enable Proxy Menu Item:
	--------------------------------------------------------------------------------
	local enableProxyMenuIcon = settings.get("fcpxHacks.enableProxyMenuIcon") or false

	--------------------------------------------------------------------------------
	-- Hammerspoon Settings:
	--------------------------------------------------------------------------------
	local startHammerspoonOnLaunch = hs.autoLaunch()
	local hammerspoonCheckForUpdates = hs.automaticallyCheckForUpdates()
	local hammerspoonDockIcon = hs.dockIcon()
	local hammerspoonMenuIcon = hs.menuIcon()

	--------------------------------------------------------------------------------
	-- Scrolling Timeline:
	--------------------------------------------------------------------------------
	scrollingTimelineActive = settings.get("fcpxHacks.scrollingTimelineActive") or false

	--------------------------------------------------------------------------------
	-- Enable Mobile Notifications:
	--------------------------------------------------------------------------------
	enableMobileNotifications = settings.get("fcpxHacks.enableMobileNotifications") or false

	--------------------------------------------------------------------------------
	-- Enable Media Import Watcher:
	--------------------------------------------------------------------------------
	enableMediaImportWatcher = settings.get("fcpxHacks.enableMediaImportWatcher") or false

	--------------------------------------------------------------------------------
	-- Touch Bar Location:
	--------------------------------------------------------------------------------
	local displayTouchBarLocation = settings.get("fcpxHacks.displayTouchBarLocation") or "Mouse"
	local displayTouchBarLocationMouse = false
	if displayTouchBarLocation == "Mouse" then displayTouchBarLocationMouse = true end
	local displayTouchBarLocationTimelineTopCentre = false
	if displayTouchBarLocation == "TimelineTopCentre" then displayTouchBarLocationTimelineTopCentre = true end


	--------------------------------------------------------------------------------
	-- Enable Check for Updates:
	--------------------------------------------------------------------------------
	enableCheckForUpdates = settings.get("fcpxHacks.enableCheckForUpdates") or false

	--------------------------------------------------------------------------------
	-- Enable XML Sharing:
	--------------------------------------------------------------------------------
	enableXMLSharing = settings.get("fcpxHacks.enableXMLSharing") or false

	--------------------------------------------------------------------------------
	-- Enable Clipboard History:
	--------------------------------------------------------------------------------
	enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false

	--------------------------------------------------------------------------------
	-- Enable Shared Clipboard:
	--------------------------------------------------------------------------------
	enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard") or false

	--------------------------------------------------------------------------------
	-- Clipboard History Menu:
	--------------------------------------------------------------------------------
	local settingsClipboardHistoryTable = {}
	if enableClipboardHistory then
		local clipboardHistory = clipboard.getHistory()
		if clipboardHistory ~= nil then
			if #clipboardHistory ~= 0 then
				for i=#clipboardHistory, 1, -1 do
					table.insert(settingsClipboardHistoryTable, {title = clipboardHistory[i][2], fn = function() finalCutProPasteFromClipboardHistory(clipboardHistory[i][1]) end, disabled = not fcpxRunning})
				end
				table.insert(settingsClipboardHistoryTable, { title = "-" })
				table.insert(settingsClipboardHistoryTable, { title = "Clear Clipboard History", fn = clearClipboardHistory })
			else
				table.insert(settingsClipboardHistoryTable, { title = "Empty", disabled = true })
			end
		end
	else
		table.insert(settingsClipboardHistoryTable, { title = "Disabled in Settings", disabled = true })
	end

	--------------------------------------------------------------------------------
	-- Shared Clipboard Menu:
	--------------------------------------------------------------------------------
	local settingsSharedClipboardTable = {}

	if enableSharedClipboard and enableClipboardHistory then

		--------------------------------------------------------------------------------
		-- Get list of files:
		--------------------------------------------------------------------------------
		local sharedClipboardFiles = {}
		local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
		for file in fs.dir(sharedClipboardPath) do
			 if file:sub(1, 30) == "Final Cut Pro Shared Clipboard" then
				sharedClipboardFiles[#sharedClipboardFiles + 1] = file:sub(36)
			 end
		end

		if next(sharedClipboardFiles) == nil then
			--------------------------------------------------------------------------------
			-- Nothing in the Shared Clipboard:
			--------------------------------------------------------------------------------
			table.insert(settingsSharedClipboardTable, { title = "Empty", disabled = true })
		else
			--------------------------------------------------------------------------------
			-- Something in the Shared Clipboard:
			--------------------------------------------------------------------------------
			for i=1, #sharedClipboardFiles do
				table.insert(settingsSharedClipboardTable, {title = sharedClipboardFiles[i], fn = function() pasteFromSharedClipboard(sharedClipboardFiles[i]) end, disabled = not fcpxRunning})
			end
			table.insert(settingsSharedClipboardTable, { title = "-" })
			table.insert(settingsSharedClipboardTable, { title = "Clear Shared Clipboard History", fn = clearSharedClipboardHistory })
		end
	else
		--------------------------------------------------------------------------------
		-- Shared Clipboard Disabled:
		--------------------------------------------------------------------------------
		table.insert(settingsSharedClipboardTable, { title = "Disabled in Settings", disabled = true })
	end

	--------------------------------------------------------------------------------
	-- Shared XML Menu:
	--------------------------------------------------------------------------------
	local settingsSharedXMLTable = {}
	if enableXMLSharing then

		--------------------------------------------------------------------------------
		-- Get list of files:
		--------------------------------------------------------------------------------
		local sharedXMLFiles = {}

		local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")

		for file in fs.dir(xmlSharingPath) do
			 if file:sub(-7) == ".fcpxml" then
				sharedXMLFiles[#sharedXMLFiles + 1] = file:sub(1, -8)
			 end
		end

		if next(sharedXMLFiles) == nil then
			--------------------------------------------------------------------------------
			-- Nothing in the Shared Clipboard:
			--------------------------------------------------------------------------------
			table.insert(settingsSharedXMLTable, { title = "Empty", disabled = true })
		else
			--------------------------------------------------------------------------------
			-- Something in the Shared Clipboard:
			--------------------------------------------------------------------------------
			for i=1, #sharedXMLFiles do
				table.insert(settingsSharedXMLTable, {title = sharedXMLFiles[i], fn = function() importSharedXML(sharedXMLFiles[i]) end, disabled = not fcpxRunning})
			end
			table.insert(settingsSharedXMLTable, { title = "-" })
			table.insert(settingsSharedXMLTable, { title = "Clear Shared XML Files", fn = clearSharedXMLFiles })
		end
	else
		--------------------------------------------------------------------------------
		-- Shared Clipboard Disabled:
		--------------------------------------------------------------------------------
		table.insert(settingsSharedXMLTable, { title = "Disabled in Settings", disabled = true })
	end

	--------------------------------------------------------------------------------
	-- Effects Shortcuts:
	--------------------------------------------------------------------------------
	local effectsListUpdated 	= settings.get("fcpxHacks.effectsListUpdated") or false
	local effectsShortcutOne 	= settings.get("fcpxHacks.effectsShortcutOne")
	local effectsShortcutTwo 	= settings.get("fcpxHacks.effectsShortcutTwo")
	local effectsShortcutThree 	= settings.get("fcpxHacks.effectsShortcutThree")
	local effectsShortcutFour 	= settings.get("fcpxHacks.effectsShortcutFour")
	local effectsShortcutFive 	= settings.get("fcpxHacks.effectsShortcutFive")
	if effectsShortcutOne == nil then 		effectsShortcutOne = " (Unassigned)" 		else effectsShortcutOne = " (" .. string.format("%.20s", effectsShortcutOne) .. ")" end
	if effectsShortcutTwo == nil then 		effectsShortcutTwo = " (Unassigned)" 		else effectsShortcutTwo = " (" .. string.format("%.20s", effectsShortcutTwo) .. ")" end
	if effectsShortcutThree == nil then 	effectsShortcutThree = " (Unassigned)" 		else effectsShortcutThree = " (" .. string.format("%.20s", effectsShortcutThree) .. ")" end
	if effectsShortcutFour == nil then 		effectsShortcutFour = " (Unassigned)" 		else effectsShortcutFour = " (" .. string.format("%.20s", effectsShortcutFour) .. ")" end
	if effectsShortcutFive == nil then 		effectsShortcutFive = " (Unassigned)" 		else effectsShortcutFive = " (" .. string.format("%.20s", effectsShortcutFive) .. ")" end

	--------------------------------------------------------------------------------
	-- Transition Shortcuts:
	--------------------------------------------------------------------------------
	local transitionsListUpdated 	= settings.get("fcpxHacks.transitionsListUpdated") or false
	local transitionsShortcutOne 	= settings.get("fcpxHacks.transitionsShortcutOne")
	local transitionsShortcutTwo 	= settings.get("fcpxHacks.transitionsShortcutTwo")
	local transitionsShortcutThree 	= settings.get("fcpxHacks.transitionsShortcutThree")
	local transitionsShortcutFour 	= settings.get("fcpxHacks.transitionsShortcutFour")
	local transitionsShortcutFive 	= settings.get("fcpxHacks.transitionsShortcutFive")
	if transitionsShortcutOne == nil then 		transitionsShortcutOne = " (Unassigned)" 		else transitionsShortcutOne 	= " (" .. string.format("%.20s", transitionsShortcutOne) .. ")" 	end
	if transitionsShortcutTwo == nil then 		transitionsShortcutTwo = " (Unassigned)" 		else transitionsShortcutTwo 	= " (" .. string.format("%.20s", transitionsShortcutTwo) .. ")" 	end
	if transitionsShortcutThree == nil then 	transitionsShortcutThree = " (Unassigned)" 		else transitionsShortcutThree 	= " (" .. string.format("%.20s", transitionsShortcutThree) .. ")"	end
	if transitionsShortcutFour == nil then 		transitionsShortcutFour = " (Unassigned)" 		else transitionsShortcutFour 	= " (" .. string.format("%.20s", transitionsShortcutFour) .. ")" 	end
	if transitionsShortcutFive == nil then 		transitionsShortcutFive = " (Unassigned)" 		else transitionsShortcutFive 	= " (" .. string.format("%.20s", transitionsShortcutFive) .. ")" 	end

	--------------------------------------------------------------------------------
	-- Titles Shortcuts:
	--------------------------------------------------------------------------------
	local titlesListUpdated 	= settings.get("fcpxHacks.titlesListUpdated") or false
	local titlesShortcutOne 	= settings.get("fcpxHacks.titlesShortcutOne")
	local titlesShortcutTwo 	= settings.get("fcpxHacks.titlesShortcutTwo")
	local titlesShortcutThree 	= settings.get("fcpxHacks.titlesShortcutThree")
	local titlesShortcutFour 	= settings.get("fcpxHacks.titlesShortcutFour")
	local titlesShortcutFive 	= settings.get("fcpxHacks.titlesShortcutFive")
	if titlesShortcutOne == nil then 		titlesShortcutOne = " (Unassigned)" 		else titlesShortcutOne 	= " (" .. string.format("%.20s", titlesShortcutOne) .. ")" 	end
	if titlesShortcutTwo == nil then 		titlesShortcutTwo = " (Unassigned)" 		else titlesShortcutTwo 	= " (" .. string.format("%.20s", titlesShortcutTwo) .. ")" 	end
	if titlesShortcutThree == nil then 		titlesShortcutThree = " (Unassigned)" 		else titlesShortcutThree 	= " (" .. string.format("%.20s", titlesShortcutThree) .. ")"	end
	if titlesShortcutFour == nil then 		titlesShortcutFour = " (Unassigned)" 		else titlesShortcutFour 	= " (" .. string.format("%.20s", titlesShortcutFour) .. ")" 	end
	if titlesShortcutFive == nil then 		titlesShortcutFive = " (Unassigned)" 		else titlesShortcutFive 	= " (" .. string.format("%.20s", titlesShortcutFive) .. ")" 	end

	--------------------------------------------------------------------------------
	-- Generators Shortcuts:
	--------------------------------------------------------------------------------
	local generatorsListUpdated 	= settings.get("fcpxHacks.generatorsListUpdated") or false
	local generatorsShortcutOne 	= settings.get("fcpxHacks.generatorsShortcutOne")
	local generatorsShortcutTwo 	= settings.get("fcpxHacks.generatorsShortcutTwo")
	local generatorsShortcutThree 	= settings.get("fcpxHacks.generatorsShortcutThree")
	local generatorsShortcutFour 	= settings.get("fcpxHacks.generatorsShortcutFour")
	local generatorsShortcutFive 	= settings.get("fcpxHacks.generatorsShortcutFive")
	if generatorsShortcutOne == nil then 		generatorsShortcutOne = " (Unassigned)" 		else generatorsShortcutOne 	= " (" .. string.format("%.20s", generatorsShortcutOne) .. ")" 	end
	if generatorsShortcutTwo == nil then 		generatorsShortcutTwo = " (Unassigned)" 		else generatorsShortcutTwo 	= " (" .. string.format("%.20s", generatorsShortcutTwo) .. ")" 	end
	if generatorsShortcutThree == nil then 		generatorsShortcutThree = " (Unassigned)" 		else generatorsShortcutThree 	= " (" .. string.format("%.20s", generatorsShortcutThree) .. ")"	end
	if generatorsShortcutFour == nil then 		generatorsShortcutFour = " (Unassigned)" 		else generatorsShortcutFour 	= " (" .. string.format("%.20s", generatorsShortcutFour) .. ")" 	end
	if generatorsShortcutFive == nil then 		generatorsShortcutFive = " (Unassigned)" 		else generatorsShortcutFive 	= " (" .. string.format("%.20s", generatorsShortcutFive) .. ")" 	end

	--------------------------------------------------------------------------------
	-- Get Menubar Settings:
	--------------------------------------------------------------------------------
	local menubarShortcutsEnabled = 	settings.get("fcpxHacks.menubarShortcutsEnabled")
	local menubarAutomationEnabled = 	settings.get("fcpxHacks.menubarAutomationEnabled")
	local menubarToolsEnabled = 		settings.get("fcpxHacks.menubarToolsEnabled")
	local menubarHacksEnabled = 		settings.get("fcpxHacks.menubarHacksEnabled")

	--------------------------------------------------------------------------------
	-- Setup Menu:
	--------------------------------------------------------------------------------
	local settingsShapeMenuTable = {
	   	{ title = "Rectangle", 																		fn = function() changeHighlightShape("Rectangle") end,				checked = displayHighlightShapeRectangle	},
	   	{ title = "Circle", 																		fn = function() changeHighlightShape("Circle") end, 				checked = displayHighlightShapeCircle		},
	   	{ title = "Diamond", 																		fn = function() changeHighlightShape("Diamond") end, 				checked = displayHighlightShapeDiamond		},
	}
	local settingsColourMenuTable = {
	   	{ title = "Red", 																			fn = function() changeHighlightColour("Red") end, 					checked = displayHighlightColourRed		},
	   	{ title = "Blue", 																			fn = function() changeHighlightColour("Blue") end, 					checked = displayHighlightColourBlue	},
	   	{ title = "Green", 																			fn = function() changeHighlightColour("Green") end, 				checked = displayHighlightColourGreen	},
	   	{ title = "Yellow", 																		fn = function() changeHighlightColour("Yellow") end, 				checked = displayHighlightColourYellow	},
	}
	local settingsHammerspoonSettings = {
		{ title = "Console...", 																	fn = openHammerspoonConsole },
		{ title = "-" },
		{ title = "-" },
		{ title = "Show Dock Icon", 																fn = toggleHammerspoonDockIcon, 									checked = hammerspoonDockIcon		},
		{ title = "Show Menu Icon", 																fn = toggleHammerspoonMenuIcon, 									checked = hammerspoonMenuIcon		},
		{ title = "-" },
	   	{ title = "Launch at Startup", 																fn = toggleLaunchHammerspoonOnStartup, 								checked = startHammerspoonOnLaunch		},
	   	{ title = "Check for Updates", 																fn = toggleCheckforHammerspoonUpdates, 								checked = hammerspoonCheckForUpdates	},
	}
	local settingsTouchBarLocation = {
	   	{ title = "Mouse Location", 																fn = function() changeTouchBarLocation("Mouse") end,				checked = displayTouchBarLocationMouse, disabled = not touchBarSupported },
	   	{ title = "Top Centre of Timeline", 														fn = function() changeTouchBarLocation("TimelineTopCentre") end,	checked = displayTouchBarLocationTimelineTopCentre, disabled = not touchBarSupported },
	   	{ title = "-" },
	   	{ title = "TIP: Hold down left OPTION", 																																																	disabled = true },
	   	{ title = "key & drag to move Touch Bar.", 																																																	disabled = true },
	}
	local settingsMenubar = {
		{ title = "Show Shortcuts", 																fn = function() toggleMenubarDisplay("Shortcuts") end, 				checked = menubarShortcutsEnabled},
		{ title = "Show Automation", 																fn = function() toggleMenubarDisplay("Automation") end, 			checked = menubarAutomationEnabled},
		{ title = "Show Tools", 																	fn = function() toggleMenubarDisplay("Tools") end, 					checked = menubarToolsEnabled},
		{ title = "Show Hacks", 																	fn = function() toggleMenubarDisplay("Hacks") end, 					checked = menubarHacksEnabled},
		{ title = "-" },
		{ title = "Display Proxy/Original Icon", 													fn = toggleEnableProxyMenuIcon, 									checked = enableProxyMenuIcon},
	   	{ title = "Display This Menu As Icon", 														fn = toggleMenubarDisplayMode, 										checked = displayMenubarAsIcon},
	}
	local settingsMenuTable = {
	    { title = "Menubar Options", 																menu = settingsMenubar},
       	{ title = "-" },
		{ title = "Touch Bar Location", 															menu = settingsTouchBarLocation},
       	{ title = "-" },
	   	{ title = "Highlight Playhead Colour", 														menu = settingsColourMenuTable},
	   	{ title = "Highlight Playhead Shape", 														menu = settingsShapeMenuTable},
       	{ title = "-" },
	   	{ title = "Hammerspoon", 																	menu = settingsHammerspoonSettings},
      	{ title = "-" },
      	{ title = "Check for Updates", 																fn = toggleCheckForUpdates, 										checked = enableCheckForUpdates},
      	{ title = "Enable Debug Mode", 																fn = toggleDebugMode, 												checked = mod.debugMode},
		{ title = "Trash FCPX Hacks Preferences", 													fn = resetSettings },
    	{ title = "-" },
    	{ title = "Created by LateNite Films", 														fn = gotoLateNiteSite },
  	    { title = "Script Version " .. fcpxhacks.scriptVersion, 																																												disabled = true },
	}
	local settingsEffectsShortcutsTable = {
		{ title = "Update Effects List", 															fn = updateEffectsList, 																										disabled = not fcpxRunning },
		{ title = "-" },
		{ title = "Effect Shortcut 1" .. effectsShortcutOne, 										fn = function() assignEffectsShortcut(1) end, 																					disabled = not effectsListUpdated },
		{ title = "Effect Shortcut 2" .. effectsShortcutTwo, 										fn = function() assignEffectsShortcut(2) end, 																					disabled = not effectsListUpdated },
		{ title = "Effect Shortcut 3" .. effectsShortcutThree, 										fn = function() assignEffectsShortcut(3) end, 																					disabled = not effectsListUpdated },
		{ title = "Effect Shortcut 4" .. effectsShortcutFour, 										fn = function() assignEffectsShortcut(4) end, 																					disabled = not effectsListUpdated },
		{ title = "Effect Shortcut 5" .. effectsShortcutFive, 										fn = function() assignEffectsShortcut(5) end, 																					disabled = not effectsListUpdated },
	}
	local settingsTransitionsShortcutsTable = {
		{ title = "Update Transitions List", 														fn = updateTransitionsList, 																									disabled = not fcpxRunning },
		{ title = "-" },
		{ title = "Transition Shortcut 1" .. transitionsShortcutOne, 								fn = function() assignTransitionsShortcut(1) end,																				disabled = not transitionsListUpdated },
		{ title = "Transition Shortcut 2" .. transitionsShortcutTwo, 								fn = function() assignTransitionsShortcut(2) end, 																				disabled = not transitionsListUpdated },
		{ title = "Transition Shortcut 3" .. transitionsShortcutThree, 								fn = function() assignTransitionsShortcut(3) end, 																				disabled = not transitionsListUpdated },
		{ title = "Transition Shortcut 4" .. transitionsShortcutFour, 								fn = function() assignTransitionsShortcut(4) end, 																				disabled = not transitionsListUpdated },
		{ title = "Transition Shortcut 5" .. transitionsShortcutFive, 								fn = function() assignTransitionsShortcut(5) end, 																				disabled = not transitionsListUpdated },
	}
	local settingsTitlesShortcutsTable = {
		{ title = "Update Titles List", 															fn = updateTitlesList, 																											disabled = not fcpxRunning },
		{ title = "-" },
		{ title = "Titles Shortcut 1" .. titlesShortcutOne, 										fn = function() assignTitlesShortcut(1) end,																					disabled = not titlesListUpdated },
		{ title = "Titles Shortcut 2" .. titlesShortcutTwo, 										fn = function() assignTitlesShortcut(2) end, 																					disabled = not titlesListUpdated },
		{ title = "Titles Shortcut 3" .. titlesShortcutThree, 										fn = function() assignTitlesShortcut(3) end, 																					disabled = not titlesListUpdated },
		{ title = "Titles Shortcut 4" .. titlesShortcutFour, 										fn = function() assignTitlesShortcut(4) end, 																					disabled = not titlesListUpdated },
		{ title = "Titles Shortcut 5" .. titlesShortcutFive, 										fn = function() assignTitlesShortcut(5) end, 																					disabled = not titlesListUpdated },
	}
	local settingsGeneratorsShortcutsTable = {
		{ title = "Update Generators List", 														fn = updateGeneratorsList, 																										disabled = not fcpxRunning },
		{ title = "-" },
		{ title = "Generators Shortcut 1" .. generatorsShortcutOne, 								fn = function() assignGeneratorsShortcut(1) end,																				disabled = not generatorsListUpdated },
		{ title = "Generators Shortcut 2" .. generatorsShortcutTwo, 								fn = function() assignGeneratorsShortcut(2) end, 																				disabled = not generatorsListUpdated },
		{ title = "Generators Shortcut 3" .. generatorsShortcutThree, 								fn = function() assignGeneratorsShortcut(3) end, 																				disabled = not generatorsListUpdated },
		{ title = "Generators Shortcut 4" .. generatorsShortcutFour, 								fn = function() assignGeneratorsShortcut(4) end, 																				disabled = not generatorsListUpdated },
		{ title = "Generators Shortcut 5" .. generatorsShortcutFive, 								fn = function() assignGeneratorsShortcut(5) end, 																				disabled = not generatorsListUpdated },
	}
	local menuTable = {
	   	{ title = "Open Final Cut Pro", 															fn = fcp.launch },
		{ title = "-" },
	}
	local shortcutsTable = {
   	    { title = "SHORTCUTS:", 																																																	disabled = true },
	    { title = "Create Optimized Media", 														fn = function() toggleCreateOptimizedMedia(not mod.FFImportCreateOptimizeMedia) end, 												checked = mod.FFImportCreateOptimizeMedia, 						disabled = not fcpxRunning },
	    { title = "Create Multicam Optimized Media", 												fn = function() toggleCreateMulticamOptimizedMedia(not mod.FFCreateOptimizedMediaForMulticamClips) end, 							checked = mod.FFCreateOptimizedMediaForMulticamClips, 			disabled = not fcpxRunning },
	    { title = "Create Proxy Media", 															fn = function() toggleCreateProxyMedia(not mod.FFImportCreateProxyMedia) end, 														checked = mod.FFImportCreateProxyMedia, 						disabled = not fcpxRunning },
	    { title = "Leave Files In Place On Import", 												fn = function() toggleLeaveInPlace(mod.FFImportCopyToMediaFolder) end, 																checked = not mod.FFImportCopyToMediaFolder, 					disabled = not fcpxRunning },
	    { title = "Enable Background Render (" .. mod.FFAutoRenderDelay .. " secs)", 					fn = function() toggleBackgroundRender(not mod.FFAutoStartBGRender) end, 															checked = mod.FFAutoStartBGRender, 								disabled = not fcpxRunning },
   	    { title = "-" },
	}
	local automationTable = {
 	    { title = "AUTOMATION:", 																																																	disabled = true },
   	    { title = "Enable Scrolling Timeline", 														fn = toggleScrollingTimeline, 										checked = scrollingTimelineActive },
   	    { title = "Enable Shortcuts During Fullscreen Playback", 									fn = toggleEnableShortcutsDuringFullscreenPlayback, 				checked = enableShortcutsDuringFullscreenPlayback },
   	    { title = "Close Media Import When Card Inserted", 											fn = toggleMediaImportWatcher, 										checked = enableMediaImportWatcher },
   	    { title = "Assign Effects Shortcuts", 														menu = settingsEffectsShortcutsTable },
   	    { title = "Assign Transitions Shortcuts", 													menu = settingsTransitionsShortcutsTable },
   	    { title = "Assign Titles Shortcuts", 														menu = settingsTitlesShortcutsTable },
   	    { title = "Assign Generators Shortcuts", 													menu = settingsGeneratorsShortcutsTable },
      	{ title = "-" },
	}
	local toolsSettings = {
	   	{ title = "Enable Mobile Notifications", 													fn = toggleEnableMobileNotifications, 								checked = enableMobileNotifications},
   	    { title = "Enable Clipboard History", 														fn = toggleEnableClipboardHistory, 									checked = enableClipboardHistory},
   	    { title = "Enable Shared Clipboard", 														fn = toggleEnableSharedClipboard, 									checked = enableSharedClipboard,							disabled = not enableClipboardHistory},
  	  	{ title = "Enable XML Sharing", 															fn = toggleEnableXMLSharing, 										checked = enableXMLSharing},
	}
	local toolsTable = {
   	    { title = "TOOLS:", 																																																		disabled = true },
   	    { title = "Options", 																		menu = toolsSettings },
      	{ title = "Paste from Clipboard History", 													menu = settingsClipboardHistoryTable },
      	{ title = "Paste from Shared Clipboard", 													menu = settingsSharedClipboardTable },
      	{ title = "Import Shared XML File", 														menu = settingsSharedXMLTable },
      	{ title = "-" },
	}
	local hacksTable = {
   	    { title = "HACKS:", 																																																		disabled = true },
   		{ title = "Enable Hacks Shortcuts in Final Cut Pro", 										fn = toggleEnableHacksShortcutsInFinalCutPro, 						checked = enableHacksShortcutsInFinalCutPro},
   		{ title = "Enable Timecode Overlay", 														fn = toggleTimecodeOverlay, 										checked = mod.FFEnableGuards },
	   	{ title = "Enable Moving Markers", 															fn = toggleMovingMarkers, 											checked = mod.allowMovingMarkers },
       	{ title = "Enable Rendering During Playback", 												fn = togglePerformTasksDuringPlayback, 								checked = not mod.FFSuspendBGOpsDuringPlay },
        { title = "Change Backup Interval (" .. tostring(mod.FFPeriodicBackupInterval) .. " mins)", 	fn = changeBackupInterval },
   	   	{ title = "Change Smart Collections Label", 												fn = changeSmartCollectionsLabel },
        { title = "-" },
    }
	local settingsTable = {
		{ title = "Display Keyboard Shortcuts", 													fn = displayShortcutList },
		{ title = "-" },
      	{ title = "Preferences...", 																menu = settingsMenuTable },
    	{ title = "-" },
    	{ title = "Quit FCPX Hacks", 																fn = quitFCPXHacks},
	}

	--------------------------------------------------------------------------------
	-- Setup Menubar:
	--------------------------------------------------------------------------------
	if menubarShortcutsEnabled then 	menuTable = fnutils.concat(menuTable, shortcutsTable) 	end
	if menubarAutomationEnabled then	menuTable = fnutils.concat(menuTable, automationTable)	end
	if menubarToolsEnabled then 		menuTable = fnutils.concat(menuTable, toolsTable)		end
	if menubarHacksEnabled then 		menuTable = fnutils.concat(menuTable, hacksTable)		end

	menuTable = fnutils.concat(menuTable, settingsTable)

	--------------------------------------------------------------------------------
	-- Check for Updates:
	--------------------------------------------------------------------------------
	if latestScriptVersion ~= nil then
		if latestScriptVersion > fcpxhacks.scriptVersion then
			table.insert(menuTable, 1, { title = "UPDATE AVAILABLE (Version " .. latestScriptVersion .. ")", fn = getScriptUpdate})
			table.insert(menuTable, 2, { title = "-" })
		end
	end

	--------------------------------------------------------------------------------
	-- Set the Menu:
	--------------------------------------------------------------------------------
	fcpxMenubar:setMenu(menuTable)
end

--------------------------------------------------------------------------------
-- DISPLAY A LIST OF ALL SHORTCUTS:
--------------------------------------------------------------------------------
function displayShortcutList()

	local enableHacksShortcutsInFinalCutPro = settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro")
	if enableHacksShortcutsInFinalCutPro == nil then enableHacksShortcutsInFinalCutPro = false end

	if enableHacksShortcutsInFinalCutPro then
		dialog.displayMessage("As you have enabled Hacks Shortcuts within the settings, you can refer to the Command Editor within Final Cut Pro review and change the shortcut selections.")
	else
		local whatMessage = [[The default FCPX Hacks Shortcut Keys are:

---------------------------------
CONTROL+OPTION+COMMAND:
---------------------------------
L = Launch Final Cut Pro (System Wide)

Z = Toggle Touch Bar

W = Toggle Scrolling Timeline

H = Highlight Browser Playhead
F = Reveal in Browser & Highlight
S = Single Match Frame & Highlight

D = Reveal Multicam in Browser & Highlight
G = Reveal Multicam in Angle Editor & Highlight

E = Batch Export from Browser

B = Change Backup Interval

T = Toggle Timecode Overlays
Y = Toggle Moving Markers
P = Toggle Rendering During Playback

M = Select Color Board Puck 1
, = Select Color Board Puck 2
. = Select Color Board Puck 3
/ = Select Color Board Puck 4

1-9 = Restore Keyword Preset

+ = Increase Timeline Clip Height
- = Decrease Timeline Clip Height

-----------------------------------------
CONTROL+OPTION+COMMAND+SHIFT:
-----------------------------------------
1-9 = Save Keyword Preset

-----------------------------------------
CONTROL+SHIFT:
-----------------------------------------
1-5 = Apply Effect]]

		dialog.displayMessage(whatMessage)
	end
end

--------------------------------------------------------------------------------
-- UPDATE EFFECTS/TRANSITIONS/TITLES/GENERATORS LISTS:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- GET LIST OF EFFECTS:
	--------------------------------------------------------------------------------
	function updateEffectsList()

		--------------------------------------------------------------------------------
		-- Make sure Final Cut Pro is active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Warning message:
		--------------------------------------------------------------------------------
		dialog.displayMessage("Depending on how many Effects you have installed this might take quite a few seconds.\n\nPlease do not use your mouse or keyboard until you're notified that this process is complete.")

		--------------------------------------------------------------------------------
		-- Get Timeline Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProTimelineButtonBar = fcp.getTimelineButtonBar()
		if finalCutProTimelineButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar.\n\nError occured in effectsShortcut() whilst using fcp.getTimelineButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Find Effects Browser Button:
		--------------------------------------------------------------------------------
		local whichRadioGroup = nil
		for i=1, finalCutProTimelineButtonBar:attributeValueCount("AXChildren") do
			if finalCutProTimelineButtonBar[i]:attributeValue("AXRole") == "AXRadioGroup" then
				if finalCutProTimelineButtonBar[i]:attributeValue("AXIdentifier") == "_NS:165" then
					whichRadioGroup = i
				end
			end
		end
		if whichRadioGroup == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar Radio Group.\n\nError occured in effectsShortcut().")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Effects or Transitions Panel Open?
		--------------------------------------------------------------------------------
		local whichPanelActivated = "None"
		if finalCutProTimelineButtonBar[whichRadioGroup][1] ~= nil then
			if finalCutProTimelineButtonBar[whichRadioGroup][1]:attributeValue("AXValue") == 1 then whichPanelActivated = "Effects" end
			if finalCutProTimelineButtonBar[whichRadioGroup][2]:attributeValue("AXValue") == 1 then whichPanelActivated = "Transitions" end
		end

		--------------------------------------------------------------------------------
		-- Make sure Video Effects panel is open:
		--------------------------------------------------------------------------------
		local effectsBrowserButton = finalCutProTimelineButtonBar[whichRadioGroup][1]
		if effectsBrowserButton ~= nil then
			if effectsBrowserButton:attributeValue("AXValue") == 0 then
				local presseffectsBrowserButtonResult = effectsBrowserButton:performAction("AXPress")
				if presseffectsBrowserButtonResult == nil then
					dialog.displayErrorMessage("Unable to press Effects Browser Button icon.")
					showTouchbar()
					return "Fail"
				end
			end
		else
			dialog.displayErrorMessage("Unable to activate Video Effects Panel.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Make sure "Installed Effects" is selected:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Group:
			--------------------------------------------------------------------------------
			local finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserSplitGroup = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXRole") == "AXSplitGroup" then
					if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXIdentifier") == "_NS:452" then
						whichEffectsBrowserSplitGroup = i
					end
				end
			end
			if whichEffectsBrowserSplitGroup == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Split Group.\n\nError occured in effectsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserPopupButton = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup]:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXRole") == "AXPopUpButton" then
					if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXIdentifier") == "_NS:45" then
						whichEffectsBrowserPopupButton = i
					end
				end
			end
			if whichEffectsBrowserPopupButton == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Popup Button.\n\nError occured in effectsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Check that "Installed Effects" is selected:
			--------------------------------------------------------------------------------
			local installedEffectsPopup = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton]
			if installedEffectsPopup ~= nil then
				if installedEffectsPopup:attributeValue("AXValue") ~= "Installed Effects" then
					installedEffectsPopup:performAction("AXPress")
					finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()
					installedEffectsPopupMenuItem = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton][1][1]
					installedEffectsPopupMenuItem:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to find 'Installed Effects' popup.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end

		--------------------------------------------------------------------------------
		-- Make sure there's nothing in the search box:
		--------------------------------------------------------------------------------
		local effectsSearchCancelButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
				effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
			end
		end
		if effectsSearchCancelButton ~= nil then
			effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
			if effectsSearchCancelButtonResult == nil then
				dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Click 'All Video':
		--------------------------------------------------------------------------------
		local allVideoAndAudioButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1][3] ~= nil then
						allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][3]
					end
				end
			end
		end
		if allVideoAndAudioButton ~= nil then
			allVideoAndAudioButton:setAttributeValue("AXSelected", true)
		else

			--------------------------------------------------------------------------------
			-- Make sure Effects Browser Sidebar is Visible:
			--------------------------------------------------------------------------------
			effectsBrowserSidebar = finalCutProEffectsTransitionsBrowserGroup[2]
			if effectsBrowserSidebar ~= nil then
				if effectsBrowserSidebar:attributeValue("AXValue") == 1 then
					effectsBrowserSidebar:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to locate Effects Browser Sidebar button.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Click 'All Video':
			--------------------------------------------------------------------------------
			local allVideoAndAudioButton = nil
			if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
						if finalCutProEffectsTransitionsBrowserGroup[1][1][1][3] ~= nil then
							allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][3]
						end
					end
				end
			end
			if allVideoAndAudioButton ~= nil then
				allVideoAndAudioButton:setAttributeValue("AXSelected", true)
			else
				dialog.displayErrorMessage("Unable to locate 'All Video & Audio' button.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay...
		--------------------------------------------------------------------------------
		timer.usleep(100000)

		--------------------------------------------------------------------------------
		-- Get list of All Video Effects:
		--------------------------------------------------------------------------------
		effectsList = finalCutProEffectsTransitionsBrowserGroup[1][4][1]
		local allVideoEffects = {}
		if effectsList ~= nil then
			for i=1, #effectsList:attributeValue("AXChildren") do
				allVideoEffects[i] = effectsList:attributeValue("AXChildren")[i]:attributeValue("AXTitle")
			end
		else
			dialog.displayErrorMessage("Unable to get list of all effects.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Click 'All Audio':
		--------------------------------------------------------------------------------
		allAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1]
		local secondAll = false
		local whichAudioButton = nil
		if allAudioButton ~= nil then
			for i=1, #allAudioButton:attributeValue("AXChildren") do
				if allAudioButton[i][1] ~= nil then
					if allAudioButton[i][1][1] ~= nil then
						if allAudioButton[i][1][1]:attributeValue("AXValue") == "All" then
							if secondAll then
								whichAudioButton = i
							else
								secondAll = true
							end
						end
					end
				end
			end
			allAudioButton[whichAudioButton]:setAttributeValue("AXSelected", true)
		else
			dialog.displayErrorMessage("Unable to locate 'All Audio' button.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get list of All Audio Effects:
		--------------------------------------------------------------------------------
		effectsList = finalCutProEffectsTransitionsBrowserGroup[1][4][1]
		local allAudioEffects = {}
		if effectsList ~= nil then
			for i=1, #effectsList:attributeValue("AXChildren") do
				allAudioEffects[i] = effectsList:attributeValue("AXChildren")[i]:attributeValue("AXTitle")
			end
		else
			dialog.displayErrorMessage("Unable to get list of all effects.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay:
		--------------------------------------------------------------------------------
		timer.doAfter(0.1, function()

			--------------------------------------------------------------------------------
			-- Make sure there's nothing in the search box:
			--------------------------------------------------------------------------------
			local effectsSearchCancelButton = nil
			if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
					effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
				end
			end
			if effectsSearchCancelButton ~= nil then
				effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
				if effectsSearchCancelButtonResult == nil then
					dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in effectsShortcut().")
					showTouchbar()
					return "Fail"
				end
			end

			--------------------------------------------------------------------------------
			-- Restore Effects or Transitions Panel:
			--------------------------------------------------------------------------------
			if whichPanelActivated == "None" then
				finalCutProTimelineButtonBar[whichRadioGroup][1]:performAction("AXPress")
			elseif whichPanelActivated == "Transitions" then
				finalCutProTimelineButtonBar[whichRadioGroup][2]:performAction("AXPress")
			end

			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			showTouchbar()

		end)

		--------------------------------------------------------------------------------
		-- All done!
		--------------------------------------------------------------------------------
		if #allVideoEffects == 0 or #allAudioEffects == 0 then
			dialog.displayMessage("Unfortunately the Effects List was not successfully updated.\n\nPlease try again.")
			return "Fail"
		else
			--------------------------------------------------------------------------------
			-- Save Results to Settings:
			--------------------------------------------------------------------------------
			settings.set("fcpxHacks.allVideoEffects", allVideoEffects)
			settings.set("fcpxHacks.allAudioEffects", allAudioEffects)
			settings.set("fcpxHacks.effectsListUpdated", true)

			--------------------------------------------------------------------------------
			-- Update Chooser:
			--------------------------------------------------------------------------------
			mod.fcpxChooser:refreshChoicesCallback()

			--------------------------------------------------------------------------------
			-- Refresh Menubar:
			--------------------------------------------------------------------------------
			refreshMenuBar()

			--------------------------------------------------------------------------------
			-- Let the user know everything's good:
			--------------------------------------------------------------------------------
			dialog.displayMessage("Effects List updated successfully.")
		end

	end

	--------------------------------------------------------------------------------
	-- GET LIST OF TRANSITIONS:
	--------------------------------------------------------------------------------
	function updateTransitionsList()

		--------------------------------------------------------------------------------
		-- Make sure Final Cut Pro is active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Warning message:
		--------------------------------------------------------------------------------
		dialog.displayMessage("Depending on how many Transitions you have installed this might take quite a few seconds.\n\nPlease do not use your mouse or keyboard until you're notified that this process is complete.")

		--------------------------------------------------------------------------------
		-- Get Timeline Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProTimelineButtonBar = fcp.getTimelineButtonBar()
		if finalCutProTimelineButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar.\n\nError occured in effectsShortcut() whilst using fcp.getTimelineButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Find Transitions Browser Button:
		--------------------------------------------------------------------------------
		local whichRadioGroup = nil
		for i=1, finalCutProTimelineButtonBar:attributeValueCount("AXChildren") do
			if finalCutProTimelineButtonBar[i]:attributeValue("AXRole") == "AXRadioGroup" then
				if finalCutProTimelineButtonBar[i]:attributeValue("AXIdentifier") == "_NS:165" then
					whichRadioGroup = i
				end
			end
		end
		if whichRadioGroup == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar Radio Group.\n\nError occured in transitionsShortcut().")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Effects or Transitions Panel Open?
		--------------------------------------------------------------------------------
		local whichPanelActivated = "None"
		if finalCutProTimelineButtonBar[whichRadioGroup][1] ~= nil then
			if finalCutProTimelineButtonBar[whichRadioGroup][1]:attributeValue("AXValue") == 1 then whichPanelActivated = "Effects" end
			if finalCutProTimelineButtonBar[whichRadioGroup][2]:attributeValue("AXValue") == 1 then whichPanelActivated = "Transitions" end
		end

		--------------------------------------------------------------------------------
		-- Make sure Transitions panel is open:
		--------------------------------------------------------------------------------
		local effectsBrowserButton = finalCutProTimelineButtonBar[whichRadioGroup][2]
		if effectsBrowserButton ~= nil then
			if effectsBrowserButton:attributeValue("AXValue") == 0 then
				local presseffectsBrowserButtonResult = effectsBrowserButton:performAction("AXPress")
				if presseffectsBrowserButtonResult == nil then
					dialog.displayErrorMessage("Unable to press Effects Browser Button icon.")
					showTouchbar()
					return "Fail"
				end
			end
		else
			dialog.displayErrorMessage("Unable to activate Video Effects Panel.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Make sure "Installed Effects" is selected:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Group:
			--------------------------------------------------------------------------------
			local finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserSplitGroup = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXRole") == "AXSplitGroup" then
					if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXIdentifier") == "_NS:452" then
						whichEffectsBrowserSplitGroup = i
					end
				end
			end
			if whichEffectsBrowserSplitGroup == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Split Group.\n\nError occured in transitionsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserPopupButton = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup]:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXRole") == "AXPopUpButton" then
					if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXIdentifier") == "_NS:45" then
						whichEffectsBrowserPopupButton = i
					end
				end
			end
			if whichEffectsBrowserPopupButton == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Popup Button.\n\nError occured in transitionsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Check that "Installed Effects" is selected:
			--------------------------------------------------------------------------------
			local installedEffectsPopup = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton]
			if installedEffectsPopup ~= nil then
				if installedEffectsPopup:attributeValue("AXValue") ~= "Installed Effects" then
					installedEffectsPopup:performAction("AXPress")
					finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()
					installedEffectsPopupMenuItem = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton][1][1]
					installedEffectsPopupMenuItem:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to find 'Installed Effects' popup.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end

		--------------------------------------------------------------------------------
		-- Make sure there's nothing in the search box:
		--------------------------------------------------------------------------------
		local effectsSearchCancelButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
				effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
			end
		end
		if effectsSearchCancelButton ~= nil then
			effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
			if effectsSearchCancelButtonResult == nil then
				dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Click 'All' Transitions:
		--------------------------------------------------------------------------------
		local allVideoAndAudioButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1][1] ~= nil then
						allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][1]
					end
				end
			end
		end
		if allVideoAndAudioButton ~= nil then
			allVideoAndAudioButton:setAttributeValue("AXSelected", true)
		else

			--------------------------------------------------------------------------------
			-- Make sure Transitions Browser Sidebar is Visible:
			--------------------------------------------------------------------------------
			effectsBrowserSidebar = finalCutProEffectsTransitionsBrowserGroup[2]
			if effectsBrowserSidebar ~= nil then
				if effectsBrowserSidebar:attributeValue("AXValue") == 1 then
					effectsBrowserSidebar:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to locate Effects Browser Sidebar button.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Click 'All' Transitions:
			--------------------------------------------------------------------------------
			local allVideoAndAudioButton = nil
			if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
						if finalCutProEffectsTransitionsBrowserGroup[1][1][1][1] ~= nil then
							allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][1]
						end
					end
				end
			end
			if allVideoAndAudioButton ~= nil then
				allVideoAndAudioButton:setAttributeValue("AXSelected", true)
			else
				dialog.displayErrorMessage("Unable to locate 'All Video & Audio' button.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay:
		--------------------------------------------------------------------------------
		timer.usleep(100000)

		--------------------------------------------------------------------------------
		-- Get list of All Transitions:
		--------------------------------------------------------------------------------
		local transitionsList = finalCutProEffectsTransitionsBrowserGroup[1][4][1]
		local allTransitions = {}
		if transitionsList ~= nil then
			for i=1, #transitionsList:attributeValue("AXChildren") do
				allTransitions[i] = transitionsList:attributeValue("AXChildren")[i]:attributeValue("AXTitle")
			end
		else
			dialog.displayErrorMessage("Unable to get list of all transitions.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Check to make sure it all worked:
		--------------------------------------------------------------------------------
		if #allTransitions == 0 or #allTransitions == 0 then
			dialog.displayMessage("Unfortunately the Transitions List was not successfully updated.\n\nPlease try again.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay:
		--------------------------------------------------------------------------------
		timer.usleep(100000)

		--------------------------------------------------------------------------------
		-- Make sure there's nothing in the search box:
		--------------------------------------------------------------------------------
		local effectsSearchCancelButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
				effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
			end
		end
		if effectsSearchCancelButton ~= nil then
			effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
			if effectsSearchCancelButtonResult == nil then
				dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Restore Effects or Transitions Panel:
		--------------------------------------------------------------------------------
		if whichPanelActivated == "Effects" then
			finalCutProTimelineButtonBar[whichRadioGroup][1]:performAction("AXPress")
		elseif whichPanelActivated == "None" then
			finalCutProTimelineButtonBar[whichRadioGroup][2]:performAction("AXPress")
		end

		--------------------------------------------------------------------------------
		-- Save Results to Settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.allTransitions", allTransitions)
		settings.set("fcpxHacks.transitionsListUpdated", true)

		--------------------------------------------------------------------------------
		-- Update Chooser:
		--------------------------------------------------------------------------------
		mod.fcpxChooser:refreshChoicesCallback()

		--------------------------------------------------------------------------------
		-- Refresh Menubar:
		--------------------------------------------------------------------------------
		refreshMenuBar()

		--------------------------------------------------------------------------------
		-- Let the user know everything's good:
		--------------------------------------------------------------------------------
		dialog.displayMessage("Transitions List updated successfully.")

		--------------------------------------------------------------------------------
		-- Show the Touch Bar:
		--------------------------------------------------------------------------------
		showTouchbar()

	end

	--------------------------------------------------------------------------------
	-- GET LIST OF TITLES:
	--------------------------------------------------------------------------------
	function updateTitlesList()

		--------------------------------------------------------------------------------
		-- Make sure Final Cut Pro is active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Warning message:
		--------------------------------------------------------------------------------
		dialog.displayMessage("Depending on how many Titles you have installed this might take quite a few seconds.\n\nPlease do not use your mouse or keyboard until you're notified that this process is complete.")

		--------------------------------------------------------------------------------
		-- Get Browser Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProBrowserButtonBar = fcp.getBrowserButtonBar()
		if finalCutProBrowserButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Browser Button Bar.\n\nError occured in updateTitlesList() whilst using fcp.getBrowserButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Button IDs:
		--------------------------------------------------------------------------------
		local libariesButtonID = nil
		local photosAudioButtonID = nil
		local titlesGeneratorsButtonID = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

				--------------------------------------------------------------------------------
				-- Button 1: Libraries
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
					libariesButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 2: Photos/Audio
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
					photosAudioButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 3: Titles/Transitions
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
					titlesGeneratorsButtonID = i
				end

			end
		end
		if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
			dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in updateTitlesList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Which Browser Panel is Open?
		--------------------------------------------------------------------------------
		local whichBrowserPanelWasOpen = nil
		if finalCutProBrowserButtonBar[libariesButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "Library" end
		if finalCutProBrowserButtonBar[photosAudioButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "PhotosAndAudio" end
		if finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "TitlesAndGenerators" end

		--------------------------------------------------------------------------------
		-- If Titles & Generators is Closed, let's open it:
		--------------------------------------------------------------------------------
		if whichBrowserPanelWasOpen ~= "TitlesAndGenerators" then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Which Split Group?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSplitGroup = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXSplitGroup" then
				titlesGeneratorsSplitGroup = i
				goto titlesGeneratorsSplitGroupExit
			end
		end
		::titlesGeneratorsSplitGroupExit::
		if titlesGeneratorsSplitGroup == nil then
			dialog.displayErrorMessage("Unable to find Titles/Generators Split Group.\n\nError occured in updateTitlesList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Is the Side Bar Closed?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSideBarClosed = true
		if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1] ~= nil then
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][1] ~= nil then
					titlesGeneratorsSideBarClosed = false
				end
			end
		end
		if titlesGeneratorsSideBarClosed then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Make sure Titles is selected:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][1]:setAttributeValue("AXSelected", true)
		if result == nil then
			dialog.displayErrorMessage("Unable to select Titles from List.\n\nError occured in updateTitlesList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Popup Button:
		--------------------------------------------------------------------------------
		local titlesPopupButton = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXPopUpButton" then
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:46" then
					titlesPopupButton = i
					goto titlesGeneratorsDropdownExit
				end
			end
		end
		if titlesPopupButton == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Popup Button.\n\nError occured in updateTitlesList().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsDropdownExit::

		--------------------------------------------------------------------------------
		-- Make sure Titles/Generators Popup Button is set to Installed Titles:
		--------------------------------------------------------------------------------
		if finalCutProBrowserButtonBar[titlesPopupButton]:attributeValue("AXValue") ~= "Installed Titles" then
			local result = finalCutProBrowserButtonBar[titlesPopupButton]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generators Popup Button.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end

			local result = finalCutProBrowserButtonBar[titlesPopupButton][1][1]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press First Popup Item.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Group:
		--------------------------------------------------------------------------------
		local titlesGeneratorsGroup = nil
		for i=1, finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup]:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXRole") == "AXScrollArea" then
						if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXIdentifier") == "_NS:9" then
							titlesGeneratorsGroup = i
							goto titlesGeneratorsGroupExit
						end
					end
				end
			end
		end
		if titlesGeneratorsGroup == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Group.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsGroupExit::

		--------------------------------------------------------------------------------
		-- Get list of all Titles:
		--------------------------------------------------------------------------------
		local allTitles = {}
		for i=1, #finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1]:attributeValue("AXChildren") do
			allTitles[i] = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][i]:attributeValue("AXTitle")
		end

		--------------------------------------------------------------------------------
		-- No Titles Found:
		--------------------------------------------------------------------------------
		if next(allTitles) == nil then
			dialog.displayMessage("Unfortunately the Titles List was not successfully updated.\n\nPlease try again.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Button IDs Again:
		--------------------------------------------------------------------------------
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

				--------------------------------------------------------------------------------
				-- Button 1: Libraries
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
					libariesButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 2: Photos/Audio
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
					photosAudioButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 3: Titles/Transitions
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
					titlesGeneratorsButtonID = i
				end

			end
		end
		if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
			dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in updateTitlesList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Go back to previously selected panel:
		--------------------------------------------------------------------------------
		if whichBrowserPanelWasOpen == "Library" then
			local result = finalCutProBrowserButtonBar[libariesButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayMessage("Unable to press Libraries Button.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end
		end
		if whichBrowserPanelWasOpen == "PhotosAndAudio" then
			local result = finalCutProBrowserButtonBar[photosAudioButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayMessage("Unable to press Photos & Audio Button.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end
		end
		if titlesGeneratorsSideBarClosed then
			local result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Save Results to Settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.allTitles", allTitles)
		settings.set("fcpxHacks.titlesListUpdated", true)

		--------------------------------------------------------------------------------
		-- Update Chooser:
		--------------------------------------------------------------------------------
		mod.fcpxChooser:refreshChoicesCallback()

		--------------------------------------------------------------------------------
		-- Refresh Menubar:
		--------------------------------------------------------------------------------
		refreshMenuBar()

		--------------------------------------------------------------------------------
		-- Let the user know everything's good:
		--------------------------------------------------------------------------------
		dialog.displayMessage("Titles List updated successfully.")

	end

	--------------------------------------------------------------------------------
	-- GET LIST OF GENERATORS:
	--------------------------------------------------------------------------------
	function updateGeneratorsList()

		--------------------------------------------------------------------------------
		-- Make sure Final Cut Pro is active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Warning message:
		--------------------------------------------------------------------------------
		dialog.displayMessage("Depending on how many Generators you have installed this might take quite a few seconds.\n\nPlease do not use your mouse or keyboard until you're notified that this process is complete.")

		--------------------------------------------------------------------------------
		-- Get Browser Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProBrowserButtonBar = fcp.getBrowserButtonBar()
		if finalCutProBrowserButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Browser Button Bar.\n\nError occured in updateGeneratorsList() whilst using fcp.getBrowserButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Button IDs:
		--------------------------------------------------------------------------------
		local libariesButtonID = nil
		local photosAudioButtonID = nil
		local titlesGeneratorsButtonID = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

				--------------------------------------------------------------------------------
				-- Button 1: Libraries
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
					libariesButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 2: Photos/Audio
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
					photosAudioButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 3: Titles/Transitions
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
					titlesGeneratorsButtonID = i
				end

			end
		end
		if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
			dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Which Browser Panel is Open?
		--------------------------------------------------------------------------------
		local whichBrowserPanelWasOpen = nil
		if finalCutProBrowserButtonBar[libariesButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "Library" end
		if finalCutProBrowserButtonBar[photosAudioButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "PhotosAndAudio" end
		if finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "TitlesAndGenerators" end

		--------------------------------------------------------------------------------
		-- If Titles & Generators is Closed, let's open it:
		--------------------------------------------------------------------------------
		if whichBrowserPanelWasOpen ~= "TitlesAndGenerators" then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in updateGeneratorsList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Which Split Group?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSplitGroup = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXSplitGroup" then
				titlesGeneratorsSplitGroup = i
				goto titlesGeneratorsSplitGroupExit
			end
		end
		::titlesGeneratorsSplitGroupExit::
		if titlesGeneratorsSplitGroup == nil then
			dialog.displayErrorMessage("Unable to find Titles/Generators Split Group.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Is the Side Bar Closed?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSideBarClosed = true
		if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1] ~= nil then
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][1] ~= nil then
					titlesGeneratorsSideBarClosed = false
				end
			end
		end
		if titlesGeneratorsSideBarClosed then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in updateGeneratorsList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Find Generators Row:
		--------------------------------------------------------------------------------
		local generatorsRow = nil
		local foundTitles = false
		for i=1, finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1]:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][i][1]:attributeValue("AXRole") == "AXGroup" then
				if foundTitles == false then
					foundTitles = true
				else
					generatorsRow = i
					goto generatorsRowExit
				end
			end
		end
		::generatorsRowExit::
		if generatorsRow == nil then
			dialog.displayErrorMessage("Unable to find Generators Row.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Select Generators Row:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][generatorsRow]:setAttributeValue("AXSelected", true)
		if result == nil then
			dialog.displayErrorMessage("Unable to select Generators from Sidebar.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Popup Button:
		--------------------------------------------------------------------------------
		local titlesPopupButton = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXPopUpButton" then
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:46" then
					titlesPopupButton = i
					goto titlesGeneratorsDropdownExit
				end
			end
		end
		if titlesPopupButton == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Popup Button.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsDropdownExit::

		--------------------------------------------------------------------------------
		-- Make sure Titles/Generators Popup Button is set to Installed Titles:
		--------------------------------------------------------------------------------
		if finalCutProBrowserButtonBar[titlesPopupButton]:attributeValue("AXValue") ~= "Installed Generators" then
			local result = finalCutProBrowserButtonBar[titlesPopupButton]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generators Popup Button.\n\nError occured in updateGeneratorsList().")
				showTouchbar()
				return "Fail"
			end

			local result = finalCutProBrowserButtonBar[titlesPopupButton][1][1]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press First Popup Item.\n\nError occured in updateGeneratorsList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Group:
		--------------------------------------------------------------------------------
		local titlesGeneratorsGroup = nil
		for i=1, finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup]:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXRole") == "AXScrollArea" then
						if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXIdentifier") == "_NS:9" then
							titlesGeneratorsGroup = i
							goto titlesGeneratorsGroupExit
						end
					end
				end
			end
		end
		if titlesGeneratorsGroup == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Group.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsGroupExit::

		--------------------------------------------------------------------------------
		-- Get list of all Generators:
		--------------------------------------------------------------------------------
		local allGenerators = {}
		for i=1, #finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1]:attributeValue("AXChildren") do
			allGenerators[i] = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][i]:attributeValue("AXTitle")
		end

		--------------------------------------------------------------------------------
		-- No Titles Found:
		--------------------------------------------------------------------------------
		if next(allGenerators) == nil then
			dialog.displayMessage("Unfortunately the Generators List was not successfully updated.\n\nPlease try again.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Button IDs Again:
		--------------------------------------------------------------------------------
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

				--------------------------------------------------------------------------------
				-- Button 1: Libraries
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
					libariesButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 2: Photos/Audio
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
					photosAudioButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 3: Titles/Transitions
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
					titlesGeneratorsButtonID = i
				end

			end
		end
		if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
			dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Go back to previously selected panel:
		--------------------------------------------------------------------------------
		if whichBrowserPanelWasOpen == "Library" then
			local result = finalCutProBrowserButtonBar[libariesButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayMessage("Unable to press Libraries Button.\n\nError occured in updateGeneratorsList().")
				showTouchbar()
				return "Fail"
			end
		end
		if whichBrowserPanelWasOpen == "PhotosAndAudio" then
			local result = finalCutProBrowserButtonBar[photosAudioButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayMessage("Unable to press Photos & Audio Button.\n\nError occured in updateGeneratorsList().")
				showTouchbar()
				return "Fail"
			end
		end
		if titlesGeneratorsSideBarClosed then
			local result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in updateGeneratorsList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Save Results to Settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.allGenerators", allGenerators)
		settings.set("fcpxHacks.generatorsListUpdated", true)

		--------------------------------------------------------------------------------
		-- Update Chooser:
		--------------------------------------------------------------------------------
		mod.fcpxChooser:refreshChoicesCallback()

		--------------------------------------------------------------------------------
		-- Refresh Menubar:
		--------------------------------------------------------------------------------
		refreshMenuBar()

		--------------------------------------------------------------------------------
		-- Let the user know everything's good:
		--------------------------------------------------------------------------------
		dialog.displayMessage("Generators List updated successfully.")

	end

--------------------------------------------------------------------------------
-- ASSIGN EFFECTS/TRANSITIONS/TITLES/GENERATORS SHORTCUTS:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- ASSIGN EFFECTS SHORTCUT:
	--------------------------------------------------------------------------------
	function assignEffectsShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Was Final Cut Pro Open?
		--------------------------------------------------------------------------------
		local wasFinalCutProOpen = fcp.frontmost()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local effectsListUpdated 	= settings.get("fcpxHacks.effectsListUpdated")
		local allVideoEffects 		= settings.get("fcpxHacks.allVideoEffects")
		local allAudioEffects 		= settings.get("fcpxHacks.allAudioEffects")

		--------------------------------------------------------------------------------
		-- Error Checking:
		--------------------------------------------------------------------------------
		if not effectsListUpdated then
			dialog.displayMessage("The Effects List doesn't appear to be up-to-date.\n\nPlease update the Effects List and try again.")
			return "Failed"
		end
		if allVideoEffects == nil or allAudioEffects == nil then
			dialog.displayMessage("The Effects List doesn't appear to be up-to-date.\n\nPlease update the Effects List and try again.")
			return "Failed"
		end
		if next(allVideoEffects) == nil or next(allAudioEffects) == nil then
			dialog.displayMessage("The Effects List doesn't appear to be up-to-date.\n\nPlease update the Effects List and try again.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Video Effects List:
		--------------------------------------------------------------------------------
		local effectChooserChoices = {}
		if allVideoEffects ~= nil and next(allVideoEffects) ~= nil then
			for i=1, #allVideoEffects do
				individualEffect = {
					["text"] = allVideoEffects[i],
					["subText"] = "Video Effect",
					["function"] = "effectsShortcut",
					["function1"] = allVideoEffects[i],
					["function2"] = "",
					["function3"] = "",
					["whichShortcut"] = whichShortcut,
					["wasFinalCutProOpen"] = wasFinalCutProOpen,
				}
				table.insert(effectChooserChoices, 1, individualEffect)
			end
		end

		--------------------------------------------------------------------------------
		-- Audio Effects List:
		--------------------------------------------------------------------------------
		if allAudioEffects ~= nil and next(allAudioEffects) ~= nil then
			for i=1, #allAudioEffects do
				individualEffect = {
					["text"] = allAudioEffects[i],
					["subText"] = "Audio Effect",
					["function"] = "effectsShortcut",
					["function1"] = allAudioEffects[i],
					["function2"] = "",
					["function3"] = "",
					["whichShortcut"] = whichShortcut,
					["wasFinalCutProOpen"] = wasFinalCutProOpen,
				}
				table.insert(effectChooserChoices, 1, individualEffect)
			end
		end

		--------------------------------------------------------------------------------
		-- Sort everything:
		--------------------------------------------------------------------------------
		table.sort(effectChooserChoices, function(a, b) return a.text < b.text end)

		effectChooser = chooser.new(effectChooserAction):bgDark(true)
														:fgColor(drawing.color.x11.snow)
														:subTextColor(drawing.color.x11.snow)
														:choices(effectChooserChoices)
														:show()

	end

		--------------------------------------------------------------------------------
		-- ASSIGN EFFECTS SHORTCUT CHOOSER ACTION:
		--------------------------------------------------------------------------------
		function effectChooserAction(result)

			--------------------------------------------------------------------------------
			-- Hide Chooser:
			--------------------------------------------------------------------------------
			effectChooser:hide()

			--------------------------------------------------------------------------------
			-- Perform Specific Function:
			--------------------------------------------------------------------------------
			if result ~= nil then
				--------------------------------------------------------------------------------
				-- Save the selection:
				--------------------------------------------------------------------------------
				whichShortcut = result["whichShortcut"]
				if whichShortcut == 1 then settings.set("fcpxHacks.effectsShortcutOne", 		result["text"]) end
				if whichShortcut == 2 then settings.set("fcpxHacks.effectsShortcutTwo", 		result["text"]) end
				if whichShortcut == 3 then settings.set("fcpxHacks.effectsShortcutThree", 	result["text"]) end
				if whichShortcut == 4 then settings.set("fcpxHacks.effectsShortcutFour", 	result["text"]) end
				if whichShortcut == 5 then settings.set("fcpxHacks.effectsShortcutFive", 	result["text"]) end
			end

			--------------------------------------------------------------------------------
			-- Put focus back in Final Cut Pro:
			--------------------------------------------------------------------------------
			if result["wasFinalCutProOpen"] then
				fcp.launch()
			end

			--------------------------------------------------------------------------------
			-- Refresh Menubar:
			--------------------------------------------------------------------------------
			refreshMenuBar()

		end

	--------------------------------------------------------------------------------
	-- ASSIGN TRANSITIONS SHORTCUT:
	--------------------------------------------------------------------------------
	function assignTransitionsShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Was Final Cut Pro Open?
		--------------------------------------------------------------------------------
		local wasFinalCutProOpen = fcp.frontmost()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local transitionsListUpdated = settings.get("fcpxHacks.transitionsListUpdated")
		local allTransitions = settings.get("fcpxHacks.allTransitions")

		--------------------------------------------------------------------------------
		-- Error Checking:
		--------------------------------------------------------------------------------
		if not transitionsListUpdated then
			dialog.displayMessage("The Effects List doesn't appear to be up-to-date.\n\nPlease update the Effects List and try again.")
			return "Failed"
		end
		if allTransitions == nil then
			dialog.displayMessage("The Effects List doesn't appear to be up-to-date.\n\nPlease update the Effects List and try again.")
			return "Failed"
		end
		if next(allTransitions) == nil then
			dialog.displayMessage("The Effects List doesn't appear to be up-to-date.\n\nPlease update the Effects List and try again.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Video Effects List:
		--------------------------------------------------------------------------------
		local transitionChooserChoices = {}
		if allTransitions ~= nil and next(allTransitions) ~= nil then
			for i=1, #allTransitions do
				individualEffect = {
					["text"] = allTransitions[i],
					["subText"] = "Transition",
					["function"] = "transitionsShortcut",
					["function1"] = allTransitions[i],
					["function2"] = "",
					["function3"] = "",
					["whichShortcut"] = whichShortcut,
					["wasFinalCutProOpen"] = wasFinalCutProOpen,
				}
				table.insert(transitionChooserChoices, 1, individualEffect)
			end
		end

		--------------------------------------------------------------------------------
		-- Sort everything:
		--------------------------------------------------------------------------------
		table.sort(transitionChooserChoices, function(a, b) return a.text < b.text end)

		transitionChooser = chooser.new(transitionsChooserAction):bgDark(true)
																 :fgColor(drawing.color.x11.snow)
																 :subTextColor(drawing.color.x11.snow)
																 :choices(transitionChooserChoices)
																 :show()

	end

		--------------------------------------------------------------------------------
		-- ASSIGN EFFECTS SHORTCUT CHOOSER ACTION:
		--------------------------------------------------------------------------------
		function transitionsChooserAction(result)

			--------------------------------------------------------------------------------
			-- Hide Chooser:
			--------------------------------------------------------------------------------
			transitionChooser:hide()

			--------------------------------------------------------------------------------
			-- Perform Specific Function:
			--------------------------------------------------------------------------------
			if result ~= nil then
				--------------------------------------------------------------------------------
				-- Save the selection:
				--------------------------------------------------------------------------------
				whichShortcut = result["whichShortcut"]
				if whichShortcut == 1 then settings.set("fcpxHacks.transitionsShortcutOne", 	result["text"]) end
				if whichShortcut == 2 then settings.set("fcpxHacks.transitionsShortcutTwo", 	result["text"]) end
				if whichShortcut == 3 then settings.set("fcpxHacks.transitionsShortcutThree", 	result["text"]) end
				if whichShortcut == 4 then settings.set("fcpxHacks.transitionsShortcutFour", 	result["text"]) end
				if whichShortcut == 5 then settings.set("fcpxHacks.transitionsShortcutFive", 	result["text"]) end
			end

			--------------------------------------------------------------------------------
			-- Put focus back in Final Cut Pro:
			--------------------------------------------------------------------------------
			if result["wasFinalCutProOpen"] then
				fcp.launch()
			end

			--------------------------------------------------------------------------------
			-- Refresh Menubar:
			--------------------------------------------------------------------------------
			refreshMenuBar()

		end

	--------------------------------------------------------------------------------
	-- ASSIGN TITLES SHORTCUT:
	--------------------------------------------------------------------------------
	function assignTitlesShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Was Final Cut Pro Open?
		--------------------------------------------------------------------------------
		local wasFinalCutProOpen = fcp.frontmost()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local titlesListUpdated = settings.get("fcpxHacks.titlesListUpdated")
		local allTitles = settings.get("fcpxHacks.allTitles")

		--------------------------------------------------------------------------------
		-- Error Checking:
		--------------------------------------------------------------------------------
		if not titlesListUpdated then
			dialog.displayMessage("The Titles List doesn't appear to be up-to-date.\n\nPlease update the Titles List and try again.")
			return "Failed"
		end
		if allTitles == nil then
			dialog.displayMessage("The Titles List doesn't appear to be up-to-date.\n\nPlease update the Titles List and try again.")
			return "Failed"
		end
		if next(allTitles) == nil then
			dialog.displayMessage("The Titles List doesn't appear to be up-to-date.\n\nPlease update the Titles List and try again.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Titles List:
		--------------------------------------------------------------------------------
		local titlesChooserChoices = {}
		if allTitles ~= nil and next(allTitles) ~= nil then
			for i=1, #allTitles do
				individualEffect = {
					["text"] = allTitles[i],
					["subText"] = "Title",
					["function"] = "transitionsShortcut",
					["function1"] = allTitles[i],
					["function2"] = "",
					["function3"] = "",
					["whichShortcut"] = whichShortcut,
					["wasFinalCutProOpen"] = wasFinalCutProOpen,
				}
				table.insert(titlesChooserChoices, 1, individualEffect)
			end
		end

		--------------------------------------------------------------------------------
		-- Sort everything:
		--------------------------------------------------------------------------------
		table.sort(titlesChooserChoices, function(a, b) return a.text < b.text end)

		titlesChooser = chooser.new(titlesChooserAction):bgDark(true)
													    :fgColor(drawing.color.x11.snow)
													    :subTextColor(drawing.color.x11.snow)
														:choices(titlesChooserChoices)
														:show()

	end

		--------------------------------------------------------------------------------
		-- ASSIGN TITLES SHORTCUT CHOOSER ACTION:
		--------------------------------------------------------------------------------
		function titlesChooserAction(result)

			--------------------------------------------------------------------------------
			-- Hide Chooser:
			--------------------------------------------------------------------------------
			titlesChooser:hide()

			--------------------------------------------------------------------------------
			-- Perform Specific Function:
			--------------------------------------------------------------------------------
			if result ~= nil then
				--------------------------------------------------------------------------------
				-- Save the selection:
				--------------------------------------------------------------------------------
				whichShortcut = result["whichShortcut"]
				if whichShortcut == 1 then settings.set("fcpxHacks.titlesShortcutOne", 		result["text"]) end
				if whichShortcut == 2 then settings.set("fcpxHacks.titlesShortcutTwo", 		result["text"]) end
				if whichShortcut == 3 then settings.set("fcpxHacks.titlesShortcutThree", 	result["text"]) end
				if whichShortcut == 4 then settings.set("fcpxHacks.titlesShortcutFour", 		result["text"]) end
				if whichShortcut == 5 then settings.set("fcpxHacks.titlesShortcutFive", 		result["text"]) end
			end

			--------------------------------------------------------------------------------
			-- Put focus back in Final Cut Pro:
			--------------------------------------------------------------------------------
			if result["wasFinalCutProOpen"] then
				fcp.launch()
			end

			--------------------------------------------------------------------------------
			-- Refresh Menubar:
			--------------------------------------------------------------------------------
			refreshMenuBar()

		end

	--------------------------------------------------------------------------------
	-- ASSIGN GENERATORS SHORTCUT:
	--------------------------------------------------------------------------------
	function assignGeneratorsShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Was Final Cut Pro Open?
		--------------------------------------------------------------------------------
		local wasFinalCutProOpen = fcp.frontmost()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local generatorsListUpdated = settings.get("fcpxHacks.generatorsListUpdated")
		local allGenerators = settings.get("fcpxHacks.allGenerators")

		--------------------------------------------------------------------------------
		-- Error Checking:
		--------------------------------------------------------------------------------
		if not generatorsListUpdated then
			dialog.displayMessage("The Generators List doesn't appear to be up-to-date.\n\nPlease update the Generators List and try again.")
			return "Failed"
		end
		if allGenerators == nil then
			dialog.displayMessage("The Generators List doesn't appear to be up-to-date.\n\nPlease update the Generators List and try again.")
			return "Failed"
		end
		if next(allGenerators) == nil then
			dialog.displayMessage("The Generators List doesn't appear to be up-to-date.\n\nPlease update the Generators List and try again.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Generators List:
		--------------------------------------------------------------------------------
		local generatorsChooserChoices = {}
		if allGenerators ~= nil and next(allGenerators) ~= nil then
			for i=1, #allGenerators do
				individualEffect = {
					["text"] = allGenerators[i],
					["subText"] = "Title",
					["function"] = "transitionsShortcut",
					["function1"] = allGenerators[i],
					["function2"] = "",
					["function3"] = "",
					["whichShortcut"] = whichShortcut,
					["wasFinalCutProOpen"] = wasFinalCutProOpen,
				}
				table.insert(generatorsChooserChoices, 1, individualEffect)
			end
		end

		--------------------------------------------------------------------------------
		-- Sort everything:
		--------------------------------------------------------------------------------
		table.sort(generatorsChooserChoices, function(a, b) return a.text < b.text end)

		generatorsChooser = chooser.new(generatorsChooserAction):bgDark(true)
																:fgColor(drawing.color.x11.snow)
																:subTextColor(drawing.color.x11.snow)
																:choices(generatorsChooserChoices)
																:show()

	end

		--------------------------------------------------------------------------------
		-- ASSIGN GENERATORS SHORTCUT CHOOSER ACTION:
		--------------------------------------------------------------------------------
		function generatorsChooserAction(result)

			--------------------------------------------------------------------------------
			-- Hide Chooser:
			--------------------------------------------------------------------------------
			generatorsChooser:hide()

			--------------------------------------------------------------------------------
			-- Perform Specific Function:
			--------------------------------------------------------------------------------
			if result ~= nil then
				--------------------------------------------------------------------------------
				-- Save the selection:
				--------------------------------------------------------------------------------
				whichShortcut = result["whichShortcut"]
				if whichShortcut == 1 then settings.set("fcpxHacks.generatorsShortcutOne", 		result["text"]) end
				if whichShortcut == 2 then settings.set("fcpxHacks.generatorsShortcutTwo", 		result["text"]) end
				if whichShortcut == 3 then settings.set("fcpxHacks.generatorsShortcutThree", 	result["text"]) end
				if whichShortcut == 4 then settings.set("fcpxHacks.generatorsShortcutFour", 		result["text"]) end
				if whichShortcut == 5 then settings.set("fcpxHacks.generatorsShortcutFive", 		result["text"]) end
			end

			--------------------------------------------------------------------------------
			-- Put focus back in Final Cut Pro:
			--------------------------------------------------------------------------------
			if result["wasFinalCutProOpen"] then
				fcp.launch()
			end

			--------------------------------------------------------------------------------
			-- Refresh Menubar:
			--------------------------------------------------------------------------------
			refreshMenuBar()

		end

--------------------------------------------------------------------------------
-- CHANGE:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- CHANGE TOUCH BAR LOCATION:
	--------------------------------------------------------------------------------
	function changeTouchBarLocation(value)
		settings.set("fcpxHacks.displayTouchBarLocation", value)

		if touchBarSupported then
			local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false
			if displayTouchBar then setTouchBarLocation() end
		end

		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- CHANGE HIGHLIGHT SHAPE:
	--------------------------------------------------------------------------------
	function changeHighlightShape(value)
		settings.set("fcpxHacks.displayHighlightShape", value)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- CHANGE HIGHLIGHT COLOUR:
	--------------------------------------------------------------------------------
	function changeHighlightColour(value)
		settings.set("fcpxHacks.displayHighlightColour", value)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- FCPX CHANGE BACKUP INTERVAL:
	--------------------------------------------------------------------------------
	function changeBackupInterval()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		if fcp.getPreference("FFPeriodicBackupInterval") == nil then
			mod.FFPeriodicBackupInterval = 15
		else
			mod.FFPeriodicBackupInterval = fcp.getPreference("FFPeriodicBackupInterval")
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp.running() then
			if dialog.displayYesNoQuestion("Changing the Backup Interval requires Final Cut Pro to restart.\n\nDo you want to continue?") then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Ask user what to set the backup interval to:
		--------------------------------------------------------------------------------
		local userSelectedBackupInterval = dialog.displaySmallNumberTextBoxMessage("What would you like to set your Final Cut Pro Backup Interval to (in minutes)?", "The backup interval you entered is not valid. Please enter a value in minutes.", mod.FFPeriodicBackupInterval)
		if not userSelectedBackupInterval then
			return "Cancel"
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		local result = fcp.setPreference("FFPeriodicBackupInterval", userSelectedBackupInterval)
		if result == nil then
			dialog.displayErrorMessage("Failed to write Backup Interval to the Final Cut Pro Preferences file.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp.restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage("Failed to restart Final Cut Pro. You will need to restart manually.")
				return "Failed"
			end
		end

	end

	--------------------------------------------------------------------------------
	-- CHANGE SMART COLLECTIONS LABEL:
	--------------------------------------------------------------------------------
	function changeSmartCollectionsLabel()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		local executeResult,executeStatus = execute("/usr/libexec/PlistBuddy -c \"Print :FFOrganizerSmartCollections\" '/Applications/Final Cut Pro.app/Contents/Frameworks/Flexo.framework/Versions/A/Resources/en.lproj/FFLocalizable.strings'")
		if tools.trim(executeResult) ~= "" then FFOrganizerSmartCollections = executeResult end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp.running() then
			if dialog.displayYesNoQuestion("Changing the Smart Collections Label requires Final Cut Pro to restart.\n\nDo you want to continue?") then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Ask user what to set the backup interval to:
		--------------------------------------------------------------------------------
		local userSelectedSmartCollectionsLabel = dialog.displayTextBoxMessage("What would you like to set your Smart Collections Label to:", "The Smart Collections Label you entered is not valid.\n\nPlease only use standard characters and numbers.", tools.trim(FFOrganizerSmartCollections))
		if not userSelectedSmartCollectionsLabel then
			return "Cancel"
		end

		--------------------------------------------------------------------------------
		-- Update plist for every Flexo language:
		--------------------------------------------------------------------------------
		for k, v in pairs(fcp.flexoLanguages()) do
			local executeResult,executeStatus = execute("/usr/libexec/PlistBuddy -c \"Set :FFOrganizerSmartCollections " .. tools.trim(userSelectedSmartCollectionsLabel) .. "\" '/Applications/Final Cut Pro.app/Contents/Frameworks/Flexo.framework/Versions/A/Resources/" .. fcp.flexoLanguages()[k] .. ".lproj/FFLocalizable.strings'")
			if executeStatus == nil then
				writeToConsole("Failed to write to '" .. fcp.flexoLanguages()[k] .. ".lproj' plist.")
				dialog.displayErrorMessage("Failed to write to '" .. fcp.flexoLanguages()[k] .. ".lproj' plist.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp.restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage("Failed to restart Final Cut Pro. You will need to restart manually.")
				return "Failed"
			end
		end

	end

--------------------------------------------------------------------------------
-- TOGGLE:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- TOGGLE DEBUG MODE:
	--------------------------------------------------------------------------------
	function toggleDebugMode()
		mod.debugMode = not mod.debugMode
		settings.set("fcpxHacks.debugMode", mod.debugMode)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE CHECK FOR UPDATES:
	--------------------------------------------------------------------------------
	function toggleCheckForUpdates()
		local enableCheckForUpdates = settings.get("fcpxHacks.enableCheckForUpdates")
		settings.set("fcpxHacks.enableCheckForUpdates", not enableCheckForUpdates)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE MENUBAR DISPLAY:
	--------------------------------------------------------------------------------
	function toggleMenubarDisplay(value)
		local menubarEnabled = settings.get("fcpxHacks.menubar" .. value .. "Enabled")
		settings.set("fcpxHacks.menubar" .. value .. "Enabled", not menubarEnabled)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE MEDIA IMPORT WATCHER:
	--------------------------------------------------------------------------------
	function toggleMediaImportWatcher()
		local enableMediaImportWatcher = settings.get("fcpxHacks.enableMediaImportWatcher") or false
		if not enableMediaImportWatcher then
			mediaImportWatcher()
		else
			mod.newDeviceMounted:stop()
		end
		settings.set("fcpxHacks.enableMediaImportWatcher", not enableMediaImportWatcher)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function toggleEnableClipboardHistory()
		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false
		if not enableClipboardHistory then
			clipboard.startWatching()
		else
			clipboard.stopWatching()
		end
		settings.set("fcpxHacks.enableClipboardHistory", not enableClipboardHistory)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE SHARED CLIPBOARD:
	--------------------------------------------------------------------------------
	function toggleEnableSharedClipboard()

		local enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard") or false

		if not enableSharedClipboard then

			result = dialog.displayChooseFolder("Which folder would you like to use for the Shared Clipboard?")

			if result ~= false then
				debugMessage("Enabled Shared Clipboard Path: " .. tostring(result))
				settings.set("fcpxHacks.sharedClipboardPath", result)

				--------------------------------------------------------------------------------
				-- Watch for Shared Clipboard Changes:
				--------------------------------------------------------------------------------
				sharedClipboardWatcher = pathwatcher.new(result, sharedClipboardFileWatcher):start()

			else
				debugMessage("Enabled Shared Clipboard Choose Path Cancelled.")
				settings.set("fcpxHacks.sharedClipboardPath", nil)
				return "failed"
			end

		else

			--------------------------------------------------------------------------------
			-- Stop Watching for Shared Clipboard Changes:
			--------------------------------------------------------------------------------
			sharedClipboardWatcher:stop()

		end

		settings.set("fcpxHacks.enableSharedClipboard", not enableSharedClipboard)
		refreshMenuBar()

	end

	--------------------------------------------------------------------------------
	-- TOGGLE XML SHARING:
	--------------------------------------------------------------------------------
	function toggleEnableXMLSharing()

		local enableXMLSharing = settings.get("fcpxHacks.enableXMLSharing") or false

		if not enableXMLSharing then

			xmlSharingDropboxPath = dialog.displayChooseFolder("Which folder would you like to use as the local Drop Box?")

			if xmlSharingDropboxPath ~= false then
				settings.set("fcpxHacks.xmlSharingDropboxPath", xmlSharingDropboxPath)
			else
				settings.set("fcpxHacks.xmlSharingDropboxPath", nil)
				settings.set("fcpxHacks.xmlSharingPath", nil)
				return "Cancelled"
			end

			xmlSharingPath = dialog.displayChooseFolder("Which folder would you like to use for XML Sharing?")

			if xmlSharingPath ~= false then
				settings.set("fcpxHacks.xmlSharingPath", xmlSharingPath)
			else
				settings.set("fcpxHacks.xmlSharingDropboxPath", nil)
				settings.set("fcpxHacks.xmlSharingPath", nil)
				return "Cancelled"
			end

			--------------------------------------------------------------------------------
			-- Watch for XML Dropbox Changes:
			--------------------------------------------------------------------------------
			xmlDropboxWatcher = pathwatcher.new(xmlSharingDropboxPath, xmlDropboxFileWatcher):start()

			--------------------------------------------------------------------------------
			-- Watch for Shared XML Folder Changes:
			--------------------------------------------------------------------------------
			sharedXMLWatcher = pathwatcher.new(xmlSharingPath, sharedXMLFileWatcher):start()

		else
			--------------------------------------------------------------------------------
			-- Stop Watchers:
			--------------------------------------------------------------------------------
			xmlDropboxWatcher:stop()
			sharedXMLWatcher:stop()

			--------------------------------------------------------------------------------
			-- Clear Settings:
			--------------------------------------------------------------------------------
			settings.set("fcpxHacks.xmlSharingDropboxPath", nil)
			settings.set("fcpxHacks.xmlSharingPath", nil)
		end

		settings.set("fcpxHacks.enableXMLSharing", not enableXMLSharing)
		refreshMenuBar()

	end

	--------------------------------------------------------------------------------
	-- TOGGLE MOBILE NOTIFICATIONS:
	--------------------------------------------------------------------------------
	function toggleEnableMobileNotifications()
		local enableMobileNotifications 	= settings.get("fcpxHacks.enableMobileNotifications") or false
		local prowlAPIKey 					= settings.get("fcpxHacks.prowlAPIKey") or ""

		if not enableMobileNotifications then

			local returnToFinalCutPro = fcp.frontmost()
			::retryProwlAPIKeyEntry::
			local appleScriptA = 'set defaultAnswer to "' .. prowlAPIKey .. '"' .. '\n\n'
			local appleScriptB = [[
				set allowedLetters to characters of (do shell script "printf \"%c\" {a..z}")
				set allowedNumbers to characters of (do shell script "printf \"%c\" {0..9}")
				set allowedAll to allowedLetters & allowedNumbers

				repeat
					try
						tell me to activate
						set response to text returned of (display dialog "Please enter your Prowl API key below.\n\nIf you don't have one you can register for free at prowlapp.com." default answer defaultAnswer buttons {"OK", "Cancel"} default button 1 with icon fcpxIcon)
					on error
						-- Cancel Pressed:
						return false
					end try
					try
						set invalidCharacters to false
						repeat with aCharacter in response
							if (aCharacter as text) is not in allowedAll then
								set invalidCharacters to true
							end if
						end repeat
						if length of response is 0 then
							set invalidCharacters to true
						end if
						if invalidCharacters is false then
							exit repeat
						end
					end try
					display dialog "The Prowl API Key you entered is not valid.\n\nPlease try again." buttons {"OK"} with icon fcpxIcon
				end repeat
				return response
			]]
			a,result = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA .. appleScriptB)
			if result == false then
				return "Cancel"
			end
			local prowlAPIKeyValidResult, prowlAPIKeyValidError = prowlAPIKeyValid(result)
			if prowlAPIKeyValidResult then
				if returnToFinalCutPro then fcp.launch() end
				settings.set("fcpxHacks.prowlAPIKey", result)
				notificationWatcher()
				settings.set("fcpxHacks.enableMobileNotifications", not enableMobileNotifications)
			else
				dialog.displayMessage("The Prowl API Key failed to validate due to the following error: " .. prowlAPIKeyValidError .. ".\n\nPlease try again.")
				goto retryProwlAPIKeyEntry
			end
		else
			shareSuccessNotificationWatcher:stop()
			shareFailedNotificationWatcher:stop()
			settings.set("fcpxHacks.enableMobileNotifications", not enableMobileNotifications)
		end
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HAMMERSPOON DOCK ICON:
	--------------------------------------------------------------------------------
	function toggleHammerspoonDockIcon()
		local originalValue = hs.dockIcon()
		hs.dockIcon(not originalValue)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HAMMERSPOON MENU ICON:
	--------------------------------------------------------------------------------
	function toggleHammerspoonMenuIcon()
		local originalValue = hs.menuIcon()
		hs.menuIcon(not originalValue)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE LAUNCH HAMMERSPOON ON START:
	--------------------------------------------------------------------------------
	function toggleLaunchHammerspoonOnStartup()
		local originalValue = hs.autoLaunch()
		hs.autoLaunch(not originalValue)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE HAMMERSPOON CHECK FOR UPDATES:
	--------------------------------------------------------------------------------
	function toggleCheckforHammerspoonUpdates()
		local originalValue = hs.automaticallyCheckForUpdates()
		hs.automaticallyCheckForUpdates(not originalValue)
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- TOGGLE ENABLE PROXY MENU ICON:
	--------------------------------------------------------------------------------
	function toggleEnableProxyMenuIcon()
		local enableProxyMenuIcon = settings.get("fcpxHacks.enableProxyMenuIcon")
		if enableProxyMenuIcon == nil then
			settings.set("fcpxHacks.enableProxyMenuIcon", true)
			enableProxyMenuIcon = true
		else
			settings.set("fcpxHacks.enableProxyMenuIcon", not enableProxyMenuIcon)
		end

		updateMenubarIcon()
		refreshMenuBar()

	end

	--------------------------------------------------------------------------------
	-- TOGGLE HACKS SHORTCUTS IN FINAL CUT PRO:
	--------------------------------------------------------------------------------
	function toggleEnableHacksShortcutsInFinalCutPro()

		--------------------------------------------------------------------------------
		-- Get current value from settings:
		--------------------------------------------------------------------------------
		local enableHacksShortcutsInFinalCutPro = settings.get("fcpxHacks.enableHacksShortcutsInFinalCutPro")
		if enableHacksShortcutsInFinalCutPro == nil then enableHacksShortcutsInFinalCutPro = false end

		--------------------------------------------------------------------------------
		-- Are we enabling or disabling?
		--------------------------------------------------------------------------------
		local enableOrDisableText = nil
		if enableHacksShortcutsInFinalCutPro then
			enableOrDisableText = "Disabling"
		else
			enableOrDisableText = "Enabling"
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp.running() then
			if dialog.displayYesNoQuestion(enableOrDisableText .. " Hacks Shortcuts in Final Cut Pro requires your Administrator password and also needs Final Cut Pro to restart before it can take affect.\n\nDo you want to continue?") then
				restartStatus = true
			else
				return "Done"
			end
		else
			if not dialog.displayYesNoQuestion(enableOrDisableText .. " Hacks Shortcuts in Final Cut Pro requires your Administrator password.\n\nDo you want to continue?") then
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Let's do it!
		--------------------------------------------------------------------------------
		local saveSettings = false
		if enableHacksShortcutsInFinalCutPro then
			--------------------------------------------------------------------------------
			-- Revert back to default keyboard layout:
			--------------------------------------------------------------------------------
			local result = fcp.setPreference("Active Command Set", "/Applications/Final Cut Pro.app/Contents/Resources/en.lproj/Default.commandset")
			if result == nil then
				dialog.displayErrorMessage("Failed to revert back to default Active Command Set.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Disable Hacks Shortcut in Final Cut Pro:
			--------------------------------------------------------------------------------
			local appleScriptA = [[
				--------------------------------------------------------------------------------
				-- Replace Files:
				--------------------------------------------------------------------------------
				try
					tell me to activate
					do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/NSProCommandGroups.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommandGroups.plist'" with administrator privileges
				on error
					display dialog commonErrorMessageStart & "Failed to restore NSProCommandGroups.plist." & commonErrorMessageEnd buttons {"Close"} with icon caution
					return "Failed"
				end try
				try
					do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/NSProCommands.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommands.plist'" with administrator privileges
				on error
					display dialog commonErrorMessageStart & "Failed to restore NSProCommands.plist." & commonErrorMessageEnd buttons {"Close"} with icon caution
					return "Failed"
				end try


				set finalCutProLanguages to {"de", "en", "es", "fr", "ja", "zh_CN"}
				repeat with whichLanguage in finalCutProLanguages
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/" & whichLanguage & ".lproj/Default.commandset '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/Default.commandset'" with administrator privileges
					on error
						display dialog commonErrorMessageStart & "Failed to restore Default.commandset." & commonErrorMessageEnd buttons {"Close"} with icon caution
						return "Failed"
					end try
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings'" with administrator privileges
					on error
						display dialog commonErrorMessageStart & "Failed to restore NSProCommandDescriptions.strings." & commonErrorMessageEnd buttons {"Close"} with icon caution
						return "Failed"
					end try
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/" & whichLanguage & ".lproj/NSProCommandNames.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandNames.strings'" with administrator privileges
					on error
						display dialog commonErrorMessageStart & "Failed to restore NSProCommandNames.strings." & commonErrorMessageEnd buttons {"Close"} with icon caution
						return "Failed"
					end try
				end repeat
				return "Done"
			]]
			ok,toggleEnableHacksShortcutsInFinalCutProResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA)
			if toggleEnableHacksShortcutsInFinalCutProResult == "Done" then saveSettings = true end
		else
			--------------------------------------------------------------------------------
			-- Revert back to default keyboard layout:
			--------------------------------------------------------------------------------
			local result = fcp.setPreference("Active Command Set", "/Applications/Final Cut Pro.app/Contents/Resources/en.lproj/Default.commandset")
			if result == nil then
				dialog.displayErrorMessage("Failed to revert back to default Active Command Set.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Enable Hacks Shortcut in Final Cut Pro:
			--------------------------------------------------------------------------------
			local appleScriptA = [[
				--------------------------------------------------------------------------------
				-- Replace Files:
				--------------------------------------------------------------------------------
				try
					tell me to activate
					do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/NSProCommandGroups.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommandGroups.plist'" with administrator privileges
				on error
					display dialog commonErrorMessageStart & "Failed to replace NSProCommandGroups.plist." & commonErrorMessageEnd buttons {"Close"} with icon caution
					return "Failed"
				end try
				try
					do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/NSProCommands.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommands.plist'" with administrator privileges
				on error
					display dialog commonErrorMessageStart & "Failed to replace NSProCommands.plist." & commonErrorMessageEnd buttons {"Close"} with icon caution
					return "Failed"
				end try

				set finalCutProLanguages to {"de", "en", "es", "fr", "ja", "zh_CN"}
				repeat with whichLanguage in finalCutProLanguages
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/" & whichLanguage & ".lproj/Default.commandset '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/Default.commandset'" with administrator privileges
					on error
						display dialog commonErrorMessageStart & "Failed to replace Default.commandset." & commonErrorMessageEnd buttons {"Close"} with icon caution
						return "Failed"
					end try
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings'" with administrator privileges
					on error
						display dialog commonErrorMessageStart & "Failed to replace NSProCommandDescriptions.strings." & commonErrorMessageEnd buttons {"Close"} with icon caution
						return "Failed"
					end try
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/new/" & whichLanguage & ".lproj/NSProCommandNames.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandNames.strings'" with administrator privileges
					on error
						display dialog commonErrorMessageStart & "Failed to replace NSProCommandNames.strings." & commonErrorMessageEnd buttons {"Close"} with icon caution
						return "Failed"
					end try
				end repeat
				return "Done"
			]]
			ok,toggleEnableHacksShortcutsInFinalCutProResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA)
			if toggleEnableHacksShortcutsInFinalCutProResult == "Done" then saveSettings = true end
		end

		--------------------------------------------------------------------------------
		-- If all is good then...
		--------------------------------------------------------------------------------
		if saveSettings then
			--------------------------------------------------------------------------------
			-- Save new value to settings:
			--------------------------------------------------------------------------------
			settings.set("fcpxHacks.enableHacksShortcutsInFinalCutPro", not enableHacksShortcutsInFinalCutPro)

			--------------------------------------------------------------------------------
			-- Restart Final Cut Pro:
			--------------------------------------------------------------------------------
			if restartStatus then
				if not fcp.restart() then
					--------------------------------------------------------------------------------
					-- Failed to restart Final Cut Pro:
					--------------------------------------------------------------------------------
					dialog.displayErrorMessage("Failed to restart Final Cut Pro. You will need to restart manually.")
					return "Failed"
				end
			end

			--------------------------------------------------------------------------------
			-- Refresh the Keyboard Shortcuts:
			--------------------------------------------------------------------------------
			bindKeyboardShortcuts()

			--------------------------------------------------------------------------------
			-- Refresh the Menu Bar:
			--------------------------------------------------------------------------------
			refreshMenuBar()

		end

	end

	--------------------------------------------------------------------------------
	-- TOGGLE ENABLE SHORTCUTS DURING FULLSCREEN PLAYBACK:
	--------------------------------------------------------------------------------
	function toggleEnableShortcutsDuringFullscreenPlayback()

		local enableShortcutsDuringFullscreenPlayback = settings.get("fcpxHacks.enableShortcutsDuringFullscreenPlayback")
		if enableShortcutsDuringFullscreenPlayback == nil then enableShortcutsDuringFullscreenPlayback = false end
		settings.set("fcpxHacks.enableShortcutsDuringFullscreenPlayback", not enableShortcutsDuringFullscreenPlayback)

		if enableShortcutsDuringFullscreenPlayback == true then
			fullscreenKeyboardWatcherUp:stop()
			fullscreenKeyboardWatcherDown:stop()
		else
			fullscreenKeyboardWatcherUp:start()
			fullscreenKeyboardWatcherDown:start()
		end

		refreshMenuBar()

	end

	--------------------------------------------------------------------------------
	-- TOGGLE MOVING MARKERS:
	--------------------------------------------------------------------------------
	function toggleMovingMarkers()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		mod.allowMovingMarkers = false
		local executeResult,executeStatus = execute("/usr/libexec/PlistBuddy -c \"Print :TLKMarkerHandler:Configuration:'Allow Moving Markers'\" '/Applications/Final Cut Pro.app/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist'")
		if tools.trim(executeResult) == "true" then mod.allowMovingMarkers = true end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp.running() then
			if dialog.displayYesNoQuestion("Toggling Moving Markers requires Final Cut Pro to restart.\n\nDo you want to continue?") then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		if mod.allowMovingMarkers then
			local executeStatus = tools.executeWithAdministratorPrivileges([[/usr/libexec/PlistBuddy -c \"Set :TLKMarkerHandler:Configuration:'Allow Moving Markers' false\" '/Applications/Final Cut Pro.app/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist']])
			if executeStatus == false then
				dialog.displayErrorMessage("Failed to write to plist.")
				return "Failed"
			end
		else
			local executeStatus = tools.executeWithAdministratorPrivileges([[/usr/libexec/PlistBuddy -c \"Set :TLKMarkerHandler:Configuration:'Allow Moving Markers' true\" '/Applications/Final Cut Pro.app/Contents/Frameworks/TLKit.framework/Versions/A/Resources/EventDescriptions.plist']])
			if executeStatus == false then
				dialog.displayErrorMessage("Failed to write to plist.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp.restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage("Failed to restart Final Cut Pro. You will need to restart manually.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Refresh Menu Bar:
		--------------------------------------------------------------------------------
		refreshMenuBar(true)

	end

	--------------------------------------------------------------------------------
	-- TOGGLE PERFORM TASKS DURING PLAYBACK:
	--------------------------------------------------------------------------------
	function togglePerformTasksDuringPlayback()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		if fcp.getPreference("FFSuspendBGOpsDuringPlay") == nil then
			mod.FFSuspendBGOpsDuringPlay = false
		else
			mod.FFSuspendBGOpsDuringPlay = fcp.getPreference("FFSuspendBGOpsDuringPlay")
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp.running() then
			if dialog.displayYesNoQuestion("Toggling the ability to perform Background Tasks during playback requires Final Cut Pro to restart.\n\nDo you want to continue?") then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		if FFSuspendBGOpsDuringPlay then
			local result = fcp.setPreference("FFSuspendBGOpsDuringPlay", false)
			if result == nil then
				dialog.displayErrorMessage("Failed to write to plist.")
				return "Failed"
			end
		else
			local result = fcp.setPreference("FFSuspendBGOpsDuringPlay", true)
			if result == nil then
				dialog.displayErrorMessage("Failed to write to plist.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp.restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage("Failed to restart Final Cut Pro. You will need to restart manually.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Refresh Menu Bar:
		--------------------------------------------------------------------------------
		refreshMenuBar(true)

	end

	--------------------------------------------------------------------------------
	-- TOGGLE TIMECODE OVERLAY:
	--------------------------------------------------------------------------------
	function toggleTimecodeOverlay()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get existing value:
		--------------------------------------------------------------------------------
		if fcp.getPreference("FFEnableGuards") == nil then
			mod.FFEnableGuards = false
		else
			mod.FFEnableGuards = fcp.getPreference("FFEnableGuards")
		end

		--------------------------------------------------------------------------------
		-- If Final Cut Pro is running...
		--------------------------------------------------------------------------------
		local restartStatus = false
		if fcp.running() then
			if dialog.displayYesNoQuestion("Toggling Timecode Overlays requires Final Cut Pro to restart.\n\nDo you want to continue?") then
				restartStatus = true
			else
				return "Done"
			end
		end

		--------------------------------------------------------------------------------
		-- Update plist:
		--------------------------------------------------------------------------------
		if mod.FFEnableGuards then
			local result = fcp.setPreference("FFEnableGuards", false)
			if result == nil then
				dialog.displayErrorMessage("Failed to write to plist.")
				return "Failed"
			end
		else
			local result = fcp.setPreference("FFEnableGuards", true)
			if result == nil then
				dialog.displayErrorMessage("Failed to write to plist.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Restart Final Cut Pro:
		--------------------------------------------------------------------------------
		if restartStatus then
			if not fcp.restart() then
				--------------------------------------------------------------------------------
				-- Failed to restart Final Cut Pro:
				--------------------------------------------------------------------------------
				dialog.displayErrorMessage("Failed to restart Final Cut Pro. You will need to restart manually.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Refresh Menu Bar:
		--------------------------------------------------------------------------------
		refreshMenuBar(true)

	end

	--------------------------------------------------------------------------------
	-- TOGGLE MENUBAR DISPLAY MODE:
	--------------------------------------------------------------------------------
	function toggleMenubarDisplayMode()

		local displayMenubarAsIcon = settings.get("fcpxHacks.displayMenubarAsIcon")


		if displayMenubarAsIcon == nil then
			 settings.set("fcpxHacks.displayMenubarAsIcon", true)
		else
			if displayMenubarAsIcon then
				settings.set("fcpxHacks.displayMenubarAsIcon", false)
			else
				settings.set("fcpxHacks.displayMenubarAsIcon", true)
			end
		end

		updateMenubarIcon()
		refreshMenuBar()

	end

	--------------------------------------------------------------------------------
	-- TOGGLE CREATE MULTI-CAM OPTIMISED MEDIA:
	--------------------------------------------------------------------------------
	function toggleCreateMulticamOptimizedMedia(optionalValue)

		--------------------------------------------------------------------------------
		-- Make sure it's active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- If we're setting rather than toggling...
		--------------------------------------------------------------------------------
		if optionalValue ~= nil then

			--------------------------------------------------------------------------------
			-- Get plist values for FFCreateOptimizedMediaForMulticamClips:
			--------------------------------------------------------------------------------
			if fcp.getPreference("FFCreateOptimizedMediaForMulticamClips") == nil then
				FFCreateOptimizedMediaForMulticamClips = true
			else
				FFCreateOptimizedMediaForMulticamClips = fcp.getPreference("FFCreateOptimizedMediaForMulticamClips")
			end

			if optionalValue == FFCreateOptimizedMediaForMulticamClips then return end

		end

		--------------------------------------------------------------------------------
		-- Define FCPX:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()

		--------------------------------------------------------------------------------
		-- Open Preferences:
		--------------------------------------------------------------------------------
		local activatePreferencesResult = fcp.selectMenuItem({"Final Cut Pro", "Preferences…"})
		if activatePreferencesResult == nil then
			dialog.displayErrorMessage("Failed to open Preferences Panel.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Toolbar:
		--------------------------------------------------------------------------------
		local timeoutCount = 0
		local whichToolbar = nil
		::tryToolbarAgain::
		fcpxElements = ax.applicationElement(fcpx)[1]
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXToolbar" then
				whichToolbar = i
				goto foundToolbar
			end
		end
		if whichToolbar == nil then
			timeoutCount = timeoutCount + 1
			if timeoutCount == 10 then
				dialog.displayErrorMessage("Unable to locate Preferences Toolbar.")
				return "Failed"
			end
			timer.usleep(200000)
			goto tryToolbarAgain
		end
		::foundToolbar::

		--------------------------------------------------------------------------------
		-- Goto Playback Preferences:
		--------------------------------------------------------------------------------
		local pressPlaybackButton = fcpxElements[whichToolbar][3]:performAction("AXPress")
		if pressPlaybackButton == nil then
			dialog.displayErrorMessage("Failed to open Import Preferences.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Group:
		--------------------------------------------------------------------------------
		local whichGroup = nil
		for i=1, (fcpxElements:attributeValueCount("AXChildren")) do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
				whichGroup = i
				goto foundGroup
			end
		end
		if whichGroup == nil then
			dialog.displayErrorMessage("Unable to locate Group.")
			return "Failed"
		end
		::foundGroup::

		--------------------------------------------------------------------------------
		-- Toggle Create Optimized Media:
		--------------------------------------------------------------------------------
		fcpxElements[whichGroup][1][15]:performAction("AXPress")

		--------------------------------------------------------------------------------
		-- Close Preferences:
		--------------------------------------------------------------------------------
		local buttonResult = fcpxElements[2]:performAction("AXPress")
		if buttonResult == nil then
			dialog.displayErrorMessage("Unable to close Preferences window.")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- TOGGLE CREATE PROXY MEDIA:
	--------------------------------------------------------------------------------
	function toggleCreateProxyMedia(optionalValue)

		--------------------------------------------------------------------------------
		-- Make sure it's active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- If we're setting rather than toggling...
		--------------------------------------------------------------------------------
		if optionalValue ~= nil then

			--------------------------------------------------------------------------------
			-- Get plist values for FFImportCreateProxyMedia:
			--------------------------------------------------------------------------------
			if fcp.getPreference("FFImportCreateProxyMedia") == nil then
				FFImportCreateProxyMedia = false
			else
				FFImportCreateProxyMedia = fcp.getPreference("FFImportCreateProxyMedia")
			end

			if optionalValue == FFImportCreateProxyMedia then return end

		end

		--------------------------------------------------------------------------------
		-- Define FCPX:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()

		--------------------------------------------------------------------------------
		-- Open Preferences:
		--------------------------------------------------------------------------------
		local activatePreferencesResult = fcp.selectMenuItem({"Final Cut Pro", "Preferences…"})
		if activatePreferencesResult == nil then
			dialog.displayErrorMessage("Failed to open Preferences Panel.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Toolbar:
		--------------------------------------------------------------------------------
		local timeoutCount = 0
		local whichToolbar = nil
		::tryToolbarAgain::
		fcpxElements = ax.applicationElement(fcpx)[1]
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXToolbar" then
				whichToolbar = i
				goto foundToolbar
			end
		end
		if whichToolbar == nil then
			timeoutCount = timeoutCount + 1
			if timeoutCount == 10 then
				dialog.displayErrorMessage("Unable to locate Preferences Toolbar.")
				return "Failed"
			end
			timer.usleep(200000)
			goto tryToolbarAgain
		end
		::foundToolbar::

		--------------------------------------------------------------------------------
		-- Goto Playback Preferences:
		--------------------------------------------------------------------------------
		local pressPlaybackButton = fcpxElements[whichToolbar][4]:performAction("AXPress")
		if pressPlaybackButton == nil then
			dialog.displayErrorMessage("Failed to open Import Preferences.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Group:
		--------------------------------------------------------------------------------
		local whichGroup = nil
		for i=1, (fcpxElements:attributeValueCount("AXChildren")) do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
				whichGroup = i
				goto foundGroup
			end
		end
		if whichGroup == nil then
			dialog.displayErrorMessage("Unable to locate Group.")
			return "Failed"
		end
		::foundGroup::

		--------------------------------------------------------------------------------
		-- Toggle Create Proxy Media:
		--------------------------------------------------------------------------------
		fcpxElements[whichGroup][1][19]:performAction("AXPress")

		--------------------------------------------------------------------------------
		-- Close Preferences:
		--------------------------------------------------------------------------------
		local buttonResult = fcpxElements[2]:performAction("AXPress")
		if buttonResult == nil then
			dialog.displayErrorMessage("Unable to close Preferences window.")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- TOGGLE CREATE OPTIMIZED MEDIA:
	--------------------------------------------------------------------------------
	function toggleCreateOptimizedMedia(optionalValue)

		--------------------------------------------------------------------------------
		-- Make sure it's active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- If we're setting rather than toggling...
		--------------------------------------------------------------------------------
		if optionalValue ~= nil then

			--------------------------------------------------------------------------------
			-- Get plist values for FFImportCreateOptimizeMedia:
			--------------------------------------------------------------------------------
			if fcp.getPreference("FFImportCreateOptimizeMedia") == nil then
				FFImportCreateOptimizeMedia = false
			else
				FFImportCreateOptimizeMedia = fcp.getPreference("FFImportCreateOptimizeMedia")
			end

			if optionalValue == FFImportCreateOptimizeMedia then return end

		end

		--------------------------------------------------------------------------------
		-- Define FCPX:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()

		--------------------------------------------------------------------------------
		-- Open Preferences:
		--------------------------------------------------------------------------------
		local activatePreferencesResult = fcp.selectMenuItem({"Final Cut Pro", "Preferences…"})
		if activatePreferencesResult == nil then
			dialog.displayErrorMessage("Failed to open Preferences Panel.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Toolbar:
		--------------------------------------------------------------------------------
		local timeoutCount = 0
		local whichToolbar = nil
		::tryToolbarAgain::
		fcpxElements = ax.applicationElement(fcpx)[1]
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXToolbar" then
				whichToolbar = i
				goto foundToolbar
			end
		end
		if whichToolbar == nil then
			timeoutCount = timeoutCount + 1
			if timeoutCount == 10 then
				dialog.displayErrorMessage("Unable to locate Preferences Toolbar.")
				return "Failed"
			end
			timer.usleep(200000)
			goto tryToolbarAgain
		end
		::foundToolbar::

		--------------------------------------------------------------------------------
		-- Goto Playback Preferences:
		--------------------------------------------------------------------------------
		local pressPlaybackButton = fcpxElements[whichToolbar][4]:performAction("AXPress")
		if pressPlaybackButton == nil then
			dialog.displayErrorMessage("Failed to open Import Preferences.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Group:
		--------------------------------------------------------------------------------
		local whichGroup = nil
		for i=1, (fcpxElements:attributeValueCount("AXChildren")) do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
				whichGroup = i
				goto foundGroup
			end
		end
		if whichGroup == nil then
			dialog.displayErrorMessage("Unable to locate Group.")
			return "Failed"
		end
		::foundGroup::

		--------------------------------------------------------------------------------
		-- Toggle Create Optimized Media:
		--------------------------------------------------------------------------------
		fcpxElements[whichGroup][1][1]:performAction("AXPress")

		--------------------------------------------------------------------------------
		-- Close Preferences:
		--------------------------------------------------------------------------------
		local buttonResult = fcpxElements[2]:performAction("AXPress")
		if buttonResult == nil then
			dialog.displayErrorMessage("Unable to close Preferences window.")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- TOGGLE LEAVE IN PLACE ON IMPORT:
	--------------------------------------------------------------------------------
	function toggleLeaveInPlace(optionalValue)

		--------------------------------------------------------------------------------
		-- Make sure it's active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- If we're setting rather than toggling...
		--------------------------------------------------------------------------------
		if optionalValue ~= nil then

			--------------------------------------------------------------------------------
			-- Get plist values for FFImportCopyToMediaFolder:
			--------------------------------------------------------------------------------
			if fcp.getPreference("FFImportCopyToMediaFolder") == nil then
				FFImportCopyToMediaFolder = true
			else
				FFImportCopyToMediaFolder = fcp.getPreference("FFImportCopyToMediaFolder")
			end

			if optionalValue == not FFImportCopyToMediaFolder then return end

		end

		--------------------------------------------------------------------------------
		-- Define FCPX:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()

		--------------------------------------------------------------------------------
		-- Open Preferences:
		--------------------------------------------------------------------------------
		local activatePreferencesResult = fcp.selectMenuItem({"Final Cut Pro", "Preferences…"})
		if activatePreferencesResult == nil then
			dialog.displayErrorMessage("Failed to open Preferences Panel.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Toolbar:
		--------------------------------------------------------------------------------
		local timeoutCount = 0
		local whichToolbar = nil
		::tryToolbarAgain::
		fcpxElements = ax.applicationElement(fcpx)[1]
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXToolbar" then
				whichToolbar = i
				goto foundToolbar
			end
		end
		if whichToolbar == nil then
			timeoutCount = timeoutCount + 1
			if timeoutCount == 10 then
				dialog.displayErrorMessage("Unable to locate Preferences Toolbar.")
				return "Failed"
			end
			timer.usleep(200000)
			goto tryToolbarAgain
		end
		::foundToolbar::

		--------------------------------------------------------------------------------
		-- Goto Playback Preferences:
		--------------------------------------------------------------------------------
		local pressPlaybackButton = fcpxElements[whichToolbar][4]:performAction("AXPress")
		if pressPlaybackButton == nil then
			dialog.displayErrorMessage("Failed to open Import Preferences.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Group:
		--------------------------------------------------------------------------------
		local whichGroup = nil
		for i=1, (fcpxElements:attributeValueCount("AXChildren")) do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
				whichGroup = i
				goto foundGroup
			end
		end
		if whichGroup == nil then
			dialog.displayErrorMessage("Unable to locate Group.")
			return "Failed"
		end
		::foundGroup::

		--------------------------------------------------------------------------------
		-- Toggle "AutoStart Background Render":
		--------------------------------------------------------------------------------
		if fcpxElements[whichGroup][1][9][1]:attributeValue("AXValue") == 0 then
			fcpxElements[whichGroup][1][9][1]:performAction("AXPress")
		else
			fcpxElements[whichGroup][1][9][2]:performAction("AXPress")
		end

		--------------------------------------------------------------------------------
		-- Close Preferences:
		--------------------------------------------------------------------------------
		local buttonResult = fcpxElements[2]:performAction("AXPress")
		if buttonResult == nil then
			dialog.displayErrorMessage("Unable to close Preferences window.")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- TOGGLE BACKGROUND RENDER:
	--------------------------------------------------------------------------------
	function toggleBackgroundRender(optionalValue)

		--------------------------------------------------------------------------------
		-- Make sure it's active:
		--------------------------------------------------------------------------------
		fcp.launch()

		--------------------------------------------------------------------------------
		-- If we're setting rather than toggling...
		--------------------------------------------------------------------------------
		if optionalValue ~= nil then

			--------------------------------------------------------------------------------
			-- Get plist values for FFAutoStartBGRender:
			--------------------------------------------------------------------------------
			if fcp.getPreference("FFAutoStartBGRender") == nil then
				FFAutoStartBGRender = true
			else
				FFAutoStartBGRender = fcp.getPreference("FFAutoStartBGRender")
			end

			if optionalValue == FFAutoStartBGRender then return end

		end

		--------------------------------------------------------------------------------
		-- Define FCPX:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()

		--------------------------------------------------------------------------------
		-- Open Preferences:
		--------------------------------------------------------------------------------
		local activatePreferencesResult = fcp.selectMenuItem({"Final Cut Pro", "Preferences…"})
		if activatePreferencesResult == nil then
			dialog.displayErrorMessage("Failed to open Preferences Panel.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Toolbar:
		--------------------------------------------------------------------------------
		local timeoutCount = 0
		local whichToolbar = nil
		::tryToolbarAgain::
		fcpxElements = ax.applicationElement(fcpx)[1]
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXToolbar" then
				whichToolbar = i
				goto foundToolbar
			end
		end
		if whichToolbar == nil then
			timeoutCount = timeoutCount + 1
			if timeoutCount == 10 then
				dialog.displayErrorMessage("Unable to locate Preferences Toolbar.")
				return "Failed"
			end
			timer.usleep(200000)
			goto tryToolbarAgain
		end
		::foundToolbar::

		--------------------------------------------------------------------------------
		-- Goto Playback Preferences:
		--------------------------------------------------------------------------------
		local pressPlaybackButton = fcpxElements[whichToolbar][3]:performAction("AXPress")
		if pressPlaybackButton == nil then
			dialog.displayErrorMessage("Failed to open Playback Preferences.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Group:
		--------------------------------------------------------------------------------
		local whichGroup = nil
		for i=1, (fcpxElements:attributeValueCount("AXChildren")) do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
				whichGroup = i
				goto foundGroup
			end
		end
		if whichGroup == nil then
			dialog.displayErrorMessage("Unable to locate Group.")
			return "Failed"
		end
		::foundGroup::

		--------------------------------------------------------------------------------
		-- Toggle "AutoStart Background Render":
		--------------------------------------------------------------------------------
		local buttonResult = fcpxElements[whichGroup][1][1]:performAction("AXPress")
		if buttonResult == nil then
			dialog.displayErrorMessage("Unable to toggle Background Render option.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Close Preferences:
		--------------------------------------------------------------------------------
		local buttonResult = fcpxElements[2]:performAction("AXPress")
		if buttonResult == nil then
			dialog.displayErrorMessage("Unable to close Preferences window.")
			return "Failed"
		end

	end

--------------------------------------------------------------------------------
-- PASTE:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- PASTE FROM CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function finalCutProPasteFromClipboardHistory(data)

		--------------------------------------------------------------------------------
		-- Write data back to Clipboard:
		--------------------------------------------------------------------------------
		clipboard.stopWatching()
		pasteboard.writeDataForUTI(fcp.clipboardUTI(), data)
		clipboard.startWatching()

		--------------------------------------------------------------------------------
		-- Paste in FCPX:
		--------------------------------------------------------------------------------
		fcp.launch()
		if not keyStrokeFromPlist("Paste") then
			dialog.displayErrorMessage("Failed to trigger the 'Paste' Shortcut.")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- PASTE FROM SHARED CLIPBOARD:
	--------------------------------------------------------------------------------
	function pasteFromSharedClipboard(whichClipboard)

		local enableSharedClipboard = settings.get("fcpxHacks.enableSharedClipboard")
		if enableSharedClipboard then
			local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
			if sharedClipboardPath ~= nil then

				local file = io.open(sharedClipboardPath .. "/Final Cut Pro Shared Clipboard for " .. whichClipboard, "r")
				if file == nil then
					dialog.displayMessage("The Shared Clipboard item could not be found.\n\nPlease try again.")
					return "Fail"
				end
				currentClipboardData = file:read("*all")
				file:close()

				--------------------------------------------------------------------------------
				-- Write data back to Clipboard:
				--------------------------------------------------------------------------------
				clipboard.stopWatching()
				pasteboard.writeDataForUTI(fcp.clipboardUTI(), currentClipboardData)
				clipboard.startWatching()

				--------------------------------------------------------------------------------
				-- Paste in FCPX:
				--------------------------------------------------------------------------------
				fcp.launch()
				if not keyStrokeFromPlist("Paste") then
					dialog.displayErrorMessage("Failed to trigger the 'Paste' Shortcut.")
					return "Failed"
				end

			end
		end
	end

--------------------------------------------------------------------------------
-- CLEAR:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- CLEAR CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function clearClipboardHistory()
		clipboard.clearHistory()
		refreshMenuBar()
	end

	--------------------------------------------------------------------------------
	-- CLEAR SHARED CLIPBOARD HISTORY:
	--------------------------------------------------------------------------------
	function clearSharedClipboardHistory()
		local sharedClipboardPath = settings.get("fcpxHacks.sharedClipboardPath")
		for file in fs.dir(sharedClipboardPath) do
			 if file:sub(1, 30) == "Final Cut Pro Shared Clipboard" then
				os.remove(sharedClipboardPath .. file)
			 end
			 refreshMenuBar()
		end
	end

	--------------------------------------------------------------------------------
	-- CLEAR SHARED XML FILES:
	--------------------------------------------------------------------------------
	function clearSharedXMLFiles()
		local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
		for file in fs.dir(xmlSharingPath) do
			 if file:sub(-7) == ".fcpxml" then
				os.remove(xmlSharingPath .. file)
			 end
			 refreshMenuBar()
		end
	end

--------------------------------------------------------------------------------
-- UPDATE:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- UPDATE MENUBAR ICON:
	--------------------------------------------------------------------------------
	function updateMenubarIcon()

		local fcpxHacksIcon = image.imageFromPath("~/.hammerspoon/hs/fcpxhacks/assets/fcpxhacks.png")
		local fcpxHacksIconSmall = fcpxHacksIcon:setSize({w=18,h=18})
		local displayMenubarAsIcon = settings.get("fcpxHacks.displayMenubarAsIcon")
		local enableProxyMenuIcon = settings.get("fcpxHacks.enableProxyMenuIcon")
		local proxyMenuIcon = ""
		local proxyStatusIcon = getProxyStatusIcon()

		fcpxMenubar:setIcon(nil)

		if enableProxyMenuIcon ~= nil then
			if enableProxyMenuIcon == true then
				if proxyStatusIcon ~= nil then
					proxyMenuIcon = " " .. proxyStatusIcon
				else
					proxyMenuIcon = ""
				end
			end
		end

		if displayMenubarAsIcon == nil then
			fcpxMenubar:setTitle("FCPX Hacks" .. proxyMenuIcon)
		else
			if displayMenubarAsIcon then
				fcpxMenubar:setIcon(fcpxHacksIconSmall)
				if proxyStatusIcon ~= nil then
					if proxyStatusIcon ~= "" then
						if enableProxyMenuIcon then
							proxyMenuIcon = proxyMenuIcon .. "  "
						end
					end
				 end
				fcpxMenubar:setTitle(proxyMenuIcon)
			else
				fcpxMenubar:setTitle("FCPX Hacks" .. proxyMenuIcon)
			end
		end

	end

--------------------------------------------------------------------------------
-- MISC:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- QUIT FCPX HACKS:
	--------------------------------------------------------------------------------
	function quitFCPXHacks()
		application("Hammerspoon"):kill()
	end

	--------------------------------------------------------------------------------
	-- OPEN HAMMERSPOON CONSOLE:
	--------------------------------------------------------------------------------
	function openHammerspoonConsole()
		hs.openConsole()
	end

	--------------------------------------------------------------------------------
	-- RESET SETTINGS:
	--------------------------------------------------------------------------------
	function resetSettings()

		local finalCutProRunning = fcp.running()

		local resetMessage = "Are you sure you want to trash the FCPX Hacks Preferences?"
		if finalCutProRunning then
			resetMessage = resetMessage .. "\n\nThis will require your Administrator password and require Final Cut Pro to restart."
		else
			resetMessage = resetMessage .. "\n\nThis will require your Administrator password."
		end

		if dialog.displayYesNoQuestion(resetMessage) then

			--------------------------------------------------------------------------------
			-- Remove Hacks Shortcut in Final Cut Pro:
			--------------------------------------------------------------------------------
			local removeHacksResult = true
			local appleScriptA = [[
				--------------------------------------------------------------------------------
				-- Replace Files:
				--------------------------------------------------------------------------------
				try
					tell me to activate
					do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/NSProCommandGroups.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommandGroups.plist'" with administrator privileges
				on error
					return "Failed"
				end try
				try
					do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/NSProCommands.plist '/Applications/Final Cut Pro.app/Contents/Resources/NSProCommands.plist'" with administrator privileges
				on error
					return "Failed"
				end try

				set finalCutProLanguages to {"de", "en", "es", "fr", "ja", "zh_CN"}
				repeat with whichLanguage in finalCutProLanguages
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/" & whichLanguage & ".lproj/Default.commandset '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/Default.commandset'" with administrator privileges
					on error
						return "Failed"
					end try
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandDescriptions.strings'" with administrator privileges
					on error
						return "Failed"
					end try
					try
						do shell script "cp -f ~/.hammerspoon/hs/fcpxhacks/plist/10-3/old/" & whichLanguage & ".lproj/NSProCommandNames.strings '/Applications/Final Cut Pro.app/Contents/Resources/" & whichLanguage & ".lproj/NSProCommandNames.strings'" with administrator privileges
					on error
						return "Failed"
					end try
				end repeat

				return "Done"
			]]
			ok,toggleEnableHacksShortcutsInFinalCutProResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA)
			if toggleEnableHacksShortcutsInFinalCutProResult ~= "Done" then
				dialog.displayErrorMessage("Failed to restore keyboard layouts. Something has gone wrong! Aborting reset.")
			else
				removeHacksResult = true
			end

			if removeHacksResult then

				--------------------------------------------------------------------------------
				-- Trash all FCPX Hacks Settings:
				--------------------------------------------------------------------------------
				for i, v in ipairs(settings.getKeys()) do
					if (v:sub(1,10)) == "fcpxHacks." then
						settings.set(v, nil)
					end
				end

				--------------------------------------------------------------------------------
				-- Restart Final Cut Pro if running:
				--------------------------------------------------------------------------------
				if finalCutProRunning then
					if not fcp.restart() then
						--------------------------------------------------------------------------------
						-- Failed to restart Final Cut Pro:
						--------------------------------------------------------------------------------
						dialog.displayMessage("We weren't able to restart Final Cut Pro.\n\nPlease restart Final Cut Pro manually.")
					end
				end

				--------------------------------------------------------------------------------
				-- Reload Hammerspoon:
				--------------------------------------------------------------------------------
				hs.reload()

			end --removeHacksResult
		end -- dialog.displayYesNoQuestion(resetMessage)
	end

	--------------------------------------------------------------------------------
	-- GET SCRIPT UPDATE:
	--------------------------------------------------------------------------------
	function getScriptUpdate()
		os.execute('open "' .. fcpxhacks.updateURL .. '"')
	end

	--------------------------------------------------------------------------------
	-- GO TO LATENITE FILMS SITE:
	--------------------------------------------------------------------------------
	function gotoLateNiteSite()
		os.execute('open "' .. fcpxhacks.developerURL .. '"')
	end

	--------------------------------------------------------------------------------
	-- IMPORT SHARED XML:
	--------------------------------------------------------------------------------
	function importSharedXML(whichSharedXML)

		local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
		whichSharedXMLPath = xmlSharingPath .. whichSharedXML .. ".fcpxml"

		local appleScriptA = 'set whichSharedXMLPath to "' .. whichSharedXMLPath .. '"' .. '\n\n'
		local appleScriptB = [[
			tell application "Final Cut Pro"
				activate
				open POSIX file whichSharedXMLPath as string
			end tell
		]]
		osascript.applescript(appleScriptA .. appleScriptB)

	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   S H O R T C U T   F E A T U R E S                        --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- NEEDS UPDATING:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- SELECT CLIP AT LANE:
	--------------------------------------------------------------------------------
	--
	-- TO DO: This is currently broken in Final Cut Pro 10.3.
	--
	function selectClipAtLane(whichLane)

		--------------------------------------------------------------------------------
		-- UNDER CONSTRUCTION:
		--------------------------------------------------------------------------------
		dialog.displayMessage("This feature has not yet been implemented for Final Cut Pro 10.3, however you can use the new built-in 'Select Above/Below' shortcuts as a workaround.")
		if 1==1 then return end

		--------------------------------------------------------------------------------
		-- Define FCPX:
		--------------------------------------------------------------------------------
		local fcpx 				= fcp.application()

		--------------------------------------------------------------------------------
		-- Get all FCPX UI Elements:
		--------------------------------------------------------------------------------
		fcpxElements = ax.applicationElement(fcp.application())[1]

		--------------------------------------------------------------------------------
		-- Variables:
		--------------------------------------------------------------------------------
		local whichSplitGroup 			= nil
		local whichGroup 				= nil
		local whichValueIndicator 		= nil
		local whichScrollArea			= nil

		--------------------------------------------------------------------------------
		-- Cache:
		--------------------------------------------------------------------------------
		local useCache = false
		if fcpxElements[selectClipAtLaneSplitGroupCache] ~= nil then
			if fcpxElements[selectClipAtLaneSplitGroupCache][selectClipAtLaneGroupCache] ~= nil then
				if fcpxElements[selectClipAtLaneSplitGroupCache][selectClipAtLaneGroupCache][1]:attributeValue("AXRole") == "AXSplitGroup" then
					if fcpxElements[selectClipAtLaneSplitGroupCache][selectClipAtLaneGroupCache][1]:attributeValue("AXIdentifier") == "_NS:11" then
						useCache = true
						whichSplitGroup = selectClipAtLaneSplitGroupCache
						whichGroup = selectClipAtLaneGroupCache
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- If Cache didn't work:
		--------------------------------------------------------------------------------
		if not useCache then

			--------------------------------------------------------------------------------
			-- Which Split Group:
			--------------------------------------------------------------------------------
			for i=1, fcpxElements:attributeValueCount("AXChildren") do
				if whichSplitGroup == nil then
					if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						whichSplitGroup = i
						goto selectClipAtLaneSplitGroupExit
					end
				end
			end
			if whichSplitGroup == nil then
				dialog.displayErrorMessage("Unable to locate Split Group.")
				return "Failed"
			end
			::selectClipAtLaneSplitGroupExit::
			selectClipAtLaneSplitGroupCache = whichSplitGroup

			--------------------------------------------------------------------------------
			-- Which Group:
			--------------------------------------------------------------------------------
			for i=1, fcpxElements[whichSplitGroup]:attributeValueCount("AXChildren") do
				if whichGroup == nil then
					if fcpxElements[whichSplitGroup]:attributeValue("AXChildren")[i][1] ~= nil then
						if fcpxElements[whichSplitGroup]:attributeValue("AXChildren")[i][1]:attributeValue("AXRole") == "AXSplitGroup" then
							if fcpxElements[whichSplitGroup]:attributeValue("AXChildren")[i][1]:attributeValue("AXIdentifier") == "_NS:11" then
								whichGroup = i
								goto selectClipAtLaneGroupExit
							end
						end
					end
				end
			end
			if whichGroup == nil then
				dialog.displayErrorMessage("Unable to locate Group.")
				return "Failed"
			end
			::selectClipAtLaneGroupExit::
			selectClipAtLaneGroupCache = whichGroup
		end

		--------------------------------------------------------------------------------
		-- NOE: Split Group = 1
		--------------------------------------------------------------------------------

		--------------------------------------------------------------------------------
		-- Which Scroll Area:
		--------------------------------------------------------------------------------
		for i=1, fcpxElements[whichSplitGroup][whichGroup][1]:attributeValueCount("AXChildren") do
			if fcpxElements[whichSplitGroup][whichGroup][1]:attributeValue("AXChildren")[i] ~= nil then
				if fcpxElements[whichSplitGroup][whichGroup][1]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXScrollArea" then
					if fcpxElements[whichSplitGroup][whichGroup][1]:attributeValue("AXChildren")[i]:attributeValue("AXIdentifier") == "_NS:95" then
						whichScrollArea = i
						goto performScrollingTimelineWatcherScrollAreaExit
					end
				end
			end
		end
		if whichScrollArea == nil then
			dialog.displayErrorMessage("Unable to locate Scroll Area.")
			return "Failed"
		end
		::performScrollingTimelineWatcherScrollAreaExit::

		--------------------------------------------------------------------------------
		-- NOTE: Layout Area = 1
		--------------------------------------------------------------------------------

		--------------------------------------------------------------------------------
		-- Which Value Indicator:
		--------------------------------------------------------------------------------
		for i=1, fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValueCount("AXChildren") do
			if fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "Playhead" then
				whichValueIndicator = i
				goto selectClipAtLaneValueIndicatorExit
			end
		end
		if whichValueIndicator == nil then
			dialog.displayErrorMessage("Unable to locate Value Indicator.")
			return "Failed"
		end
		::selectClipAtLaneValueIndicatorExit::

		--------------------------------------------------------------------------------
		-- Timeline Playhead Position:
		--------------------------------------------------------------------------------
		local timelinePlayheadXPosition = fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][whichValueIndicator]:attributeValue("AXPosition")['x']

		--------------------------------------------------------------------------------
		-- Which Layout Items (Selected Timeline Clip):
		--------------------------------------------------------------------------------
		local whichLayoutItems = {}
		for i=1, fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValueCount("AXChildren") do
			if fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValue("AXChildren")[i] ~= nil then

				--------------------------------------------------------------------------------
				-- Normal clips:
				--------------------------------------------------------------------------------
				if fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXLayoutItem" then
					local currentClipPositionMinX = fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXPosition")['x']
					local currentClipPositionMaxX = currentClipPositionMinX + fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXSize")['w']

					if timelinePlayheadXPosition >= currentClipPositionMinX and timelinePlayheadXPosition <= currentClipPositionMaxX then
						local currentClipPositionY = fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXPosition")['y']
						whichLayoutItems[#whichLayoutItems + 1] = { i, currentClipPositionY, currentClipSizeH}
					end
				end

				--------------------------------------------------------------------------------
				-- Storylines:
				--------------------------------------------------------------------------------
				if fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
					for ii=1, fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][i]:attributeValueCount("AXChildren") do
						if fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][i][ii] ~= nil then
							if fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][i][ii]:attributeValue("AXRole") == "AXLayoutItem" then

								local currentClipPositionMinX = fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][i][ii]:attributeValue("AXPosition")['x']
								local currentClipPositionMaxX = currentClipPositionMinX + fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][i][ii]:attributeValue("AXSize")['w']

								if timelinePlayheadXPosition >= currentClipPositionMinX and timelinePlayheadXPosition <= currentClipPositionMaxX then
									local currentClipPositionY = fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][i][ii]:attributeValue("AXPosition")['y']
									whichLayoutItems[#whichLayoutItems + 1] = { i, currentClipPositionY, currentClipSizeH }
								end

							end
						end
					end -- ii loop
				end
			end
		end

		local howManyClips = tools.tableCount(whichLayoutItems)
		if next(whichLayoutItems) == nil or howManyClips < whichLane then
			writeToConsole("ERROR: Couldn't find any clips at selected lane (selectClipAtLane).")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Sort the table:
		--------------------------------------------------------------------------------
		table.sort(whichLayoutItems, function(a, b) return a[2] > b[2] end)

		--------------------------------------------------------------------------------
		-- Which clip to we need:
		--------------------------------------------------------------------------------
		local whichClip = whichLayoutItems[whichLane][1]

		--------------------------------------------------------------------------------
		-- Click the clip:
		--------------------------------------------------------------------------------
		local clipCentrePosition = {}
		local clipPosition = fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][whichClip]:attributeValue("AXPosition")
		local clipSize = fcpxElements[whichSplitGroup][whichGroup][1][whichScrollArea][1][whichClip]:attributeValue("AXSize")

		clipCentrePosition['x'] = timelinePlayheadXPosition
		clipCentrePosition['y'] = clipPosition['y'] + ( clipSize['h'] / 2 )

		tools.ninjaMouseClick(clipCentrePosition)

	end

	--------------------------------------------------------------------------------
	-- BATCH EXPORT FROM BROWSER:
	--------------------------------------------------------------------------------
	--
	-- TO DO: This is currently broken in Final Cut Pro 10.3.
	--
	function batchExportToCompressor()

		--------------------------------------------------------------------------------
		-- UNDER CONSTRUCTION:
		--------------------------------------------------------------------------------
		dialog.displayMessage("This feature has not yet been implemented for Final Cut Pro 10.3.")
		if 1==1 then return end

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Check that there's a default destination:
		--------------------------------------------------------------------------------
		local executeResult,executeStatus = execute("defaults read ~/Library/Preferences/com.apple.FinalCut.plist FFShareDestinationsDefaultDestinationIndex")
		if executeStatus == nil then
			dialog.displayErrorMessage("Failed to access the Final Cut Pro preferences when trying to work out Default Share Destination.")
			return "Failed"
		end
		if tonumber(executeResult) > 10000 then
				local appleScriptA = [[
				activate application "Final Cut Pro"
				tell application "System Events"
					tell process "Final Cut Pro"
						display dialog "It doesn't look like you have a Default Destination selected." & return & return & "You can set a Default Destination by going to 'Preferences', clicking the 'Destinations' tab, right-clicking on the Destination you would like to use and then click 'Make Default'." buttons {"Close"} with icon fcpxIcon
						set frontmost to true
					end tell
				end tell
			]]
			local ok,dialogBoxResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA)
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Get Current FCPX Save Location:
		--------------------------------------------------------------------------------
		local executeResult,executeStatus = execute("defaults read ~/Library/Preferences/com.apple.FinalCut.plist NSNavLastRootDirectory -string")
		if executeStatus == nil then
			dialog.displayErrorMessage("We could not determine the last place you exported a file to. If this is the first time you've used Final Cut Pro, please do a test export prior to using this tool.")
			return "Failed"
		end
		local lastSavePath = tools.trim(executeResult)

		--------------------------------------------------------------------------------
		-- Filmstrip or List Mode?
		--------------------------------------------------------------------------------
		local fcpxBrowserMode = getFinalCutProBrowserMode()
		if (fcpxBrowserMode == "Failed") then -- Error Checking:
			dialog.displayErrorMessage("Unable to determine if Filmstrip or List Mode.")
			return
		end

		--------------------------------------------------------------------------------
		-- Get all FCPX UI Elements:
		--------------------------------------------------------------------------------
		fcpx = fcp.application()
		fcpxElements = ax.applicationElement(fcpx)[1]

		--------------------------------------------------------------------------------
		-- Which Split Group:
		--------------------------------------------------------------------------------
		local whichSplitGroup = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if whichSplitGroup == nil then
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
					whichSplitGroup = i
				end
			end
		end
		if whichSplitGroup == nil then
			dialog.displayErrorMessage("Unable to locate Split Group.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- List Mode:
		--------------------------------------------------------------------------------
		if fcpxBrowserMode == "List" then

			--------------------------------------------------------------------------------
			-- Which Group contains the browser:
			--------------------------------------------------------------------------------
			whichGroup = nil
			for i=1, fcpxElements[whichSplitGroup]:attributeValueCount("AXChildren") do
				if whichGroupGroup == nil then
					if fcpxElements[whichSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
						--------------------------------------------------------------------------------
						-- We now have ALL of the groups, and need to work out which group we actually want:
						--------------------------------------------------------------------------------
						for x=1, fcpxElements[whichSplitGroup][i]:attributeValueCount("AXChildren") do
							if fcpxElements[whichSplitGroup][i][x]:attributeValue("AXRole") == "AXSplitGroup" then
								--------------------------------------------------------------------------------
								-- Which Split Group is it:
								--------------------------------------------------------------------------------
								for y=1, fcpxElements[whichSplitGroup][i][x]:attributeValueCount("AXChildren") do
									if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXRole") == "AXSplitGroup" then
										if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXIdentifier") == "_NS:231" then
											whichGroup = i
											goto listGroupDone
										end
									end
								end
							end
						end
					end
				end
			end
			::listGroupDone::
			if whichGroup == nil then
				local appleScriptA = [[
					activate application "Final Cut Pro"
					tell application "System Events"
						tell process "Final Cut Pro"
							display dialog "It doesn't look like you have any clips selected in the Library?" buttons {"Close"} with icon fcpxIcon
							set frontmost to true
						end tell
					end tell
				]]
				local ok,dialogBoxResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA)
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Split Group Two:
			--------------------------------------------------------------------------------
			whichSplitGroupTwo = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup]:attributeValueCount("AXChildren")) do
				if whichSplitGroupTwo == nil then
					if fcpxElements[whichSplitGroup][whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						whichSplitGroupTwo = i
						goto listSplitGroupTwo
					end
				end
			end
			::listSplitGroupTwo::
			if whichSplitGroupTwo == nil then
				dialog.displayErrorMessage("Unable to locate Split Group Two.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Split Group Three:
			--------------------------------------------------------------------------------
			whichSplitGroupThree = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValueCount("AXChildren")) do
				if whichSplitGroupThree == nil then
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						whichSplitGroupThree = i
						goto listSplitGroupThree
					end
				end
			end
			::listSplitGroupThree::
			if whichSplitGroupThree == nil then
				dialog.displayErrorMessage("Unable to locate Split Group Three.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Scroll Area:
			--------------------------------------------------------------------------------
			whichScrollArea = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXScrollArea" then
					whichScrollArea = i
				end
			end
			if whichScrollArea == nil then
				dialog.displayErrorMessage("Unable to locate Scroll Area.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Outline:
			--------------------------------------------------------------------------------
			whichOutline = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXOutline" then
					whichOutline = i
				end
			end
			if whichOutline == nil then
				dialog.displayErrorMessage("Unable to locate Outline.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Rows's (can be multiple):
			--------------------------------------------------------------------------------
			whichRows = {nil}
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXRow" then
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline]:attributeValue("AXChildren")[i]:attributeValue("AXSelected") == true then
						whichRows[#whichRows + 1] = i
					end
				end
			end

		--------------------------------------------------------------------------------
		-- Filmstrip Mode:
		--------------------------------------------------------------------------------
		elseif fcpxBrowserMode == "Filmstrip" then

			--------------------------------------------------------------------------------
			-- Which Group contains the browser:
			--------------------------------------------------------------------------------
			whichGroup = nil
			for i=1, fcpxElements[whichSplitGroup]:attributeValueCount("AXChildren") do
				if whichGroupGroup == nil then
					if fcpxElements[whichSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
						--------------------------------------------------------------------------------
						-- We now have ALL of the groups, and need to work out which group we actually want:
						--------------------------------------------------------------------------------
						for x=1, fcpxElements[whichSplitGroup][i]:attributeValueCount("AXChildren") do
							if fcpxElements[whichSplitGroup][i][x]:attributeValue("AXRole") == "AXSplitGroup" then
								--------------------------------------------------------------------------------
								-- Which Split Group is it:
								--------------------------------------------------------------------------------
								for y=1, fcpxElements[whichSplitGroup][i][x]:attributeValueCount("AXChildren") do
									if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXRole") == "AXScrollArea" then
										if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXIdentifier") == "_NS:40" then
											whichGroup = i
											goto filmstripGroupDone
										end
									end
								end
							end
						end
					end
				end
			end
			::filmstripGroupDone::
			if whichGroup == nil then
				dialog.displayErrorMessage("Unable to locate Group.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Split Group Two:
			--------------------------------------------------------------------------------
			whichSplitGroupTwo = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup]:attributeValueCount("AXChildren")) do
				if whichSplitGroupTwo == nil then
					if fcpxElements[whichSplitGroup][whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						whichSplitGroupTwo = i
						goto filmstripSplitGroupTwoDone
					end
				end
			end
			::filmstripSplitGroupTwoDone::
			if whichSplitGroupTwo == nil then
				dialog.displayErrorMessage("Unable to locate Split Group Two.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Scroll Area:
			--------------------------------------------------------------------------------
			whichScrollArea = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXScrollArea" then
					whichScrollArea = i
				end
			end
			if whichScrollArea == nil then
				dialog.displayErrorMessage("Unable to locate Scroll Area.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Group Two:
			--------------------------------------------------------------------------------
			whichGroupTwo = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
					whichGroupTwo = i
				end
			end
			if whichGroupTwo == nil then
				dialog.displayErrorMessage("Unable to locate Group Two.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Group Three's (can be multiple):
			--------------------------------------------------------------------------------
			whichGroupThree = {}
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXSelectedChildren")[1] ~= nil then
						whichGroupThree[#whichGroupThree + 1] = i
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- How many clips (regardless of Filmstrip or List mode)?
		--------------------------------------------------------------------------------
		local howManyClips = 0
		if fcpxBrowserMode == "Filmstrip" then howManyClips = #whichGroupThree end
		if fcpxBrowserMode == "List" then howManyClips = #whichRows end

		--------------------------------------------------------------------------------
		-- How many times cancel is forced during the Batch Export:
		--------------------------------------------------------------------------------
		cancelCount = 0

		--------------------------------------------------------------------------------
		-- If no clips are selected, then what about Keywords, Events or Libraries?
		--------------------------------------------------------------------------------
		if howManyClips == 0 then

			--------------------------------------------------------------------------------
			-- Which Library Scroll Area:
			--------------------------------------------------------------------------------
			whichLibraryScrollArea = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXScrollArea" then
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXIdentifier") == "_NS:32" then
						whichLibraryScrollArea = i
					end
				end
			end
			if whichLibraryScrollArea == nil then
				dialog.displayErrorMessage("Unable to locate Library Scroll Area.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- NOTE: There's only one AXOutline next so just use [1].
			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Which Library Role:
			--------------------------------------------------------------------------------
			whichLibraryRows = {}
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichLibraryScrollArea][1]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichLibraryScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXRow" then
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichLibraryScrollArea][1]:attributeValue("AXChildren")[i]:attributeValue("AXSelected") == true then
						whichLibraryRows[#whichLibraryRows + 1] = i
					end
				end
			end

			if #whichLibraryRows == 0 then
				dialog.displayErrorMessage("Unable to locate Library Role.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Display Dialog to make sure the current path is acceptable:
			--------------------------------------------------------------------------------
			local appleScriptA = 'set howManyClips to "' .. #whichLibraryRows .. '"\n'
			local appleScriptB = 'set lastSavePath to "' .. lastSavePath .. '"\n'
			local appleScriptC = [[
				activate application "Final Cut Pro"
				tell application "System Events"
					tell process "Final Cut Pro"
						try
							if howManyClips is equal to "1" then
								display dialog "Final Cut Pro will export the contents of the selected item using your default export settings to the following location:" & return & return & lastSavePath & return & return & "If you wish to change this location, export something else with your preferred destination first." & return & return & "Please do not move the mouse or interrupt Final Cut Pro once you press the Continue button as it may break the automation." & return & return & "If there's already a file with the same name in the export destination then that clip will be skipped." buttons {"Continue Batch Export", "Cancel"} with icon fcpxIcon
							else
								display dialog "Final Cut Pro will export the contents of the " & howManyClips & " selected items using your default export settings to the following location:" & return & return & lastSavePath & return & return & "If you wish to change this location, export something else with your preferred destination first." & return & return & "Please do not move the mouse or interrupt Final Cut Pro once you press the Continue button as it may break the automation." & return & return & "If there's already a file with the same name in the export destination then that clip will be skipped." buttons {"Continue Batch Export", "Cancel"} with icon fcpxIcon
							end if
						on error
							return "Failed"
						end try
						if the button returned of the result is "Continue Batch Export" then
							return "Done"
						end if
						set frontmost to true
					end tell
				end tell
			]]
			local ok,dialogBoxResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA .. appleScriptB .. appleScriptC)

			--------------------------------------------------------------------------------
			-- Abort when Cancel is pressed:
			--------------------------------------------------------------------------------
			if dialogBoxResult == "Failed" then return "Failed" end

			--------------------------------------------------------------------------------
			-- If was previously in Filmstrip mode - need to get data as if from list:
			--------------------------------------------------------------------------------
			if fcpxBrowserMode == "Filmstrip" then

				--------------------------------------------------------------------------------
				-- Switch to list mode:
				--------------------------------------------------------------------------------
				viewAsListResult = fcp.selectMenuItem({"View", "Browser", "as List"})
				if viewAsListResult == nil then
					dialog.displayErrorMessage("Failed to switch to list mode.")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Trigger Group clips by None:
				--------------------------------------------------------------------------------
				groupClipsByResult = fcp.selectMenuItem({"View", "Browser", "Group Clips By", "None"})
				if groupClipsByResult == nil then
					dialog.displayErrorMessage("Failed to switch to Group Clips by None.")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Group contains the browser:
				--------------------------------------------------------------------------------
				whichGroup = nil
				for i=1, fcpxElements[whichSplitGroup]:attributeValueCount("AXChildren") do
					if whichGroupGroup == nil then
						if fcpxElements[whichSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
							--------------------------------------------------------------------------------
							-- We now have ALL of the groups, and need to work out which group we actually want:
							--------------------------------------------------------------------------------
							for x=1, fcpxElements[whichSplitGroup][i]:attributeValueCount("AXChildren") do
								if fcpxElements[whichSplitGroup][i][x]:attributeValue("AXRole") == "AXSplitGroup" then
									--------------------------------------------------------------------------------
									-- Which Split Group is it:
									--------------------------------------------------------------------------------
									for y=1, fcpxElements[whichSplitGroup][i][x]:attributeValueCount("AXChildren") do
										if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXRole") == "AXSplitGroup" then
											if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXIdentifier") == "_NS:231" then
												whichGroup = i
												goto listGroupDoneA
											end
										end
									end
								end
							end
						end
					end
				end
				::listGroupDoneA::
				if whichGroup == nil then
					dialog.displayErrorMessage("Unable to locate Group.")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Split Group Two:
				--------------------------------------------------------------------------------
				whichSplitGroupTwo = nil
				for i=1, (fcpxElements[whichSplitGroup][whichGroup]:attributeValueCount("AXChildren")) do
					if whichSplitGroupTwo == nil then
						if fcpxElements[whichSplitGroup][whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
							whichSplitGroupTwo = i
							goto listSplitGroupTwoA
						end
					end
				end
				::listSplitGroupTwoA::
				if whichSplitGroupTwo == nil then
					dialog.displayErrorMessage("Unable to locate Split Group Two.")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Split Group Three:
				--------------------------------------------------------------------------------
				whichSplitGroupThree = nil
				for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValueCount("AXChildren")) do
					if whichSplitGroupThree == nil then
						if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
							whichSplitGroupThree = i
							goto listSplitGroupThreeA
						end
					end
				end
				::listSplitGroupThreeA::
				if whichSplitGroupThree == nil then
					dialog.displayErrorMessage("Unable to locate Split Group Three.")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Scroll Area:
				--------------------------------------------------------------------------------
				whichScrollArea = nil
				for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree]:attributeValueCount("AXChildren")) do
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXScrollArea" then
						whichScrollArea = i
					end
				end
				if whichScrollArea == nil then
					dialog.displayErrorMessage("Unable to locate Scroll Area.")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Outline:
				--------------------------------------------------------------------------------
				whichOutline = nil
				for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea]:attributeValueCount("AXChildren")) do
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXOutline" then
						whichOutline = i
					end
				end
				if whichOutline == nil then
					dialog.displayErrorMessage("Unable to locate Outline.")
					return "Failed"
				end

			end

			--------------------------------------------------------------------------------
			-- Now we need to apply to each row:
			--------------------------------------------------------------------------------
			for i=1, #whichLibraryRows do

				--------------------------------------------------------------------------------
				-- Select Left Panel Item:
				--------------------------------------------------------------------------------
				fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichLibraryScrollArea][1][whichLibraryRows[i]]:setAttributeValue("AXSelected", true)

				--------------------------------------------------------------------------------
				-- Get all individual items from right panel:
				--------------------------------------------------------------------------------
				local whichRows = {}
				if whichRows ~= nil then -- Clear whichRows if needed.
					for k in pairs (whichRows) do
						whichRows[k] = nil
					end
				end
				for ii=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline]:attributeValueCount("AXChildren")) do
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline]:attributeValue("AXChildren")[ii]:attributeValue("AXRole") == "AXRow" then
						if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline]:attributeValue("AXChildren")[ii][1]:attributeValue("AXRole") == "AXGroup" then
							if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline]:attributeValue("AXChildren")[ii][1][2]:attributeValue("AXDescription") == "Organizer filmlist name column" then
								whichRows[#whichRows + 1] = ii
							end
						end
					end
				end

				if #whichRows == 0 then
					dialog.displayErrorMessage("Nothing in the selected item.")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Bring Focus Back to Clips:
				--------------------------------------------------------------------------------
				local originalMousePoint = mouse.getAbsolutePosition()
				local listPosition = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea]:attributeValue("AXPosition")
				eventtap.leftClick(listPosition)
				mouse.setAbsolutePosition(originalMousePoint)

				--------------------------------------------------------------------------------
				-- Begin Clip Loop:
				--------------------------------------------------------------------------------
				for x=1, #whichRows do

					--------------------------------------------------------------------------------
					-- Select clip:
					--------------------------------------------------------------------------------
					fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline][whichRows[x]]:setAttributeValue("AXSelected", true)

					--------------------------------------------------------------------------------
					-- Trigger CMD+E (Export Using Default Share)
					--------------------------------------------------------------------------------
					if not keyStrokeFromPlist("ShareDefaultDestination") then
						dialog.displayErrorMessage("Failed to trigger the 'Export using Default Share Destination' Shortcut.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Wait for window to open:
					--------------------------------------------------------------------------------
					fcpxExportWindow = ax.applicationElement(fcpx)

					local timeoutCount = 0
					local exportWindowOpen = false

					::waitForExportWindowA::
					whichExportWindow = nil
					for yi=1, (fcpxExportWindow:attributeValueCount("AXChildren")) do
						if fcpxExportWindow:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXWindow" then
							for yx=1, fcpxExportWindow:attributeValue("AXChildren")[yi]:attributeValueCount("AXChildren") do
								if fcpxExportWindow[yi][yx]:attributeValue("AXRole") == "AXImage" then
									if fcpxExportWindow[yi][yx]:attributeValue("AXDescription") == "Share WindowBackground" then
										exportWindowOpen = true
										whichExportWindow = yi
									end
								end
							end
						end
					end

					if exportWindowOpen == false then
						timeoutCount = timeoutCount + 1
						if timeoutCount == 10 then
							dialog.displayErrorMessage("It took too long for Export Window to open so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto waitForExportWindowA
						end
					end

					--------------------------------------------------------------------------------
					-- Find Next Button:
					--------------------------------------------------------------------------------
					whichNextButton = nil
					for yi=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
							if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Next…" then
								whichNextButton = yi
							end
						end
					end
					if whichNextButton == nil then
						dialog.displayErrorMessage("Unable to locate Group Two.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Then press it:
					--------------------------------------------------------------------------------
					pressNextButtonResult = fcpxExportWindow[whichExportWindow][whichNextButton]:performAction("AXPress")
					if pressNextButtonResult == nil then
						dialog.displayErrorMessage("Unable to press Next Button.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Wait for Save Window to Open:
					--------------------------------------------------------------------------------
					local timeoutCount = 0
					local saveWindowOpen = false

					whichSaveSheet = nil

					::waitForSaveWindowA::
					for yi=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXSheet" then
							if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXDescription") == "save" then
								whichSaveSheet = yi
								saveWindowOpen = true
							end
						end
					end
					if whichSaveSheet == nil then
						dialog.displayErrorMessage("Unable to locate Save Window.")
						return "Failed"
					end

					if saveWindowOpen == false then
						timeoutCount = timeoutCount + 1
						if timeoutCount == 10 then
							dialog.displayErrorMessage("It took too long for Save Window to open so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto waitForSaveWindowA
						end
					end

					--------------------------------------------------------------------------------
					-- Find Save Button:
					--------------------------------------------------------------------------------
					whichSaveButton = nil
					for yi=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
							if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Save" then
								whichSaveButton = yi
							end
						end
					end
					if whichSaveButton == nil then
						dialog.displayErrorMessage("Unable to locate Group Two.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Press Save Button:
					--------------------------------------------------------------------------------
					local pressSaveButtonResult = fcpxExportWindow[whichExportWindow][whichSaveSheet][whichSaveButton]:performAction("AXPress")
					if pressSaveButtonResult == nil then
						dialog.displayErrorMessage("Unable to press Save Button.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Make sure Save Window is closed:
					--------------------------------------------------------------------------------
					local timeoutCount = 0

					::checkSaveWindowIsClosedA::
					if fcpxExportWindow[whichExportWindow][whichSaveSheet] == nil then
						-- Continue on...
					else
						--------------------------------------------------------------------------------
						-- If an alert appears, click Cancel:
						--------------------------------------------------------------------------------
						whichAlertSheet = nil
						whichAlertButton = nil
						performCancel = false
						for yi=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
							if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXSheet" then
								if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXDescription") == "alert" then
									for yx=1, fcpxExportWindow[whichExportWindow][whichSaveSheet][yi]:attributeValueCount("AXChildren") do
										if fcpxExportWindow[whichExportWindow][whichSaveSheet][yi][yx]:attributeValue("AXRole") == "AXButton" then
											if fcpxExportWindow[whichExportWindow][whichSaveSheet][yi][yx]:attributeValue("AXTitle") == "Cancel" then
												whichAlertSheet = yi
												whichAlertButton = yx
												performCancel = true
											end
										end
									end
								end
							end
						end
						if performCancel then
							cancelCount = cancelCount + 1

							--------------------------------------------------------------------------------
							-- Press Cancel on the Alert:
							--------------------------------------------------------------------------------
							local pressCancelButton = fcpxExportWindow[whichExportWindow][whichSaveSheet][whichAlertSheet][whichAlertButton]:performAction("AXPress")
							if pressCancelButton == nil then
								dialog.displayErrorMessage("Unable to press Cancel Button on the Alert.")
								return "Failed"
							end

							--------------------------------------------------------------------------------
							-- Press Cancel on the Save Dialog:
							--------------------------------------------------------------------------------
							whichCancelButton = nil
							for yi=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
								if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
									if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Cancel" then
										whichCancelButton = yi
									end
								end
							end
							if whichCancelButton == nil then
								dialog.displayErrorMessage("Unable to locate the cancel button.")
								return "Failed"
							end
							local pressCancelButton = fcpxExportWindow[whichExportWindow][whichSaveSheet][whichCancelButton]:performAction("AXPress")
							if pressCancelButton == nil then
								dialog.displayErrorMessage("Unable to press Cancel Button on Save Dialog.")
								return "Failed"
							end

							--------------------------------------------------------------------------------
							-- Press Cancel on the Export Window:
							--------------------------------------------------------------------------------
							whichCancelExportButton = nil
							for yi=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
								if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
									if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Cancel" then
										whichCancelExportButton = yi
									end
								end
							end
							if whichCancelExportButton == nil then
								dialog.displayErrorMessage("Unable to locate Group Two.")
								return "Failed"
							end
							local pressCancelButton = fcpxExportWindow[whichExportWindow][whichCancelExportButton]:performAction("AXPress")
							if pressCancelButton == nil then
								dialog.displayErrorMessage("Unable to press Cancel Button on Export Window.")
								return "Failed"
							end

							goto nextClipInListQueueA

						end -- Perform Cancel

						timeoutCount = timeoutCount + 1
						if timeoutCount == 20 then
							dialog.displayErrorMessage("It took too long for the Save Window to close so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto checkSaveWindowIsClosedA
						end
					end -- Save Sheet Closed
					::nextClipInListQueueA::
				end -- x loop
			end -- i loop
		else
		--------------------------------------------------------------------------------
		-- Single Keyword or Smart Selection:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Display Dialog to make sure the current path is acceptable:
			--------------------------------------------------------------------------------
			local appleScriptA = 'set howManyClips to "' .. howManyClips .. '"\n'
			local appleScriptB = 'set lastSavePath to "' .. lastSavePath .. '"\n'
			local appleScriptC = [[
				activate application "Final Cut Pro"
				tell application "System Events"
					tell process "Final Cut Pro"
						try
							if howManyClips is "1" then
								display dialog "Final Cut Pro will export this clip using your default export settings to the following location:" & return & return & lastSavePath & return & return & "If you wish to change this location, export something else with your preferred destination first." & return & return & "Please do not move the mouse or interrupt Final Cut Pro once you press the Continue button as it may break the automation." & return & return & "If there's already a file with the same name in the export destination then that clip will be skipped." buttons {"Continue Batch Export", "Cancel"} with icon fcpxIcon
							else
								display dialog "Final Cut Pro will export these " & howManyClips & " clips using your default export settings to the following location:" & return & return & lastSavePath & return & return & "If you wish to change this location, export something else with your preferred destination first." & return & return & "Please do not move the mouse or interrupt Final Cut Pro once you press the Continue button as it may break the automation." & return & return & "If there's already a file with the same name in the export destination then that clip will be skipped." buttons {"Continue Batch Export", "Cancel"} with icon fcpxIcon
							end if
						on error
							return "Failed"
						end try
						if the button returned of the result is "Continue Batch Export" then
							return "Done"
						end if
						set frontmost to true
					end tell
				end tell
			]]
			local ok,dialogBoxResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA .. appleScriptB .. appleScriptC)

			--------------------------------------------------------------------------------
			-- Abort when Cancel is pressed:
			--------------------------------------------------------------------------------
			if dialogBoxResult == "Failed" then return "Failed" end

			--------------------------------------------------------------------------------
			-- Bring Focus Back to Clips:
			--------------------------------------------------------------------------------
			if fcpxBrowserMode == "List" then
				local originalMousePoint = mouse.getAbsolutePosition()
				local listPosition = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline][1]:attributeValue("AXPosition")
				eventtap.leftClick(listPosition)
				mouse.setAbsolutePosition(originalMousePoint)
			end

			--------------------------------------------------------------------------------
			-- Let the games begin!
			--------------------------------------------------------------------------------
			if fcpxBrowserMode == "Filmstrip" then
				for i=1, #whichGroupThree do

					--------------------------------------------------------------------------------
					-- Which Layout Item:
					--------------------------------------------------------------------------------
					whichLayoutItem = nil
					local noRangeSelected = false
					for x=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo][whichGroupThree[i]]:attributeValueCount("AXChildren")) do
						if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo][whichGroupThree[i]]:attributeValue("AXChildren")[x]:attributeValue("AXRole") == "AXLayoutItem" then
							whichLayoutItem = x
						else
							--------------------------------------------------------------------------------
							-- If one of the clips doesn't have a range selected:
							--------------------------------------------------------------------------------
							if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo][whichGroupThree[i]]:attributeValue("AXChildren")[x]:attributeValue("AXRole") == "AXImage" then
								whichLayoutItem = x
								noRangeSelected = true
							end
						end
					end
					if whichLayoutItem == nil then
						dialog.displayErrorMessage("Unable to locate Layout Item.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- If one of the clips doesn't have a range selected:
					--------------------------------------------------------------------------------
					::checkClipPositionTop::
					if noRangeSelected then
						clipPosition = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo][whichGroupThree[i]][whichLayoutItem]:attributeValue("AXPosition")
					else
						clipPosition = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo][whichGroupThree[i]][whichLayoutItem][1]:attributeValue("AXPosition")
					end

					clipPosition['x'] = clipPosition['x'] + 5
					clipPosition['y'] = clipPosition['y'] + 10

					--------------------------------------------------------------------------------
					-- Make sure the clip is actually visible:
					--------------------------------------------------------------------------------
					local scrollAreaPosition = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea]:attributeValue("AXPosition")
					local scrollAreaSize = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea]:attributeValue("AXSize")

						--------------------------------------------------------------------------------
						-- Need to scroll up:
						--------------------------------------------------------------------------------
						if clipPosition['y'] < scrollAreaPosition['y'] then
							local scrollBarValue = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][2][1]:attributeValue("AXValue")
							fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][2][1]:setAttributeValue("AXValue", (scrollBarValue - 0.02))
							goto checkClipPositionTop
						end

						--------------------------------------------------------------------------------
						-- Need to scroll down:
						--------------------------------------------------------------------------------
						if clipPosition['y'] > (scrollAreaPosition['y']+scrollAreaSize['h']) then
							local scrollBarValue = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][2][1]:attributeValue("AXValue")
							fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][2][1]:setAttributeValue("AXValue", (scrollBarValue + 0.02))
							goto checkClipPositionTop
						end

					--------------------------------------------------------------------------------
					-- Click Thumbnail:
					--------------------------------------------------------------------------------
					local originalMousePoint = mouse.getAbsolutePosition()
					eventtap.leftClick(clipPosition)
					mouse.setAbsolutePosition(originalMousePoint)

					--------------------------------------------------------------------------------
					-- Trigger CMD+E (Export Using Default Share):
					--------------------------------------------------------------------------------
					if not keyStrokeFromPlist("ShareDefaultDestination") then
						dialog.displayErrorMessage("Failed to trigger the 'Export using Default Share Destination' Shortcut.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Wait for window to open:
					--------------------------------------------------------------------------------
					fcpxExportWindow = ax.applicationElement(fcpx)

					local timeoutCount = 0
					local exportWindowOpen = false

					::waitForExportWindowC::
					whichExportWindow = nil
					for yi=1, (fcpxExportWindow:attributeValueCount("AXChildren")) do
						if fcpxExportWindow:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXWindow" then
							for yx=1, fcpxExportWindow:attributeValue("AXChildren")[yi]:attributeValueCount("AXChildren") do
								if fcpxExportWindow[yi][yx]:attributeValue("AXRole") == "AXImage" then
									if fcpxExportWindow[yi][yx]:attributeValue("AXDescription") == "Share WindowBackground" then

										exportWindowOpen = true
										whichExportWindow = yi
									end
								end
							end
						end
					end

					if exportWindowOpen == false then
						timeoutCount = timeoutCount + 1
						if timeoutCount == 5 then
							dialog.displayErrorMessage("It took too long (five seconds) for Export Window to open so I gave up.")
							return "Failed"
						else
							timer.usleep(1000000)
							goto waitForExportWindowC
						end
					end

					--------------------------------------------------------------------------------
					-- Find Next Button:
					--------------------------------------------------------------------------------
					whichNextButton = nil
					for yi=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
							if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Next…" then
								whichNextButton = yi
							end
						end
					end
					if whichNextButton == nil then
						dialog.displayErrorMessage("Unable to locate Group Two.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Then press it:
					--------------------------------------------------------------------------------
					local pressNextButtonResult = fcpxExportWindow[whichExportWindow][whichNextButton]:performAction("AXPress")
					if pressNextButtonResult == nil then
						dialog.displayErrorMessage("Failed to press Next Button.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Wait for Save Window to Open:
					--------------------------------------------------------------------------------
					local timeoutCount = 0
					local saveWindowOpen = false

					whichSaveSheet = nil

					::waitForSaveWindowC::
					for yi=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXSheet" then
							if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXDescription") == "save" then
								whichSaveSheet = yi
								saveWindowOpen = true
							end
						end
					end
					if whichSaveSheet == nil then
						dialog.displayErrorMessage("Unable to locate Save Window.")
						return "Failed"
					end

					if saveWindowOpen == false then
						timeoutCount = timeoutCount + 1
						if timeoutCount == 10 then
							dialog.displayErrorMessage("It took too long for Save Window to open so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto waitForSaveWindowC
						end
					end

					--------------------------------------------------------------------------------
					-- Find Save Button:
					--------------------------------------------------------------------------------
					whichSaveButton = nil
					for yi=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
							if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Save" then
								whichSaveButton = yi
							end
						end
					end
					if whichSaveButton == nil then
						dialog.displayErrorMessage("Unable to locate Group Two.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Press Save Button:
					--------------------------------------------------------------------------------
					local pressSaveButtonResult = fcpxExportWindow[whichExportWindow][whichSaveSheet][whichSaveButton]:performAction("AXPress")
					if pressSaveButtonResult == nil then
						dialog.displayErrorMessage("Unable to press Save Button.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Make sure Save Window is closed:
					--------------------------------------------------------------------------------
					local timeoutCount = 0

					::checkSaveWindowIsClosedC::
					if fcpxExportWindow[whichExportWindow][whichSaveSheet] == nil then
						-- Continue on...
					else

						--------------------------------------------------------------------------------
						-- If an alert appears, click Cancel:
						--------------------------------------------------------------------------------
						whichAlertSheet = nil
						whichAlertButton = nil
						performCancel = false
						for yi=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
							if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXSheet" then
								if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXDescription") == "alert" then
									for yx=1, fcpxExportWindow[whichExportWindow][whichSaveSheet][yi]:attributeValueCount("AXChildren") do
										if fcpxExportWindow[whichExportWindow][whichSaveSheet][yi][yx]:attributeValue("AXRole") == "AXButton" then
											if fcpxExportWindow[whichExportWindow][whichSaveSheet][yi][yx]:attributeValue("AXTitle") == "Cancel" then
												whichAlertSheet = yi
												whichAlertButton = yx
												performCancel = true
											end
										end
									end
								end
							end
						end
						if performCancel then
							cancelCount = cancelCount + 1

							--------------------------------------------------------------------------------
							-- Press Cancel on the Alert:
							--------------------------------------------------------------------------------
							local pressCancelButton = fcpxExportWindow[whichExportWindow][whichSaveSheet][whichAlertSheet][whichAlertButton]:performAction("AXPress")
							if pressCancelButton == nil then
								dialog.displayErrorMessage("Unable to press Cancel on the Alert.")
								return "Failed"
							end

							--------------------------------------------------------------------------------
							-- Press Cancel on the Save Dialog:
							--------------------------------------------------------------------------------
							whichCancelButton = nil
							for yi=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
								if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
									if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Cancel" then
										whichCancelButton = yi
									end
								end
							end
							if whichCancelButton == nil then
								dialog.displayErrorMessage("Unable to locate the cancel button.")
								return "Failed"
							end
							local pressCancelButton = fcpxExportWindow[whichExportWindow][whichSaveSheet][whichCancelButton]:performAction("AXPress")
							if pressCancelButton == nil then
								dialog.displayErrorMessage("Unable to press the cancel button on the save dialog.")
								return "Failed"
							end

							--------------------------------------------------------------------------------
							-- Press Cancel on the Export Window:
							--------------------------------------------------------------------------------
							whichCancelExportButton = nil
							for yi=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
								if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXButton" then
									if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[yi]:attributeValue("AXTitle") == "Cancel" then
										whichCancelExportButton = yi
									end
								end
							end
							if whichCancelExportButton == nil then
								dialog.displayErrorMessage("Unable to locate Group Two.")
								return "Failed"
							end
							local pressCancelButton = fcpxExportWindow[whichExportWindow][whichCancelExportButton]:performAction("AXPress")
							if pressCancelButton == nil then
								dialog.displayErrorMessage("Unable to press the Cancel button on the Export Window.")
								return "Failed"
							end

							goto nextClipInFilmstripQueueC

						end
						timeoutCount = timeoutCount + 1
						if timeoutCount == 20 then
							dialog.displayErrorMessage("It took too long for the Save Window to close so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto checkSaveWindowIsClosedC
						end
					end
					::nextClipInFilmstripQueueC::
				end
			end
			--------------------------------------------------------------------------------
			-- List Mode:
			--------------------------------------------------------------------------------
			if fcpxBrowserMode == "List" then
				for i=1, #whichRows do

					--------------------------------------------------------------------------------
					-- Select clip:
					--------------------------------------------------------------------------------
					fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichScrollArea][whichOutline][whichRows[i]]:setAttributeValue("AXSelected", true)

					--------------------------------------------------------------------------------
					-- Trigger CMD+E (Export Using Default Share)
					--------------------------------------------------------------------------------
					if not keyStrokeFromPlist("ShareDefaultDestination") then
						dialog.displayErrorMessage("Failed to trigger the 'Export using Default Share Destination' Shortcut.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Wait for window to open:
					--------------------------------------------------------------------------------
					fcpxExportWindow = ax.applicationElement(fcpx)

					local timeoutCount = 0
					local exportWindowOpen = false

					::waitForExportWindow::
					whichExportWindow = nil
					for yi=1, (fcpxExportWindow:attributeValueCount("AXChildren")) do
						if fcpxExportWindow:attributeValue("AXChildren")[yi]:attributeValue("AXRole") == "AXWindow" then
							for yx=1, fcpxExportWindow:attributeValue("AXChildren")[yi]:attributeValueCount("AXChildren") do
								if fcpxExportWindow[yi][yx]:attributeValue("AXRole") == "AXImage" then
									if fcpxExportWindow[yi][yx]:attributeValue("AXDescription") == "Share WindowBackground" then
										exportWindowOpen = true
										whichExportWindow = yi
									end
								end
							end
						end
					end

					if exportWindowOpen == false then
						timeoutCount = timeoutCount + 1
						if timeoutCount == 10 then
							dialog.displayErrorMessage("It took too long for Export Window to open so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto waitForExportWindow
						end
					end

					--------------------------------------------------------------------------------
					-- Find Next Button:
					--------------------------------------------------------------------------------
					whichNextButton = nil
					for i=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXButton" then
							if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[i]:attributeValue("AXTitle") == "Next…" then
								whichNextButton = i
							end
						end
					end
					if whichNextButton == nil then
						dialog.displayErrorMessage("Unable to locate Group Two.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Then press it:
					--------------------------------------------------------------------------------
					fcpxExportWindow[whichExportWindow][whichNextButton]:performAction("AXPress")

					--------------------------------------------------------------------------------
					-- Wait for Save Window to Open:
					--------------------------------------------------------------------------------
					local timeoutCount = 0
					local saveWindowOpen = false

					whichSaveSheet = nil

					::waitForSaveWindow::
					for i=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSheet" then
							if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "save" then
								whichSaveSheet = i
								saveWindowOpen = true
							end
						end
					end
					if whichSaveSheet == nil then
						dialog.displayErrorMessage("Unable to locate Save Window.")
						return "Failed"
					end

					if saveWindowOpen == false then
						timeoutCount = timeoutCount + 1
						if timeoutCount == 10 then
							dialog.displayErrorMessage("It took too long for Save Window to open so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto waitForSaveWindow
						end
					end

					--------------------------------------------------------------------------------
					-- Find Save Button:
					--------------------------------------------------------------------------------
					whichSaveButton = nil
					for i=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
						if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXButton" then
							if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[i]:attributeValue("AXTitle") == "Save" then
								whichSaveButton = i
							end
						end
					end
					if whichSaveButton == nil then
						dialog.displayErrorMessage("Unable to locate Group Two.")
						return "Failed"
					end

					--------------------------------------------------------------------------------
					-- Press Save Button:
					--------------------------------------------------------------------------------
					fcpxExportWindow[whichExportWindow][whichSaveSheet][whichSaveButton]:performAction("AXPress")

					--------------------------------------------------------------------------------
					-- Make sure Save Window is closed:
					--------------------------------------------------------------------------------
					local timeoutCount = 0

					::checkSaveWindowIsClosed::
					if fcpxExportWindow[whichExportWindow][whichSaveSheet] == nil then
						-- Continue on...
					else

						--------------------------------------------------------------------------------
						-- If an alert appears, click Cancel:
						--------------------------------------------------------------------------------
						whichAlertSheet = nil
						whichAlertButton = nil
						performCancel = false
						for i=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
							if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSheet" then
								if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "alert" then
									for x=1, fcpxExportWindow[whichExportWindow][whichSaveSheet][i]:attributeValueCount("AXChildren") do
										if fcpxExportWindow[whichExportWindow][whichSaveSheet][i][x]:attributeValue("AXRole") == "AXButton" then
											if fcpxExportWindow[whichExportWindow][whichSaveSheet][i][x]:attributeValue("AXTitle") == "Cancel" then
												whichAlertSheet = i
												whichAlertButton = x
												performCancel = true
											end
										end
									end
								end
							end
						end
						if performCancel then
							cancelCount = cancelCount + 1

							--------------------------------------------------------------------------------
							-- Press Cancel on the Alert:
							--------------------------------------------------------------------------------
							fcpxExportWindow[whichExportWindow][whichSaveSheet][whichAlertSheet][whichAlertButton]:performAction("AXPress")

							--------------------------------------------------------------------------------
							-- Press Cancel on the Save Dialog:
							--------------------------------------------------------------------------------
							whichCancelButton = nil
							for i=1, (fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValueCount("AXChildren")) do
								if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXButton" then
									if fcpxExportWindow[whichExportWindow][whichSaveSheet]:attributeValue("AXChildren")[i]:attributeValue("AXTitle") == "Cancel" then
										whichCancelButton = i
									end
								end
							end
							if whichCancelButton == nil then
								dialog.displayErrorMessage("Unable to locate the cancel button.")
								return "Failed"
							end
							fcpxExportWindow[whichExportWindow][whichSaveSheet][whichCancelButton]:performAction("AXPress")

							--------------------------------------------------------------------------------
							-- Press Cancel on the Export Window:
							--------------------------------------------------------------------------------
							whichCancelExportButton = nil
							for i=1, (fcpxExportWindow[whichExportWindow]:attributeValueCount("AXChildren")) do
								if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXButton" then
									if fcpxExportWindow[whichExportWindow]:attributeValue("AXChildren")[i]:attributeValue("AXTitle") == "Cancel" then
										whichCancelExportButton = i
									end
								end
							end
							if whichCancelExportButton == nil then
								dialog.displayErrorMessage("Unable to locate Group Two.")
								return "Failed"
							end
							fcpxExportWindow[whichExportWindow][whichCancelExportButton]:performAction("AXPress")

							goto nextClipInListQueue

						end
						timeoutCount = timeoutCount + 1
						if timeoutCount == 20 then
							dialog.displayErrorMessage("It took too long for the Save Window to close so I gave up.")
							return "Failed"
						else
							timer.usleep(500000)
							goto checkSaveWindowIsClosed
						end
					end
					::nextClipInListQueue::
				end -- i loop
			end -- List Mode
		end -- Left Panel or Right Panel

		--------------------------------------------------------------------------------
		-- Batch Export Complete:
		--------------------------------------------------------------------------------
		local appleScriptA = 'set cancelCount to "' .. cancelCount .. '"\n'
		local appleScriptB = [[
			activate application "Final Cut Pro"
			tell application "System Events"
				tell process "Final Cut Pro"
					if cancelCount is "0" then
						display dialog "Batch Export is now complete." buttons {"Done"} with icon fcpxIcon
					else if cancelCount is "1" then
						display dialog "Batch Export is now complete." & return & return & "One clip was skipped as a file with the same name already existed." buttons {"Done"} with icon fcpxIcon
					else
						display dialog "Batch Export is now complete." & return & return & cancelCount & " clips were skipped as files with the same names already existed." buttons {"Done"} with icon fcpxIcon
					end if
				end tell
			end tell
		]]
		local ok,dialogBoxResult = osascript.applescript(mod.commonErrorMessageAppleScript .. appleScriptA .. appleScriptB)

	end

	--------------------------------------------------------------------------------
	-- FCPX SINGLE MATCH FRAME:
	--------------------------------------------------------------------------------
	--
	-- TO DO: This is currently broken in Final Cut Pro 10.3.
	--
	function singleMatchFrame()

		--------------------------------------------------------------------------------
		-- UNDER CONSTRUCTION:
		--------------------------------------------------------------------------------
		dialog.displayMessage("This feature has not yet been implemented for Final Cut Pro 10.3.")
		if 1==1 then return end

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Define FCPX:
		--------------------------------------------------------------------------------
		fcpx = application.get("Final Cut Pro")

		--------------------------------------------------------------------------------
		-- Click on 'Reveal in Browser':
		--------------------------------------------------------------------------------
		local resultRevealInBrowser = nil
		resultRevealInBrowser = fcp.selectMenuItem({"File", "Reveal in Browser"})
		if resultRevealInBrowser == nil then
			--------------------------------------------------------------------------------
			-- Error:
			--------------------------------------------------------------------------------
			dialog.displayErrorMessage("Unable to trigger Reveal in Browser.")
			return
		end

		--------------------------------------------------------------------------------
		-- Filmstrip or List Mode?
		--------------------------------------------------------------------------------
		local fcpxBrowserMode = getFinalCutProBrowserMode()

		-- Error Checking:
		if (fcpxBrowserMode == "Failed") then
			dialog.displayErrorMessage("Unable to determine if Filmstrip or List Mode.")
			return
		end

		--------------------------------------------------------------------------------
		-- Get all FCPX UI Elements:
		--------------------------------------------------------------------------------
		fcpx = fcp.application()
		fcpxElements = ax.applicationElement(fcpx)

		--------------------------------------------------------------------------------
		-- Which Window:
		--------------------------------------------------------------------------------
		local whichWindow = nil
		local whichEventsWindow = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXWindow" then
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXTitle") == "Events" then
					whichEventsWindow = i
				end
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXTitle") == "Final Cut Pro" then
					whichWindow = i
				end
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXTitle") ~= "Final Cut Pro" or fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXTitle") == "Events" then
					if fcpxElements:attributeValue("AXChildren")[i][1] ~= nil then
						if fcpxElements:attributeValue("AXChildren")[i][1][1] ~= nil then
							if fcpxElements:attributeValue("AXChildren")[i][1][1][1] ~= nil then
								if fcpxElements:attributeValue("AXChildren")[i][1][1][1]:attributeValue("AXRole") == "AXSplitGroup" then
									if fcpxElements:attributeValue("AXChildren")[i][1][1][1]:attributeValue("AXIdentifier") == "_NS:11" then
										whichEventsWindow = i -- Because something FCPX doesn't give the Secondary Window an AXTitle!
									end
								end
							end
						end
					end
				end
			end
		end
		if whichWindow == nil then
			writeToConsole("ERROR: Unable to find whichWindow in highlightFCPXBrowserPlayhead.")
			dialog.displayMessage("We weren't able to find the browser playhead.\n\nAre you sure it's actually on the screen currently?")
			return "Failed"
		end
		if whichEventsWindow ~= nil then whichWindow = whichEventsWindow end
		fcpxElements = ax.applicationElement(fcpx)[whichWindow]

		--------------------------------------------------------------------------------
		-- Which Split Group:
		--------------------------------------------------------------------------------
		local whichSplitGroup = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if whichSplitGroup == nil then
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
					whichSplitGroup = i
				end
			end
		end
		if whichSplitGroup == nil then
			dialog.displayErrorMessage("Unable to locate Split Group.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- List Mode:
		--------------------------------------------------------------------------------
		if fcpxBrowserMode == "List" then

			--------------------------------------------------------------------------------
			-- Which Group contains the browser:
			--------------------------------------------------------------------------------
			local whichGroup = nil
			for i=1, fcpxElements[whichSplitGroup]:attributeValueCount("AXChildren") do
				if whichGroupGroup == nil then
					if fcpxElements[whichSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
						--------------------------------------------------------------------------------
						-- We now have ALL of the groups, and need to work out which group we actually want:
						--------------------------------------------------------------------------------
						for x=1, fcpxElements[whichSplitGroup][i]:attributeValueCount("AXChildren") do
							if fcpxElements[whichSplitGroup][i][x]:attributeValue("AXRole") == "AXSplitGroup" then
								--------------------------------------------------------------------------------
								-- Which Split Group is it:
								--------------------------------------------------------------------------------
								for y=1, fcpxElements[whichSplitGroup][i][x]:attributeValueCount("AXChildren") do
									if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXRole") == "AXSplitGroup" then
										if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXIdentifier") == "_NS:231" then
											whichGroup = i
											goto listGroupDone
										end
									end
								end
							end
						end
					end
				end
			end
			::listGroupDone::
			if whichGroup == nil then
				dialog.displayErrorMessage("Unable to locate Group.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Split Group Two:
			--------------------------------------------------------------------------------
			local whichSplitGroupTwo = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup]:attributeValueCount("AXChildren")) do
				if whichSplitGroupTwo == nil then
					if fcpxElements[whichSplitGroup][whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						whichSplitGroupTwo = i
						goto listSplitGroupTwo
					end
				end
			end
			::listSplitGroupTwo::
			if whichSplitGroupTwo == nil then
				dialog.displayErrorMessage("Unable to locate Split Group Two.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Split Group Three:
			--------------------------------------------------------------------------------
			local whichSplitGroupThree = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValueCount("AXChildren")) do
				if whichSplitGroupThree == nil then
					if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						whichSplitGroupThree = i
						goto listSplitGroupThree
					end
				end
			end
			::listSplitGroupThree::
			if whichSplitGroupThree == nil then
				dialog.displayErrorMessage("Unable to locate Split Group Three.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Group Two:
			--------------------------------------------------------------------------------
			local whichGroupTwo = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
					whichGroupTwo = i
				end
			end
			if whichGroupTwo == nil then
				dialog.displayErrorMessage("Unable to locate Group Two.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which is Persistent Playhead?
			--------------------------------------------------------------------------------
			local whichPersistentPlayhead = (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichGroupTwo]:attributeValueCount("AXChildren")) - 1

			--------------------------------------------------------------------------------
			-- Get Description Based off Playhead:
			--------------------------------------------------------------------------------
			persistentPlayheadPosition = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichSplitGroupThree][whichGroupTwo][whichPersistentPlayhead]:attributeValue("AXPosition")

			persistentPlayheadPosition['x'] = persistentPlayheadPosition['x'] + 20
			persistentPlayheadPosition['y'] = persistentPlayheadPosition['y'] + 20

			currentElement = ax.systemWideElement():elementAtPosition(persistentPlayheadPosition)

			if currentElement:attributeValue("AXRole") == "AXHandle" then
				currentElement = currentElement:attributeValue("AXParent")
			end

			oneElementBack = currentElement:attributeValue("AXParent")

			local searchTerm = oneElementBack:attributeValue("AXDescription")

			local whichSearchGroup = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup]:attributeValueCount("AXChildren")) do
				if whichSearchGroup == nil then
					if fcpxElements[whichSplitGroup][whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
						whichSearchGroup = i
						goto searchGroupDone
					end
				end
			end
			::searchGroupDone::
			if whichSearchGroup == nil then
				dialog.displayErrorMessage("Unable to locate Search Group.")
				return "Failed"
			end

			local searchTextFieldPosition = fcpxElements[whichSplitGroup][whichGroup][whichSearchGroup]:attributeValueCount("AXChildren")
			local searchTextField = fcpxElements[whichSplitGroup][whichGroup][whichSearchGroup][searchTextFieldPosition]

			--------------------------------------------------------------------------------
			-- Set the search field to Title of the Selected Clip:
			--------------------------------------------------------------------------------
			local searchTextFieldResult = searchTextField:setAttributeValue("AXValue", searchTerm)
			if searchTextFieldResult == nil then
				dialog.displayErrorMessage("Unable to set Search Field.")
			end

			--------------------------------------------------------------------------------
			-- Trigger the search:
			--------------------------------------------------------------------------------
			local searchTextFieldActionResult = searchTextField:performAction("AXConfirm")
			if searchTextFieldActionResult == nil then
				dialog.displayErrorMessage("Unable to trigger Search.")
			end

			--------------------------------------------------------------------------------
			-- Highlight Browser Playhead:
			--------------------------------------------------------------------------------
			highlightFCPXBrowserPlayhead()

		--------------------------------------------------------------------------------
		-- Filmstrip Mode:
		--------------------------------------------------------------------------------
		elseif fcpxBrowserMode == "Filmstrip" then

			--------------------------------------------------------------------------------
			-- Which Group contains the browser:
			--------------------------------------------------------------------------------
			local whichGroup = nil
			for i=1, fcpxElements[whichSplitGroup]:attributeValueCount("AXChildren") do
				if whichGroupGroup == nil then
					if fcpxElements[whichSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
						--------------------------------------------------------------------------------
						-- We now have ALL of the groups, and need to work out which group we actually want:
						--------------------------------------------------------------------------------
						for x=1, fcpxElements[whichSplitGroup][i]:attributeValueCount("AXChildren") do
							if fcpxElements[whichSplitGroup][i][x]:attributeValue("AXRole") == "AXSplitGroup" then
								--------------------------------------------------------------------------------
								-- Which Split Group is it:
								--------------------------------------------------------------------------------
								for y=1, fcpxElements[whichSplitGroup][i][x]:attributeValueCount("AXChildren") do
									if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXRole") == "AXScrollArea" then
										if fcpxElements[whichSplitGroup][i][x][y]:attributeValue("AXIdentifier") == "_NS:40" then
											whichGroup = i
											goto filmstripGroupDone
										end
									end
								end
							end
						end
					end
				end
			end
			::filmstripGroupDone::
			if whichGroup == nil then
				dialog.displayErrorMessage("Unable to locate Group.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Split Group Two:
			--------------------------------------------------------------------------------
			local whichSplitGroupTwo = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup]:attributeValueCount("AXChildren")) do
				if whichSplitGroupTwo == nil then
					if fcpxElements[whichSplitGroup][whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						whichSplitGroupTwo = i
						goto filmstripSplitGroupTwoDone
					end
				end
			end
			::filmstripSplitGroupTwoDone::
			if whichSplitGroupTwo == nil then
				dialog.displayErrorMessage("Unable to locate Split Group Two.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Scroll Area:
			--------------------------------------------------------------------------------
			local whichScrollArea = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXScrollArea" then
					whichScrollArea = i
				end
			end
			if whichScrollArea == nil then
				dialog.displayErrorMessage("Unable to locate Scroll Area.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which Group Two:
			--------------------------------------------------------------------------------
			local whichGroupTwo = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea]:attributeValueCount("AXChildren")) do
				if fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
					whichGroupTwo = i
				end
			end
			if whichGroupTwo == nil then
				dialog.displayErrorMessage("Unable to locate Group Two.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Which is Persistent Playhead:
			--------------------------------------------------------------------------------
			local whichPersistentPlayhead = (fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo]:attributeValueCount("AXChildren")) - 1

			--------------------------------------------------------------------------------
			-- Get Description Based off Playhead:
			--------------------------------------------------------------------------------
			persistentPlayheadPosition = fcpxElements[whichSplitGroup][whichGroup][whichSplitGroupTwo][whichScrollArea][whichGroupTwo][whichPersistentPlayhead]:attributeValue("AXPosition")

			persistentPlayheadPosition['x'] = persistentPlayheadPosition['x'] + 20
			persistentPlayheadPosition['y'] = persistentPlayheadPosition['y'] + 20

			currentElement = ax.systemWideElement():elementAtPosition(persistentPlayheadPosition)

			if currentElement:attributeValue("AXRole") == "AXHandle" then
				currentElement = currentElement:attributeValue("AXParent")
			end

			oneElementBack = currentElement:attributeValue("AXParent")

			local searchTerm = oneElementBack:attributeValue("AXDescription")

			local whichSearchGroup = nil
			for i=1, (fcpxElements[whichSplitGroup][whichGroup]:attributeValueCount("AXChildren")) do
				if whichSearchGroup == nil then
					if fcpxElements[whichSplitGroup][whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
						whichSearchGroup = i
						goto searchGroupDone
					end
				end
			end
			::searchGroupDone::
			if whichSearchGroup == nil then
				dialog.displayErrorMessage("Unable to locate Search Group.")
				return "Failed"
			end

			local searchTextFieldPosition = fcpxElements[whichSplitGroup][whichGroup][whichSearchGroup]:attributeValueCount("AXChildren")
			local searchTextField = fcpxElements[whichSplitGroup][whichGroup][whichSearchGroup][searchTextFieldPosition]

			--------------------------------------------------------------------------------
			-- Set the search field to Title of the Selected Clip:
			--------------------------------------------------------------------------------
			local searchTextFieldResult = searchTextField:setAttributeValue("AXValue", searchTerm)
			if searchTextFieldResult == nil then
				dialog.displayErrorMessage("Unable to set Search Field.")
			end

			--------------------------------------------------------------------------------
			-- Trigger the search:
			--------------------------------------------------------------------------------
			local searchTextFieldActionResult = searchTextField:performAction("AXConfirm")
			if searchTextFieldActionResult == nil then
				dialog.displayErrorMessage("Unable to trigger Search.")
			end

			--------------------------------------------------------------------------------
			-- Highlight Browser Playhead:
			--------------------------------------------------------------------------------
			highlightFCPXBrowserPlayhead()

		end
	end

	--------------------------------------------------------------------------------
	-- CHANGE TIMELINE CLIP HEIGHT:
	--------------------------------------------------------------------------------
	--
	-- TO DO: This is currently broken in Final Cut Pro 10.3.
	--
	local changeTimelineClipHeightPressed = nil
	function changeTimelineClipHeight(direction)

		--------------------------------------------------------------------------------
		-- UNDER CONSTRUCTION:
		--------------------------------------------------------------------------------
		dialog.displayMessage("This feature has not yet been implemented for Final Cut Pro 10.3, however Apple has added an Increase/Decrease Clip Height Shortcut to the Command Editor which you can use.")
		if 1==1 then return end

		writeToConsole("DOWN " .. direction)

		--------------------------------------------------------------------------------
		-- LOCAL VARIABLES:
		--------------------------------------------------------------------------------
		local showError = false
		local event = eventtap.event

		increaseThumbnailSizeModifiers = convertModifiersKeysForEventTap(mod.finalCutProShortcutKey["IncreaseThumbnailSize"]['modifiers'])
		decreaseThumbnailSizeModifiers = convertModifiersKeysForEventTap(mod.finalCutProShortcutKey["DecreaseThumbnailSize"]['modifiers'])
		increaseThumbnailSizeCharacterString = keycodes.map[mod.finalCutProShortcutKey["IncreaseThumbnailSize"]['characterString']]
		decreaseThumbnailSizeCharacterString = keycodes.map[mod.finalCutProShortcutKey["DecreaseThumbnailSize"]['characterString']]

		--------------------------------------------------------------------------------
		-- ERROR DETECTION:
		--------------------------------------------------------------------------------
		if increaseThumbnailSizeModifiers == nil then showError = true end
		if decreaseThumbnailSizeModifiers == nil then showError = true end
		if increaseThumbnailSizeCharacterString == nil then showError = true end
		if decreaseThumbnailSizeCharacterString == nil then showError = true end
		if next(increaseThumbnailSizeModifiers) == nil and increaseThumbnailSizeCharacterString == "" then showError = true end
		if next(decreaseThumbnailSizeModifiers) == nil and decreaseThumbnailSizeCharacterString == "" then showError = true end
		if showError then
			dialog.displayErrorMessage("The Increase/Decrease Clip Height keyboard shortcuts must be allocated in the Final Cut Pro Command Editor for this feature to work.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- DO ONCE:
		--------------------------------------------------------------------------------
		if direction == "up" then
			writeToConsole("up")
			--event.newKeyEvent(increaseThumbnailSizeModifiers, increaseThumbnailSizeCharacterString, true):post()
			--event.newKeyEvent(increaseThumbnailSizeModifiers, increaseThumbnailSizeCharacterString, false):post()
		else
			writeToConsole("down")
			--event.newKeyEvent(decreaseThumbnailSizeModifiers, decreaseThumbnailSizeCharacterString, true):post()
			--event.newKeyEvent(decreaseThumbnailSizeModifiers, decreaseThumbnailSizeCharacterString, false):post()
		end

	end

		--------------------------------------------------------------------------------
		-- CHANGE TIMELINE CLIP HEIGHT REPEAT:
		--------------------------------------------------------------------------------
		function changeTimelineClipHeightRepeat(direction)

		--------------------------------------------------------------------------------
		-- UNDER CONSTRUCTION:
		--------------------------------------------------------------------------------
		if 1==1 then return end

			writeToConsole("REPEAT " .. direction)

			local event = eventtap.event
			if direction == "up" then
				--event.newKeyEvent(increaseThumbnailSizeModifiers, increaseThumbnailSizeCharacterString, true):post()
				--event.newKeyEvent(increaseThumbnailSizeModifiers, increaseThumbnailSizeCharacterString, false):post()

				--eventtap.event.newKeyEvent({"cmd", "shift"}, "=", true):post()
				--eventtap.event.newKeyEvent({"cmd", "shift"}, "=", false):post()

			else
				--event.newKeyEvent(decreaseThumbnailSizeModifiers, decreaseThumbnailSizeCharacterString, true):post()
				--event.newKeyEvent(decreaseThumbnailSizeModifiers, decreaseThumbnailSizeCharacterString, false):post()

				--eventtap.event.newKeyEvent({"cmd", "shift"}, "-", true):post()
				--eventtap.event.newKeyEvent({"cmd", "shift"}, "-", false):post()
			end

		end

--------------------------------------------------------------------------------
-- KEYWORDS:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- SAVE KEYWORDS:
	--------------------------------------------------------------------------------
	function saveKeywordSearches(whichButton)

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Check to see if the Keyword Editor is already open:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()
		local fcpxElements = ax.applicationElement(fcpx)
		local whichWindow = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements[i]:attributeValue("AXRole") == "AXWindow" then
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:264" then
					whichWindow = i
				end
			end
		end
		if whichWindow == nil then
			dialog.displayMessage("This shortcut should only be used when the Keyword Editor is already open.\n\nPlease open the Keyword Editor and try again.")
			return
		end
		fcpxElements = fcpxElements[whichWindow]

		--------------------------------------------------------------------------------
		-- Get Starting Textfield:
		--------------------------------------------------------------------------------
		local startTextField = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if startTextField == nil then
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "favorite 1" then
					startTextField = i
					goto startTextFieldDone
				end
			end
		end
		::startTextFieldDone::
		if startTextField == nil then
			--------------------------------------------------------------------------------
			-- Keyword Shortcuts Buttons isn't down:
			--------------------------------------------------------------------------------
			fcpxElements = ax.applicationElement(fcpx)[1] -- Refresh
			for i=1, fcpxElements:attributeValueCount("AXChildren") do
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "Keyword Shortcuts" then
					keywordDisclosureTriangle = i
					goto keywordDisclosureTriangleDone
				end
			end
			::keywordDisclosureTriangleDone::
			if fcpxElements[keywordDisclosureTriangle] == nil then
				dialog.displayMessage("Please make sure that the Keyboard Shortcuts are visible before using this feature.")
				return "Failed"
			else
				local keywordDisclosureTriangleResult = fcpxElements[keywordDisclosureTriangle]:performAction("AXPress")
				if keywordDisclosureTriangleResult == nil then
					dialog.displayMessage("Please make sure that the Keyboard Shortcuts are visible before using this feature.")
					return "Failed"
				end
			end
		end

		--------------------------------------------------------------------------------
		-- Get Values from the Keyword Editor:
		--------------------------------------------------------------------------------
		local savedKeywordValues = {}
		local favoriteCount = 1
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "favorite " .. favoriteCount then
				savedKeywordValues[favoriteCount] = fcpxElements[i]:attributeValue("AXHelp")
				favoriteCount = favoriteCount + 1
			end
		end

		--------------------------------------------------------------------------------
		-- Save Values to Settings:
		--------------------------------------------------------------------------------
		local savedKeywords = settings.get("fcpxHacks.savedKeywords")
		if savedKeywords == nil then savedKeywords = {} end
		for i=1, 9 do
			if savedKeywords['Preset ' .. tostring(whichButton)] == nil then
				savedKeywords['Preset ' .. tostring(whichButton)] = {}
			end
			savedKeywords['Preset ' .. tostring(whichButton)]['Item ' .. tostring(i)] = savedKeywordValues[i]
		end
		settings.set("fcpxHacks.savedKeywords", savedKeywords)

		--------------------------------------------------------------------------------
		-- Saved:
		--------------------------------------------------------------------------------
		alert.closeAll(0)
		alert.show("Your Keywords have been saved to Preset " .. tostring(whichButton))

	end

	--------------------------------------------------------------------------------
	-- RESTORE KEYWORDS:
	--------------------------------------------------------------------------------
	function restoreKeywordSearches(whichButton)

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get Values from Settings:
		--------------------------------------------------------------------------------
		local savedKeywords = settings.get("fcpxHacks.savedKeywords")
		local restoredKeywordValues = {}

		if savedKeywords == nil then
			dialog.displayMessage("It doesn't look like you've saved any keyword presets yet?")
			return "Fail"
		end
		if savedKeywords['Preset ' .. tostring(whichButton)] == nil then
			dialog.displayMessage("It doesn't look like you've saved anything to this keyword preset yet?")
			return "Fail"
		end
		for i=1, 9 do
			restoredKeywordValues[i] = savedKeywords['Preset ' .. tostring(whichButton)]['Item ' .. tostring(i)]
		end

		--------------------------------------------------------------------------------
		-- Check to see if the Keyword Editor is already open:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()
		local fcpxElements = ax.applicationElement(fcpx)
		local whichWindow = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements[i]:attributeValue("AXRole") == "AXWindow" then
				if fcpxElements[i]:attributeValue("AXIdentifier") == "_NS:264" then
					whichWindow = i
				end
			end
		end
		if whichWindow == nil then
			dialog.displayMessage("This shortcut should only be used when the Keyword Editor is already open.\n\nPlease open the Keyword Editor and try again.")
			return
		end
		fcpxElements = fcpxElements[whichWindow]

		--------------------------------------------------------------------------------
		-- Get Starting Textfield:
		--------------------------------------------------------------------------------
		local startTextField = nil
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if startTextField == nil then
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "favorite 1" then
					startTextField = i
					goto startTextFieldDone
				end
			end
		end
		::startTextFieldDone::
		if startTextField == nil then
			--------------------------------------------------------------------------------
			-- Keyword Shortcuts Buttons isn't down:
			--------------------------------------------------------------------------------
			local keywordDisclosureTriangle = nil
			for i=1, fcpxElements:attributeValueCount("AXChildren") do
				if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "Keyword Shortcuts" then
					keywordDisclosureTriangle = i
					goto keywordDisclosureTriangleDone
				end
			end
			::keywordDisclosureTriangleDone::

			if fcpxElements[keywordDisclosureTriangle] ~= nil then
				local keywordDisclosureTriangleResult = fcpxElements[keywordDisclosureTriangle]:performAction("AXPress")
				if keywordDisclosureTriangleResult == nil then
					dialog.displayMessage("Please make sure that the Keyboard Shortcuts are visible before using this feature.")
					return "Failed"
				end
			else
				dialog.displayErrorMessage("Could not find keyword disclosure triangle.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Restore Values to Keyword Editor:
		--------------------------------------------------------------------------------
		local favoriteCount = 1
		for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "favorite " .. favoriteCount then
				currentKeywordSelection = fcpxElements[i]

				setKeywordResult = currentKeywordSelection:setAttributeValue("AXValue", restoredKeywordValues[favoriteCount])
				keywordActionResult = currentKeywordSelection:setAttributeValue("AXFocused", true)
				eventtap.keyStroke({""}, "return")

				--------------------------------------------------------------------------------
				-- If at first you don't succeed, try, oh try, again!
				--------------------------------------------------------------------------------
				if fcpxElements[i][1]:attributeValue("AXValue") ~= restoredKeywordValues[favoriteCount] then
					setKeywordResult = currentKeywordSelection:setAttributeValue("AXValue", restoredKeywordValues[favoriteCount])
					keywordActionResult = currentKeywordSelection:setAttributeValue("AXFocused", true)
					eventtap.keyStroke({""}, "return")
				end

				favoriteCount = favoriteCount + 1
			end
		end

		--------------------------------------------------------------------------------
		-- Successfully Restored:
		--------------------------------------------------------------------------------
		alert.closeAll(0)
		alert.show("Your Keywords have been restored to Preset " .. tostring(whichButton))

	end

--------------------------------------------------------------------------------
-- SCROLLING TIMELINE RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- ACTIVE SCROLLING TIMELINE WATCHER:
	--------------------------------------------------------------------------------
	function toggleScrollingTimeline()

		--------------------------------------------------------------------------------
		-- Toggle Scrolling Timeline:
		--------------------------------------------------------------------------------
		scrollingTimelineActivated = settings.get("fcpxHacks.scrollingTimelineActive") or false
		if scrollingTimelineActivated then
			--------------------------------------------------------------------------------
			-- Update Settings:
			--------------------------------------------------------------------------------
			settings.set("fcpxHacks.scrollingTimelineActive", false)

			--------------------------------------------------------------------------------
			-- Stop Watchers:
			--------------------------------------------------------------------------------
			scrollingTimelineWatcherUp:stop()
			scrollingTimelineWatcherDown:stop()

			--------------------------------------------------------------------------------
			-- Stop Scrolling Timeline Loops:
			--------------------------------------------------------------------------------
			if mod.scrollingTimelineTimer ~= nil then mod.scrollingTimelineTimer:stop() end
			if mod.scrollingTimelineScrollbarTimer ~= nil then mod.scrollingTimelineScrollbarTimer:stop() end

			--------------------------------------------------------------------------------
			-- Turn off variable:
			--------------------------------------------------------------------------------
			mod.scrollingTimelineSpacebarPressed = false

			--------------------------------------------------------------------------------
			-- Display Notification:
			--------------------------------------------------------------------------------
			alert.closeAll(0)
			alert.show("Scrolling Timeline Deactivated")

		else
			--------------------------------------------------------------------------------
			-- Update Settings:
			--------------------------------------------------------------------------------
			settings.set("fcpxHacks.scrollingTimelineActive", true)

			--------------------------------------------------------------------------------
			-- Start Watchers:
			--------------------------------------------------------------------------------
			scrollingTimelineWatcherUp:start()
			scrollingTimelineWatcherDown:start()

			--------------------------------------------------------------------------------
			-- If activated whilst already playing, then turn on Scrolling Timeline:
			--------------------------------------------------------------------------------
			-- TO DO: it would be great to be able to do this if possible?
				-- scrollingTimelineSpacebarCheck = true
				-- timer.waitUntil(function() return scrollingTimelineSpacebarCheck end, function() checkScrollingTimelinePress() end, 0.00000001)

			--------------------------------------------------------------------------------
			-- Display Notification:
			--------------------------------------------------------------------------------
			alert.closeAll(0)
			alert.show("Scrolling Timeline Activated")

		end

		--------------------------------------------------------------------------------
		-- Refresh Menu Bar:
		--------------------------------------------------------------------------------
		refreshMenuBar()

	end

	--------------------------------------------------------------------------------
	-- SCROLLING TIMELINE FUNCTION:
	--------------------------------------------------------------------------------
	function performScrollingTimelineLoops(timelineScrollArea, whichValueIndicator, initialPlayheadXPosition)

		--------------------------------------------------------------------------------
		-- Define Scrollbar Check Timer:
		--------------------------------------------------------------------------------
		mod.scrollingTimelineScrollbarTimer = timer.new(0.001, function()
			if timelineScrollArea[2] ~= nil then
				performScrollingTimelineLoops(whichSplitGroup, whichGroup)
				scrollbarSearchLoopActivated = false
			end
		end)

		--------------------------------------------------------------------------------
		-- Trigger Scrollbar Check Timer if No Scrollbar Visible:
		--------------------------------------------------------------------------------
		if timelineScrollArea[2] == nil then
			mod.scrollingTimelineScrollbarTimer:start()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Make sure Playhead is actually visible:
		--------------------------------------------------------------------------------
		local scrollAreaX = timelineScrollArea:attributeValue("AXPosition")['x']
		local scrollAreaW = timelineScrollArea:attributeValue("AXSize")['w']
		local endOfTimelineXPosition = (scrollAreaX + scrollAreaW)
		if initialPlayheadXPosition > endOfTimelineXPosition or initialPlayheadXPosition < scrollAreaX then
			local timelineWidth = timelineScrollArea:attributeValue("AXSize")['w']
			initialPlayheadXPosition = (timelineWidth / 2)
		end

		--------------------------------------------------------------------------------
		-- Initial Scrollbar Value:
		--------------------------------------------------------------------------------
		local initialScrollbarValue = timelineScrollArea[2][1]:attributeValue("AXValue")

		--------------------------------------------------------------------------------
		-- Define the Loop of Death:
		--------------------------------------------------------------------------------
		mod.scrollingTimelineTimer = timer.new(0.000001, function()

			--------------------------------------------------------------------------------
			-- Does the scrollbar still exist?
			--------------------------------------------------------------------------------
			if timelineScrollArea[1] ~= nil and timelineScrollArea[2] ~= nil then

				local scrollbarWidth = timelineScrollArea[2][1]:attributeValue("AXSize")['w']
				local timelineWidth = timelineScrollArea[1]:attributeValue("AXSize")['w']

				local howMuchBiggerTimelineIsThanScrollbar = scrollbarWidth / timelineWidth

				--------------------------------------------------------------------------------
				-- If you change the edit the location of the Value Indicator will change:
				--------------------------------------------------------------------------------
				if timelineScrollArea[1][whichValueIndicator]:attributeValue("AXDescription") ~= "Playhead" then
					for i=1, timelineScrollArea[1]:attributeValueCount("AXChildren") do
						if timelineScrollArea[1]:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "Playhead" then
							whichValueIndicator = i
							goto performScrollingTimelineValueIndicatorExitX
						end
					end
					if whichValueIndicator == nil then
						dialog.displayErrorMessage("Unable to locate Value Indicator.")
						return "Failed"
					end
					::performScrollingTimelineValueIndicatorExitX::
				end

				local currentPlayheadXPosition = timelineScrollArea[1][whichValueIndicator]:attributeValue("AXPosition")['x']

				initialPlayheadPecentage = initialPlayheadXPosition / scrollbarWidth
				currentPlayheadPecentage = currentPlayheadXPosition / scrollbarWidth

				x = initialPlayheadPecentage * howMuchBiggerTimelineIsThanScrollbar
				y = currentPlayheadPecentage * howMuchBiggerTimelineIsThanScrollbar

				scrollbarStep = y - x

				local currentScrollbarValue = timelineScrollArea[2][1]:attributeValue("AXValue")
				timelineScrollArea[2][1]:setAttributeValue("AXValue", currentScrollbarValue + scrollbarStep)
			end

		end)

		--------------------------------------------------------------------------------
		-- Begin the Loop of Death:
		--------------------------------------------------------------------------------
		mod.scrollingTimelineTimer:start()

	end

--------------------------------------------------------------------------------
-- MATCH FRAME RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- PERFORM MULTICAM MATCH FRAME:
	--------------------------------------------------------------------------------
	function multicamMatchFrame(goBackToTimeline) -- True or False

		--------------------------------------------------------------------------------
		-- Just in case:
		--------------------------------------------------------------------------------
		if goBackToTimeline == nil then goBackToTimeline = true end
		if type(goBackToTimeline) ~= "boolean" then goBackToTimeline = true end

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Open in Angle Editor:
		--------------------------------------------------------------------------------
		local openInAngleEditorResult = fcp.selectMenuItem({"Clip", "Open in Angle Editor"})
		if openInAngleEditorResult == nil then
			dialog.displayErrorMessage("Failed to open clip in Angle Editor.\n\nAre you sure the clip you have selected is a Multicam?")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Put focus back on the timeline:
		--------------------------------------------------------------------------------
		local goToTimelineResult = fcp.selectMenuItem({"Window", "Go To", "Timeline"})
		if goToTimelineResult == nil then
			dialog.displayErrorMessage("Unable to return to timeline.")
			return
		end

		--------------------------------------------------------------------------------
		-- Reveal In Browser:
		--------------------------------------------------------------------------------
		local revealInBrowserResult = fcp.selectMenuItem({"File", "Reveal in Browser"})
		if revealInBrowserResult == nil then
			dialog.displayErrorMessage("Unable to Reveal in Browser.")
			return
		end

		--------------------------------------------------------------------------------
		-- Go back to original timeline if appropriate:
		--------------------------------------------------------------------------------
		if goBackToTimeline then
			local timelineHistoryBackResult = fcp.selectMenuItem({"View", "Timeline History Back"})
			if timelineHistoryBackResult == nil then
				dialog.displayErrorMessage("Unable to go back to previous timeline.")
				return
			end
		end

		--------------------------------------------------------------------------------
		-- Highlight Browser Playhead:
		--------------------------------------------------------------------------------
		highlightFCPXBrowserPlayhead()

	end

	--------------------------------------------------------------------------------
	-- MATCH FRAME THEN HIGHLIGHT FCPX BROWSER PLAYHEAD:
	--------------------------------------------------------------------------------
	function matchFrameThenHighlightFCPXBrowserPlayhead()
		--------------------------------------------------------------------------------
		-- Delete Any Highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Click on 'Reveal in Browser':
		--------------------------------------------------------------------------------
		local result = fcp.selectMenuItem({"File", "Reveal in Browser"})
		if result == nil then
			dialog.displayErrorMessage("Failed to 'Reveal in Browser'.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- If it worked then...
		--------------------------------------------------------------------------------
		if resultRevealInBrowser then
			--------------------------------------------------------------------------------
			-- Highlight FCPX Browser Playhead:
			--------------------------------------------------------------------------------
			highlightFCPXBrowserPlayhead()
		else
			--------------------------------------------------------------------------------
			-- Error:
			--------------------------------------------------------------------------------
			dialog.displayErrorMessage("Unable to trigger Reveal in Browser.")
		end
	end

--------------------------------------------------------------------------------
-- COLOR BOARD RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- COLOR BOARD - PUCK SELECTION:
	--------------------------------------------------------------------------------
	function colorBoardSelectPuck(whichPuck, whichPanel, whichDirection)

		--------------------------------------------------------------------------------
		-- Make sure Nudge Shortcuts are allocated:
		--------------------------------------------------------------------------------
		local nudgeShortcutMissing = false
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckUp"]['characterString'] == "" then nudgeShortcutMissing = true end
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckDown"]['characterString'] == "" then nudgeShortcutMissing = true	end
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckLeft"]['characterString'] == "" then nudgeShortcutMissing = true	end
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckRight"]['characterString'] == "" then nudgeShortcutMissing = true end
		if nudgeShortcutMissing then
			dialog.displayMessage("This feature requires the Color Board Nudge Pucks shortcuts to be allocated.\n\nPlease allocate these shortcuts keys to anything you like in the Command Editor and try again.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- The first button is actually the reset button:
		--------------------------------------------------------------------------------
		whichPuck = whichPuck + 1

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get Final Cut Pro Color Board Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProColorBoardRadioGroup = fcp.getColorBoardRadioGroup()
		if finalCutProColorBoardRadioGroup == nil then

			--------------------------------------------------------------------------------
			-- Open Color Board:
			--------------------------------------------------------------------------------
			local result = fcp.selectMenuItem({"Window", "Go To", "Color Board"})
			if result == nil then
				dialog.displayErrorMessage("Failed to goto Color Board.")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Try again:
			--------------------------------------------------------------------------------
			finalCutProColorBoardRadioGroup = fcp.getColorBoardRadioGroup()

		end
		if finalCutProColorBoardRadioGroup == nil then
			dialog.displayMessage("Please make sure you have a clip selected in the timeline before using this function.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Change to correct panel:
		--------------------------------------------------------------------------------
		if whichPanel ~= nil then
			local result = finalCutProColorBoardRadioGroup[whichPanel]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Could not open specific Color Board panel.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Select Correct Puck:
		--------------------------------------------------------------------------------
		colorBoardPanel = finalCutProColorBoardRadioGroup
		local whichPuckCount = 1
		for i=1, colorBoardPanel:attributeValue("AXParent"):attributeValueCount("AXChildren") do
			if colorBoardPanel:attributeValue("AXParent")[i]:attributeValue("AXRole") == "AXButton" then
				if whichPuckCount == whichPuck then
					whichPuckButton = i
					goto colorBoardSelectPuckExit
				else
					whichPuckCount = whichPuckCount + 1
				end
			end
		end
		::colorBoardSelectPuckExit::

		if not colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXFocused") then
			local colorBoardPosition = {}
			colorBoardPosition['x'] = colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXPosition")['x'] + (colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXSize")['w'] / 2)
			colorBoardPosition['y'] = colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXPosition")['y'] + (colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXSize")['h'] / 2)
			tools.ninjaMouseClick(colorBoardPosition)
		end

		--------------------------------------------------------------------------------
		-- If a Direction is specified:
		--------------------------------------------------------------------------------
		if whichDirection ~= nil then

			--------------------------------------------------------------------------------
			-- Get shortcut key from plist, press and hold if required:
			--------------------------------------------------------------------------------
			mod.releaseColorBoardDown = false
			timer.doUntil(function() return mod.releaseColorBoardDown end, function()
				if whichDirection == "up" then
					if mod.finalCutProShortcutKey["ColorBoard-NudgePuckUp"]['characterString'] ~= "" then
						keyStrokeFromPlist("ColorBoard-NudgePuckUp")
					end
				end
				if whichDirection == "down" then
					if mod.finalCutProShortcutKey["ColorBoard-NudgePuckDown"]['characterString'] ~= "" then
						keyStrokeFromPlist("ColorBoard-NudgePuckDown")
					end
				end
				if whichDirection == "left" then
					if mod.finalCutProShortcutKey["ColorBoard-NudgePuckLeft"]['characterString'] ~= "" then
						keyStrokeFromPlist("ColorBoard-NudgePuckLeft")
					end
				end
				if whichDirection == "right" then
					if mod.finalCutProShortcutKey["ColorBoard-NudgePuckRight"]['characterString'] ~= "" then
						keyStrokeFromPlist("ColorBoard-NudgePuckRight")
					end
				end
			end, eventtap.keyRepeatInterval())

		end

	end

	--------------------------------------------------------------------------------
	-- COLOR BOARD - PUCK CONTROL VIA MOUSE:
	--------------------------------------------------------------------------------
	function colorBoardMousePuck(whichPuck, whichPanel)

		--------------------------------------------------------------------------------
		-- Local Variables:
		--------------------------------------------------------------------------------
		local colorBoardOriginalMousePoint = mouse.getAbsolutePosition()

		--------------------------------------------------------------------------------
		-- Make sure Nudge Shortcuts are allocated:
		--------------------------------------------------------------------------------
		local nudgeShortcutMissing = false
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckUp"]['characterString'] == "" then nudgeShortcutMissing = true end
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckDown"]['characterString'] == "" then nudgeShortcutMissing = true	end
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckLeft"]['characterString'] == "" then nudgeShortcutMissing = true	end
		if mod.finalCutProShortcutKey["ColorBoard-NudgePuckRight"]['characterString'] == "" then nudgeShortcutMissing = true end
		if nudgeShortcutMissing then
			dialog.displayMessage("This feature requires the Color Board Nudge Pucks shortcuts to be allocated.\n\nPlease allocate these shortcuts keys to anything you like in the Command Editor and try again.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- The first button is actually the reset button:
		--------------------------------------------------------------------------------
		whichPuck = whichPuck + 1

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get Final Cut Pro Color Board Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProColorBoardRadioGroup = fcp.getColorBoardRadioGroup()
		if finalCutProColorBoardRadioGroup == nil then

			--------------------------------------------------------------------------------
			-- Open Color Board:
			--------------------------------------------------------------------------------
			local result = fcp.selectMenuItem({"Window", "Go To", "Color Board"})
			if result == nil then
				dialog.displayErrorMessage("Failed to goto Color Board.")
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Try again:
			--------------------------------------------------------------------------------
			finalCutProColorBoardRadioGroup = fcp.getColorBoardRadioGroup()

		end
		if finalCutProColorBoardRadioGroup == nil then
			dialog.displayMessage("Please make sure you have a clip selected in the timeline before using this function.")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Change to correct panel:
		--------------------------------------------------------------------------------
		if whichPanel ~= nil then
			local result = finalCutProColorBoardRadioGroup[whichPanel]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Could not open specific Color Board panel.")
				return "Failed"
			end
		end

		--------------------------------------------------------------------------------
		-- Select Correct Puck:
		--------------------------------------------------------------------------------
		colorBoardPanel = finalCutProColorBoardRadioGroup
		local whichPuckCount = 1
		for i=1, colorBoardPanel:attributeValue("AXParent"):attributeValueCount("AXChildren") do
			if colorBoardPanel:attributeValue("AXParent")[i]:attributeValue("AXRole") == "AXButton" then
				if whichPuckCount == whichPuck then
					whichPuckButton = i
					goto colorBoardSelectPuckExit
				else
					whichPuckCount = whichPuckCount + 1
				end
			end
		end
		::colorBoardSelectPuckExit::

		if not colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXFocused") then
			local colorBoardPosition = {}
			colorBoardPosition['x'] = colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXPosition")['x'] + (colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXSize")['w'] / 2)
			colorBoardPosition['y'] = colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXPosition")['y'] + (colorBoardPanel:attributeValue("AXParent")[whichPuckButton]:attributeValue("AXSize")['h'] / 2)
			tools.ninjaMouseClick(colorBoardPosition)
		end

		--------------------------------------------------------------------------------
		-- Get shortcut key from plist, press and hold if required:
		--------------------------------------------------------------------------------
		mod.releaseMouseColorBoardDown = false
		timer.doUntil(function() return mod.releaseMouseColorBoardDown end, function()

			local currentMousePoint = mouse.getAbsolutePosition()

			if currentMousePoint['y'] < colorBoardOriginalMousePoint['y'] then
				keyStrokeFromPlist("ColorBoard-NudgePuckUp")
				colorBoardOriginalMousePoint = currentMousePoint
			end
			if currentMousePoint['y'] > colorBoardOriginalMousePoint['y'] then
				keyStrokeFromPlist("ColorBoard-NudgePuckDown")
				colorBoardOriginalMousePoint = currentMousePoint
			end

			if whichPanel == 1 then
				if currentMousePoint['x'] < colorBoardOriginalMousePoint['x'] then
					keyStrokeFromPlist("ColorBoard-NudgePuckLeft")
					colorBoardOriginalMousePoint = currentMousePoint
				end
				if currentMousePoint['x'] > colorBoardOriginalMousePoint['x'] then
					keyStrokeFromPlist("ColorBoard-NudgePuckRight")
					colorBoardOriginalMousePoint = currentMousePoint
				end
			end

		end, 0.00001)

	end

	--------------------------------------------------------------------------------
	-- COLOR BOARD - RELEASE MOUSE KEYPRESS:
	--------------------------------------------------------------------------------
	function colorBoardMousePuckRelease()
		mod.releaseMouseColorBoardDown = true
	end

	--------------------------------------------------------------------------------
	-- COLOR BOARD - RELEASE KEYPRESS:
	--------------------------------------------------------------------------------
	function colorBoardSelectPuckRelease()
		mod.releaseColorBoardDown = true
	end

--------------------------------------------------------------------------------
-- EFFECTS/TRANSITIONS/TITLES/GENERATOR RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- TRANSITIONS SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function transitionsShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local currentShortcut = nil
		if whichShortcut == 1 then currentShortcut = settings.get("fcpxHacks.transitionsShortcutOne") end
		if whichShortcut == 2 then currentShortcut = settings.get("fcpxHacks.transitionsShortcutTwo") end
		if whichShortcut == 3 then currentShortcut = settings.get("fcpxHacks.transitionsShortcutThree") end
		if whichShortcut == 4 then currentShortcut = settings.get("fcpxHacks.transitionsShortcutFour") end
		if whichShortcut == 5 then currentShortcut = settings.get("fcpxHacks.transitionsShortcutFive") end
		if type(whichShortcut) == "string" then currentShortcut = whichShortcut end

		if currentShortcut == nil then
			dialog.displayMessage("There is no Transition assigned to this shortcut.\n\nYou can assign Tranistions Shortcuts via the FCPX Hacks menu bar.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Timeline Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProTimelineButtonBar = fcp.getTimelineButtonBar()
		if finalCutProTimelineButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar.\n\nError occured in effectsShortcut() whilst using fcp.getTimelineButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Find Transitions Browser Button:
		--------------------------------------------------------------------------------
		local whichRadioGroup = nil
		for i=1, finalCutProTimelineButtonBar:attributeValueCount("AXChildren") do
			if finalCutProTimelineButtonBar[i]:attributeValue("AXRole") == "AXRadioGroup" then
				if finalCutProTimelineButtonBar[i]:attributeValue("AXIdentifier") == "_NS:165" then
					whichRadioGroup = i
				end
			end
		end
		if whichRadioGroup == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar Radio Group.\n\nError occured in transitionsShortcut().")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Effects or Transitions Panel Open?
		--------------------------------------------------------------------------------
		local whichPanelActivated = "None"
		if finalCutProTimelineButtonBar[whichRadioGroup][1] ~= nil then
			if finalCutProTimelineButtonBar[whichRadioGroup][1]:attributeValue("AXValue") == 1 then whichPanelActivated = "Effects" end
			if finalCutProTimelineButtonBar[whichRadioGroup][2]:attributeValue("AXValue") == 1 then whichPanelActivated = "Transitions" end
		end

		--------------------------------------------------------------------------------
		-- Make sure Transitions panel is open:
		--------------------------------------------------------------------------------
		local effectsBrowserButton = finalCutProTimelineButtonBar[whichRadioGroup][2]
		if effectsBrowserButton ~= nil then
			if effectsBrowserButton:attributeValue("AXValue") == 0 then
				local presseffectsBrowserButtonResult = effectsBrowserButton:performAction("AXPress")
				if presseffectsBrowserButtonResult == nil then
					dialog.displayErrorMessage("Unable to press Effects Browser Button icon.")
					showTouchbar()
					return "Fail"
				end
			end
		else
			dialog.displayErrorMessage("Unable to activate Video Effects Panel.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Make sure "Installed Effects" is selected:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Group:
			--------------------------------------------------------------------------------
			local finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserSplitGroup = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXRole") == "AXSplitGroup" then
					if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXIdentifier") == "_NS:452" then
						whichEffectsBrowserSplitGroup = i
					end
				end
			end
			if whichEffectsBrowserSplitGroup == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Split Group.\n\nError occured in transitionsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserPopupButton = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup]:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXRole") == "AXPopUpButton" then
					if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXIdentifier") == "_NS:45" then
						whichEffectsBrowserPopupButton = i
					end
				end
			end
			if whichEffectsBrowserPopupButton == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Popup Button.\n\nError occured in transitionsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Check that "Installed Effects" is selected:
			--------------------------------------------------------------------------------
			local installedEffectsPopup = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton]
			if installedEffectsPopup ~= nil then
				if installedEffectsPopup:attributeValue("AXValue") ~= "Installed Effects" then
					installedEffectsPopup:performAction("AXPress")
					finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()
					installedEffectsPopupMenuItem = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton][1][1]
					installedEffectsPopupMenuItem:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to find 'Installed Effects' popup.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end

		--------------------------------------------------------------------------------
		-- Make sure there's nothing in the search box:
		--------------------------------------------------------------------------------
		local effectsSearchCancelButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
				effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
			end
		end
		if effectsSearchCancelButton ~= nil then
			effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
			if effectsSearchCancelButtonResult == nil then
				dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Click 'All':
		--------------------------------------------------------------------------------
		local allVideoAndAudioButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1][1] ~= nil then
						allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][1]
					end
				end
			end
		end
		if allVideoAndAudioButton ~= nil then
			allVideoAndAudioButton:setAttributeValue("AXSelected", true)
		else

			--------------------------------------------------------------------------------
			-- Make sure Transitions Browser Sidebar is Visible:
			--------------------------------------------------------------------------------
			effectsBrowserSidebar = finalCutProEffectsTransitionsBrowserGroup[2]
			if effectsBrowserSidebar ~= nil then
				if effectsBrowserSidebar:attributeValue("AXValue") == 1 then
					effectsBrowserSidebar:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to locate Effects Browser Sidebar button.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Click 'All Video & Audio':
			--------------------------------------------------------------------------------
			local allVideoAndAudioButton = nil
			if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
						if finalCutProEffectsTransitionsBrowserGroup[1][1][1][1] ~= nil then
							allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][1]
						end
					end
				end
			end
			if allVideoAndAudioButton ~= nil then
				allVideoAndAudioButton:setAttributeValue("AXSelected", true)
			else
				dialog.displayErrorMessage("Unable to locate 'All Video & Audio' button.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay...
		--------------------------------------------------------------------------------
		timer.usleep(100000)

		--------------------------------------------------------------------------------
		-- Perform Search:
		--------------------------------------------------------------------------------
		local effectsSearchField = nil
		if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then effectsSearchField = finalCutProEffectsTransitionsBrowserGroup[4] end
		if effectsSearchField ~= nil then
			effectsSearchField:setAttributeValue("AXValue", currentShortcut)
			effectsSearchField[1]:performAction("AXPress")
		else
			dialog.displayErrorMessage("Unable to type search request in search box.\n\nError occured in transitionsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Make sure scroll bar is at top:
		--------------------------------------------------------------------------------
		local effectsScrollBar = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][4] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][4][2] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][4][2][1] ~= nil then
						effectsScrollBar = finalCutProEffectsTransitionsBrowserGroup[1][4][2][1]
					end
				end
			end
		end
		if effectsScrollBar ~= nil then
			effectsScrollBar:setAttributeValue("AXValue", 0)
		end

		--------------------------------------------------------------------------------
		-- Get First Item in Browser:
		--------------------------------------------------------------------------------
		local effectButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][4] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][4][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][4][1][1] ~= nil then
						effectButton = finalCutProEffectsTransitionsBrowserGroup[1][4][1][1]
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		if effectButton == nil then

			--------------------------------------------------------------------------------
			-- Remove first dash:
			--------------------------------------------------------------------------------
			currentShortcut = string.sub(currentShortcut, string.find(currentShortcut, "-") + 2)

			writeToConsole("currentShortcut: " .. currentShortcut)

			--------------------------------------------------------------------------------
			-- Perform Search:
			--------------------------------------------------------------------------------
			if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then effectsSearchField = finalCutProEffectsTransitionsBrowserGroup[4] end
			if effectsSearchField ~= nil then
				effectsSearchField:setAttributeValue("AXValue", currentShortcut)
				effectsSearchField[1]:performAction("AXPress")
			else
				dialog.displayErrorMessage("Unable to type search request in search box.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Get First Item in Browser:
			--------------------------------------------------------------------------------
			if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][4] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][4][1] ~= nil then
						if finalCutProEffectsTransitionsBrowserGroup[1][4][1][1] ~= nil then
							effectButton = finalCutProEffectsTransitionsBrowserGroup[1][4][1][1]
						end
					end
				end
			end

		end

		--------------------------------------------------------------------------------
		-- Double Click on First Item in Browser:
		--------------------------------------------------------------------------------
		if effectButton ~= nil then

			--------------------------------------------------------------------------------
			-- Original Mouse Position:
			--------------------------------------------------------------------------------
			local originalMousePosition = mouse.getAbsolutePosition()

			--------------------------------------------------------------------------------
			-- Get centre of button:
			--------------------------------------------------------------------------------
			local effectButtonPosition = {}
			effectButtonPosition['x'] = effectButton:attributeValue("AXPosition")['x'] + (effectButton:attributeValue("AXSize")['w'] / 2)
			effectButtonPosition['y'] = effectButton:attributeValue("AXPosition")['y'] + (effectButton:attributeValue("AXSize")['h'] / 2)

			--------------------------------------------------------------------------------
			-- Double Click:
			--------------------------------------------------------------------------------
			tools.tools.doubleLeftClick(effectButtonPosition)

			--------------------------------------------------------------------------------
			-- Put it back:
			--------------------------------------------------------------------------------
			mouse.setAbsolutePosition(originalMousePosition)

		else
			dialog.displayErrorMessage("Unable to locate effect.\n\nError occured in transitionsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay:
		--------------------------------------------------------------------------------
		timer.doAfter(0.1, function()

			--------------------------------------------------------------------------------
			-- Make sure there's nothing in the search box:
			--------------------------------------------------------------------------------
			local effectsSearchCancelButton = nil
			if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
					effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
				end
			end
			if effectsSearchCancelButton ~= nil then
				effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
				if effectsSearchCancelButtonResult == nil then
					dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in transitionsShortcut().")
					showTouchbar()
					return "Fail"
				end
			end

			--------------------------------------------------------------------------------
			-- Restore Effects or Transitions Panel:
			--------------------------------------------------------------------------------
			if whichPanelActivated == "Effects" then
				finalCutProTimelineButtonBar[whichRadioGroup][1]:performAction("AXPress")
			elseif whichPanelActivated == "None" then
				finalCutProTimelineButtonBar[whichRadioGroup][2]:performAction("AXPress")
			end

			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			showTouchbar()

		end)

	end

	--------------------------------------------------------------------------------
	-- EFFECTS SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function effectsShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local currentShortcut = nil
		if whichShortcut == 1 then currentShortcut = settings.get("fcpxHacks.effectsShortcutOne") end
		if whichShortcut == 2 then currentShortcut = settings.get("fcpxHacks.effectsShortcutTwo") end
		if whichShortcut == 3 then currentShortcut = settings.get("fcpxHacks.effectsShortcutThree") end
		if whichShortcut == 4 then currentShortcut = settings.get("fcpxHacks.effectsShortcutFour") end
		if whichShortcut == 5 then currentShortcut = settings.get("fcpxHacks.effectsShortcutFive") end
		if type(whichShortcut) == "string" then currentShortcut = whichShortcut end

		if currentShortcut == nil then
			dialog.displayMessage("There is no Effect assigned to this shortcut.\n\nYou can assign Effects Shortcuts via the FCPX Hacks menu bar.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Timeline Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProTimelineButtonBar = fcp.getTimelineButtonBar()
		if finalCutProTimelineButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar.\n\nError occured in effectsShortcut() whilst using fcp.getTimelineButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Find Effects Browser Button:
		--------------------------------------------------------------------------------
		local whichRadioGroup = nil
		for i=1, finalCutProTimelineButtonBar:attributeValueCount("AXChildren") do
			if finalCutProTimelineButtonBar[i]:attributeValue("AXRole") == "AXRadioGroup" then
				if finalCutProTimelineButtonBar[i]:attributeValue("AXIdentifier") == "_NS:165" then
					whichRadioGroup = i
				end
			end
		end
		if whichRadioGroup == nil then
			dialog.displayErrorMessage("Unable to detect Timeline Button Bar Radio Group.\n\nError occured in effectsShortcut().")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Effects or Transitions Panel Open?
		--------------------------------------------------------------------------------
		local whichPanelActivated = "None"
		if finalCutProTimelineButtonBar[whichRadioGroup][1] ~= nil then
			if finalCutProTimelineButtonBar[whichRadioGroup][1]:attributeValue("AXValue") == 1 then whichPanelActivated = "Effects" end
			if finalCutProTimelineButtonBar[whichRadioGroup][2]:attributeValue("AXValue") == 1 then whichPanelActivated = "Transitions" end
		end

		--------------------------------------------------------------------------------
		-- Make sure Video Effects panel is open:
		--------------------------------------------------------------------------------
		local effectsBrowserButton = finalCutProTimelineButtonBar[whichRadioGroup][1]
		if effectsBrowserButton ~= nil then
			if effectsBrowserButton:attributeValue("AXValue") == 0 then
				local presseffectsBrowserButtonResult = effectsBrowserButton:performAction("AXPress")
				if presseffectsBrowserButtonResult == nil then
					dialog.displayErrorMessage("Unable to press Effects Browser Button icon.")
					showTouchbar()
					return "Fail"
				end
			end
		else
			dialog.displayErrorMessage("Unable to activate Video Effects Panel.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Make sure "Installed Effects" is selected:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Group:
			--------------------------------------------------------------------------------
			local finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserSplitGroup = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXRole") == "AXSplitGroup" then
					if finalCutProEffectsTransitionsBrowserGroup[i]:attributeValue("AXIdentifier") == "_NS:452" then
						whichEffectsBrowserSplitGroup = i
					end
				end
			end
			if whichEffectsBrowserSplitGroup == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Split Group.\n\nError occured in effectsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Get Transitions Browser Split Group:
			--------------------------------------------------------------------------------
			local whichEffectsBrowserPopupButton = nil
			for i=1, finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup]:attributeValueCount("AXChildren") do
				if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXRole") == "AXPopUpButton" then
					if finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][i]:attributeValue("AXIdentifier") == "_NS:45" then
						whichEffectsBrowserPopupButton = i
					end
				end
			end
			if whichEffectsBrowserPopupButton == nil then
				dialog.displayErrorMessage("Unable to detect Transitions Browser's Popup Button.\n\nError occured in effectsShortcut().")
				return "Failed"
			end

			--------------------------------------------------------------------------------
			-- Check that "Installed Effects" is selected:
			--------------------------------------------------------------------------------
			local installedEffectsPopup = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton]
			if installedEffectsPopup ~= nil then
				if installedEffectsPopup:attributeValue("AXValue") ~= "Installed Effects" then
					installedEffectsPopup:performAction("AXPress")
					finalCutProEffectsTransitionsBrowserGroup = fcp.getEffectsTransitionsBrowserGroup()
					installedEffectsPopupMenuItem = finalCutProEffectsTransitionsBrowserGroup[whichEffectsBrowserSplitGroup][whichEffectsBrowserPopupButton][1][1]
					installedEffectsPopupMenuItem:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to find 'Installed Effects' popup.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end

		--------------------------------------------------------------------------------
		-- Make sure there's nothing in the search box:
		--------------------------------------------------------------------------------
		local effectsSearchCancelButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
				effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
			end
		end
		if effectsSearchCancelButton ~= nil then
			effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
			if effectsSearchCancelButtonResult == nil then
				dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Click 'All Video & Audio':
		--------------------------------------------------------------------------------
		local allVideoAndAudioButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1][1] ~= nil then
						allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][1]
					end
				end
			end
		end
		if allVideoAndAudioButton ~= nil then
			allVideoAndAudioButton:setAttributeValue("AXSelected", true)
		else

			--------------------------------------------------------------------------------
			-- Make sure Effects Browser Sidebar is Visible:
			--------------------------------------------------------------------------------
			effectsBrowserSidebar = finalCutProEffectsTransitionsBrowserGroup[2]
			if effectsBrowserSidebar ~= nil then
				if effectsBrowserSidebar:attributeValue("AXValue") == 1 then
					effectsBrowserSidebar:performAction("AXPress")
				end
			else
				dialog.displayErrorMessage("Unable to locate Effects Browser Sidebar button.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Click 'All Video & Audio':
			--------------------------------------------------------------------------------
			local allVideoAndAudioButton = nil
			if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][1][1] ~= nil then
						if finalCutProEffectsTransitionsBrowserGroup[1][1][1][1] ~= nil then
							allVideoAndAudioButton = finalCutProEffectsTransitionsBrowserGroup[1][1][1][1]
						end
					end
				end
			end
			if allVideoAndAudioButton ~= nil then
				allVideoAndAudioButton:setAttributeValue("AXSelected", true)
			else
				dialog.displayErrorMessage("Unable to locate 'All Video & Audio' button.\n\nError occured in effectsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay...
		--------------------------------------------------------------------------------
		timer.usleep(100000)

		--------------------------------------------------------------------------------
		-- Perform Search:
		--------------------------------------------------------------------------------
		local effectsSearchField = nil
		if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then effectsSearchField = finalCutProEffectsTransitionsBrowserGroup[4] end
		if effectsSearchField ~= nil then
			effectsSearchField:setAttributeValue("AXValue", currentShortcut)
			effectsSearchField[1]:performAction("AXPress")
		else
			dialog.displayErrorMessage("Unable to type search request in search box.\n\nError occured in effectsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Make sure scroll bar is at top:
		--------------------------------------------------------------------------------
		local effectsScrollBar = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][4] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][4][2] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][4][2][1] ~= nil then
						effectsScrollBar = finalCutProEffectsTransitionsBrowserGroup[1][4][2][1]
					end
				end
			end
		end
		if effectsScrollBar ~= nil then
			effectsScrollBar:setAttributeValue("AXValue", 0)
		end

		--------------------------------------------------------------------------------
		-- Double click on effect:
		--------------------------------------------------------------------------------
		local effectButton = nil
		if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
			if finalCutProEffectsTransitionsBrowserGroup[1][4] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][4][1] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][4][1][1] ~= nil then
						effectButton = finalCutProEffectsTransitionsBrowserGroup[1][4][1][1]
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		if effectButton == nil then

			--------------------------------------------------------------------------------
			-- Remove first dash:
			--------------------------------------------------------------------------------
			currentShortcut = string.sub(currentShortcut, string.find(currentShortcut, "-") + 2)

			writeToConsole("currentShortcut: " .. currentShortcut)

			--------------------------------------------------------------------------------
			-- Perform Search:
			--------------------------------------------------------------------------------
			if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then effectsSearchField = finalCutProEffectsTransitionsBrowserGroup[4] end
			if effectsSearchField ~= nil then
				effectsSearchField:setAttributeValue("AXValue", currentShortcut)
				effectsSearchField[1]:performAction("AXPress")
			else
				dialog.displayErrorMessage("Unable to type search request in search box.\n\nError occured in transitionsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Get First Item in Browser:
			--------------------------------------------------------------------------------
			if finalCutProEffectsTransitionsBrowserGroup[1] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[1][4] ~= nil then
					if finalCutProEffectsTransitionsBrowserGroup[1][4][1] ~= nil then
						if finalCutProEffectsTransitionsBrowserGroup[1][4][1][1] ~= nil then
							effectButton = finalCutProEffectsTransitionsBrowserGroup[1][4][1][1]
						end
					end
				end
			end

		end

		--------------------------------------------------------------------------------
		-- Get First Item in Browser:
		--------------------------------------------------------------------------------
		if effectButton ~= nil then

			--------------------------------------------------------------------------------
			-- Original Mouse Position:
			--------------------------------------------------------------------------------
			local originalMousePosition = mouse.getAbsolutePosition()

			--------------------------------------------------------------------------------
			-- Get centre of button:
			--------------------------------------------------------------------------------
			local effectButtonPosition = {}
			effectButtonPosition['x'] = effectButton:attributeValue("AXPosition")['x'] + (effectButton:attributeValue("AXSize")['w'] / 2)
			effectButtonPosition['y'] = effectButton:attributeValue("AXPosition")['y'] + (effectButton:attributeValue("AXSize")['h'] / 2)

			--------------------------------------------------------------------------------
			-- Double Click:
			--------------------------------------------------------------------------------
			tools.doubleLeftClick(effectButtonPosition)

			--------------------------------------------------------------------------------
			-- Put it back:
			--------------------------------------------------------------------------------
			mouse.setAbsolutePosition(originalMousePosition)

		else
			dialog.displayErrorMessage("Unable to locate effect.\n\nError occured in effectsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay:
		--------------------------------------------------------------------------------
		timer.doAfter(0.1, function()

			--------------------------------------------------------------------------------
			-- Make sure there's nothing in the search box:
			--------------------------------------------------------------------------------
			local effectsSearchCancelButton = nil
			if finalCutProEffectsTransitionsBrowserGroup[4] ~= nil then
				if finalCutProEffectsTransitionsBrowserGroup[4][2] ~= nil then
					effectsSearchCancelButton = finalCutProEffectsTransitionsBrowserGroup[4][2]
				end
			end
			if effectsSearchCancelButton ~= nil then
				effectsSearchCancelButtonResult = effectsSearchCancelButton:performAction("AXPress")
				if effectsSearchCancelButtonResult == nil then
					dialog.displayErrorMessage("Unable to cancel effects search.\n\nError occured in effectsShortcut().")
					showTouchbar()
					return "Fail"
				end
			end

			--------------------------------------------------------------------------------
			-- Restore Effects or Transitions Panel:
			--------------------------------------------------------------------------------
			if whichPanelActivated == "None" then
				finalCutProTimelineButtonBar[whichRadioGroup][1]:performAction("AXPress")
			elseif whichPanelActivated == "Transitions" then
				finalCutProTimelineButtonBar[whichRadioGroup][2]:performAction("AXPress")
			end

			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			showTouchbar()

		end)

	end

	--------------------------------------------------------------------------------
	-- TITLES SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function titlesShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local currentShortcut = nil
		if whichShortcut == 1 then currentShortcut = settings.get("fcpxHacks.titlesShortcutOne") end
		if whichShortcut == 2 then currentShortcut = settings.get("fcpxHacks.titlesShortcutTwo") end
		if whichShortcut == 3 then currentShortcut = settings.get("fcpxHacks.titlesShortcutThree") end
		if whichShortcut == 4 then currentShortcut = settings.get("fcpxHacks.titlesShortcutFour") end
		if whichShortcut == 5 then currentShortcut = settings.get("fcpxHacks.titlesShortcutFive") end
		if type(whichShortcut) == "string" then currentShortcut = whichShortcut end

		if currentShortcut == nil then
			dialog.displayMessage("There is no Title assigned to this shortcut.\n\nYou can assign Titles Shortcuts via the FCPX Hacks menu bar.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Browser Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProBrowserButtonBar = fcp.getBrowserButtonBar()
		if finalCutProBrowserButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Browser Button Bar.\n\nError occured in titlesShortcut() whilst using fcp.getBrowserButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Button IDs:
		--------------------------------------------------------------------------------
		local libariesButtonID = nil
		local photosAudioButtonID = nil
		local titlesGeneratorsButtonID = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

				--------------------------------------------------------------------------------
				-- Button 1: Libraries
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
					libariesButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 2: Photos/Audio
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
					photosAudioButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 3: Titles/Transitions
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
					titlesGeneratorsButtonID = i
				end

			end
		end
		if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
			dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in updateTitlesList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Which Browser Panel is Open?
		--------------------------------------------------------------------------------
		local whichBrowserPanelWasOpen = nil
		if finalCutProBrowserButtonBar[libariesButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "Library" end
		if finalCutProBrowserButtonBar[photosAudioButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "PhotosAndAudio" end
		if finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "TitlesAndGenerators" end

		--------------------------------------------------------------------------------
		-- If Titles & Generators is Closed, let's open it:
		--------------------------------------------------------------------------------
		if whichBrowserPanelWasOpen ~= "TitlesAndGenerators" then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in titlesShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Which Split Group?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSplitGroup = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXSplitGroup" then
				titlesGeneratorsSplitGroup = i
				goto titlesGeneratorsSplitGroupExit
			end
		end
		::titlesGeneratorsSplitGroupExit::
		if titlesGeneratorsSplitGroup == nil then
			dialog.displayErrorMessage("Unable to find Titles/Generators Split Group.\n\nError occured in titlesShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Is the Side Bar Closed?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSideBarClosed = true
		if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1] ~= nil then
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][1] ~= nil then
					titlesGeneratorsSideBarClosed = false
				end
			end
		end
		if titlesGeneratorsSideBarClosed then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in titlesShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Make sure Titles is selected:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][1]:setAttributeValue("AXSelected", true)
		if result == nil then
			dialog.displayErrorMessage("Unable to select Titles from List.\n\nError occured in titlesShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Popup Button:
		--------------------------------------------------------------------------------
		local titlesPopupButton = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXPopUpButton" then
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:46" then
					titlesPopupButton = i
					goto titlesGeneratorsDropdownExit
				end
			end
		end
		if titlesPopupButton == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Popup Button.\n\nError occured in titlesShortcut().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsDropdownExit::

		--------------------------------------------------------------------------------
		-- Make sure Titles/Generators Popup Button is set to Installed Titles:
		--------------------------------------------------------------------------------
		if finalCutProBrowserButtonBar[titlesPopupButton]:attributeValue("AXValue") ~= "Installed Titles" then
			local result = finalCutProBrowserButtonBar[titlesPopupButton]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generators Popup Button.\n\nError occured in titlesShortcut().")
				showTouchbar()
				return "Fail"
			end

			local result = finalCutProBrowserButtonBar[titlesPopupButton][1][1]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press First Popup Item.\n\nError occured in updateTitlesList().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay...
		--------------------------------------------------------------------------------
		timer.usleep(100000)

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Group:
		--------------------------------------------------------------------------------
		local titlesGeneratorsGroup = nil
		for i=1, finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup]:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXRole") == "AXScrollArea" then
						if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXIdentifier") == "_NS:9" then
							titlesGeneratorsGroup = i
							goto titlesGeneratorsGroupExit
						end
					end
				end
			end
		end
		if titlesGeneratorsGroup == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Group.\n\nError occured in titlesShortcut().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsGroupExit::

		--------------------------------------------------------------------------------
		-- Enter text into Search box:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3]:setAttributeValue("AXValue", currentShortcut)
		if result == nil then
			dialog.displayErrorMessage("Unable to enter search value.\n\nError occured in titlesShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Trigger Search:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3][1]:performAction("AXPress")
		if result == nil then
			dialog.displayErrorMessage("Unable to press Search Button.\n\nError occured in titlesShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Selected Title:
		--------------------------------------------------------------------------------
		local selectedTitle = nil
		if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup] ~= nil then
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1] ~= nil then
						selectedTitle = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1]
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		if selectedTitle == nil then

			--------------------------------------------------------------------------------
			-- Remove first dash:
			--------------------------------------------------------------------------------
			currentShortcut = string.sub(currentShortcut, string.find(currentShortcut, "-") + 2)

			--------------------------------------------------------------------------------
			-- Enter text into Search box:
			--------------------------------------------------------------------------------
			local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3]:setAttributeValue("AXValue", currentShortcut)
			if result == nil then
				dialog.displayErrorMessage("Unable to enter search value.\n\nError occured in titlesShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Trigger Search:
			--------------------------------------------------------------------------------
			local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3][1]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Search Button.\n\nError occured in titlesShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Get Selected Title:
			--------------------------------------------------------------------------------
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1] ~= nil then
						if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1] ~= nil then
							selectedTitle = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1]
						end
					end
				end
			end

		end

		--------------------------------------------------------------------------------
		-- Click First Item in Browser:
		--------------------------------------------------------------------------------
		if selectedTitle ~= nil then

			--------------------------------------------------------------------------------
			-- Original Mouse Position:
			--------------------------------------------------------------------------------
			local originalMousePosition = mouse.getAbsolutePosition()

			--------------------------------------------------------------------------------
			-- Get centre of button:
			--------------------------------------------------------------------------------
			local selectedTitlePosition = {}
			selectedTitlePosition['x'] = selectedTitle:attributeValue("AXPosition")['x'] + (selectedTitle:attributeValue("AXSize")['w'] / 2)
			selectedTitlePosition['y'] = selectedTitle:attributeValue("AXPosition")['y'] + (selectedTitle:attributeValue("AXSize")['h'] / 2)

			--------------------------------------------------------------------------------
			-- Double Click:
			--------------------------------------------------------------------------------
			tools.doubleLeftClick(selectedTitlePosition)

			--------------------------------------------------------------------------------
			-- Put it back:
			--------------------------------------------------------------------------------
			mouse.setAbsolutePosition(originalMousePosition)

		else
			dialog.displayErrorMessage("Unable to locate Title.\n\nError occured in titlesShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay:
		--------------------------------------------------------------------------------
		timer.doAfter(0.1, function()

			--------------------------------------------------------------------------------
			-- Make sure there's nothing in the search box:
			--------------------------------------------------------------------------------
			local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3][2]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Cancel Search Button.\n\nError occured in titlesShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Get Button IDs Again:
			--------------------------------------------------------------------------------
			for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
				if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

					--------------------------------------------------------------------------------
					-- Button 1: Libraries
					--------------------------------------------------------------------------------
					if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
						libariesButtonID = i
					end

					--------------------------------------------------------------------------------
					-- Button 2: Photos/Audio
					--------------------------------------------------------------------------------
					if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
						photosAudioButtonID = i
					end

					--------------------------------------------------------------------------------
					-- Button 3: Titles/Transitions
					--------------------------------------------------------------------------------
					if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
						titlesGeneratorsButtonID = i
					end

				end
			end
			if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
				dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in titlesShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Go back to previously selected panel:
			--------------------------------------------------------------------------------
			if whichBrowserPanelWasOpen == "Library" then
				local result = finalCutProBrowserButtonBar[libariesButtonID]:performAction("AXPress")
				if result == nil then
					dialog.displayMessage("Unable to press Libraries Button.\n\nError occured in titlesShortcut().")
					showTouchbar()
					return "Fail"
				end
			end
			if whichBrowserPanelWasOpen == "PhotosAndAudio" then
				local result = finalCutProBrowserButtonBar[photosAudioButtonID]:performAction("AXPress")
				if result == nil then
					dialog.displayMessage("Unable to press Photos & Audio Button.\n\nError occured in titlesShortcut().")
					showTouchbar()
					return "Fail"
				end
			end
			if titlesGeneratorsSideBarClosed then
				local result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
				if result == nil then
					dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in titlesShortcut().")
					showTouchbar()
					return "Fail"
				end
			end

			--------------------------------------------------------------------------------
			-- Restore Touch Bar:
			--------------------------------------------------------------------------------
			showTouchbar()
		end)

	end

	--------------------------------------------------------------------------------
	-- GENERATORS SHORTCUT PRESSED:
	--------------------------------------------------------------------------------
	function generatorsShortcut(whichShortcut)

		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		hideTouchbar()

		--------------------------------------------------------------------------------
		-- Get settings:
		--------------------------------------------------------------------------------
		local currentShortcut = nil
		if whichShortcut == 1 then currentShortcut = settings.get("fcpxHacks.generatorsShortcutOne") end
		if whichShortcut == 2 then currentShortcut = settings.get("fcpxHacks.generatorsShortcutTwo") end
		if whichShortcut == 3 then currentShortcut = settings.get("fcpxHacks.generatorsShortcutThree") end
		if whichShortcut == 4 then currentShortcut = settings.get("fcpxHacks.generatorsShortcutFour") end
		if whichShortcut == 5 then currentShortcut = settings.get("fcpxHacks.generatorsShortcutFive") end
		if type(whichShortcut) == "string" then currentShortcut = whichShortcut end

		if currentShortcut == nil then
			dialog.displayMessage("There is no Generator assigned to this shortcut.\n\nYou can assign Generator Shortcuts via the FCPX Hacks menu bar.")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Browser Button Bar:
		--------------------------------------------------------------------------------
		local finalCutProBrowserButtonBar = fcp.getBrowserButtonBar()
		if finalCutProBrowserButtonBar == nil then
			dialog.displayErrorMessage("Unable to detect Browser Button Bar.\n\nError occured in generatorsShortcut() whilst using fcp.getBrowserButtonBar().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Button IDs:
		--------------------------------------------------------------------------------
		local libariesButtonID = nil
		local photosAudioButtonID = nil
		local titlesGeneratorsButtonID = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

				--------------------------------------------------------------------------------
				-- Button 1: Libraries
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
					libariesButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 2: Photos/Audio
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
					photosAudioButtonID = i
				end

				--------------------------------------------------------------------------------
				-- Button 3: Titles/Transitions
				--------------------------------------------------------------------------------
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
					titlesGeneratorsButtonID = i
				end

			end
		end
		if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
			dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in generatorsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Which Browser Panel is Open?
		--------------------------------------------------------------------------------
		local whichBrowserPanelWasOpen = nil
		if finalCutProBrowserButtonBar[libariesButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "Library" end
		if finalCutProBrowserButtonBar[photosAudioButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "PhotosAndAudio" end
		if finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:attributeValue("AXValue") == 1 then whichBrowserPanelWasOpen = "TitlesAndGenerators" end

		--------------------------------------------------------------------------------
		-- If Titles & Generators is Closed, let's open it:
		--------------------------------------------------------------------------------
		if whichBrowserPanelWasOpen ~= "TitlesAndGenerators" then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Which Split Group?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSplitGroup = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXSplitGroup" then
				titlesGeneratorsSplitGroup = i
				goto titlesGeneratorsSplitGroupExit
			end
		end
		::titlesGeneratorsSplitGroupExit::
		if titlesGeneratorsSplitGroup == nil then
			dialog.displayErrorMessage("Unable to find Titles/Generators Split Group.\n\nError occured in generatorsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Is the Side Bar Closed?
		--------------------------------------------------------------------------------
		local titlesGeneratorsSideBarClosed = true
		if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1] ~= nil then
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][1] ~= nil then
					titlesGeneratorsSideBarClosed = false
				end
			end
		end
		if titlesGeneratorsSideBarClosed then
			result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Find Generators Row:
		--------------------------------------------------------------------------------
		local generatorsRow = nil
		local foundTitles = false
		for i=1, finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1]:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][i][1]:attributeValue("AXRole") == "AXGroup" then
				if foundTitles == false then
					foundTitles = true
				else
					generatorsRow = i
					goto generatorsRowExit
				end
			end
		end
		::generatorsRowExit::
		if generatorsRow == nil then
			dialog.displayErrorMessage("Unable to find Generators Row.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Select Generators Row:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][1][1][generatorsRow]:setAttributeValue("AXSelected", true)
		if result == nil then
			dialog.displayErrorMessage("Unable to select Generators from Sidebar.\n\nError occured in updateGeneratorsList().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Popup Button:
		--------------------------------------------------------------------------------
		local titlesPopupButton = nil
		for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXPopUpButton" then
				if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:46" then
					titlesPopupButton = i
					goto titlesGeneratorsDropdownExit
				end
			end
		end
		if titlesPopupButton == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Popup Button.\n\nError occured in generatorsShortcut().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsDropdownExit::

		--------------------------------------------------------------------------------
		-- Make sure Titles/Generators Popup Button is set to Installed Titles:
		--------------------------------------------------------------------------------
		if finalCutProBrowserButtonBar[titlesPopupButton]:attributeValue("AXValue") ~= "Installed Titles" then
			local result = finalCutProBrowserButtonBar[titlesPopupButton]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Titles/Generators Popup Button.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end

			local result = finalCutProBrowserButtonBar[titlesPopupButton][1][1]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press First Popup Item.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay...
		--------------------------------------------------------------------------------
		timer.usleep(100000)

		--------------------------------------------------------------------------------
		-- Get Titles/Generators Group:
		--------------------------------------------------------------------------------
		local titlesGeneratorsGroup = nil
		for i=1, finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup]:attributeValueCount("AXChildren") do
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXRole") == "AXScrollArea" then
						if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][i][1]:attributeValue("AXIdentifier") == "_NS:9" then
							titlesGeneratorsGroup = i
							goto titlesGeneratorsGroupExit
						end
					end
				end
			end
		end
		if titlesGeneratorsGroup == nil then
			dialog.displayErrorMessage("Unable to detect Titles/Generators Group.\n\nError occured in generatorsShortcut().")
			showTouchbar()
			return "Fail"
		end
		::titlesGeneratorsGroupExit::

		--------------------------------------------------------------------------------
		-- Enter text into Search box:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3]:setAttributeValue("AXValue", currentShortcut)
		if result == nil then
			dialog.displayErrorMessage("Unable to enter search value.\n\nError occured in generatorsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Trigger Search:
		--------------------------------------------------------------------------------
		local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3][1]:performAction("AXPress")
		if result == nil then
			dialog.displayErrorMessage("Unable to press Search Button.\n\nError occured in generatorsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Selected Title:
		--------------------------------------------------------------------------------
		local selectedTitle = nil
		if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup] ~= nil then
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1] ~= nil then
						selectedTitle = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1]
					end
				end
			end
		end

		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		if selectedTitle == nil then

			--------------------------------------------------------------------------------
			-- Remove first dash:
			--------------------------------------------------------------------------------
			currentShortcut = string.sub(currentShortcut, string.find(currentShortcut, "-") + 2)

			--------------------------------------------------------------------------------
			-- Enter text into Search box:
			--------------------------------------------------------------------------------
			local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3]:setAttributeValue("AXValue", currentShortcut)
			if result == nil then
				dialog.displayErrorMessage("Unable to enter search value.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Trigger Search:
			--------------------------------------------------------------------------------
			local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3][1]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Search Button.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Get Selected Title:
			--------------------------------------------------------------------------------
			if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup] ~= nil then
				if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1] ~= nil then
					if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1] ~= nil then
						if finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1] ~= nil then
							selectedTitle = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][titlesGeneratorsGroup][1][1][1]
						end
					end
				end
			end

		end

		--------------------------------------------------------------------------------
		-- Click First Item in Browser:
		--------------------------------------------------------------------------------
		if selectedTitle ~= nil then

			--------------------------------------------------------------------------------
			-- Original Mouse Position:
			--------------------------------------------------------------------------------
			local originalMousePosition = mouse.getAbsolutePosition()

			--------------------------------------------------------------------------------
			-- Get centre of button:
			--------------------------------------------------------------------------------
			local selectedTitlePosition = {}
			selectedTitlePosition['x'] = selectedTitle:attributeValue("AXPosition")['x'] + (selectedTitle:attributeValue("AXSize")['w'] / 2)
			selectedTitlePosition['y'] = selectedTitle:attributeValue("AXPosition")['y'] + (selectedTitle:attributeValue("AXSize")['h'] / 2)

			--------------------------------------------------------------------------------
			-- Double Click:
			--------------------------------------------------------------------------------
			tools.doubleLeftClick(selectedTitlePosition)

			--------------------------------------------------------------------------------
			-- Put it back:
			--------------------------------------------------------------------------------
			mouse.setAbsolutePosition(originalMousePosition)

		else
			dialog.displayErrorMessage("Unable to locate Generator.\n\nError occured in generatorsShortcut().")
			showTouchbar()
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Add a bit of a delay:
		--------------------------------------------------------------------------------
		timer.doAfter(0.1, function()

			--------------------------------------------------------------------------------
			-- Make sure there's nothing in the search box:
			--------------------------------------------------------------------------------
			local result = finalCutProBrowserButtonBar[titlesGeneratorsSplitGroup][3][2]:performAction("AXPress")
			if result == nil then
				dialog.displayErrorMessage("Unable to press Cancel Search Button.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Get Button IDs Again:
			--------------------------------------------------------------------------------
			for i=1, finalCutProBrowserButtonBar:attributeValueCount("AXChildren") do
				if finalCutProBrowserButtonBar[i]:attributeValue("AXRole") == "AXCheckBox" then

					--------------------------------------------------------------------------------
					-- Button 1: Libraries
					--------------------------------------------------------------------------------
					if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:416" then
						libariesButtonID = i
					end

					--------------------------------------------------------------------------------
					-- Button 2: Photos/Audio
					--------------------------------------------------------------------------------
					if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:425" then
						photosAudioButtonID = i
					end

					--------------------------------------------------------------------------------
					-- Button 3: Titles/Transitions
					--------------------------------------------------------------------------------
					if finalCutProBrowserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:433" then
						titlesGeneratorsButtonID = i
					end

				end
			end
			if libariesButtonID == nil or photosAudioButtonID == nil or titlesGeneratorsButtonID == nil then
				dialog.displayErrorMessage("Unable to detect Browser Buttons.\n\nError occured in generatorsShortcut().")
				showTouchbar()
				return "Fail"
			end

			--------------------------------------------------------------------------------
			-- Go back to previously selected panel:
			--------------------------------------------------------------------------------
			if whichBrowserPanelWasOpen == "Library" then
				local result = finalCutProBrowserButtonBar[libariesButtonID]:performAction("AXPress")
				if result == nil then
					dialog.displayMessage("Unable to press Libraries Button.\n\nError occured in generatorsShortcut().")
					showTouchbar()
					return "Fail"
				end
			end
			if whichBrowserPanelWasOpen == "PhotosAndAudio" then
				local result = finalCutProBrowserButtonBar[photosAudioButtonID]:performAction("AXPress")
				if result == nil then
					dialog.displayMessage("Unable to press Photos & Audio Button.\n\nError occured in generatorsShortcut().")
					showTouchbar()
					return "Fail"
				end
			end
			if titlesGeneratorsSideBarClosed then
				local result = finalCutProBrowserButtonBar[titlesGeneratorsButtonID]:performAction("AXPress")
				if result == nil then
					dialog.displayErrorMessage("Unable to press Titles/Generator Button.\n\nError occured in generatorsShortcut().")
					showTouchbar()
					return "Fail"
				end
			end

			--------------------------------------------------------------------------------
			-- Restore Touch Bar:
			--------------------------------------------------------------------------------
			showTouchbar()
		end)

	end

--------------------------------------------------------------------------------
-- OTHER SHORTCUTS:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- TOGGLE TOUCH BAR:
	--------------------------------------------------------------------------------
	function toggleTouchBar()

		--------------------------------------------------------------------------------
		-- Check for compatibility:
		--------------------------------------------------------------------------------
		if not touchBarSupported then
			dialog.displayMessage("Touch Bar support requires macOS 10.12.1 (Build 16B2657) or later.\n\nPlease update macOS and try again.")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Get Settings:
		--------------------------------------------------------------------------------
		local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false

		--------------------------------------------------------------------------------
		-- Toggle Touch Bar:
		--------------------------------------------------------------------------------
		setTouchBarLocation()
		mod.touchBarWindow:toggle()

		--------------------------------------------------------------------------------
		-- Update Settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.displayTouchBar", not displayTouchBar)

	end

	--------------------------------------------------------------------------------
	-- CUT AND SWITCH MULTI-CAM:
	--------------------------------------------------------------------------------
	function cutAndSwitchMulticam(whichMode, whichAngle)

		if whichMode == "Audio" then
			if not keyStrokeFromPlist("MultiAngleEditStyleAudio") then
				dialog.displayErrorMessage("We were unable to trigger the 'Cut/Switch Multicam Audio Only' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.")
				return "Failed"
			end
		end

		if whichMode == "Video" then
			if not keyStrokeFromPlist("MultiAngleEditStyleVideo") then
				dialog.displayErrorMessage("We were unable to trigger the 'Cut/Switch Multicam Video Only' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.")
				return "Failed"
			end
		end

		if whichMode == "Both" then
			if not keyStrokeFromPlist("MultiAngleEditStyleAudioVideo") then
				dialog.displayMessage("We were unable to trigger the 'Cut/Switch Multicam Audio and Video' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.")
				return "Failed"
			end
		end

		if not keyStrokeFromPlist("CutSwitchAngle" .. tostring(string.format("%02d", whichAngle))) then
			dialog.displayMessage("We were unable to trigger the 'Cut and Switch to Viewer Angle " .. tostring(whichAngle) .. "' Shortcut.\n\nPlease make sure this shortcut is allocated in the Command Editor.")
			return "Failed"
		end

	end

	--------------------------------------------------------------------------------
	-- MOVE TO PLAYHEAD:
	--------------------------------------------------------------------------------
	function moveToPlayhead()

		local enableClipboardHistory = settings.get("fcpxHacks.enableClipboardHistory") or false

		if enableClipboardHistory then clipboard.stopWatching() end

		if not keyStrokeFromPlist("Cut") then
			dialog.displayErrorMessage("Failed to trigger the 'Cut' Shortcut.")
			return "Failed"
		end

		if not keyStrokeFromPlist("Paste") then
			dialog.displayErrorMessage("Failed to trigger the 'Paste' Shortcut.")
			return "Failed"
		end

		if enableClipboardHistory then
			timer.usleep(1000000) -- Not sure why this is needed, but it is.
			clipboard.startWatching()
		end

	end

	--------------------------------------------------------------------------------
	-- HIGHLIGHT FINAL CUT PRO BROWSER PLAYHEAD:
	--------------------------------------------------------------------------------
	function highlightFCPXBrowserPlayhead()

		--------------------------------------------------------------------------------
		-- Delete any pre-existing highlights:
		--------------------------------------------------------------------------------
		deleteAllHighlights()

		--------------------------------------------------------------------------------
		-- Get Browser Split Group:
		--------------------------------------------------------------------------------
		browserSplitGroup = fcp.getBrowserSplitGroup()
		if browserSplitGroup == nil then
			writeToConsole("ERROR: Failed to get Browser Split Group in highlightFCPXBrowserPlayhead().")
			return "Fail"
		end

		--------------------------------------------------------------------------------
		-- Which Group:
		--------------------------------------------------------------------------------
		local whichGroup = nil
		for i=1, browserSplitGroup:attributeValueCount("AXChildren") do
			if browserSplitGroup:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
				whichGroup = i
			end
		end
		if whichGroup == nil then
			writeToConsole("ERROR: Unable to locate Group in highlightFCPXBrowserPlayhead().")
			return "Failed"
		end

		--------------------------------------------------------------------------------
		-- Which Scroll Area:
		--------------------------------------------------------------------------------
		local whichScrollArea = nil
		for i=1, browserSplitGroup[whichGroup]:attributeValueCount("AXChildren") do
			if browserSplitGroup[whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXScrollArea" then
				whichScrollArea = i
			end
		end

		if whichScrollArea == nil then

			--------------------------------------------------------------------------------
			-- LIST VIEW:
			--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Which Split Group:
				--------------------------------------------------------------------------------
				local whichSplitGroup = nil
				for i=1, browserSplitGroup[whichGroup]:attributeValueCount("AXChildren") do
					if browserSplitGroup[whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXSplitGroup" then
						if browserSplitGroup[whichGroup]:attributeValue("AXChildren")[i]:attributeValue("AXIdentifier") == "_NS:658" then
							whichSplitGroup = i
							goto exitWhichSplitGroupLoop
						end
					end
				end
				::exitWhichSplitGroupLoop::
				if whichSplitGroup == nil then
					writeToConsole("ERROR: Unable to locate Split Group in highlightFCPXBrowserPlayhead().")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Group 2:
				--------------------------------------------------------------------------------
				local whichGroupTwo = nil
				for i=1, browserSplitGroup[whichGroup][whichSplitGroup]:attributeValueCount("AXChildren") do
					if browserSplitGroup[whichGroup][whichSplitGroup]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
						if browserSplitGroup[whichGroup][whichSplitGroup]:attributeValue("AXChildren")[i]:attributeValue("AXIdentifier") == "_NS:590" then
							whichGroupTwo = i
							goto exitWhichGroupTwoLoop
						end
					end
				end
				::exitWhichGroupTwoLoop::
				if whichGroupTwo == nil then
					writeToConsole("ERROR: Unable to locate Group Two in highlightFCPXBrowserPlayhead().")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Value Indicator:
				--------------------------------------------------------------------------------
				local whichValueIndicator = nil
				whichValueIndicator = browserSplitGroup[whichGroup][whichSplitGroup][whichGroupTwo]:attributeValueCount("AXChildren") - 1
				persistentPlayhead = browserSplitGroup[whichGroup][whichSplitGroup][whichGroupTwo][whichValueIndicator]

		else

			--------------------------------------------------------------------------------
			-- FILMSTRIP VIEW:
			--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Which Group 2:
				--------------------------------------------------------------------------------
				local whichGroupTwo = nil
				for i=1, browserSplitGroup[whichGroup][whichScrollArea]:attributeValueCount("AXChildren") do
					if browserSplitGroup[whichGroup][whichScrollArea]:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXGroup" then
						if browserSplitGroup[whichGroup][whichScrollArea]:attributeValue("AXChildren")[i]:attributeValue("AXIdentifier") == "_NS:39" then
							whichGroupTwo = i
							goto exitWhichGroupTwoLoop
						end
					end
				end
				::exitWhichGroupTwoLoop::
				if whichGroupTwo == nil then
					writeToConsole("ERROR: Unable to locate Group Two in highlightFCPXBrowserPlayhead().")
					return "Failed"
				end

				--------------------------------------------------------------------------------
				-- Which Value Indicator:
				--------------------------------------------------------------------------------
				local whichValueIndicator = nil
				whichValueIndicator = browserSplitGroup[whichGroup][whichScrollArea][whichGroupTwo]:attributeValueCount("AXChildren") - 1
				persistentPlayhead = browserSplitGroup[whichGroup][whichScrollArea][whichGroupTwo][whichValueIndicator]

		end

		--[[
		if persistentPlayhead == nil then
			--------------------------------------------------------------------------------
			-- Browser on Second Screen (Filmstrip View):
			--------------------------------------------------------------------------------
			persistentPlayhead = sw:searchPath({
				{ role = "AXWindow", Title = "Events"},
				{ role = "AXSplitGroup", },
				{ role = "AXGroup", },
				{ role = "AXSplitGroup", Identifier = "_NS:344"},
				{ role = "AXGroup", },
				{ role = "AXScrollArea", Identifier = "_NS:33"},
				{ role = "AXGroup", Identifier = "_NS:39"},
				{ role = "AXValueIndicator", Description = "persistent playhead" },
			}, 1)
		end

		if persistentPlayhead == nil then
			--------------------------------------------------------------------------------
			-- Browser on Second Screen (List View):
			--------------------------------------------------------------------------------
			persistentPlayhead = sw:searchPath({
				{ role = "AXWindow", Title = "Events"},
				{ role = "AXSplitGroup",},
				{ role = "AXGroup", },
				{ role = "AXSplitGroup", Identifier = "_NS:344"},
				{ role = "AXGroup", },
				{ role = "AXSplitGroup", Identifier = "_NS:658"},
				{ role = "AXGroup", Identifier = "_NS:590"},
				{ role = "AXValueIndicator", Description = "persistent playhead" },
			}, 1)
		end
		--]]

		if persistentPlayhead ~= nil then

			--------------------------------------------------------------------------------
			-- Playhead Position:
			--------------------------------------------------------------------------------
			persistentPlayheadPosition = persistentPlayhead:attributeValue("AXPosition")
			persistentPlayheadSize = persistentPlayhead:attributeValue("AXSize")

			--------------------------------------------------------------------------------
			-- Highlight Mouse:
			--------------------------------------------------------------------------------
			mouseHighlight(persistentPlayheadPosition["x"], persistentPlayheadPosition["y"], persistentPlayheadSize["w"], persistentPlayheadSize["h"])

		end

	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--      C O M M O N     F I N A L    C U T    P R O     F U N C T I O N S     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GET FINAL CUT PRO PROXY STATUS ICON:
--------------------------------------------------------------------------------
function getProxyStatusIcon() -- Returns Icon or Nil

	local result = nil

	local proxyOnIcon = "🔴"
	local proxyOffIcon = "🔵"

	local FFPlayerQuality = fcp.getPreference("FFPlayerQuality")

	if FFPlayerQuality == "4" then
		result = proxyOnIcon 		-- Proxy (4)
	else
		result = proxyOffIcon 		-- Original (5)
	end

	return result

end

--------------------------------------------------------------------------------
-- WHICH BROWSER MODE IS ACTIVE IN FINAL CUT PRO?
--------------------------------------------------------------------------------
--
-- TO DO: This is currently broken in Final Cut Pro 10.3, and probably no longer needed.
--
function getFinalCutProBrowserMode() -- Returns "Filmstrip", "List" or "Failed"

	--------------------------------------------------------------------------------
	-- Define FCPX:
	--------------------------------------------------------------------------------
	local fcpx = fcp.application()

	--------------------------------------------------------------------------------
	-- Get all FCPX UI Elements:
	--------------------------------------------------------------------------------
	fcpxElements = ax.applicationElement(fcpx)

	--------------------------------------------------------------------------------
	-- Which AXMenuBar:
	--------------------------------------------------------------------------------
	local whichMenuBar = nil
	for i=1, fcpxElements:attributeValueCount("AXChildren") do
			if fcpxElements:attributeValue("AXChildren")[i]:attributeValue("AXRole") == "AXMenuBar" then
				whichMenuBar = i
				goto getFinalCutProBrowserModeWhichMenuBarExit
			end
	end
	if whichMenuBar == nil then	return "Failed"	end
	::getFinalCutProBrowserModeWhichMenuBarExit::

	--------------------------------------------------------------------------------
	-- Which option is ticked?
	--------------------------------------------------------------------------------
	if fcpxElements[whichMenuBar][9][1][5][1][1]:attributeValue("AXMenuItemMarkChar") == "✓" then return "Filmstrip" end 	-- "as Filmstrips " Selected
	if fcpxElements[whichMenuBar][9][1][5][1][2]:attributeValue("AXMenuItemMarkChar") == "✓"  then return "List" end 		-- "as List" Selected


	return "Filmstrip"

	--return "Failed"

end

--------------------------------------------------------------------------------
-- CHECK TO SEE IF WE SHOULD ACTUALLY TURN ON THE SCROLLING TIMELINE:
--------------------------------------------------------------------------------
function checkScrollingTimelinePress()

	--------------------------------------------------------------------------------
	-- Define FCPX:
	--------------------------------------------------------------------------------
	local fcpx 				= fcp.application()
	local fcpxElements 		= ax.applicationElement(fcpx)

	--------------------------------------------------------------------------------
	-- Don't activate scrollbar in fullscreen mode:
	--------------------------------------------------------------------------------
	local fullscreenActive = false

		--------------------------------------------------------------------------------
		-- No player controls visible:
		--------------------------------------------------------------------------------
		if fcpxElements[1][1] ~= nil then
			if fcpxElements[1][1]:attributeValue("AXDescription") == "Display Area" then
				fullscreenActive = true
			end
		end

		--------------------------------------------------------------------------------
		-- Player controls visible:
		--------------------------------------------------------------------------------
		if fcpxElements[1][1] ~= nil then
			if fcpxElements[1][1][1] ~= nil then
				if fcpxElements[1][1][1][1] ~= nil then
					if fcpxElements[1][1][1][1]:attributeValue("AXDescription") == "Play Pause" then
						fullscreenActive = true
					end
				end
			end
		end

	--------------------------------------------------------------------------------
	-- If Full Screen is Active then abort:
	--------------------------------------------------------------------------------
	if fullscreenActive then
		debugMessage("Spacebar pressed in fullscreen mode whilst watching for scrolling timeline.")
		return "Stop"
	end

	--------------------------------------------------------------------------------
	-- Get Timeline Scroll Area:
	--------------------------------------------------------------------------------
	local timelineScrollArea = fcp.getTimelineScrollArea()
	if timelineScrollArea == nil then
		writeToConsole("ERROR: Could not find Timeline Scroll Area.")
		return "Stop"
	end

	--------------------------------------------------------------------------------
	-- Check mouse is in timeline area:
	--------------------------------------------------------------------------------
	local mouseLocation = mouse.getAbsolutePosition()
	local timelinePosition = timelineScrollArea:attributeValue("AXPosition")
	local timelineSize = timelineScrollArea:attributeValue("AXSize")
	local isMouseInTimelineArea = true
	if (mouseLocation['y'] <= timelinePosition['y']) then isMouseInTimelineArea = false end 							-- Too High
	if (mouseLocation['y'] >= (timelinePosition['y']+timelineSize['h'])) then isMouseInTimelineArea = false end 		-- Too Low
	if (mouseLocation['x'] <= timelinePosition['x']) then isMouseInTimelineArea = false end 							-- Too Left
	if (mouseLocation['x'] >= (timelinePosition['x']+timelineSize['w'])) then isMouseInTimelineArea = false end 		-- Too Right
	if isMouseInTimelineArea then

		--------------------------------------------------------------------------------
		-- Mouse is in the timeline area when spacebar pressed so LET'S DO IT!
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Debug Mode:
			--------------------------------------------------------------------------------
			debugMessage("Mouse inside Timeline Area.")

			--------------------------------------------------------------------------------
			-- Which Value Indicator:
			--------------------------------------------------------------------------------
			local whichValueIndicator = nil
			for i=1, timelineScrollArea[1]:attributeValueCount("AXChildren") do
				if timelineScrollArea[1]:attributeValue("AXChildren")[i]:attributeValue("AXDescription") == "Playhead" then
					whichValueIndicator = i
					goto performScrollingTimelineValueIndicatorExit
				end
			end
			if whichValueIndicator == nil then
				dialog.displayErrorMessage("Unable to locate Value Indicator.")
				return "Failed"
			end
			::performScrollingTimelineValueIndicatorExit::

			local initialPlayheadXPosition = timelineScrollArea[1][whichValueIndicator]:attributeValue("AXPosition")['x']

			performScrollingTimelineLoops(timelineScrollArea, whichValueIndicator, initialPlayheadXPosition)
	else

		--------------------------------------------------------------------------------
		-- Debug Mode:
		--------------------------------------------------------------------------------
		debugMessage("Mouse outside of Timeline Area.")

	end
end

--------------------------------------------------------------------------------
-- HIGHLIGHT MOUSE IN FCPX:
--------------------------------------------------------------------------------
function mouseHighlight(mouseHighlightX, mouseHighlightY, mouseHighlightW, mouseHighlightH)

	--------------------------------------------------------------------------------
	-- Delete Previous Highlights:
	--------------------------------------------------------------------------------
	deleteAllHighlights()

	--------------------------------------------------------------------------------
	-- Get Sizing Preferences:
	--------------------------------------------------------------------------------
	local displayHighlightShape = nil
	displayHighlightShape = settings.get("fcpxHacks.displayHighlightShape")
	if displayHighlightShape == nil then displayHighlightShape = "Rectangle" end

	--------------------------------------------------------------------------------
	-- Get Highlight Colour Preferences:
	--------------------------------------------------------------------------------
	local displayHighlightColour = nil
	displayHighlightColour = settings.get("fcpxHacks.displayHighlightColour")
	if displayHighlightColour == nil then 		displayHighlightColour = "Red" 												end
	if displayHighlightColour == "Red" then 	displayHighlightColour = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1} 	end
	if displayHighlightColour == "Blue" then 	displayHighlightColour = {["red"]=0,["blue"]=1,["green"]=0,["alpha"]=1}		end
	if displayHighlightColour == "Green" then 	displayHighlightColour = {["red"]=0,["blue"]=0,["green"]=1,["alpha"]=1}		end
	if displayHighlightColour == "Yellow" then 	displayHighlightColour = {["red"]=1,["blue"]=0,["green"]=1,["alpha"]=1}		end

	--------------------------------------------------------------------------------
    -- Highlight the FCPX Browser Playhead:
    --------------------------------------------------------------------------------
   	if displayHighlightShape == "Rectangle" then
		mod.browserHighlight = drawing.rectangle(geometry.rect(mouseHighlightX, mouseHighlightY, mouseHighlightW, mouseHighlightH - 12))
		mod.browserHighlight:setStrokeColor(displayHighlightColour)
		mod.browserHighlight:setFill(false)
		mod.browserHighlight:setStrokeWidth(5)
		mod.browserHighlight:show()
	end
	if displayHighlightShape == "Circle" then
		mod.browserHighlight = drawing.circle(geometry.rect((mouseHighlightX-(mouseHighlightH/2)+10), mouseHighlightY, mouseHighlightH-12, mouseHighlightH-12))
		mod.browserHighlight:setStrokeColor(displayHighlightColour)
		mod.browserHighlight:setFill(false)
		mod.browserHighlight:setStrokeWidth(5)
		mod.browserHighlight:show()
	end
	if displayHighlightShape == "Diamond" then
		mod.browserHighlight = drawing.circle(geometry.rect(mouseHighlightX, mouseHighlightY, mouseHighlightW, mouseHighlightH - 12))
		mod.browserHighlight:setStrokeColor(displayHighlightColour)
		mod.browserHighlight:setFill(false)
		mod.browserHighlight:setStrokeWidth(5)
		mod.browserHighlight:show()
	end

	--------------------------------------------------------------------------------
    -- Set a timer to delete the circle after 3 seconds:
    --------------------------------------------------------------------------------
    mod.browserHighlightTimer = timer.doAfter(3, function() mod.browserHighlight:delete() end)

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                     C O M M O N    F U N C T I O N S                       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GENERAL:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- PROWL API KEY VALID:
	--------------------------------------------------------------------------------
	function prowlAPIKeyValid(input)

		local result = false
		local errorMessage = nil

		prowlAction = "https://api.prowlapp.com/publicapi/verify?apikey=" .. input
		httpResponse, httpBody, httpHeader = http.get(prowlAction, nil)

		if string.match(httpBody, "success") then
			result = true
		else
			local xml = slaxdom:dom(tostring(httpBody))
			errorMessage = xml['root']['el'][1]['kids'][1]['value']
		end

		return result, errorMessage

	end

	--------------------------------------------------------------------------------
	-- DELETE ALL HIGHLIGHTS:
	--------------------------------------------------------------------------------
	function deleteAllHighlights()
		--------------------------------------------------------------------------------
		-- Delete FCPX Browser Highlight:
		--------------------------------------------------------------------------------
		if mod.browserHighlight then
			mod.browserHighlight:delete()
			if mod.browserHighlightTimer then
				mod.browserHighlightTimer:stop()
			end
		end
	end

	--------------------------------------------------------------------------------
	-- CHECK FOR FCPX HACKS UPDATES:
	--------------------------------------------------------------------------------
	function checkForUpdates()

		local enableCheckForUpdates = settings.get("fcpxHacks.enableCheckForUpdates")
		if enableCheckForUpdates then
			debugMessage("Checking for updates.")
			latestScriptVersion = nil
			updateResponse, updateBody, updateHeader = http.get("https://latenitefilms.com/downloads/fcpx-hammerspoon-version.html", nil)
			if updateResponse == 200 then
				if updateBody:sub(1,8) == "LATEST: " then
					--------------------------------------------------------------------------------
					-- Update Script Version:
					--------------------------------------------------------------------------------
					latestScriptVersion = updateBody:sub(9)

					--------------------------------------------------------------------------------
					-- macOS Notification:
					--------------------------------------------------------------------------------
					if not mod.shownUpdateNotification then
						if latestScriptVersion > fcpxhacks.scriptVersion then
							updateNotification = notify.new(function() getScriptUpdate() end):setIdImage(image.imageFromPath("~/.hammerspoon/hs/fcpxhacks/assets/fcpxhacks.icns"))
																:title("FCPX Hacks Update Available")
																:subTitle("Version " .. latestScriptVersion)
																:informativeText("Do you wish to install?")
																:hasActionButton(true)
																:actionButtonTitle("Install")
																:otherButtonTitle("Not Yet")
																:send()
							mod.shownUpdateNotification = true
						end
					end

					--------------------------------------------------------------------------------
					-- Refresh Menubar:
					--------------------------------------------------------------------------------
					refreshMenuBar()
				end
			end
		end

	end

--------------------------------------------------------------------------------
-- TOUCH BAR RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- SHOW TOUCH BAR:
	--------------------------------------------------------------------------------
	function showTouchbar()
		--------------------------------------------------------------------------------
		-- Check if we need to show the Touch Bar:
		--------------------------------------------------------------------------------
		if touchBarSupported then
			local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false
			if displayTouchBar then mod.touchBarWindow:show() end
		end
	end

	--------------------------------------------------------------------------------
	-- HIDE TOUCH BAR:
	--------------------------------------------------------------------------------
	function hideTouchbar()
		--------------------------------------------------------------------------------
		-- Hide the Touch Bar:
		--------------------------------------------------------------------------------
		if touchBarSupported then mod.touchBarWindow:hide() end
	end

	--------------------------------------------------------------------------------
	-- SET TOUCH BAR LOCATION:
	--------------------------------------------------------------------------------
	function setTouchBarLocation()

		--------------------------------------------------------------------------------
		-- Get Settings:
		--------------------------------------------------------------------------------
		local displayTouchBarLocation = settings.get("fcpxHacks.displayTouchBarLocation") or "Mouse"

		--------------------------------------------------------------------------------
		-- Show Touch Bar at Mouse Pointer Position:
		--------------------------------------------------------------------------------
		if displayTouchBarLocation == "Mouse" then

			--------------------------------------------------------------------------------
			-- Position Touch Bar to Mouse Pointer Location:
			--------------------------------------------------------------------------------
			mod.touchBarWindow:atMousePosition()

		end

		--------------------------------------------------------------------------------
		-- Show Touch Bar at Top Centre of Timeline:
		--------------------------------------------------------------------------------
		if displayTouchBarLocation == "TimelineTopCentre" then

			--------------------------------------------------------------------------------
			-- Position Touch Bar to Top Centre of Final Cut Pro Timeline:
			--------------------------------------------------------------------------------
			local timelineScrollArea = fcp.getTimelineScrollArea()
			local timelineScrollAreaPosition = {}
			timelineScrollAreaPosition['x'] = timelineScrollArea:attributeValue("AXPosition")['x'] + (timelineScrollArea:attributeValue("AXSize")['w'] / 2) - (mod.touchBarWindow:getFrame()['w'] / 2)
			timelineScrollAreaPosition['y'] = timelineScrollArea:attributeValue("AXPosition")['y'] + 20
			mod.touchBarWindow:topLeft(timelineScrollAreaPosition)

		end

		--------------------------------------------------------------------------------
		-- Save last Touch Bar Location to Settings:
		--------------------------------------------------------------------------------
		settings.set("fcpxHacks.lastTouchBarLocation", mod.touchBarWindow:topLeft())

	end

--------------------------------------------------------------------------------
-- SHORTCUT RELATED:
--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- PERFORM KEYSTROKE FROM PLIST DATA:
	--------------------------------------------------------------------------------
	function keyStrokeFromPlist(whichShortcut)
		if mod.finalCutProShortcutKey[whichShortcut]['modifiers'] == nil then return false end
		if mod.finalCutProShortcutKey[whichShortcut]['characterString'] == nil then return false end
		if next(mod.finalCutProShortcutKey[whichShortcut]['modifiers']) == nil and mod.finalCutProShortcutKey[whichShortcut]['characterString'] == "" then return false end
		eventtap.keyStroke(convertModifiersKeysForEventTap(mod.finalCutProShortcutKey[whichShortcut]['modifiers']), 	keycodes.map[mod.finalCutProShortcutKey[whichShortcut]['characterString']])
		return true
	end

	--------------------------------------------------------------------------------
	-- MODIFIER MATCH:
	--------------------------------------------------------------------------------
	function modifierMatch(inputA, inputB)

		local match = true

		if fnutils.contains(inputA, "ctrl") and not fnutils.contains(inputB, "ctrl") then match = false end
		if fnutils.contains(inputA, "alt") and not fnutils.contains(inputB, "alt") then match = false end
		if fnutils.contains(inputA, "cmd") and not fnutils.contains(inputB, "cmd") then match = false end
		if fnutils.contains(inputA, "shift") and not fnutils.contains(inputB, "shift") then match = false end

		return match

	end

	--------------------------------------------------------------------------------
	-- CONVERTS MODIFIERS KEYS INTO SOMETHING EVENTTAP CAN UNDERSTAND:
	--------------------------------------------------------------------------------
	function convertModifiersKeysForEventTap(input)

		for i in pairs(input) do
			if input[i] == "control" 	then input[i] = "ctrl" end
			if input[i] == "option" 	then input[i] = "alt" end
			if input[i] == "command" 	then input[i] = "cmd" end
			if input[i] == "⌃" 			then input[i] = "ctrl" end
			if input[i] == "⌥" 			then input[i] = "alt" end
			if input[i] == "⌘" 			then input[i] = "cmd" end
			if input[i] == "⇧" 			then input[i] = "shift" end
		end

		return input

	end

	--------------------------------------------------------------------------------
	-- KEYCODE TRANSLATOR:
	--------------------------------------------------------------------------------
	function keyCodeTranslator(input)

		local englishKeyCodes = {
			["'"] = 39,
			[","] = 43,
			["-"] = 27,
			["."] = 47,
			["/"] = 44,
			["0"] = 29,
			["1"] = 18,
			["2"] = 19,
			["3"] = 20,
			["4"] = 21,
			["5"] = 23,
			["6"] = 22,
			["7"] = 26,
			["8"] = 28,
			["9"] = 25,
			[";"] = 41,
			["="] = 24,
			["["] = 33,
			["\\"] = 42,
			["]"] = 30,
			["`"] = 50,
			["a"] = 0,
			["b"] = 11,
			["c"] = 8,
			["d"] = 2,
			["delete"] = 51,
			["down"] = 125,
			["e"] = 14,
			["end"] = 119,
			["escape"] = 53,
			["f"] = 3,
			["f1"] = 122,
			["f10"] = 109,
			["f11"] = 103,
			["f12"] = 111,
			["f13"] = 105,
			["f14"] = 107,
			["f15"] = 113,
			["f16"] = 106,
			["f17"] = 64,
			["f18"] = 79,
			["f19"] = 80,
			["f2"] = 120,
			["f20"] = 90,
			["f3"] = 99,
			["f4"] = 118,
			["f5"] = 96,
			["f6"] = 97,
			["f7"] = 98,
			["f8"] = 100,
			["f9"] = 101,
			["forwarddelete"] = 117,
			["g"] = 5,
			["h"] = 4,
			["help"] = 114,
			["home"] = 115,
			["i"] = 34,
			["j"] = 38,
			["k"] = 40,
			["l"] = 37,
			["left"] = 123,
			["m"] = 46,
			["n"] = 45,
			["o"] = 31,
			["p"] = 35,
			["pad*"] = 67,
			["pad+"] = 69,
			["pad-"] = 78,
			["pad."] = 65,
			["pad/"] = 75,
			["pad0"] = 82,
			["pad1"] = 83,
			["pad2"] = 84,
			["pad3"] = 85,
			["pad4"] = 86,
			["pad5"] = 87,
			["pad6"] = 88,
			["pad7"] = 89,
			["pad8"] = 91,
			["pad9"] = 92,
			["pad="] = 81,
			["padclear"] = 71,
			["padenter"] = 76,
			["pagedown"] = 121,
			["pageup"] = 116,
			["q"] = 12,
			["r"] = 15,
			["return"] = 36,
			["right"] = 124,
			["s"] = 1,
			["space"] = 49,
			["t"] = 17,
			["tab"] = 48,
			["u"] = 32,
			["up"] = 126,
			["v"] = 9,
			["w"] = 13,
			["x"] = 7,
			["y"] = 16,
			["z"] = 6,
			["§"] = 10
		}

		if englishKeyCodes[input] == nil then
			if keycodes.map[input] == nil then
				return ""
			else
				return keycodes.map[input]
			end
		else
			return englishKeyCodes[input]
		end

	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                             W A T C H E R S                                --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AUTOMATICALLY DO THINGS WHEN FINAL CUT PRO IS RESIZED:
--------------------------------------------------------------------------------
function finalCutProResizeWatcher()
	finalCutProWindowFilter = window.filter.new{"Final Cut Pro"}
	finalCutProWindowFilter:subscribe(window.filter.windowMoved, function()
		debugMessage("Window Resized.")
		if touchBarSupported then
			local displayTouchBar = settings.get("fcpxHacks.displayTouchBar") or false
			if displayTouchBar then setTouchBarLocation() end
		end
	end)
end

--------------------------------------------------------------------------------
-- AUTOMATICALLY DO THINGS WHEN FINAL CUT PRO IS ACTIVATED OR DEACTIVATED:
--------------------------------------------------------------------------------
function finalCutProWatcher(appName, eventType, appObject)

	if (appName == "Final Cut Pro") then
		if (eventType == application.watcher.activated) then
			--------------------------------------------------------------------------------
	  		-- Final Cut Pro Activated:
	  		--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Enable Hotkeys:
				--------------------------------------------------------------------------------
				hotkeys:enter()

				--------------------------------------------------------------------------------
				-- Enable Menubar Items:
				--------------------------------------------------------------------------------
				refreshMenuBar()

				--------------------------------------------------------------------------------
				-- Full Screen Keyboard Watcher:
				--------------------------------------------------------------------------------
				if settings.get("fcpxHacks.enableShortcutsDuringFullscreenPlayback") == true then
					fullscreenKeyboardWatcherUp:start()
					fullscreenKeyboardWatcherDown:start()
				end

				--------------------------------------------------------------------------------
				-- Disable Scrolling Timeline Watcher:
				--------------------------------------------------------------------------------
				if settings.get("fcpxHacks.scrollingTimelineActive") == true then
					if scrollingTimelineWatcherUp ~= nil then
						scrollingTimelineWatcherUp:start()
						scrollingTimelineWatcherDown:start()
					end
				end

				--------------------------------------------------------------------------------
				-- Check if we need to show the Touch Bar:
				--------------------------------------------------------------------------------
				showTouchbar()

		elseif (eventType == application.watcher.deactivated) or (eventType == application.watcher.terminated) then
			--------------------------------------------------------------------------------
			-- Final Cut Pro Lost Focus:
			--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Full Screen Keyboard Watcher:
				--------------------------------------------------------------------------------
				if settings.get("fcpxHacks.enableShortcutsDuringFullscreenPlayback") == true then
					fullscreenKeyboardWatcherUp:stop()
					fullscreenKeyboardWatcherDown:stop()
				end

				--------------------------------------------------------------------------------
				-- Disable Scrolling Timeline Watcher:
				--------------------------------------------------------------------------------
				if settings.get("fcpxHacks.scrollingTimelineActive") == true then
					if scrollingTimelineWatcherUp ~= nil then
						scrollingTimelineWatcherUp:stop()
						scrollingTimelineWatcherDown:stop()
					end
				end

				--------------------------------------------------------------------------------
				-- Check if we need to hide the Touch Bar:
				--------------------------------------------------------------------------------
				hideTouchbar()

				--------------------------------------------------------------------------------
				-- Disable hotkeys:
				--------------------------------------------------------------------------------
				hotkeys:exit()

				--------------------------------------------------------------------------------
				-- Disable Menubar Items:
				--------------------------------------------------------------------------------
				refreshMenuBar()

				--------------------------------------------------------------------------------
				-- Delete the Mouse Circle:
				--------------------------------------------------------------------------------
				deleteAllHighlights()

		end
	end
end

--------------------------------------------------------------------------------
-- AUTOMATICALLY RELOAD THIS CONFIG FILE WHEN UPDATED:
--------------------------------------------------------------------------------
function hammerspoonConfigWatcher(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

--------------------------------------------------------------------------------
-- AUTOMATICALLY DO THINGS WHEN FCPX PLIST IS UPDATED:
--------------------------------------------------------------------------------
function finalCutProSettingsWatcher(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-24) == "com.apple.FinalCut.plist" then
            doReload = true
        end
    end
    if doReload then

		--------------------------------------------------------------------------------
		-- Refresh Keyboard Shortcuts if Command Set Changed & Command Editor Closed:
		--------------------------------------------------------------------------------
    	if mod.lastCommandSet ~= fcp.getActiveCommandSetPath() then
    		if not mod.isCommandEditorOpen then
	    		timer.doAfter(0.0000000000001, function() bindKeyboardShortcuts() end)
			end
		end

    	--------------------------------------------------------------------------------
    	-- Refresh Menubar:
    	--------------------------------------------------------------------------------
    	refreshMenuBar(true)

    	--------------------------------------------------------------------------------
    	-- Update Menubar Icon:
    	--------------------------------------------------------------------------------
    	updateMenubarIcon()

    end
end

--------------------------------------------------------------------------------
-- DISABLE SHORTCUTS WHEN FCPX COMMAND EDITOR IS OPEN:
--------------------------------------------------------------------------------
function commandEditorWatcher()
	local commandEditorID = nil
	local filter = window.filter.new(true)
	filter:subscribe(
	  window.filter.windowCreated,
	  (function(window, applicationName)
		if applicationName == 'Final Cut Pro' then
			if (window:title() == 'Command Editor') then

				--------------------------------------------------------------------------------
				-- Command Editor is Open:
				--------------------------------------------------------------------------------
				commandEditorID = window:id()
				mod.isCommandEditorOpen = true
				debugMessage("Command Editor Opened.")
				--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Disable Hotkeys:
				--------------------------------------------------------------------------------
				if hotkeys ~= nil then -- For the rare case when Command Editor is open on load.
					hotkeys:exit()
				end
				--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Hide the Touch Bar:
				--------------------------------------------------------------------------------
				hideTouchbar()

			end
		end
	  end),
	  true
	)
	filter:subscribe(
	  window.filter.windowDestroyed,
	  (function(window, applicationName)
		if applicationName == 'Final Cut Pro' then
			if (window:id() == commandEditorID) then

				--------------------------------------------------------------------------------
				-- Command Editor is Closed:
				--------------------------------------------------------------------------------
				commandEditorID = nil
				mod.isCommandEditorOpen = false
				debugMessage("Command Editor Closed.")
				--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Check if we need to show the Touch Bar:
				--------------------------------------------------------------------------------
				showTouchbar()
				--------------------------------------------------------------------------------

				--------------------------------------------------------------------------------
				-- Refresh Keyboard Shortcuts:
				--------------------------------------------------------------------------------
				timer.doAfter(0.0000000000001, function() bindKeyboardShortcuts() end)
				--------------------------------------------------------------------------------

			end
		end
	  end),
	  true
	)

end

--------------------------------------------------------------------------------
-- ENABLE SHORTCUTS DURING FCPX FULLSCREEN PLAYBACK:
--------------------------------------------------------------------------------
function fullscreenKeyboardWatcher()
	fullscreenKeyboardWatcherWorking = false
	fullscreenKeyboardWatcherUp = eventtap.new({ eventtap.event.types.keyUp }, function(event)
		fullscreenKeyboardWatcherWorking = false
	end)
	fullscreenKeyboardWatcherDown = eventtap.new({ eventtap.event.types.keyDown }, function(event)

		--------------------------------------------------------------------------------
		-- Don't repeat if key is held down:
		--------------------------------------------------------------------------------
		if fullscreenKeyboardWatcherWorking then return false end
		fullscreenKeyboardWatcherWorking = true

		--------------------------------------------------------------------------------
		-- Define Final Cut Pro:
		--------------------------------------------------------------------------------
		local fcpx = fcp.application()
		local fcpxElements = ax.applicationElement(fcpx)

		--------------------------------------------------------------------------------
		-- Only Continue if in Full Screen Playback Mode:
		--------------------------------------------------------------------------------
		if fcpxElements[1][1] ~= nil then
			if fcpxElements[1][1]:attributeValue("AXDescription") == "Display Area" then

				--------------------------------------------------------------------------------
				-- Get keypress information:
				--------------------------------------------------------------------------------
				local whichKey = event:getKeyCode()			-- EXAMPLE: keyCodeTranslator(whichKey) == "c"
				local whichModifier = event:getFlags()		-- EXAMPLE: whichFlags['cmd']

				--------------------------------------------------------------------------------
				-- Check all of these shortcut keys for presses:
				--------------------------------------------------------------------------------
				local fullscreenKeys = {"SetSelectionStart", "SetSelectionEnd", "AnchorWithSelectedMedia", "AnchorWithSelectedMediaAudioBacktimed", "InsertMedia", "AppendWithSelectedMedia" }
				for x, whichShortcutKey in pairs(fullscreenKeys) do
					if mod.finalCutProShortcutKey[whichShortcutKey] ~= nil then
						if mod.finalCutProShortcutKey[whichShortcutKey]['characterString'] ~= nil then
							if mod.finalCutProShortcutKey[whichShortcutKey]['characterString'] ~= "" then
								if whichKey == mod.finalCutProShortcutKey[whichShortcutKey]['characterString'] and modifierMatch(whichModifier, mod.finalCutProShortcutKey[whichShortcutKey]['modifiers']) then
									eventtap.keyStroke({""}, "escape")
									eventtap.keyStroke(convertModifiersKeysForEventTap(mod.finalCutProShortcutKey["ToggleEventLibraryBrowser"]['modifiers']), keycodes.map[mod.finalCutProShortcutKey["ToggleEventLibraryBrowser"]['characterString']])
									eventtap.keyStroke(convertModifiersKeysForEventTap(mod.finalCutProShortcutKey[whichShortcutKey]['modifiers']), keycodes.map[mod.finalCutProShortcutKey[whichShortcutKey]['characterString']])
									eventtap.keyStroke(convertModifiersKeysForEventTap(mod.finalCutProShortcutKey["PlayFullscreen"]['modifiers']), keycodes.map[mod.finalCutProShortcutKey["PlayFullscreen"]['characterString']])
									return true
								end
							end
						end
					end
				end
			end
			--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Fullscreen with playback controls:
			--------------------------------------------------------------------------------
			if fcpxElements[1][1][1] ~= nil then
				if fcpxElements[1][1][1][1] ~= nil then
					if fcpxElements[1][1][1][1]:attributeValue("AXDescription") == "Play Pause" then

						--------------------------------------------------------------------------------
						-- Get keypress information:
						--------------------------------------------------------------------------------
						local whichKey = event:getKeyCode()			-- EXAMPLE: keyCodeTranslator(whichKey) == "c"
						local whichModifier = event:getFlags()		-- EXAMPLE: whichFlags['cmd']

						--------------------------------------------------------------------------------
						-- Check all of these shortcut keys for presses:
						--------------------------------------------------------------------------------
						local fullscreenKeys = {"SetSelectionStart", "SetSelectionEnd", "AnchorWithSelectedMedia", "AnchorWithSelectedMediaAudioBacktimed", "InsertMedia", "AppendWithSelectedMedia" }
						for x, whichShortcutKey in pairs(fullscreenKeys) do
							if mod.finalCutProShortcutKey[whichShortcutKey]['characterString'] ~= nil then
								if mod.finalCutProShortcutKey[whichShortcutKey]['characterString'] ~= "" then
									if whichKey == mod.finalCutProShortcutKey[whichShortcutKey]['characterString'] and modifierMatch(whichModifier, mod.finalCutProShortcutKey[whichShortcutKey]['modifiers']) then
										eventtap.keyStroke({""}, "escape")
										eventtap.keyStroke(convertModifiersKeysForEventTap(mod.finalCutProShortcutKey["ToggleEventLibraryBrowser"]['modifiers']), keycodes.map[mod.finalCutProShortcutKey["ToggleEventLibraryBrowser"]['characterString']])
										eventtap.keyStroke(convertModifiersKeysForEventTap(mod.finalCutProShortcutKey[whichShortcutKey]['modifiers']), keycodes.map[mod.finalCutProShortcutKey[whichShortcutKey]['characterString']])
										eventtap.keyStroke(convertModifiersKeysForEventTap(mod.finalCutProShortcutKey["PlayFullscreen"]['modifiers']), keycodes.map[mod.finalCutProShortcutKey["PlayFullscreen"]['characterString']])
										return true
									end
								end
							end
						end
					end
				end
			end
			--------------------------------------------------------------------------------

		end
	end)
end

--------------------------------------------------------------------------------
-- MEDIA IMPORT WINDOW WATCHER:
--------------------------------------------------------------------------------
function mediaImportWatcher()
	debugMessage("Watching for new media...")
	mod.newDeviceMounted = fs.volume.new(function(event, table)
		if event == fs.volume.didMount then

			debugMessage("Media Inserted.")

			local mediaImportCount = 0
			local stopMediaImportTimer = false
			local currentApplication = application.frontmostApplication()
			debugMessage("Currently using '"..currentApplication:name().."'")

			local fcpx = fcp.application()
			local fcpxHidden = true
			if fcpx ~= nil then fcpxHidden = fcpx:isHidden() end

			mediaImportTimer = timer.doUntil(
				function()
					return stopMediaImportTimer
				end,
				function()
					if not fcp.prunning() then
						debugMessage("FCPX is not running. Stop watching.")
						stopMediaImportTimer = true
					else
						local fcpx = fcp.application()
						local fcpxElements = ax.applicationElement(fcpx)
						if fcpxElements[1] ~= nil then
							if fcpxElements[1]:attributeValue("AXTitle") == "Media Import" then
								if mediaImportCount ~= 0 then
									--------------------------------------------------------------------------------
									-- Media Import Window was not open:
									--------------------------------------------------------------------------------
									fcpxElements[1][11]:performAction("AXPress")
									if fcpxHidden then fcpx:hide() end
									application.launchOrFocus(currentApplication:name())
									debugMessage("Hid FCPX and returned to '"..currentApplication:name().."'.")
								end
								stopMediaImportTimer = true
							end
						end
						mediaImportCount = mediaImportCount + 1
						if mediaImportCount == 500 then
							debugMessage("Gave up watching for the Media Import window after 5 seconds.")
							stopMediaImportTimer = true
						end
					end
				end,
				0.01
			)
		end
	end)
	mod.newDeviceMounted:start()

end

--------------------------------------------------------------------------------
-- FCPX SCROLLING TIMELINE WATCHER:
--------------------------------------------------------------------------------
function scrollingTimelineWatcher()

	--------------------------------------------------------------------------------
	-- Key Press Up Watcher:
	--------------------------------------------------------------------------------
	scrollingTimelineWatcherUp = eventtap.new({ eventtap.event.types.keyUp }, function(event)
		mod.scrollingTimelineWatcherWorking = false
	end)

	--------------------------------------------------------------------------------
	-- Key Press Down Watcher:
	--------------------------------------------------------------------------------
	scrollingTimelineWatcherDown = eventtap.new({ eventtap.event.types.keyDown }, function(event)

		--------------------------------------------------------------------------------
		-- Don't repeat if key is held down:
		--------------------------------------------------------------------------------
		if mod.scrollingTimelineWatcherWorking then
			return false
		else
			--------------------------------------------------------------------------------
			-- Prevent Key Being Held Down:
			--------------------------------------------------------------------------------
			mod.scrollingTimelineWatcherWorking = true

			--------------------------------------------------------------------------------
			-- Spacebar Pressed:
			--------------------------------------------------------------------------------
			if event:getKeyCode() == 49 and next(event:getFlags()) == nil then
				--------------------------------------------------------------------------------
				-- Make sure the Command Editor is closed:
				--------------------------------------------------------------------------------
				if not mod.isCommandEditorOpen and not mod.fcpxChooserActive then

					--------------------------------------------------------------------------------
					-- Toggle Scrolling Timeline Spacebar Pressed Variable:
					--------------------------------------------------------------------------------
					mod.scrollingTimelineSpacebarPressed = not mod.scrollingTimelineSpacebarPressed

					--------------------------------------------------------------------------------
					-- Either stop or start the Scrolling Timeline:
					--------------------------------------------------------------------------------
					if mod.scrollingTimelineSpacebarPressed then
						scrollingTimelineSpacebarCheck = true
						timer.waitUntil(function() return scrollingTimelineSpacebarCheck end, function() checkScrollingTimelinePress() end, 0.0000000000001)
					else
						if mod.scrollingTimelineTimer ~= nil then mod.scrollingTimelineTimer:stop() end
						if mod.scrollingTimelineScrollbarTimer ~= nil then mod.scrollingTimelineScrollbarTimer:stop() end
					end

				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- NOTIFICATION WATCHER:
--------------------------------------------------------------------------------
function notificationWatcher()

	--------------------------------------------------------------------------------
	-- USED FOR DEVELOPMENT:
	--------------------------------------------------------------------------------
	--foo = distributednotifications.new(function(name, object, userInfo) print(string.format("name: %s\nobject: %s\nuserInfo: %s\n", name, object, inspect(userInfo))) end)
	--foo:start()

	--------------------------------------------------------------------------------
	-- SHARE SUCCESSFUL NOTIFICATION WATCHER:
	--------------------------------------------------------------------------------
	-- NOTE: ProTranscoderDidCompleteNotification doesn't seem to trigger when exporting small clips.
	shareSuccessNotificationWatcher = distributednotifications.new(notificationWatcherAction, "uploadSuccess")
	shareSuccessNotificationWatcher:start()

	--------------------------------------------------------------------------------
	-- SHARE UNSUCCESSFUL NOTIFICATION WATCHER:
	--------------------------------------------------------------------------------
	shareFailedNotificationWatcher = distributednotifications.new(notificationWatcherAction, "ProTranscoderDidFailNotification")
	shareFailedNotificationWatcher:start()

end

	--------------------------------------------------------------------------------
	-- NOTIFICATION WATCHER ACTION:
	--------------------------------------------------------------------------------
	function notificationWatcherAction(name, object, userInfo)

		local prowlAPIKey = settings.get("fcpxHacks.prowlAPIKey") or nil
		if prowlAPIKey ~= nil then

			local prowlApplication = http.encodeForQuery("FINAL CUT PRO")
			local prowlEvent = http.encodeForQuery("")
			local prowlDescription = nil

			if name == "uploadSuccess" then prowlDescription = http.encodeForQuery("Share Successful") end
			if name == "ProTranscoderDidFailNotification" then prowlDescription = http.encodeForQuery("Share Failed") end

			local prowlAction = "https://api.prowlapp.com/publicapi/add?apikey=" .. prowlAPIKey .. "&application=" .. prowlApplication .. "&event=" .. prowlEvent .. "&description=" .. prowlDescription
			httpResponse, httpBody, httpHeader = http.get(prowlAction, nil)

			if not string.match(httpBody, "success") then
				local xml = slaxdom:dom(tostring(httpBody))
				local errorMessage = xml['root']['el'][1]['kids'][1]['value'] or nil
				if errorMessage ~= nil then writeToConsole("PROWL ERROR: " .. tools.trim(tostring(errorMessage))) end
			end
		end

	end

--------------------------------------------------------------------------------
-- SHARED CLIPBOARD WATCHER:
--------------------------------------------------------------------------------
function sharedClipboardFileWatcher(files)
	debugMessage("Refreshing Shared Clipboard.")
	refreshMenuBar()
end

--------------------------------------------------------------------------------
-- SHARED XML FILE WATCHER:
--------------------------------------------------------------------------------
function sharedXMLFileWatcher(files)
	debugMessage("Refreshing Shared XML Folder.")

	for _,file in pairs(files) do
        if file:sub(-7) == ".fcpxml" then
			local testFile = io.open(file, "r")
			if testFile ~= nil then
				testFile:close()
				if not string.find(file, "(" .. host.localizedName() ..")") then
					local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
					sharedXMLNotification = notify.new(sharedXMLNotificationAction):setIdImage(image.imageFromPath("~/.hammerspoon/hs/fcpxhacks/assets/fcpxhacks.icns"))
														   						   :title("New XML Recieved")
														   						   :subTitle(file:sub(string.len(xmlSharingPath) + 1, -8))
														   						   :informativeText("FCPX Hacks has recieved a new XML file.")
														   						   :hasActionButton(true)
														   						   :actionButtonTitle("Import XML")
														   						   :send()
				end
			end
        end
    end

	refreshMenuBar()
end

	--------------------------------------------------------------------------------
	-- SHARED XML FILE NOTIFICATION ACTION:
	--------------------------------------------------------------------------------
	function sharedXMLNotificationAction(value)
		importSharedXML(value:subTitle())
	end

--------------------------------------------------------------------------------
-- LOCAL XML DROPBOX WATCHER:
--------------------------------------------------------------------------------
function xmlDropboxFileWatcher(files)
    for _,file in pairs(files) do
        if string.match(file, '<?xml version="1.0" encoding') then

			--------------------------------------------------------------------------------
			-- Read XML Data:
			--------------------------------------------------------------------------------
			local plistFile = io.open(file, "r")
			if plistFile == nil then return end -- This happens when the file is deleted from the Watch Folder.

			--------------------------------------------------------------------------------
			-- Display Text Box:
			--------------------------------------------------------------------------------
			local textboxResult = dialog.displayTextBoxMessage("How would you like to label this XML file?", "The label you entered has special characters that cannot be used.\n\nPlease try again.", "")

			--------------------------------------------------------------------------------
			-- Read XML File Data:
			--------------------------------------------------------------------------------
			plistFileData = plistFile:read("*all")
			plistFile:close()

			--------------------------------------------------------------------------------
			-- Delete file in Drop Box:
			--------------------------------------------------------------------------------
			os.remove(file)

			if not textboxResult then
				return -- Cancelled
			else
				--------------------------------------------------------------------------------
				-- Get Settings:
				--------------------------------------------------------------------------------
				local xmlSharingPath = settings.get("fcpxHacks.xmlSharingPath")
				local xmlSharingDropboxPath = settings.get("fcpxHacks.xmlSharingDropboxPath")

				--------------------------------------------------------------------------------
				-- Get only the needed XML content:
				--------------------------------------------------------------------------------
				local startOfXML = string.find(plistFileData, "<?xml version=")
				local endOfXML = string.find(plistFileData, "</fcpxml>")

				--------------------------------------------------------------------------------
				-- Error Detection:
				--------------------------------------------------------------------------------
				if startOfXML == nil or endOfXML == nil then
					dialog.displayErrorMessage("Something went wrong when attempting to translate the XML data from the file in the Dropbox. Please try again.\n\nError occurred in xmlDropboxFileWatcher().")
					if plistFileData ~= nil then
						debugMessage("Start of plistFileData.")
						debugMessage(plistFileData)
						debugMessage("End of plistFileData.")
					else
						debugMessage("ERROR: plistFileData is nil.")
					end
					return "fail"
				end

				--------------------------------------------------------------------------------
				-- New XML:
				--------------------------------------------------------------------------------
				newXML = string.sub(plistFileData, startOfXML - 2, endOfXML + 8)

				--------------------------------------------------------------------------------
				-- Save the XML content to the Shared XML Folder:
				--------------------------------------------------------------------------------
				local file = io.open(xmlSharingPath .. textboxResult .. " (" .. host.localizedName() .. ").fcpxml", "w")
				currentClipboardData = file:write(newXML)
				file:close()
			end
        end
    end
end

--------------------------------------------------------------------------------
-- TOUCH BAR WATCHER:
--------------------------------------------------------------------------------
function touchbarWatcher(obj, message)

	if message == "didEnter" then
        mod.mouseInsideTouchbar = true
    elseif message == "didExit" then
        mod.mouseInsideTouchbar = false

        --------------------------------------------------------------------------------
	    -- Just in case we got here before the eventtap returned the Touch Bar to normal:
	    --------------------------------------------------------------------------------
        mod.touchBarWindow:movable(false)
        mod.touchBarWindow:acceptsMouseEvents(true)
		settings.set("fcpxHacks.lastTouchBarLocation", mod.touchBarWindow:topLeft())

    end

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                L E T ' S     D O     T H I S     T H I N G !               --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

loadScript()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------