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

local nextId = 0
local function win(frame, screen)
  nextId = nextId + 1
  local w = {f = frame, id_ = nextId}
  function w:id() return self.id_ end
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

-- Third -> two-thirds -> back to half, on both sides.
check("leftCycle left third -> left two-thirds",
  run(window.leftCycle, {x = 1800, y = 0, w = 2560 / 3, h = 1440}, screens[2]),
  {x = 1800, y = 0, w = 2560 * 2 / 3, h = 1440})

check("leftCycle left two-thirds -> left half",
  run(window.leftCycle, {x = 1800, y = 0, w = 2560 * 2 / 3, h = 1440}, screens[2]),
  {x = 1800, y = 0, w = 1280, h = 1440})

check("rightCycle right third -> right two-thirds",
  run(window.rightCycle, {x = 1800 + 2560 - 2560 / 3, y = 0, w = 2560 / 3, h = 1440}, screens[2]),
  {x = 1800 + 2560 / 3, y = 0, w = 2560 * 2 / 3, h = 1440})

check("rightCycle right two-thirds -> right half",
  run(window.rightCycle, {x = 1800 + 2560 / 3, y = 0, w = 2560 * 2 / 3, h = 1440}, screens[2]),
  {x = 1800 + 1280, y = 0, w = 1280, h = 1440})

-- Third-width but not against the left edge: not part of the cycle yet.
check("leftCycle third-width off the edge -> half",
  run(window.leftCycle, {x = 2200, y = 0, w = 2560 / 3, h = 1440}, screens[2]),
  {x = 1800, y = 0, w = 1280, h = 1440})

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

-- Centred within the secondary's frame, not at x = (2560 - 800) / 2.
check("center keeps size, centres on this screen",
  run(window.center, {x = 2000, y = 300, w = 800, h = 600}, screens[2]),
  {x = 1800 + (2560 - 800) / 2, y = (1440 - 600) / 2, w = 800, h = 600})

-- The primary's y origin is 25 (menu bar), so the vertical centre is offset.
check("center respects a non-zero y origin",
  run(window.center, {x = 100, y = 100, w = 600, h = 400}, screens[1]),
  {x = (1800 - 600) / 2, y = 25 + (1100 - 400) / 2, w = 600, h = 400})

-- Too wide for the screen: width clamps to fit, height is kept.
check("center shrinks only the oversized axis",
  run(window.center, {x = 0, y = 100, w = 2000, h = 400}, screens[1]),
  {x = 0, y = 25 + (1100 - 400) / 2, w = 1800, h = 400})

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

print("\n-- full screen: app's own mode first, macOS full screen otherwise --")

