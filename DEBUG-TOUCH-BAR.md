# Debug Record — Top bar does not accept touch

> Status: ✅ **RESOLVED** · last updated 2026-08-28 (after reboot)
> Root cause: **runtime-state wedge in the pre-reboot compositor session** — a
> clean re-login restored bar touch with zero config changes.
> Symptom: tapping the Omarchy top bar ("omarchy-bar" layer surface) does nothing;
> the touch reaches the **desktop/background layer** instead (double-tap on the
> (former) bar area opens the wallpaper picker, which is `Background.qml`
> `onDoubleClicked`). Mouse clicks on the bar work fine.

## User timeline (authoritative)

1. **Fresh Omarchy install → tapping the top bar WORKED.**
2. Later, after "改了啥" (unspecified changes — **user to confirm**), bar taps stopped working.
3. This project's session added: Phase-2 gesture config + fcitx5/Rime/fonts install.
4. Current: bar taps pass through to the desktop.

## Experiments already done (each with user verification)

| # | Variable | Change | Result |
|---|---|---|---|
| 1 | `gestures:workspace_swipe_touch` | ON→OFF + `hyprctl reload` | ❌ still broken |
| 2 | fcitx5 | fully stopped (`systemctl --user stop`) | ❌ still broken |
| 3 | deduced suspects | touch device / fonts / rime data | ❌ irrelevant |

**Cleared:** Phase-2 gesture option, fcitx5 process, touchscreen hardware,
fonts, Rime deployment. The breakage either predates this project's session
(user-side changes since install) or lives in compositor/shell runtime state.

## Objective evidence gathered

### Raw touch coordinates are correct (event15 = Wacom Finger)

Captured with `cat /dev/input/event15` while user tapped 4 spots:

| tap | ABS_MT x | ABS_MT y | location (normalized) | match |
|---|---|---|---|---|
| 1 | 252 | 74 | (4.7%, 1.0%) | top-left bar ✓ |
| 2 | 179 | 111 | (3.3%, 1.5%) | top-left bar ✓ |
| 3 | 5082 | 6911 | (94%, 96%) | bottom edge ✓ |
| 4 | 5253 | 6832 | (97%, 95%) | bottom edge ✓ |

Device raw ranges ~0..5405 x, 0..7194 y (Wacom HID native calibration).
Finger placement is exactly where the user aimed — the device and libinput
are fine; the failure is downstream (compositor targeting / surface input).

### Layer surface map (`hyprctl layers`) — no occlusion

```
background  omarchy-background  0 0 1200 800   (pid 5302, quickshell)
top         omarchy-bar         0 0 1200 30    (pid 5302, quickshell)
overlay     (none)
```
No fcitx5 or other surface overlaps the bar.

### Process timeline

- Shell (pid 5302) & Hyprland started 84+ min before the complaint, never restarted.
- fcitx5 restarted at 22:47 by this project (rime setup) — cleared by experiment 2.

## Analysis so far (Hyprland 0.56.2 source, tag v0.56.2)

- Touch down path: `CInputManager::onTouchDown` → `refocus(TOUCH_COORDS)` →
  `mouseMoveUnified(..., overridePos)` hit-tests: IME popups → overlay LS →
  **top LS** → fullscreen → windows → bottom → background LS.
- `CViewHitTester::layerSurfaceAt` skips a surface only when its
  `effectiveInputRegion()` is empty; Quickshell **never sets wl_surface input
  regions** (verified in Quickshell source — only hyprland *visible region*
  is set) ⇒ the bar's input region is the full 1200x30 box ⇒ it *should* be hit.
- With correct coords + hittable 1200x30 bar at (0,0), taps at y≈1% of the
  screen should map inside the bar. They don't. **Root cause not yet found.**

## Open hypotheses (ordered)

1. **User-side config change since fresh install** (scale / GDK scale / theme /
   GNOME leftovers / input tweaks / an extra monitor tried earlier). Need the
   user's memory of "后续改了啥". Most likely to explain "worked at install".
2. **Runtime state wedged in this compositor session** → the planned reboot
   tests this directly.
3. Something layered above the bar that `hyprctl layers` doesn't show
   (tablet-mode specific surface, xdg popup, fcitx5 text-input popup).

## Post-reboot test — RESULT: PASS

Rebooted, logged back in (fcitx5 auto-started via `omarchy-fcitx5.service`, swipe
was OFF). Tapping the top bar **works** — bar buttons respond, no pass-through
to the desktop/background. Runtime-state wedge confirmed as the root cause;
no config-level difference vs fresh install.

### Resolution actions taken

1. Re-enabled `gestures:workspace_swipe_touch = true` in
   `~/.config/hypr/tablet-experience.lua` (backup `tablet-experience.lua.bak.swipe-off`),
   confirmed via `hyprctl getoption` + zero `configerrors`. → **Phase 2 resumed.**
2. Next: user test of edge-swipe workspace switching.

## Post-reboot test (original plan)

1. Reboot / log back in (fcitx5 unit is **enabled**, will start fresh; swipe
   gesture remains OFF).
2. Tap the top bar.
   - **Works** ⇒ runtime-state wedge; resume Phase 2 (re-enable swipe), then
     Phase 4 (fcitx5 VK) with a re-login test after each.
   - **Broken** ⇒ config-level difference vs fresh install ⇒ enumerate the
     user's own changes, or diff `~/.config/hypr/` + `~/.config/omarchy/`
     against `/usr/share/omarchy/default/` + backups.

## Commands for re-diagnosis (if needed)

```bash
hyprctl layers                       # layer surface map (expect 1200x30 bar)
cat /dev/input/event15 | hexdump     # raw touch while tapping (group input)
hyprctl configerrors                 # config sanity
hyprctl devices                      # device list (look for change vs audit)
diff -u ~/.config/hypr/input.lua /usr/share/omarchy/default/hypr/input.lua
```

## Things NOT to forget (later phases)

- Restore `gestures:workspace_swipe_touch` after the touch fix is solid.
- Restart fcitx5 (or re-login) before testing Chinese input / Rime again.
- Remove `python-pywayland` once diagnostics are done (`sudo pacman -R`).