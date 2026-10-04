-- Smooth continuous scrolling while a key is held, with trackpad-style
-- acceleration and momentum.
--
-- Bound to F13 / F14, which the Keychron firmware emits for fn+PageUp and
-- fn+PageDown. The fn key itself is not usable as a trigger: macOS stamps the
-- function flag on every navigation key, so fn+PageUp and a bare PageUp
-- arrive identically (verified -- a plain Up arrow also reports flags=[fn]).
-- Making the combo emit nothing in firmware does not help either, since
-- Hammerspoon can only act on events macOS actually receives. F13/F14 have no
-- default binding on macOS, so they are a clean private channel, and plain
-- PageUp/PageDown keep their normal page-jump.

local M = {}

-- Speeds are in pixels per second, so these read as real-world values.
--
-- START_SPEED is what a quick tap gives you, so it wants to be small enough
-- to nudge precisely. The ramp then pulls up to MAX_SPEED, and on release the
-- scroll coasts instead of stopping dead -- that coast is what reads as
-- "trackpad" rather than "key repeat".
local START_SPEED = 260
local MAX_SPEED = 2200
local ACCELERATION = 4200

-- Per-tick damping applied after release. 0.88 at 60Hz decays to roughly a
-- tenth of the release speed in about a third of a second.
local COAST_DAMPING = 0.88

-- Below this the coast is no longer visible, so the timer shuts down.
local STOP_SPEED = 40

local TICK_SECONDS = 1 / 60

-- A release can be missed if focus changes mid-hold or the key sticks, which
-- would otherwise scroll forever. Cap the accelerating phase.
local MAX_HOLD_SECONDS = 10

-- Positive vertical scrolls the content up (the view moves toward the top).
local UP = 1
local DOWN = -1

local timer
local direction = 0
local held = false
local speed = 0
local heldUntil = 0

-- Scroll events take whole pixels, and at low speeds a tick is worth less
-- than one. Carrying the remainder keeps slow scrolling smooth instead of
-- truncating it away to nothing.
local remainder = 0

local function halt()
  if timer then
    timer:stop()
    timer = nil
  end

  direction = 0
  held = false
  speed = 0
  remainder = 0
end

local function tick()
  if held then
    if hs.timer.secondsSinceEpoch() > heldUntil then
      held = false -- safety: treat a missed release as a release
    else
      speed = math.min(MAX_SPEED, speed + ACCELERATION * TICK_SECONDS)
    end
  end

  if not held then
    speed = speed * COAST_DAMPING
    if speed < STOP_SPEED then
      halt()
      return
    end
  end

  remainder = remainder + speed * TICK_SECONDS
  local pixels = math.floor(remainder)
  remainder = remainder - pixels

  if pixels > 0 then
    hs.eventtap.event.newScrollEvent({0, pixels * direction}, {}, "pixel"):post()
  end
end

local function press(newDirection)
  -- Reversing mid-coast should not inherit the old momentum.
  if direction ~= newDirection then
    speed = 0
    remainder = 0
  end

  direction = newDirection
  held = true
  heldUntil = hs.timer.secondsSinceEpoch() + MAX_HOLD_SECONDS
  speed = math.max(speed, START_SPEED)

  if not timer then
    timer = hs.timer.doEvery(TICK_SECONDS, tick)
  end
end

local function release(oldDirection)
  -- Ignore a release for a direction we are no longer scrolling, so letting
  -- go of one key after pressing the other does not cancel the new scroll.
  if direction == oldDirection then
    held = false
  end
end

--- Bind F13 and F14 to scroll up and down while held.
function M.start()
  -- The firmware sends fn alongside F13/F14; hs.hotkey matches anyway.
  hs.hotkey.bind({}, "f13", function() press(UP) end, function() release(UP) end)
  hs.hotkey.bind({}, "f14", function() press(DOWN) end, function() release(DOWN) end)

  return M
end

--- Stop any scroll in progress. For the console, and for reloads.
function M.stopAll()
  halt()
end

--- Current speed in pixels per second, for tuning from the console.
function M.speed()
  return speed
end

return M
