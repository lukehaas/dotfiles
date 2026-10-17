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

local function approx(a, b)
  return math.abs(a - b) <= TOLERANCE
end

-- Wraps the focused-window boilerplate every handler shared: fetch the window,
-- hand its frame and its screen's usable frame to fn, write the frame back.
-- Returns a function suitable for passing straight to hs.hotkey.bind.
local function withFrame(fn)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end

    local screen = win:screen()
    if not screen then return end

    local f = win:frame()
    fn(f, screen:frame(), win)
    win:setFrame(f)
  end
end

-- Snap to the left half; pressing again from the left half narrows to a third.
M.leftCycle = withFrame(function(f, max)
  local half = max.w / 2
  local onLeftHalf = approx(f.w, half) and approx(f.x, max.x)

  f.x = max.x
  f.y = max.y
  f.h = max.h
  f.w = onLeftHalf and (max.w / 3) or half
end)

-- Snap to the right half; pressing again from the right half narrows to a third.
M.rightCycle = withFrame(function(f, max)
  local half = max.w / 2
  local rightEdge = max.x + max.w
  local onRightHalf = approx(f.w, half) and approx(f.x + f.w, rightEdge)

  f.y = max.y
  f.h = max.h
  f.w = onRightHalf and (max.w / 3) or half
  f.x = rightEdge - f.w
end)

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

return M
