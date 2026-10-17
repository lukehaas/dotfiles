-- Resolve window.lua relative to this file so the suite runs from anywhere.
local here = (arg and arg[0] and arg[0]:match("(.*/)")) or "./"
package.path = here .. "../?.lua;" .. package.path

-- Simulated displays: primary at origin, secondary offset to the right with a
-- different resolution. The old code's `f.x == 0` / `max.w` assumptions only
-- hold on the primary, so the secondary is where the bugs showed.
local PRIMARY   = {x = 0,    y = 25, w = 1800, h = 1100}
local SECONDARY = {x = 1800, y = 0,  w = 2560, h = 1440}

local screens = {}
local function makeScreen(id, frame)
  local s = {}
  function s:id() return id end
  function s:frame() return frame end
  function s:next() return screens[(id % #screens) + 1] end
  return s
end
screens[1] = makeScreen(1, PRIMARY)
screens[2] = makeScreen(2, SECONDARY)

local current  -- the window under test
hs = {
  window = {focusedWindow = function() return current end},
}

local function win(frame, screen)
  local w = {f = frame}
  function w:frame() return {x = self.f.x, y = self.f.y, w = self.f.w, h = self.f.h} end
  function w:setFrame(nf) self.f = nf end
  function w:screen() return screen end
  return w
end

local window = require("window")

local failures = 0
local function check(label, got, want)
  local ok = true
  for _, k in ipairs({"x", "y", "w", "h"}) do
    if math.abs(got[k] - want[k]) > 0.01 then ok = false end
  end
  local fmt = function(t) return string.format("x=%g y=%g w=%g h=%g", t.x, t.y, t.w, t.h) end
  if ok then
    print(string.format("  ok   %-42s %s", label, fmt(got)))
  else
    failures = failures + 1
    print(string.format("  FAIL %-42s got %s | want %s", label, fmt(got), fmt(want)))
  end
end

local function run(handler, frame, screen)
  current = win(frame, screen)
  handler()
  return current.f
end

print("\n-- secondary display (origin x=1800) --")

check("leftCycle snaps to left half",
  run(window.leftCycle, {x = 2000, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800, y = 0, w = 1280, h = 1440})

-- The old code set f.x = max.x then tested `f.x == 0`, which is never true
-- here, so the third-width step was unreachable on a secondary display.
check("leftCycle left half -> left third",
  run(window.leftCycle, {x = 1800, y = 0, w = 1280, h = 1440}, screens[2]),
  {x = 1800, y = 0, w = 2560 / 3, h = 1440})

check("rightCycle snaps to right half",
  run(window.rightCycle, {x = 2000, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800 + 1280, y = 0, w = 1280, h = 1440})

-- Old code compared `f.x + f.w >= max.w` (a width, not the right edge), so on
-- this screen any right-half window already satisfied it by accident.
check("rightCycle right half -> right third",
  run(window.rightCycle, {x = 1800 + 1280, y = 0, w = 1280, h = 1440}, screens[2]),
  {x = 1800 + 2560 - 2560 / 3, y = 0, w = 2560 / 3, h = 1440})

check("maximize fills the screen",
  run(window.maximize, {x = 2000, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800, y = 0, w = 2560, h = 1440})

-- Old code did `f.x = 0`, yanking the window onto the primary display.
check("moveLeft stays on this screen",
  run(window.moveLeft, {x = 2200, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800, y = 300, w = 800, h = 600})

-- Old code did `f.x = max.w - f.w`, landing the window on the primary.
check("moveRight hits the right edge",
  run(window.moveRight, {x = 2000, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800 + 2560 - 800, y = 300, w = 800, h = 600})

print("\n-- resize: each free edge moves one step, touching edges stay put --")
-- SECONDARY is 2560x1440, so stepW = 128 and stepH = 72.

check("grow, all edges free",
  run(window.grow, {x = 2000, y = 300, w = 800, h = 600}, screens[2]),
  {x = 2000 - 128, y = 300 - 72, w = 800 + 256, h = 600 + 144})

-- The left edge is touching, so only the right edge moves, by ONE step.
check("grow flush-left: right edge only",
  run(window.grow, {x = 1800, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800, y = 300 - 72, w = 800 + 128, h = 600 + 144})

check("grow flush-right: left edge only",
  run(window.grow, {x = 3560, y = 300, w = 800, h = 600}, screens[2]),
  {x = 3560 - 128, y = 300 - 72, w = 800 + 128, h = 600 + 144})

-- Axes are independent: full width, free vertically.
check("grow full-width: y axis only",
  run(window.grow, {x = 1800, y = 300, w = 2560, h = 600}, screens[2]),
  {x = 1800, y = 300 - 72, w = 2560, h = 600 + 144})

check("grow maximized is a no-op",
  run(window.grow, {x = 1800, y = 0, w = 2560, h = 1440}, screens[2]),
  {x = 1800, y = 0, w = 2560, h = 1440})

check("shrink, all edges free",
  run(window.shrink, {x = 2000, y = 300, w = 800, h = 600}, screens[2]),
  {x = 2000 + 128, y = 300 + 72, w = 800 - 256, h = 600 - 144})

-- Shrink follows the same rule: the touching edge stays, the free one moves in.
check("shrink flush-left: right edge only",
  run(window.shrink, {x = 1800, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800, y = 300 + 72, w = 800 - 128, h = 600 - 144})

check("shrink flush-right: left edge only",
  run(window.shrink, {x = 3560, y = 300, w = 800, h = 600}, screens[2]),
  {x = 3560 + 128, y = 300 + 72, w = 800 - 128, h = 600 - 144})

-- The agreed exception: nothing is free, so both edges come in.
check("shrink maximized pulls both in",
  run(window.shrink, {x = 1800, y = 0, w = 2560, h = 1440}, screens[2]),
  {x = 1800 + 128, y = 72, w = 2560 - 256, h = 1440 - 144})

-- Left and right both touch, so neither moves; only the free y edges do.
check("shrink full-width: y axis only",
  run(window.shrink, {x = 1800, y = 300, w = 2560, h = 600}, screens[2]),
  {x = 1800, y = 300 + 72, w = 2560, h = 600 - 144})

check("shrink full-height: x axis only",
  run(window.shrink, {x = 2000, y = 0, w = 800, h = 1440}, screens[2]),
  {x = 2000 + 128, y = 0, w = 800 - 256, h = 1440})

-- The reported bug: a left-half window has left, top AND bottom touching.
-- Only the right edge is free, so only it may move.
check("shrink left-half: right edge only",
  run(window.shrink, {x = 1800, y = 0, w = 1280, h = 1440}, screens[2]),
  {x = 1800, y = 0, w = 1280 - 128, h = 1440})

check("grow left-half: right edge only",
  run(window.grow, {x = 1800, y = 0, w = 1280, h = 1440}, screens[2]),
  {x = 1800, y = 0, w = 1280 + 128, h = 1440})

check("shrink refuses below the minimum",
  run(window.shrink, {x = 2000, y = 300, w = 120, h = 120}, screens[2]),
  {x = 2000, y = 300, w = 120, h = 120})

print("\n-- screen moves: size kept unless it won't fit --")
-- PRIMARY is 1800x1100 at (0,25); SECONDARY is 2560x1440 at (1800,0).

-- Centred on the primary -> centred on the secondary, SAME pixel size.
check("fits: size unchanged, stays centred",
  run(window.nextScreen, {x = 450, y = 300, w = 900, h = 550}, screens[1]),
  {x = 2630, y = 445, w = 900, h = 550})

-- Onto the smaller screen with room to spare: still no resize.
check("fits on smaller screen: unchanged",
  run(window.nextScreen, {x = 2680, y = 420, w = 800, h = 600}, screens[2]),
  {x = 500, y = 275, w = 800, h = 600})

-- Too wide AND too tall for the primary: shrunk on both axes to fit.
check("too big: shrunk to fit",
  run(window.nextScreen, {x = 2000, y = 100, w = 2000, h = 1300}, screens[2]),
  {x = 0, y = 25, w = 1800, h = 1100})

-- Too wide but short enough: only the width is reduced.
-- Centre y sits at 650 of the secondary's 1440, so 25 + (650/1440)*1100 on
-- the primary; minus half the kept height of 500.
check("too wide only: height kept",
  run(window.nextScreen, {x = 2000, y = 400, w = 2000, h = 500}, screens[2]),
  {x = 0, y = 25 + (650 / 1440) * 1100 - 250, w = 1800, h = 500})

-- Tall enough to exceed the primary but narrow: only the height is reduced.
-- Centre x is 550 into the secondary, mapped across then offset by half the
-- kept width of 700. Height fills the primary, so y pins to its top.
check("too tall only: width kept",
  run(window.nextScreen, {x = 2000, y = 0, w = 700, h = 1400}, screens[2]),
  {x = (550 / 2560) * 1800 - 350, y = 25, w = 700, h = 1100})

-- A window hugging an edge is clamped inside rather than hanging off.
-- The mapped centre would put the window past the primary's right edge, so x
-- clamps to 1800 - 600.
check("right-flush stays inside",
  run(window.nextScreen, {x = 1800 + 2560 - 600, y = 100, w = 600, h = 400}, screens[2]),
  {x = 1200, y = 25 + (300 / 1440) * 1100 - 200, w = 600, h = 400})

print("\n-- degenerate input --")

local singleScreen = {}
function singleScreen:id() return 9 end
function singleScreen:frame() return PRIMARY end
function singleScreen:next() return singleScreen end

check("nextScreen with one display is a no-op",
  run(window.nextScreen, {x = 100, y = 100, w = 400, h = 400}, singleScreen),
  {x = 100, y = 100, w = 400, h = 400})

-- Old code called win:frame() unconditionally and threw here.
current = nil
local ok, err = pcall(window.maximize)
if ok then
  print("  ok   no focused window is handled")
else
  failures = failures + 1
  print("  FAIL no focused window threw: " .. tostring(err))
end

print()
if failures == 0 then
  print("all checks passed")
else
  print(failures .. " check(s) failed")
  os.exit(1)
end
