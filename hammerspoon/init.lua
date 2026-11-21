-- Message port for the `hs` command line tool. Without this the CLI has
-- nothing to connect to, so leave it loaded if you use `hs -c`.
require("hs.ipc")

local window = require("window")

-- Do Not Disturb while a camera is in use. Needs the "DND On" / "DND Off"
-- shortcuts; logs and stays off if they are missing.
require("dnd").start()

-- Smooth scrolling on F13 / F14 (fn+PageUp / fn+PageDown via firmware).
require("scroll").start()

-- Bring the terminal forward, launching it first if it isn't running. Bundle
-- ID rather than name so a renamed .app or a lookalike can't be picked up.
-- Deliberately not on HYPER: that layer is for window management.
hs.hotkey.bind({"ctrl", "alt"}, "T", function()
  hs.application.launchOrFocusByBundleID("com.github.wez.wezterm")
end)

-- Global, not local: an eventtap that nothing references gets garbage
-- collected, which silently stops it.
ctrlS = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()
    local app = hs.application.frontmostApplication()

    if keyCode == hs.keycodes.map["s"]
        and flags.ctrl
        and app
        and app:bundleID() == "com.github.wez.wezterm" then

        hs.eventtap.keyStroke({"ctrl"}, "s", 0, app)
        return true
    end

    return false
end)

ctrlS:start()

local HYPER = {"cmd", "alt", "ctrl"}

local bindings = {
  Left  = window.leftCycle,  -- left half, then third, then two-thirds
  Right = window.rightCycle, -- right half, then third, then two-thirds
  Up    = window.nextScreen,
  Down  = window.previousScreen,
  Return = window.maximize,
  Z     = window.undo,
  H     = window.focusLeft,
  J     = window.focusDown,
  K     = window.focusUp,
  L     = window.focusRight,
  ["="] = window.grow,
  ["-"] = window.shrink,
  A     = window.moveLeft,
  D     = window.moveRight,
  C     = window.center,
  F     = window.toggleFullScreen, -- app's own full screen, else macOS's
}

for key, handler in pairs(bindings) do
  hs.hotkey.bind(HYPER, key, handler)
end
