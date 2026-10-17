# Window handler tests

Two suites covering `../window.lua`.

| File | Needs Hammerspoon? | Checks | What it proves |
|------|-------------------|--------|----------------|
| `window_spec.lua` | No | 28 | The geometry maths, deterministically |
| `live_spec.lua` | Yes | 20 per screen + cross-screen | It works on the real displays |

Run the simulated suite first. It's deterministic, needs nothing running, and
covers a fabricated two-screen layout with offset origins — which is where
most of the original bugs lived.

## Simulated suite

```bash
lua5.4 ~/.hammerspoon/tests/window_spec.lua
```

Stubs the `hs` API and two fake displays (a primary at `0,25` and a secondary
at `1800,0` with a different resolution), then runs every handler against
them. Exits non-zero on failure, so it works in a pre-commit hook.

Expected values are written as explicit arithmetic — `25 + (650 / 1440) * 1100
- 250` rather than `271.528` — so the reasoning is visible rather than being a
number you have to trust. Tolerance is 0.01.

## Live suite

```bash
hs ~/.hammerspoon/tests/live_spec.lua
```

Runs the full set against **each attached screen**, then the cross-screen
moves. With one display it reports that the cross-screen moves weren't
exercised rather than silently passing.

It borrows WezTerm's main window: saves the frame, takes focus, moves the
window through every case, then restores it. The last line confirms the
restore matched. If you switch terminals, change the app name on line 5.

## Reload before running the live suite

Lua caches `require`, so **a running Hammerspoon keeps the old `window.lua`
until you reload**. Edit the module and the live suite will happily test the
previous version.

```bash
hs -c "hs.reload()"
```

If that command hangs, that's expected — reloading invalidates the message
port the CLI is talking to, and it sometimes waits instead of erroring.
Dispatch it detached instead:

```bash
hs -c "hs.reload()" >/dev/null 2>&1 &
```

Then confirm it came back up:

```bash
hs -c 'return #hs.hotkey.getHotkeys()'   # expect 9
```

## Syntax check without running anything

```bash
luac5.4 -p ~/.hammerspoon/window.lua ~/.hammerspoon/init.lua
```

Silent means both parse. Worth doing before a reload — a syntax error in
`init.lua` leaves you with no hotkeys at all.

## Reading the output

Position is asserted tightly (3px live, 0.01 simulated). **Size is asserted
loosely in the live suite only** — within 25% — because apps resize themselves
after a scripted resize. WezTerm rounds to character cells and has clamped
`1290` to `1134` on one run and honoured it on the next. A real transform bug
would be off by more than 2x, so the loose bound still catches one; the exact
arithmetic is `window_spec.lua`'s job.

The cross-screen checks print `fits: size should be KEPT` or `too big: should
SHRINK to fit` so you can see which rule is under test.

## Two gotchas these suites handle, worth knowing if you write more

- **`hs.window.animationDuration` defaults to 0.2s.** Read a frame straight
  after setting it and you get the *pre-animation* value. Both suites zero it
  and restore it afterwards.
- **`focusedWindow()` drifts.** The handlers resolve the focused window
  themselves, so if focus moves mid-suite you're testing a different window
  than the one you positioned. `live_spec.lua` pins by window id and
  re-verifies before each check.

Any Accessibility call can also block on an unresponsive app, which wedges the
whole Hammerspoon runtime until it answers. Pass `-t <seconds>` to the `hs`
CLI so it gives up rather than hanging your shell.
