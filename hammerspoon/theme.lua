-- Switch the terminal theme to match the screen WezTerm is on: E-Ink colours
-- on the Bigme B13, Catppuccin Mocha everywhere else.
--
-- The theme is global (one state file, one tmux server), so the focused
-- WezTerm window decides. Moving it to the other screen, or focusing a
-- WezTerm window that is already there, switches theme.
--
-- The switch itself is ~/.config/bin/theme, shared with the shell.

local M = {}

-- The name macOS reports for the B13. A placeholder until it's confirmed:
-- with the B13 connected, list the real names with
--   hs -c 'for _, s in ipairs(hs.screen.allScreens()) do print(s:name()) end'
local EINK_SCREEN = "B13"

local HOME = os.getenv("HOME")
local THEME_CMD = HOME .. "/.config/bin/theme"
local STATE_FILE = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/theme"

local log = hs.logger.new("theme", "info")

-- Kept referenced: a filter or watcher that nothing references gets garbage
-- collected, which silently stops it.
local filter
local screenWatcher

function M.themeFor(screenName)
  return screenName == EINK_SCREEN and "eink" or "dark"
end

-- Read rather than cached, so a theme set by hand from the shell is seen.
local function currentTheme()
  local f = io.open(STATE_FILE, "r")
  if not f then return "dark" end
  local theme = f:read("l") or "dark"
  f:close()
  return theme
end

local function isWezTerm(win)
  local app = win and win:application()
  return app ~= nil and app:bundleID() == "com.github.wez.wezterm"
end

local function update()
  local win = hs.window.focusedWindow()
  if not isWezTerm(win) then return end
  local screen = win:screen()
  if not screen then return end

  local wanted = M.themeFor(screen:name())
  if wanted == currentTheme() then return end

  log.i("WezTerm on " .. screen:name() .. " - switching to " .. wanted)
  hs.task.new(THEME_CMD, function(code, _, stderr)
    if code ~= 0 then log.e("theme " .. wanted .. " failed: " .. stderr) end
  end, {wanted}):start()
end

function M.start()
  -- windowMoved also fires for unfocused windows, e.g. when macOS gathers
  -- them off a disconnected screen. update() only looks at the focused one.
  filter = hs.window.filter.new("WezTerm")
  filter:subscribe({
    hs.window.filter.windowFocused,
    hs.window.filter.windowMoved,
  }, update)

  -- A screen being connected or removed can move the focused window without
  -- the filter noticing.
  screenWatcher = hs.screen.watcher.new(update)
  screenWatcher:start()

  update()
end

return M
