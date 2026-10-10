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

local HYPER = {"cmd", "alt", "ctrl"}

local bindings = {
  Left  = window.leftCycle,  -- left half, then left third
  Right = window.rightCycle, -- right half, then right third
  Up    = window.nextScreen,
  Down  = window.previousScreen,
  F     = window.maximize,
  ["="] = window.grow,
  ["-"] = window.shrink,
  A     = window.moveLeft,
  D     = window.moveRight,
}

for key, handler in pairs(bindings) do
  hs.hotkey.bind(HYPER, key, handler)
end
