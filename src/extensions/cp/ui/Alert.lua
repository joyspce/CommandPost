--- === cp.ui.Alert ===
---
--- Alert UI Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
local log                           = require("hs.logger").new("alert")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local axutils                       = require("cp.ui.axutils")
local Button                        = require("cp.ui.Button")
local prop                          = require("cp.prop")

local If                            = require("cp.rx.go.If")
local WaitUntil                     = require("cp.rx.go.WaitUntil")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local Alert = {}

--- cp.ui.Alert.matches(element) -> boolean
--- Function
--- Checks to see if an element matches what we think it should be.
---
--- Parameters:
---  * element - An `axuielementObject` to check.
---
--- Returns:
---  * `true` if matches otherwise `false`
function Alert.matches(element)
    if element then
        return element:attributeValue("AXRole") == "AXSheet"
    end
    return false
end

--- cp.ui.Alert.new(app) -> Alert
--- Constructor
--- Creates a new `Alert` instance.
---
--- Parameters:
---  * parent - The parent object.
---
--- Returns:
---  * A new `Browser` object.
function Alert.new(parent)
    local UI = parent.UI:mutate(function(original)
        return axutils.childMatching(original(), Alert.matches)
    end)

    local o = prop.extend({
        _parent = parent,

--- cp.ui.Alert.UI <cp.prop: hs._asm.axuielement; read-only; live?>
--- Field
--- The `axuielement` for the Alert, or `nil` if not available.
        UI = UI,


--- cp.ui.Alert.isShowing <cp.prop: boolean; read-only; live>
--- Field
--- Is the alert showing?
        isShowing = UI:ISNOT(nil),

--- cp.ui.Alert.title <cp.prop: string>
--- Field
--- Gets the title of the alert.
        title = UI:mutate(function(original)
            local ui = original()
            return ui and ui:attributeValue("AXTitle")
        end),

    }, Alert)

--- cp.ui.Alert.default <cp.ui.Button>
--- Field
--- The default [Button](cp.ui.Button.md) for the `Alert`.
    o.default = Button.new(o, UI:mutate(function(original)
        local ui = original()
        return ui and ui:attributeValue("AXDefaultButton")
    end))

--- cp.ui.Alert.cancel <cp.ui.Button>
--- Field
--- The cancel [Button](cp.ui.Button.md) for the `Alert`.
    o.cancel = Button.new(o, UI:mutate(function(original)
        local ui = original()
        return ui and ui:attributeValue("AXDefaultButton")
    end))

    return o
end

--- cp.ui.Alert:parent() -> parent
--- Method
--- Returns the parent object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * parent
function Alert:parent()
    return self._parent
end

--- cp.ui.Alert:app() -> App
--- Method
--- Returns the app instance.
---
--- Parameters:
---  * None
---
--- Returns:
---  * App
function Alert:app()
    return self:parent():app()
end

--- cp.ui.Alert:hide() -> none
--- Method
--- Hides the alert by pressing the "Cancel" button.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Alert:hide()
    self:pressCancel()
end

--- cp.ui.Alert:doHide() -> cp.rx.go.Statement <boolean>
--- Method
--- Attempts to hide the Alert (if visible) by pressing the [Cancel](#cancel) button.
---
--- Parameters:
--- * None
---
--- Returns:
--- * A [Statement](cp.rx.go.Statement.md) to execute, resolving to `true` if the button was present and clicked, otherwise `false`.
function Alert:doHide()
    return If(self.isShowing):Then(
        self:doCancel()
    ):Then(WaitUntil(self.isShowing():NOT()))
    :Otherwise(true)
    :TimeoutAfter(10000)
    :Label("Alert:doHide")
end

--- cp.ui.Alert:doCancel() -> cp.rx.go.Statement <boolean>
--- Method
--- Attempts to hide the Alert (if visible) by pressing the [Cancel](#cancel) button.
---
--- Parameters:
--- * None
---
--- Returns:
--- * A [Statement](cp.rx.go.Statement.md) to execute, resolving to `true` if the button was present and clicked, otherwise `false`.
function Alert:doCancel()
    return self.cancel:doPress()
end

--- cp.ui.Alert:doDefault() -> cp.rx.go.Statement <boolean>
--- Method
--- Attempts to press the `default` [Button](cp.ui.Button.md).
---
--- Parameters:
--- * None
---
--- Returns:
--- * A [Statement](cp.rx.go.Statement.md) to execute, resolving to `true` if the button was present and clicked, otherwise `false`.
function Alert:doDefault()
    return self.default:doPress()
end

--- cp.ui.Alert:doPress(buttonFromLeft) -> cp.rx.go.Statement <boolean>
--- Method
--- Attempts to press the indicated button from left-to-right, if it can be found.
---
--- Parameters:
--- * buttonFromLeft    - The number of the button from left-to-right.
---
--- Returns:
--- * a [Statement](cp.rx.go.Statement.md) to execute, resolving in `true` if the button was found and pressed, otherwise `false`.
function Alert:doPress(buttonFromLeft)
    return If(self.UI):Then(function(ui)
        local button = axutils.childFromLeft(ui, 1, Button.matches)
        if button then
            button:doPress()
        end
    end)
    :Otherwise(false)
    :ThenYield()
    :Label("Alert:doPress("..tostring(buttonFromLeft)..")")
end

--- cp.ui.Alert:pressCancel() -> self, boolean
--- Method
--- Presses the Cancel button.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `Alert` object.
---  * `true` if successful, otherwise `false`.
function Alert:pressCancel()
    local _, success = self:cancel():press()
    return self, success
end

--- cp.ui.Alert:pressDefault() -> self, boolean
--- Method
--- Presses the Default button.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `Alert` object.
---  * `true` if successful, otherwise `false`.
function Alert:pressDefault()
    local _, success = self:default():press()
    return self, success
end

--- cp.ui.Alert:containsText(value[, plain]) -> boolean
--- Method
--- Checks if there are any child text elements containing the exact text or pattern, from beginning to end.
---
--- Parameters:
---  * textPattern   - The text pattern to check.
---  * plain         - If `true`, the text will be compared exactly, otherwise it will be considered to be a pattern. Defaults to `false`.
---
--- Returns:
---  * `true` if an element's `AXValue` matches the text pattern exactly.
function Alert:containsText(value, plain)
    local textUI = axutils.childMatching(self:UI(), function(element)
        local eValue = element:attributeValue("AXValue")
        if type(eValue) == "string" then
            if plain then
                return eValue == value
            else
                local s,e = eValue:find(value)
                log.df("Found: start: %s, end: %s, len: %s", s, e, eValue:len())
                return s == 1 and e == eValue:len()
            end
        end
        return false
    end)
    return textUI ~= nil
end

return Alert
