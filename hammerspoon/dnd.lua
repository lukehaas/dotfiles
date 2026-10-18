-- Turn on Do Not Disturb while a camera is in use, and turn it back off
-- afterwards.
--
-- Setting a Focus mode has no public API. The `defaults -currentHost write
-- ... doNotDisturb` key stopped working when Monterey replaced Do Not Disturb
-- with Focus modes, and UI-scripting Control Center breaks whenever Apple
-- redesigns it. Driving a Shortcut is the one route that survives, so this
-- needs two shortcuts created by hand in the Shortcuts app (the `shortcuts`
-- CLI can run them but not create them). Each is a single "Set Focus" action:
--
--   "DND On"  -> Set Focus: Do Not Disturb, Turn On
--   "DND Off" -> Set Focus: Do Not Disturb, Turn Off
--
-- KNOWN LIMITATION: a Focus you set by hand is switched off at the end of the
-- next camera call.
--
-- `enabledByUs` below stops this module releasing a Focus it never set, but
-- only while no camera event occurs. Turn Do Not Disturb on yourself, then
-- join a video call: on camera-on this module runs "DND On" (a no-op, it is
-- already on), takes credit, and runs "DND Off" when the call ends. Verified
-- 2026-10-02; the log read:
--
--   18:58:05  camera in use - Do Not Disturb on
--   18:58:13  cameras free  - Do Not Disturb off   <-- manual setting lost
--
-- Fixing it needs the Focus state read *before* enabling, to tell "I turned
-- this on" from "this was already on". There is no way to read it from here:
-- Hammerspoon has no Focus API, and ~/Library/DoNotDisturb/DB/ is
-- "Operation not permitted" without Full Disk Access. The route would be a
-- third shortcut wrapping a focus-getter action, read via
-- `shortcuts run 'DND State' --output-path`, and an early return when it
-- reports Focus already on.
--
-- Left unfixed deliberately: it needs that extra shortcut plus output
-- parsing, and only bites in the sequence "set DND by hand, then take a call,
-- then end it". Using a separate custom Focus mode does not help -- macOS
-- runs one Focus at a time, so activating any mode displaces a manual one.

local M = {}

local SHORTCUT_ON = "DND On"
local SHORTCUT_OFF = "DND Off"

-- Engage quickly so a notification can't land as a call starts, but release
-- slowly: apps drop the camera stream briefly when switching views, and
-- flapping Focus on and off is worse than staying on a few seconds too long.
local ON_DELAY = 0.5
local OFF_DELAY = 5

local log = hs.logger.new("dnd", "info")

-- Set only when this module turned Focus on, so a Focus set by hand survives
-- as long as no camera event occurs. See KNOWN LIMITATION above for the case
-- this does not cover.
local enabledByUs = false

local pending
local watched = {}

-- Cleared by stop(), so a shortcut finishing afterwards changes nothing.
local active = false

-- The shortcut in flight, if any. Held here so it isn't garbage collected
-- mid-run, and so apply() can tell one is still going.
local running

-- Shortcuts take around a second to run, so they run as a task rather than
-- through hs.execute, which would freeze every hotkey and timer meanwhile.
local function runShortcut(name, onSuccess)
  running = hs.task.new("/usr/bin/shortcuts", function(rc, stdout, stderr)
    running = nil
    if not active then return end

    if rc == 0 then
      onSuccess()
    else
      local output = (stderr ~= "" and stderr or stdout or ""):gsub("%s+$", "")
      log.ef("shortcut '%s' failed (rc %s): %s", name, tostring(rc), output)
    end
  end, {"run", name})

  if not running:start() then
    running = nil
    log.ef("shortcut '%s' could not be started", name)
  end
end

local function anyCameraInUse()
  for _, camera in ipairs(hs.camera.allCameras()) do
    -- A camera unplugged mid-call can throw rather than report cleanly.
    local ok, inUse = pcall(camera.isInUse, camera)
    if ok and inUse then return true, camera:name() end
  end

  return false
end

local function apply()
  -- One shortcut at a time. Anything that changed while one was running is
  -- picked up by the apply() it makes when it succeeds. A failure does not
  -- retry, so a broken shortcut can't loop; the next camera event tries again.
  if running then return end

  local inUse, name = anyCameraInUse()

  if inUse and not enabledByUs then
    runShortcut(SHORTCUT_ON, function()
      enabledByUs = true
      log.f("camera in use (%s) - Do Not Disturb on", name)
      apply()
    end)
  elseif not inUse and enabledByUs then
    runShortcut(SHORTCUT_OFF, function()
      enabledByUs = false
      log.i("cameras free - Do Not Disturb off")
      apply()
    end)
  end
end

local function schedule()
  -- Read the state now only to pick the delay; apply() re-reads when it fires.
  local delay = anyCameraInUse() and ON_DELAY or OFF_DELAY

  if pending then pending:stop() end
  pending = hs.timer.doAfter(delay, function()
    pending = nil
    apply()
  end)
end

local function watchCameras()
  for _, camera in ipairs(watched) do
    pcall(camera.stopPropertyWatcher, camera)
  end
  watched = {}

  for _, camera in ipairs(hs.camera.allCameras()) do
    -- The property name is always reported as "gone" whichever way the state
    -- went, so it tells us nothing; re-read isInUse() instead of trusting it.
    camera:setPropertyWatcherCallback(function() schedule() end)
    camera:startPropertyWatcher()
    watched[#watched + 1] = camera
  end
end

local function shortcutsInstalled()
  local output, ok = hs.execute("/usr/bin/shortcuts list")
  if not ok or not output then return false end

  local found = {}
  for line in output:gmatch("[^\n]+") do
    found[line] = true
  end

  return found[SHORTCUT_ON] and found[SHORTCUT_OFF]
end

--- Start watching. Returns the module, or nil if the shortcuts are missing.
function M.start()
  if not shortcutsInstalled() then
    log.ef("missing shortcuts - create '%s' and '%s' in the Shortcuts app, each a single Set Focus action, then reload",
      SHORTCUT_ON, SHORTCUT_OFF)
    return nil
  end

  active = true
  watchCameras()

  -- Cameras come and go (an iPhone waking, a webcam unplugged), so the
  -- per-device watchers have to be re-registered when the list changes.
  hs.camera.setWatcherCallback(function()
    watchCameras()
    schedule()
  end)
  hs.camera.startWatcher()

  -- A camera may already be live when this loads.
  schedule()

  return M
end

--- Stop watching. Releases Focus if this module had turned it on, so stopping
--- never leaves you stuck in Do Not Disturb.
function M.stop()
  active = false

  if pending then
    pending:stop()
    pending = nil
  end

  for _, camera in ipairs(watched) do
    pcall(camera.stopPropertyWatcher, camera)
  end
  watched = {}

  if hs.camera.isWatcherRunning() then hs.camera.stopWatcher() end

  -- A shortcut still in flight may be turning Focus on, and its result will
  -- be ignored now, so release Focus for it too. This waits on purpose: a
  -- caller stopping the module (or reloading) expects Focus off on return.
  local inFlight = running ~= nil
  if running then
    running:waitUntilExit()
    running = nil
  end

  if enabledByUs or inFlight then
    local output, ok = hs.execute(string.format("/usr/bin/shortcuts run '%s'", SHORTCUT_OFF))
    if not ok then
      log.ef("shortcut '%s' failed: %s", SHORTCUT_OFF, (output or ""):gsub("%s+$", ""))
    end
    enabledByUs = false
  end
end

--- Whether this module currently has Focus turned on. For the console.
function M.isActive()
  return enabledByUs
end

return M