-- Records what toggleFullScreen did instead of touching geometry.
local function fsWin(opts)
  local w = {calls = {}}
  local app = {}
  function app:bundleID() return opts.bundleID end
  function app:selectMenuItem(path)
    w.calls[#w.calls + 1] = "menu:" .. table.concat(path, " > ")
    return opts.menuWorks ~= false
  end
  function w:isFullScreen() return opts.native or false end
  function w:setFullScreen(on) w.calls[#w.calls + 1] = "native:" .. tostring(on) end
  function w:application() return opts.bundleID and app or nil end
  return w
end

local function checkCalls(label, opts, want)
  current = fsWin(opts)
  window.toggleFullScreen()
  local got = table.concat(current.calls, ", ")
  if got == want then
    print(string.format("  ok   %-42s %s", label, got))
  else
    failures = failures + 1
    print(string.format("  FAIL %-42s got [%s] | want [%s]", label, got, want))
  end
end

checkCalls("WezTerm uses its own menu item",
  {bundleID = "com.github.wez.wezterm"},
  "menu:View > Toggle full screen mode")

checkCalls("other apps use macOS full screen",
  {bundleID = "com.apple.Safari"},
  "native:true")

-- A renamed or missing menu item must not leave the key inert.
checkCalls("menu item fails -> macOS full screen",
  {bundleID = "com.github.wez.wezterm", menuWorks = false},
  "menu:View > Toggle full screen mode, native:true")

-- Already in macOS full screen (even WezTerm): leave it, don't stack modes.
checkCalls("macOS full screen always exits",
  {bundleID = "com.github.wez.wezterm", native = true},
  "native:false")

checkCalls("no application -> macOS full screen",
  {},
  "native:true")

print("\n-- undo: steps back through what the handlers changed --")

-- Runs handlers in order on one window, returning its final frame.
local function sequence(frame, screen, ...)
  current = win(frame, screen)
  for _, handler in ipairs({...}) do handler() end
  return current.f
end

local START = {x = 2000, y = 300, w = 800, h = 600}

check("undo restores the frame before the last action",
  sequence(START, screens[2], window.leftCycle, window.undo), START)

check("undo steps back one action at a time",
  sequence(START, screens[2], window.leftCycle, window.leftCycle, window.undo),
  {x = 1800, y = 0, w = 1280, h = 1440})

check("repeated undo walks back to the start",
  sequence(START, screens[2], window.leftCycle, window.grow, window.center,
    window.undo, window.undo, window.undo), START)

check("undo with nothing remembered is a no-op",
  sequence(START, screens[2], window.undo), START)

-- Growing a maximized window changes nothing, so it records nothing: one
-- undo still gets back to before the maximize.
check("no-op actions are not remembered",
  sequence(START, screens[2], window.maximize, window.grow, window.undo), START)

check("undo carries a window back across screens",
  sequence({x = 450, y = 300, w = 900, h = 550}, screens[1], window.nextScreen, window.undo),
  {x = 450, y = 300, w = 900, h = 550})

-- Maximize is not a toggle: a second press is a no-op and records nothing,
-- so one undo gets back to before the first press.
check("maximize twice stays maximized",
  sequence(START, screens[2], window.maximize, window.maximize),
  {x = 1800, y = 0, w = 2560, h = 1440})

check("second maximize adds no undo step",
  sequence(START, screens[2], window.maximize, window.maximize, window.undo), START)

-- Each window has its own history.
current = win(START, screens[2])
local first = current
window.leftCycle()
current = win({x = 2100, y = 400, w = 500, h = 500}, screens[2])
window.undo()
check("undo only touches the focused window's history", current.f,
  {x = 2100, y = 400, w = 500, h = 500})
current = first
window.undo()
check("the other window's history is intact", current.f, START)

print("\n-- directional focus --")

-- Records how focusWindow<Direction> was called rather than computing focus,
-- which is Hammerspoon's job.
local focusCalls
local function focusable(standard)
  local w = win({x = 0, y = 0, w = 100, h = 100}, screens[1])
  function w:isStandard() return standard end
  for _, dir in ipairs({"West", "South", "North", "East"}) do
    w["focusWindow" .. dir] = function(self, candidates, frontmost, strict)
      focusCalls[#focusCalls + 1] = {dir = dir, candidates = candidates,
        frontmost = frontmost, strict = strict}
    end
  end
  return w
end

local helper = focusable(false)
local other = focusable(true)
current = focusable(true)
hs.window.orderedWindows = function() return {current, helper, other} end

for _, case in ipairs({
  {window.focusLeft, "West"}, {window.focusDown, "South"},
  {window.focusUp, "North"}, {window.focusRight, "East"},
}) do
  focusCalls = {}
  case[1]()
  local call = focusCalls[1]
  local ok = #focusCalls == 1 and call.dir == case[2]
    and call.frontmost == true and call.strict == true
    and #call.candidates == 2 and call.candidates[1] == current
    and call.candidates[2] == other
  if ok then
    print(string.format("  ok   %-42s %s, standard windows only, front to back",
      "focus " .. case[2]:lower(), case[2]))
  else
    failures = failures + 1
    print("  FAIL focus " .. case[2]:lower() .. " called focusWindow wrongly")
  end
end

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
for name, handler in pairs({maximize = window.maximize, undo = window.undo,
                            focusLeft = window.focusLeft}) do
  local ok, err = pcall(handler)
  if ok then
    print("  ok   no focused window is handled: " .. name)
  else
    failures = failures + 1
    print("  FAIL no focused window threw in " .. name .. ": " .. tostring(err))
  end
end

print()
if failures == 0 then
  print("all checks passed")
else
  print(failures .. " check(s) failed")
  os.exit(1)
end
