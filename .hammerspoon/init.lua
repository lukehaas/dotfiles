-- Message port for the `hs` command line tool. Without this the CLI has
-- nothing to connect to, so leave it loaded if you use `hs -c`.
require("hs.ipc")

-- Reload when a config file is saved. Deliberately not a bare one-liner:
-- the watcher sees everything under ~/.hammerspoon (tests/, Spoons/,
-- .DS_Store), and a spurious reload drops module state -- dnd.lua would
-- forget it had turned Focus on and could leave Do Not Disturb stuck. Global
-- so the watcher isn't garbage collected once this file finishes running.
configWatcher = hs.pathwatcher.new(hs.configdir, function(paths)
  for _, path in ipairs(paths) do
    if path:match("%.lua$") and not path:match("/tests/") then
      return hs.reload()
    end
  end
end):start()

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
