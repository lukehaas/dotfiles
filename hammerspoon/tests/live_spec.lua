-- Live geometry suite: runs every handler against each attached screen, then
-- the cross-screen moves. Run with: hs ~/.hammerspoon/tests/live_spec.lua
local window = require("window")

local app = hs.application.get("WezTerm")
local target = app and app:mainWindow()
if not target then return "WezTerm window not found - aborting" end

local id = target:id()
target:focus()
hs.timer.usleep(300000)
if hs.window.focusedWindow():id() ~= id then
  return "could not take focus - aborting without touching any window"
end

local original = target:frame()
local originalScreen = target:screen():name()
local savedDuration = hs.window.animationDuration
hs.window.animationDuration = 0  -- else frame() reads pre-animation values

local out, failures = {}, 0

local function near(a, b) return math.abs(a - b) <= 2 end

local function check(name, start, want, fn)
  if hs.window.focusedWindow():id() ~= id then
    failures = failures + 1
    out[#out + 1] = "  FAIL " .. name .. " (focus drifted)"
    return
  end

  target:setFrame({x = start[1], y = start[2], w = start[3], h = start[4]})
  fn()
  local got = target:frame()

  local ok = near(got.x, want[1]) and near(got.y, want[2])
         and near(got.w, want[3]) and near(got.h, want[4])
  if not ok then failures = failures + 1 end

  out[#out + 1] = string.format("  %s %-26s x=%-7.6g y=%-7.6g w=%-7.6g h=%-7.6g%s",
    ok and "ok  " or "FAIL", name, got.x, got.y, got.w, got.h,
    ok and "" or string.format("   | want x=%g y=%g w=%g h=%g", want[1], want[2], want[3], want[4]))
end

local function runScreenSuite(screen)
  local sf = screen:frame()
  local stepW, stepH = sf.w / 20, sf.h / 20
  local half, third = sf.w / 2, sf.w / 3

  -- Park the window on this screen before asserting anything about it.
  target:setFrame({x = sf.x + 100, y = sf.y + 100, w = 700, h = 500})
  local landed = target:screen()
  out[#out + 1] = string.format("\n%s  (x=%g y=%g w=%g h=%g)", screen:name(), sf.x, sf.y, sf.w, sf.h)
  if landed:id() ~= screen:id() then
    failures = failures + 1
    out[#out + 1] = string.format("  FAIL window landed on %s, not this screen - skipping", landed:name())
    return
  end

  local inside = {sf.x + 200, sf.y + 100, 600, 400}

  check("maximize", inside, {sf.x, sf.y, sf.w, sf.h}, window.maximize)
  check("leftCycle -> half", inside, {sf.x, sf.y, half, sf.h}, window.leftCycle)
  check("leftCycle -> third", {sf.x, sf.y, half, sf.h}, {sf.x, sf.y, third, sf.h}, window.leftCycle)
  check("rightCycle -> half", inside, {sf.x + half, sf.y, half, sf.h}, window.rightCycle)
  check("rightCycle -> third", {sf.x + half, sf.y, half, sf.h},
    {sf.x + sf.w - third, sf.y, third, sf.h}, window.rightCycle)
  check("moveLeft", inside, {sf.x, sf.y + 100, 600, 400}, window.moveLeft)
  check("moveRight", inside, {sf.x + sf.w - 600, sf.y + 100, 600, 400}, window.moveRight)

  check("grow all edges free", inside,
    {sf.x + 200 - stepW, sf.y + 100 - stepH, 600 + stepW * 2, 400 + stepH * 2}, window.grow)
  check("grow flush-left", {sf.x, sf.y + 100, 600, 400},
    {sf.x, sf.y + 100 - stepH, 600 + stepW, 400 + stepH * 2}, window.grow)
  check("grow full-width", {sf.x, sf.y + 100, sf.w, 400},
    {sf.x, sf.y + 100 - stepH, sf.w, 400 + stepH * 2}, window.grow)
  check("grow maximized", {sf.x, sf.y, sf.w, sf.h}, {sf.x, sf.y, sf.w, sf.h}, window.grow)

  check("shrink all edges free", inside,
    {sf.x + 200 + stepW, sf.y + 100 + stepH, 600 - stepW * 2, 400 - stepH * 2}, window.shrink)
  check("shrink left-half", {sf.x, sf.y, half, sf.h},
    {sf.x, sf.y, half - stepW, sf.h}, window.shrink)
  check("shrink full-width", {sf.x, sf.y + 100, sf.w, 400},
    {sf.x, sf.y + 100 + stepH, sf.w, 400 - stepH * 2}, window.shrink)
  check("shrink maximized", {sf.x, sf.y, sf.w, sf.h},
    {sf.x + stepW, sf.y + stepH, sf.w - stepW * 2, sf.h - stepH * 2}, window.shrink)
  check("shrink min floor", {sf.x + 200, sf.y + 100, 110, 110},
    {sf.x + 200, sf.y + 100, 110, 110}, window.shrink)
end

-- Cross-screen moves need their own check. Apps may snap their own size after
-- a resize (WezTerm rounds to character cells, and shrinks itself further on a
-- wide screen), so asserting against the frame we *asked* for would test the
-- app's compliance rather than our transform. Instead: measure what the window
-- actually holds immediately before the handler runs, and assert the handler
-- mapped that proportionally onto the target screen.
-- Position is asserted exactly: it is what the screen-relative coordinate
-- handling affects, and what the original bugs got wrong.
--
-- Size is asserted loosely, because apps resize themselves after a scripted
-- resize -- WezTerm rounds to character cells and clamps inconsistently from
-- run to run. The deterministic arithmetic lives in window_spec.lua, with
-- hand-derived constants; this suite's value is that it runs against real
-- screens and a real window.
local POSITION_TOLERANCE = 3
local SIZE_RELATIVE_TOLERANCE = 0.25

local function checkMove(name, fn, settle)
  local before = target:frame()
  local fromScreen = target:screen()
  local from = fromScreen:frame()
  local toScreenObj = fromScreen:next()
  local to = toScreenObj:frame()

  -- Size is kept unless it exceeds the new screen; position follows the
  -- window's centre, clamped inside.
  local w = math.min(before.w, to.w)
  local h = math.min(before.h, to.h)
  local centreX = to.x + (((before.x + before.w / 2) - from.x) / from.w) * to.w
  local centreY = to.y + (((before.y + before.h / 2) - from.y) / from.h) * to.h
  local want = {
    x = math.max(to.x, math.min(centreX - w / 2, to.x + to.w - w)),
    y = math.max(to.y, math.min(centreY - h / 2, to.y + to.h - h)),
    w = w, h = h,
  }

  local fits = before.w <= to.w and before.h <= to.h

  fn()
  hs.timer.usleep(settle)
  local got = target:frame()
  local landed = target:screen()

  local movedScreen = landed:id() ~= fromScreen:id()
  local positionOk = math.abs(got.x - want.x) <= POSITION_TOLERANCE
                 and math.abs(got.y - want.y) <= POSITION_TOLERANCE
  local sizeOk = math.abs(got.w - want.w) <= want.w * SIZE_RELATIVE_TOLERANCE
             and math.abs(got.h - want.h) <= want.h * SIZE_RELATIVE_TOLERANCE

  local ok = movedScreen and positionOk and sizeOk
  if not ok then failures = failures + 1 end

  out[#out + 1] = string.format("  %s %-20s %s -> %-12s %s", ok and "ok  " or "FAIL", name,
    fromScreen:name():sub(1, 11), landed:name():sub(1, 11),
    fits and "fits: size should be KEPT" or "too big: should SHRINK to fit")
  out[#out + 1] = string.format("         before w=%-7.6g h=%-7.6g   got w=%-7.6g h=%-7.6g   want w=%-7.6g h=%-7.6g",
    before.w, before.h, got.w, got.h, want.w, want.h)
  out[#out + 1] = string.format("         position got x=%-7.6g y=%-7.6g  want x=%-7.6g y=%-7.6g%s",
    got.x, got.y, want.x, want.y, positionOk and "  exact" or "   <-- MISMATCH")
end

local function runCrossScreen(screens)
  local a = screens[1]:frame()

  -- A window small enough for every screen: its size must survive the trip.
  out[#out + 1] = "\ncross-screen, window that fits everywhere (size must be kept)"
  target:setFrame({x = a.x + a.w * 0.25, y = a.y + a.h * 0.25, w = a.w * 0.35, h = a.h * 0.35})
  hs.timer.usleep(600000)
  checkMove("nextScreen", window.nextScreen, 600000)
  checkMove("nextScreen back", window.nextScreen, 600000)

  -- A window wider than the laptop: must shrink on the way over, then keep
  -- that size on the way back.
  out[#out + 1] = "\ncross-screen, window too wide for the smaller screen"
  target:setFrame({x = a.x + 100, y = a.y + 200, w = a.w * 0.8, h = a.h * 0.5})
  hs.timer.usleep(600000)
  checkMove("nextScreen", window.nextScreen, 600000)
  checkMove("nextScreen back", window.nextScreen, 600000)
end

local screens = hs.screen.allScreens()
out[#out + 1] = string.format("%d screens attached; target: %s (id %d)", #screens, target:title():sub(1, 24), id)

local ok, err = pcall(function()
  for _, screen in ipairs(screens) do runScreenSuite(screen) end
  if #screens > 1 then runCrossScreen(screens) else
    out[#out + 1] = "\n(single display: cross-screen moves not exercised)"
  end
end)

target:setFrame(original)
hs.window.animationDuration = savedDuration
local restored = target:frame()

out[#out + 1] = ""
if not ok then out[#out + 1] = "ERROR during suite: " .. tostring(err) end
out[#out + 1] = string.format("restored to %s x=%g y=%g w=%g h=%g (match=%s)",
  originalScreen, restored.x, restored.y, restored.w, restored.h,
  tostring(near(restored.x, original.x) and near(restored.y, original.y)
       and near(restored.w, original.w) and near(restored.h, original.h)))
out[#out + 1] = (failures == 0 and ok) and "all checks passed" or (failures .. " check(s) FAILED")

return table.concat(out, "\n")
