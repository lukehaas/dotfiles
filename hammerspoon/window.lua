-- Window geometry handlers. Keybindings live in init.lua.
--
-- Every frame here is in screen-relative coordinates: a screen's frame has a
-- non-zero origin on anything but the primary display, so edges are
-- max.x / max.x + max.w, never 0 / max.w.

local M = {}

-- Window frames get rounded by the window server, and some apps snap to their
-- own increments, so geometry comparisons need slack.
local TOLERANCE = 4

-- Refuse to shrink a window into uselessness.
local MIN_SIZE = 100

-- How close an edge must be to the screen edge to count as touching it.
local EDGE_TOLERANCE = 2

-- How many frames undo remembers per window.
local HISTORY_DEPTH = 20

local function approx(a, b)
  return math.abs(a - b) <= TOLERANCE
end

local function sameFrame(a, b)
  return approx(a.x, b.x) and approx(a.y, b.y)
     and approx(a.w, b.w) and approx(a.h, b.h)
end

-- Frames each window had before a handler changed them, keyed by window id,
-- most recent last. Entries for closed windows are never pruned: macOS doesn't
-- reuse window ids within a session, and HISTORY_DEPTH bounds each stack, so
-- the cost is a few small tables per window ever touched.
local history = {}

local function remember(win, frame)
  local id = win:id()
  if not id then return end

  local stack = history[id] or {}
  stack[#stack + 1] = frame
  if #stack > HISTORY_DEPTH then table.remove(stack, 1) end
  history[id] = stack
end

-- Wraps the focused-window boilerplate every handler shared: fetch the window,
-- hand its frame and its screen's usable frame to fn, write the frame back.
-- Returns a function suitable for passing straight to hs.hotkey.bind.
--
-- The frame from before the change is remembered for undo. A handler that
-- leaves the frame as it was (growing a maximized window, say) records
-- nothing, so undo never spends a press on a step that changed nothing.
local function withFrame(fn)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end

    local screen = win:screen()
    if not screen then return end

    local f = win:frame()
    local before = {x = f.x, y = f.y, w = f.w, h = f.h}
    fn(f, screen:frame(), win)
    if sameFrame(f, before) then return end

    remember(win, before)
    win:setFrame(f)
  end
end

-- Put the focused window back where it was before the last handler moved it.
-- Repeated presses keep stepping back, up to HISTORY_DEPTH. Undo itself
-- records nothing, so it only ever goes backwards.
function M.undo()
  local win = hs.window.focusedWindow()
  if not win then return end

  local stack = history[win:id()]
  local frame = stack and table.remove(stack)
  if frame then win:setFrame(frame) end
end

-- Widths the Left/Right keys step through, as fractions of the screen. Each
-- press moves to the next one if the window is already at the current one
-- against that edge; otherwise it starts again at the first.
local SNAP_WIDTHS = {1 / 2, 1 / 3, 2 / 3}

local function snapCycle(side)
  return withFrame(function(f, max)
    local left = side == "left"
    local rightEdge = max.x + max.w
    local onEdge = left and approx(f.x, max.x) or approx(f.x + f.w, rightEdge)

    local width = SNAP_WIDTHS[1]
    if onEdge then
      for i, frac in ipairs(SNAP_WIDTHS) do
        if approx(f.w, max.w * frac) then
          width = SNAP_WIDTHS[i % #SNAP_WIDTHS + 1]
          break
        end
      end
    end

    f.y = max.y
    f.h = max.h
    f.w = max.w * width
    f.x = left and max.x or rightEdge - f.w
  end)
end

-- Half, then a third, then two-thirds, then back to half.
M.leftCycle = snapCycle("left")
M.rightCycle = snapCycle("right")

-- Always fills the screen; deliberately not a toggle. On a window that
-- already fills it this changes nothing and records nothing. Undo is the way
-- back.
M.maximize = withFrame(function(f, max)
  f.x = max.x
  f.y = max.y
  f.w = max.w
  f.h = max.h
end)

-- Move a frame from one screen to another, keeping its size. Only a window
-- too big for the new screen is shrunk, and only on the axis that doesn't
-- fit -- scaling it proportionally would shrink windows that had room to
-- spare.
--
-- Position follows the window's centre rather than its top-left corner: with
-- the size held fixed, mapping the corner would drift a centred window
-- off-centre. The result is then clamped fully inside the new screen.
local function remap(f, from, to)
  local w = math.min(f.w, to.w)
  local h = math.min(f.h, to.h)

  local centreX = to.x + (((f.x + f.w / 2) - from.x) / from.w) * to.w
  local centreY = to.y + (((f.y + f.h / 2) - from.y) / from.h) * to.h

  f.x = math.max(to.x, math.min(centreX - w / 2, to.x + to.w - w))
  f.y = math.max(to.y, math.min(centreY - h / 2, to.y + to.h - h))
  f.w = w
  f.h = h
end

-- Move the window to another display. `pick` chooses the target from the
-- window's current screen.
local function toScreen(pick)
  return withFrame(function(f, max, win)
    local screen = win:screen()
    local target = pick(screen)

    -- next() and previous() wrap around, so both return the current screen
    -- when there is only one display. Nothing to do.
    if not target or target:id() == screen:id() then return end

    remap(f, max, target:frame())
  end)
end

-- With two displays these are the same move; they differ only from three up.
M.nextScreen = toScreen(function(screen) return screen:next() end)
M.previousScreen = toScreen(function(screen) return screen:previous() end)

-- Resize by 5% of the screen. `direction` is 1 to grow, -1 to shrink.
--
-- An edge against the screen edge stays put, so shrinking a left-half window
-- pulls its right edge in and leaves the other three alone. The sole exception
-- is shrinking a window with no free edge anywhere: every edge comes in, so
-- the key isn't inert on a maximized window.
local function resizeBy(direction)
  return withFrame(function(f, max)
    local stepW = (max.w / 20) * direction
    local stepH = (max.h / 20) * direction

    local maxRight, maxBottom = max.x + max.w, max.y + max.h
    local atLeft = f.x <= max.x + EDGE_TOLERANCE
    local atRight = (f.x + f.w) >= maxRight - EDGE_TOLERANCE
    local atTop = f.y <= max.y + EDGE_TOLERANCE
    local atBottom = (f.y + f.h) >= maxBottom - EDGE_TOLERANCE

    local moveAll = direction < 0 and atLeft and atRight and atTop and atBottom

    local function delta(touching, step)
      return (touching and not moveAll) and 0 or step
    end

    -- Work in edges rather than position/size: each edge moves independently,
    -- then the pair becomes a position and a size.
    local left = math.max(f.x - delta(atLeft, stepW), max.x)
    local right = math.min(f.x + f.w + delta(atRight, stepW), maxRight)
    local top = math.max(f.y - delta(atTop, stepH), max.y)
    local bottom = math.min(f.y + f.h + delta(atBottom, stepH), maxBottom)

    -- Each axis is accepted or rejected on its own, so a window that can't
    -- shrink further horizontally can still shrink vertically.
    if (right - left) >= MIN_SIZE then
      f.x, f.w = left, right - left
    end

    if (bottom - top) >= MIN_SIZE then
      f.y, f.h = top, bottom - top
    end
  end)
end

M.grow = resizeBy(1)
M.shrink = resizeBy(-1)

-- Move against an edge without changing size.
M.moveLeft = withFrame(function(f, max)
  f.x = max.x
end)

M.moveRight = withFrame(function(f, max)
  f.x = max.x + max.w - f.w
end)

-- Apps with their own full screen mode that stays in the current Space, keyed
-- by bundle ID, mapped to the menu item that toggles it. Menu titles are
-- matched exactly, case included.
local OWN_FULL_SCREEN = {
  ["com.github.wez.wezterm"] = {"View", "Toggle full screen mode"},
}

-- Prefer the app's own full screen mode; fall back to macOS full screen (its
-- own Space) for apps without one, or if the menu item can't be selected.
--
-- A window already in macOS full screen always leaves it, whichever app owns
-- it, so the key can't strand a window that was put there some other way.
function M.toggleFullScreen()
  local win = hs.window.focusedWindow()
  if not win then return end

  if win:isFullScreen() then
    win:setFullScreen(false)
    return
  end

  local app = win:application()
  local item = app and OWN_FULL_SCREEN[app:bundleID()]
  if item and app:selectMenuItem(item) then return end

  win:setFullScreen(true)
end

-- Focus the nearest window in a direction ("East", "West", "North", "South").
--
-- Candidates are standard windows only: macOS also reports helper windows
-- (Chrome's status bar, for one), and focusing one of those looks like a
-- no-op. orderedWindows() is front to back, which Hammerspoon uses to break
-- ties. frontmost skips windows hidden entirely behind the current one;
-- strict keeps to windows within 45 degrees of the direction, so pressing
-- Right never lands on a window that's mostly above.
local function focusToward(direction)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end

    local candidates = {}
    for _, w in ipairs(hs.window.orderedWindows()) do
      if w:isStandard() then candidates[#candidates + 1] = w end
    end

    win["focusWindow" .. direction](win, candidates, true, true)
  end
end

M.focusLeft = focusToward("West")
M.focusDown = focusToward("South")
M.focusUp = focusToward("North")
M.focusRight = focusToward("East")

-- Centre on the current screen, keeping size. A window larger than the screen
-- is shrunk to fit on that axis, or centring would push its edges off-screen.
M.center = withFrame(function(f, max)
  f.w = math.min(f.w, max.w)
  f.h = math.min(f.h, max.h)
  f.x = max.x + (max.w - f.w) / 2
  f.y = max.y + (max.h - f.h) / 2
end)

return M
