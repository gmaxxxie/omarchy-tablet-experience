# Omarchy Tablet Experience (ThinkPad X12)

Project home for building a **Laptop / Tablet mode** extension on Omarchy 4.0.1 + Hyprland 0.56.2 for the **Lenovo ThinkPad X12 Detachable Gen 1**.

## One-click install (marketplace format)

The repository root IS the plugin root (manifest at root, per the [Omarchy plugin conventions](https://omarchyplugins.com/develop.html)):

```sh
# plugin (QML service + bar button) — standard Omarchy git install:
omarchy plugin add https://github.com/gmaxxxie/omarchy-tablet-experience.git --enable

# system side (helper daemons, Hyprland hooks, packages) — from the cloned plugin dir:
~/.config/omarchy/plugins/maxt.tablet-experience/install.sh
```

`install.sh` copies `scripts/` to `~/.local/bin`, wires `hyprland.lua` (touch swipe + `SUPER+U` / `SUPER+SHIFT+U` / `SUPER+SHIFT+R`) and autostart hooks, and installs required packages (squeekboard, iio-sensor-proxy, python-evdev). Every modified file gets a `*.bak.<timestamp>`; `uninstall.sh` reverses everything (only touching files that byte-match the install). Preview with `./install.sh --dry-run --no-packages`.

Options: `--no-packages` · `--with-ime` (fcitx5-rime + CJK fonts) · `--with-camera` (libcamera) · `--dry-run`.

**Hardware defaults target the ThinkPad X12** (folio keyboard USB `17ef:60fe`, Wacom touchscreen), all overridable via env vars:

| Var | Meaning | Default |
|---|---|---|
| `OMARCHY_ROTATE_DISPLAY` | display to rotate | first Hyprland monitor |
| `OMARCHY_KB_VENDOR` / `OMARCHY_KB_PRODUCT` | detachable-keyboard USB id | `17ef` / `60fe` |
| `OMARCHY_TOUCH_NAME` | space-separated substrings matching the touch device name | `wacom finger` |

Uninstall: `uninstall.sh` (system side) + `omarchy plugin remove maxt.tablet-experience`.

![Tablet-mode window-manage popup](preview.png)

### Upgrade compatibility (Omarchy / Hyprland updates)

- **The plugin never modifies Omarchy's package files** (`/usr/share/omarchy` —
  verified `pacman -Qkk omarchy` → 0 altered). All changes live in the user
  config area and official extension points: `plugins/`, `Extensions` menu
  jsonc, `autostart.lua` (`o.launch_on_start`), and a 1-line `require` in
  `hyprland.lua`. Package upgrades never silently overwrite those; worst
  case new defaults arrive as `.pacnew` files and the hooks go missing
  (visible, not destructive).
- **After any system upgrade, self-check with:**

  ```sh
  ~/.config/omarchy/plugins/maxt.tablet-experience/install.sh --verify
  ```

  It checks the 8 helper scripts, the hypr hooks, plugin enabled state,
  live keybinds and running daemons — read-only, exits 1 on anything broken.
  Recovery is always the same idempotent re-run: `install.sh`.
- **Platform API dependencies** (outside our control, affect every plugin):
  Hyprland's Lua runtime API (`hyprctl eval "hl.monitor(...)"` etc.),
  Quickshell/QML APIs, and the `omarchy-shell` / `omarchy-osd` / `omarchy plugin`
  CLI contracts used by scripts and hooks.
- **Namespace:** helper binaries use the reserved `texp-*` prefix
  (`texp-vk`, `texp-rotate`, …) so they can never collide with official
  `omarchy-*` tools (earlier releases used `omarchy-*` — migrated because a
  future official binary of the same name would shadow them via PATH).

## Status board

| Phase | Feature | Status |
|---|---|---|
| 0 | Hardware/software audit | ✅ `AUDIT.md` |
| 1 | Touchscreen basic support | ✅ recognized + enabled; bar-touch issue **resolved via reboot** (runtime wedge, see `DEBUG-TOUCH-BAR.md`) |
| 2 | Native workspace swipe | ✅ edge-swipe verified working (user-tested), `gestures:workspace_swipe_touch=true` |
| 3 | Input method (Chinese) | ✅ fcitx5 + Rime + Wanxiang deployed + **LTS gram 语言模型已装入** (~400MB, 无 sudo) |
| 4 | Virtual keyboard | 🟡 squeekboard (extra) core path **working**: D-Bus toggle ✓, bottom-edge up-swipe show ✓ (user-tested), `SUPER+U` bind ✓; **v0.7.0: top-bar keyboard icon toggle added** (show/hide + live state highlight, same texp-vk path); pending autostart + touch/Chinese input verification |
| 5–11 | rotation / state / UI / auto-switch | P5 ✅ · P7/8 ✅ · **P6/9/10 live since v0.6.1** (auto-switch ✓; auto-orient ✓ — orientation reads `normal` via sysfs; see 2026-08-29 note) · **v0.6.2: tablet popup rotation = ⟲/⟳ icon steps** (90° relative from current, replaces the numeric picker) · **v0.6.3: correct rotate-right glyph** (`fa-rotate` U+F2F1 renders as the refresh circle → `fa-rotate_right` U+F2F9) · **P11 ✅ `texp-touch` multi-touch daemon (synthetics-tested, live, needs 2-finger pass)** · **v0.7.1: laptop mode always forces display back to 0° landscape** (keyboard dock → face-up panel; silent, tablet rotation preset preserved for next tablet entry) |
| 12 | **Hardware full bring-up (esp. camera)** | 🟡 camera **verified via UVC** (RGB MJPG + IR, see `PHASE12-HARDWARE.md`); IPU6 CSI confirmed dead end. libcamera now installed → browser test pending relogin. Fingerprint enrolled+live, BT scan verified, audio sinks/sources present |
| 13 | **Tablet window manage (v0.5.6: close / move ws / layout + Auto⇄Fixed rotation)** | ✅ live. Always-mounted bar entry: laptop → `Laptop` button (popup = mode/rotation only); tablet → `窗口` button unlocking close ✕ / move-to-workspace grid (1–10) / Dwindle·Scrolling switch (persisted like SUPER+L). Max/min/restore removed. Targeting = window under last touch, visible windows only. **New: texp-touch single-finger tap now FOCUSES the tapped visible window** (Hyprland touch never focuses — Touch.cpp; this mattered in scrolling layout where windows sit off-view). Verified: focus dispatch changes activewindow; move/layout/close re-verified. Notification feedback on move/layout. **v1.8: window manage moved OUT of ⋮ into a dedicated window icon** (close + move-to-workspace grid); ⋮ keeps rotation / layout / hidden bar icons |
| 14 | **Voice input (v1.5, voxtype hold-to-talk + ⏎ v1.6 + Delete/Clear v1.10 + direction pad & VK-exclusivity v1.11)** | ✅ implemented. Tablet bar **mic icon** → bottom-right hold-to-talk button (MultiPointTouchArea, mouse+touch); press = `voxtype record start` (SIGUSR1), release = `record stop` (SIGUSR2 → transcribe + type at cursor via wtype, CJK OK). **English action row** below: Delete (BackSpace), Clear (select-all + delete), Enter (Return) to fix/submit the dictated line. **v1.11: left-side direction pad** (2x2 grid ↑↓←→, wtype -k Left/Right/Up/Down) floats on the left edge for caret positioning; **voice input ↔ virtual keyboard are mutually exclusive** (opening one closes the other — showVoiceInput hides the OSK, and a VK-visible poll closes voice). Live state mirrors `$XDG_RUNTIME_DIR/voxtype/state`; overlay 240x230 + dirpad 168x168 both verified mapped bottom-right / left-center. IPC: `voiceInputToggle|Show|Hide`. voxtype-bin 1.0.0 deployed (daemon + sensevoice zh + wtype) |
| 15 | **Virtual-keyboard: number row (v1.7) → wvkbd-deskintl (v1.12)** | ✅ done. v1.7 added a number row to squeekboard's custom us/us_wide layouts for Chinese candidates. **v1.12: switched the keyboard to wvkbd-deskintl** (wlroots-native) because squeekboard lacks Ctrl/Super/Alt/Shift — needed for Omarchy/AI-terminal keyboard shortcuts. wvkbd-deskintl has **Ctrl/Super/Alt/Shift/AltGr + F1-F12 + number row + arrows**, sized via `-H/-L` (350px). texp-vk now controls it via SIGUSR1/2/RTMIN and mirrors visibility to `~/.local/state/texp-vk/visible` (BarWidget/Service poll that for the icon highlight + voice↔VK exclusivity). squeekboard (with the number-row layout) stays as fallback. Build helper `scripts/texp-install-wvkbd` (AUR ships only mobintl). Verified: texp-vk toggle/hide work, wvkbd surface 1536x350, Hyprland sees `hl-virtual-keyboard-wvkbd-deskintl`, voice↔VK exclusivity both directions |
| 16 | **Dedicated tablet window-manage icon (v1.8) + top-bar-disappears-on-detach fix (v1.8.1)** | ✅ v1.8: close/move moved out of ⋮ into its own window icon popup. v1.8.1 BUGFIX: detaching the keyboard sometimes hid the top bar — root cause = the 5px top-edge strip's TapHandler swallowed a stray touch landing on it at the moment tablet mode starts, flipping `bar-off` on. Fix: the strip now only **arms 2s after it shows** (re-arms each show), so the detach-time touch can't toggle the bar. Verified: clean tablet entry no longer sets bar-off (bar stays shown); strip tap toggle still works after the debounce |
| 17 | **Auto-orient calibration (v1.9)** | ✅ FIXED. User reported "holding landscape but screen went portrait" — root cause: `texp-orient`'s X/Y axis→posture mapping followed the iio convention but is rotated vs the X12 accelerometer's actual mounting, so handheld-landscape (−Y gravity) was misclassified `left-up` → rotated 90°. 4-position physical calibration (2026-09-02) measured: landscape 打横 → −Y, right-long-edge-down → +X, left-long-edge-down → −X, upside-down → +Y. New classify(): +X→left-up(90°), −X→right-up(270°), +Y→bottom-up(180°), −Y→normal(0°), ±Z unchanged (flat). Self-check with all 4 captured vectors passes; live sensor now labels landscape `normal` and screen holds 0° with auto-orient on |
| 18 | **Two-finger tap = right click (v1.12.2)** | ✅ user asked whether 2-finger touch equals right-click (it did NOT — texp-touch mapped it to close-panels). Changed tap2 to **right click** via ydotool: move cursor to touch point (`ydotool mousemove --absolute`) + `ydotool click 3`. Added ydotool to required packages, a uinput udev rule (`/dev/uinput` root:input 0660), enabled `ydotool.service` (needs `input` group at login; current session starts it via `newgrp input`), and setpriv-started texp-touch under the input group. Verified `ydotool click 3` exit 0 + socket up. NOTE: this replaced the old "2-finger tap closes panels" gesture |

## System facts (captured 2026-08-28)

- **Omarchy** 4.0.1-1 (Quattro), **Hyprland** 0.56.2 (Lua config API), **Quickshell** 0.3.1-1, SDDM + uwsm Wayland session
- **Monitor** `eDP-1` 1920x1280@60, scale 1.6, transform 0 (logical 1200x800)
- **Touchscreen** `wacom-hid-525d-finger` (event15) · **Pen** `wacom-hid-525d-pen` (event14)
- **Keyboard** = USB `17ef:60fe` "Darfon Folio case" → attach/detach = USB plug/unplug (future auto-mode signal)
- **Sensors** iio: accel (`accel_3d`) ✓ live · gyro ✓ · hinge (`in_angl0/1/2` = hinge/screen/keyboard, raw=0, unverified)
- **IME**: Fcitx5 (Omarchy-managed `omarchy-fcitx5.service`, Wayland text-input-v3) + Rime + **Wanxiang v17.7.1** (schema `wanxiang`, in `~/.local/share/fcitx5/rime/`, deployed ✓)
- **Camera**: Syntek `174f:118f` (USB) on Intel **IPU6** stack (PCI 00:05.0, `/dev/video0–13`) — output NOT yet verified (Phase 12)
- **Other hw seen**: fingerprint `06cb:00bd` Synaptics Prometheus · BT `8087:0026` AX201 · audio `sof-hda-dsp` — all pending verification
- **Fonts**: noto-fonts-cjk + wqy-microhei ✓

## Files changed so far (all reversible, backups in place)

| Path | Change | Backup |
|---|---|---|
| `~/.config/hypr/hyprland.lua` | appended `require("hypr.tablet-experience")` | `hyprland.lua.bak.1787928342` |
| `~/.config/hypr/tablet-experience.lua` | NEW — plugin-owned generated config (Phase 2 swipe + Phase 4 `SUPER+U` vk bind) | latest edit 2026-08-29 |
| `~/.config/hypr/autostart.lua` | added `o.launch_on_start("texp-vk daemon")` (Phase 4 persistence) | `autostart.lua.bak.*` |
| `~/.local/bin/texp-window` + `scripts/texp-window` | v0.4 — `resolve|close|move <ws>|layout <dwindle|scrolling|toggle>` via 0.56 Lua API; only VISIBLE windows targeted; layout persisted like omarchy's SUPER+L; notify feedback | (repo archive) |
| `~/.local/bin/texp-close` + `scripts/texp-close` | REWRITTEN (v0.3) — panels first, then `texp-window resolve` (last touch or focused); `--at X Y`/`--dry-run` | (repo archive) |
| `~/.local/bin/texp-touch` + `scripts/texp-touch` | v0.5 — records last touch on real windows + **single-finger tap focuses the tapped visible window** (`hl.dsp.focus` via eval); tap2 = `texp-close --at`; skips bar/panels/VK | (repo archive) |
| `~/.local/bin/texp-rotate` + `scripts/texp-rotate` | v0.3 — ALSO sets `input:touchdevice:transform` to match the monitor (touch alignment on rotated screens was previously broken: Hyprland never recalibrates it) | (repo archive) |
| `~/.config/omarchy/plugins/maxt.tablet-experience/manifest.json` | v0.3.0 — kinds `service, bar-widget` (panel kind REVERTED — see pivot note) | — |
| `~/.config/omarchy/plugins/maxt.tablet-experience/BarWidget.qml` | v0.5 — always-mounted button (laptop label=“Laptop”, tablet label=“窗口”); manage section (close/move/layout) rendered only in tablet mode; Laptop/Tablet + rotation always; IPC `maxt.tablet-window` | (repo archive) |
| `~/.local/bin/texp-rotate` + `scripts/texp-rotate` | Phase 5 — rotation helper (transform 0/90/180/270) + OSD | (repo archive) |
| `~/.local/bin/texp-orient` + `scripts/texp-orient` | Phase 6 — IIO accel posture probe (sysfs, zero deps) | (repo archive) |
| `config/hypr/tablet-experience.lua` (this repo) | Phase 5 — archived copy incl. `SUPER+SHIFT+R` rotation-cycle bind | — |
| `PHASE12-HARDWARE.md` (this repo) | NEW — camera UVC verification + IPU6 dead-end analysis, fingerprint/BT/audio status | — |
| `~/.config/fcitx5/profile` | added `rime` as 2nd input method | `profile.bak.1787928474` |
| `~/.local/share/fcitx5/rime/` | NEW — Wanxiang v17.7.1 files | (download from GitHub releases) |

**Packages added (official `extra`, all removable):** fcitx5-rime, librime(+data), noto-fonts-cjk, wqy-microhei, python-pywayland (diagnostic tool — remove later), squeekboard, python-evdev (gesture daemon dep).

## Current runtime state (2026-08-29)

**Phase 5 — manual rotation (done, pending user touch-check):** `texp-rotate`
(script + OSD, live at `~/.local/bin/`, archived at `scripts/texp-rotate`)
rotates eDP-1 via `hyprctl eval "hl.monitor({...})"` — all 4 transforms
verified roundtrip. Binds `SUPER+SHIFT+R` → rotate to next orientation
(0°/90°/180°/270° cycle, `texp-rotate next`), added to
`tablet-experience.lua` (archived at `config/hypr/tablet-experience.lua`),
config reloaded clean, binds registered. Touch/pen mapping follows the
monitor automatically (`input:touchdevice:output=Auto`), awaiting physical
verification. (Original `SUPER+CTRL+0..3` binds REMOVED — they collided with
omarchy's `SUPER+CTRL+1..9` bar-panel keybinds; see AUDIT.)

**Phase 6 — auto-rotation (iio-sensor-proxy now installed; wiring pending):**
IIO accel_3d live (g=(−0.35,−6.61,−8.21), dominant −z ⇒ `normal`). Probe
`texp-orient` (sysfs; `--watch` to calibrate) classifies postures. Next:
wiring orientation→transform through the state machine (Phase 7 service hook).

**Phases 7+8 — Laptop/Tablet state machine + Omarchy plugin (done, live):** plugin v0.2.0
(on disk; **Phase 6 auto-orientation + Phase 9 keyboard watcher + Phase 10
auto-switch wiring included but pending activation — see the hot-reload note
below**):
- **Service.qml** — persistent mode (`PersistentProperties reloadableId`,
  `laptop|tablet` + `tabletRotation` preset off/0°/180°), idempotent apply
  (OSD + optional rotate on enter-tablet), Charm IPC:
  `omarchy-shell maxt.tablet-experience {getState|getMode|toggle|setMode|setRotation}`
- **v0.2.0 additions (phase 6/9/10):** `autoOrient` (opt-in; sensor-following
  rotation — the orientation probe polls `texp-orient --json` (sysfs accel,
  zero deps) every 1.5s since v0.6.1; iio-sensor-proxy is NOT usable on this
  board: `AccelerometerOrientation` sticks at "undefined" even with the device
  detected + tagged, so we classify from sysfs ourselves — verified live:
  `orientation=normal`), applies normal→0°/left-up→90°/bottom-up→180°/
  right-up→270° silently, tablet-mode only), `autoSwitchMode` (opt-in; USB
  17ef:60fe attach/detach
  via `texp-kbdetect` → laptop/tablet), IPC
  `setAutoOrient`/`setAutoSwitch`, extended getState. Boot marker log line on
  activation: `tablet-experience Service LOADED v2`.
- **BarWidget.qml** — mode button (left=toggle, right=rotation-preset ring);
  nerd glyphs verified in JetBrainsMono Nerd Font
- Menu rows `tablet.*` in `~/.config/omarchy/extensions/omarchy-menu.jsonc`
- Bind `SUPER+SHIFT+U` → toggle (`SUPER+T` and friends already taken)
- Enabled `--section right`; IPC verified live for phase 7/8 methods; phase
  6/9/10 methods verified by offline `quickshell -p` load (parses +
  instantiates cleanly).

**PLATFORM FINDING (v0.6.1):** plugin QML is read from the DISCOVERED plugin
folder at shell start — the `~/.cache/quickshell/qmlcache` is only a compile
cache and rebuilds from whatever source the plugin manager resolves. The real
trap: a SECOND folder under `~/.config/omarchy/plugins/` carrying a
`manifest.json` with the same id (`maxt.tablet-experience`) shadows/duplicates
the plugin and the shell serves ITS (stale) QML — rotation / window-manage /
auto-switch then call the old `omarchy-*` helpers and fail loudly in the
journal (`Process failed to start ... omarchy-kbdetect`) while the bar/shell
looks fine. Never keep backups or scratch copies with that manifest.json inside
the plugins dir (move them out, e.g. `~/.local/state/`). `install.sh --verify`
now checks for both stale `omarchy-*` refs in the plugin QML and duplicate
plugin folders.

**PLATFORM FINDING (v0.5): bar-widget QML components are cached like service QML — editing `BarWidget.qml` hot-reloads the plugin but keeps serving the OLD widget; the new code only appears after a full shell restart. `omarchy restart shell` can silently fail to relaunch (killed the shell, nothing came back, exit 0) — recovery: `hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("omarchy-launch-shell"))'` (actually cleaner: kill quickshell and let the `omarchy-launch-shell` supervisor relaunch it). Verify with `omarchy-shell shell debugBarGeometry` (widget row `slotVis/itemVis` must be true) and the `MAXT-WIDGET-ONLINE` probe in the journal.

**PLATFORM FINDING (recorded):** Omarchy service-plugin QML hot-reload does
NOT swap service code — the component is cached per URL; disable→enable and
`shell rescanPlugins` keep serving the ORIGINAL instance (verified: new IPC
methods absent, boot `console.log` missing after multiple reload cycles). New
plugin code applies only on a full omarchy-shell restart (next login).
`omarchy-shell` CLI itself is unaffected. This also means: keep the plugin
stable between logins; verify changes after a relogin.

**Phase 11 — multi-touch gestures (`texp-touch`, live, needs your 2-finger pass):**
passive evdev daemon (no grab) on the Wacom finger device; gestures only
run CLI/hyprctl (never synthesise input): **2-finger tap = VK toggle ·
2-finger swipe LEFT/RIGHT = workspace +1/-1 · 2-finger swipe DOWN = omarchy
menu**. hyprpm route considered and skipped (no gesture plugin for
Hyprland 0.56.2; external daemons as MVP dep rejected). Live-capture
protocol finding (2026-08-29): the panel IS true multi-touch (S0/S1/S2);
single-touch streams are slot-less (bare events imply slot 0), multi-touch
frames carry `ABS_MT_SLOT` per contact. The tracker is slot-keyed with
last-seen-slot fallback; the earlier "no SLOT events" claim (texp-vk
note) was disproven and corrected.
Classifier verified with 10 synthetic cases (all PASS); daemon running now
and autostarted (`autostart.lua`). **A physical two-finger pass is
pending** (my two live capture windows got no touches) — see Next actions.

**Hardware (Phase 12):** camera output verified — device is a USB camera bridge
with two UVC functions: `/dev/video64` RGB (MJPG 2592x1944 max) and
`/dev/video66` IR (GREY 640x480); real frames captured (`verify/cam-rgb-1280x720.jpg`;
see `PHASE12-HARDWARE.md`). Intel IPU6 CSI path is a confirmed dead end
(`IPU6 in secure mode`, `ov8856: failed to find sensor: -5`) — `/dev/video0–63`
isys nodes are junk. Fingerprint: enrolled (`#0: right-index-finger`), sudo PAM
prompt verified live. BT AX201 scan verified. Audio: SOF sinks + 2 mics via
WirePlumber. **`libcamera` installed (user) — browser camera test pending a
relogin/restart so WirePlumber picks the UVC device up.**

- `gestures:workspace_swipe_touch = true` (Phase 2, verified)
- VK renderer: **squeekboard** — D-Bus `sm.puri.OSK0.SetVisible`, state property `.Visible` (toggle = read-then-invert)
- Gesture daemon: `~/.local/bin/texp-vk daemon` (also archived at `scripts/texp-vk` in this repo) — bottom 12% up-swipe → show; kb-visible + start ≥68% downward drag → dismiss; threshold/zone constants at top of file
- Wacom touch quirk: reports `ABS_MT_TRACKING_ID` **without** `ABS_MT_SLOT` events (fixed in daemon: tracks by touch-id)
- fcitx5 service enabled → auto-start on next login

## Next actions

**Today's work (2026-09-02, v1.5.0 → v1.12.2)** — one big tablet-input session,
16 commits (f190407..29056ff), all pushed to origin/main:

| Ver | What | Notes |
|---|---|---|
| 1.5.0 | **Voice input (voxtype hold-to-talk)** | top-bar mic icon → bottom hold-to-talk button; `voxtype record start/stop` (SIGUSR1/2), state mirrored from voxtype's state file; IPC `voiceInputToggle/Show/Hide` |
| 1.5.1 | voice button → bottom-right | relative anchor, 28px margins |
| 1.6.0 | ⏎ **Enter** button (wtype Return) | submit dictated line |
| 1.7.0 | **Virtual-keyboard number row** | custom squeekboard us/us_wide layouts + GNOME input-sources GSettings="us" (squeekboard resolves its layout name from there) |
| 1.8.0 | **Window-manage dedicated icon** | close ✕ / move-to-workspace 1-10 popup, no longer buried in ⋮ |
| 1.8.1 | **Top bar no longer disappears on keyboard detach** | root cause: 5px top-edge strip's TapHandler swallowed a stray touch at tablet-entry and flipped `bar-off`; strip now arms 2s after showing |
| 1.9.0 | **Auto-orient calibrated** | 4-position physical calibration fixed texp-orient's X/Y mapping (landscape −Y, right-down +X, left-down −X, upside-down +Y); self-check + live verified |
| 1.10.0 | **Delete / Clear** buttons (BackSpace / select-all+delete) | beside Enter |
| 1.10.1 | English labels + tidy equal-width row | Delete/Clear/Enter, English hint |
| 1.10.2 | mic centered relative to action row | Column children are left-aligned by default |
| 1.11.0 | **Direction pad + voice↔VK exclusivity + VK arrows** | left-side ↑↓←→ caret keys; opening voice closes the OSK and vice-versa; arrow row in squeekboard layout |
| 1.12.0 | **Virtual keyboard → wvkbd-deskintl** | wlroots-native with Ctrl/Super/Alt/Shift/AltGr + F1-F12 + numbers + arrows, sized 350px; texp-vk controls it via signals + mirrors visibility to `~/.local/state/texp-vk/visible`; squeekboard stays as fallback; build helper `texp-install-wvkbd` (AUR ships only mobintl) |
| 1.12.1 | direction pad → **bottom-left**, same line as Delete/Clear/Enter | 44px single arrow row, aligned bottom edge |
| 1.12.2 | **Two-finger tap = RIGHT CLICK** | was close-panels; injected via ydotool (uinput) `click 3` at the touch point; added ydotool + uinput udev rule + ydotool.service; current session runs daemons under `input` group via newgrp/setpriv |

---

**TODO / open items & plans (2026-09-02)**

Pending user verification (touchscreen — needs physical hands):
- [ ] wvkbd-deskintl **Chinese input** (fcitx5 candidates via number row) — tap-test
- [ ] wvkbd **modifier keys** (Sup/Ctr/Alt) in an AI terminal — tap-test
- [ ] **two-finger tap = right-click** (context menu / terminal paste)
- [ ] full voice flow: hold-talk → transcribe → ↑↓←→ caret → Delete/Clear → Enter
- [ ] top-bar detach fix (2s strip debounce) — long-term observe
- [ ] voice direction pad / action-row alignment — visual check (`~/voice-dirpad-align.png`)

Known caveats / follow-ups:
- [ ] Current session lacks the `input` group (needs re-login): ydotoold + texp-touch are running under it via newgrp/setpriv; next login the ydotool.service + autostart take over automatically
- [ ] wvkbd panel height is 350px (`-L`); tune if too big/small — `OMARCHY_VK_HEIGHT_LANDSCAPE`
- [ ] wvkbd-deskintl is built by `scripts/texp-install-wvkbd` (needs cairo/pango/wayland/libxkbcommon dev pkgs) — validate on a fresh machine
- [ ] replacing 2-finger-close-panels lost the close gesture (gesture set is full) — move it to another gesture (e.g. 4-finger tap) if still wanted

Plans / ideas:
- [ ] voice text post-processing / replacement table (voxtype supports it)
- [ ] wvkbd color scheme matched to the current theme
- [ ] Chinese candidate UX on wvkbd (e.g. dedicated pinyin layer / bigger digits)
- [ ] confirm squeekboard fallback path still clean after the wvkbd switch (it stays installed)

**Done this round (2026-09-02, v1.4.0): no auto-rotate on tablet entry.**

User: "切换为tablet时，不用自动旋转屏幕90度的，只要根据如果是自动就按照识别到的方向，如果是固定方向也是先不旋转的"
- applyNext no longer defaults the rotation preset to `auto` on tablet entry,
  and no longer applies a fixed preset either — the display keeps its current
  angle on every tablet entry. Rotation now happens ONLY when the user asks
  (popup Auto / ⟲⟳ / setRotation) or, with the `auto` preset already on,
  follows the sensor posture (autoOrient path unchanged).
- Verified live: tablet entry with preset off → transform stays 0; `auto` →
  follows sensor (left-up → 1); fixed 2 → applied only when explicitly set
  (entry stays 0); laptop always resets to 0. Widget rotation header fixed to
  show "off" instead of "undefined".

**Done this round (2026-09-02, v1.3.0): per-icon on/off toggles + Hide/Show all.**

User: "似乎没有实现；且加上隐藏的 icon 可以是 on/off 切换来是否展示；也应该也有 hide all or show all 快速全部切换"
- Each hidden bar icon is now an on/off toggle in the ⋮ popup (✓ mark +
  `active` highlight = on the bar; tap toggles hide/show). New service helpers
  `hideBarWidget <id>` / `showAllBarIcons()` / `hideAllBarIcons()`; the
  snapshot stays in shell.json during these so both directions work instantly
  and nothing re-pares itself afterwards. Verified live: toggle weather on
  (`center: [clock, weather]`) / off (`[clock]`), Show all → full 4/5/8 with
  snapshot held, Hide all → pared 3/1/4, stable in tablet afterwards.
- Also fixed the likely cause of "似乎没有实现": the plugin service QML is
  re-instantiated by omarchy after every shell.json mutation, and the bar
  widget cached the FIRST service instance — popup state/actions could hit a
  stale object and appear dead. The widget now re-resolves the service every
  1.5 s (`serviceTimer`), so the popup toggles always talk to the live one.

**Done this round (2026-09-02, v1.2.2): "restore all bar icons" stays restored in tablet mode.**

**Done this round (2026-09-02, v1.2.1): bottom-edge up-swipe disabled.**

User request: "虚拟键盘用手指在屏幕从下往上展示的先取消吧" — the texp-vk
daemon (bottom-edge up-swipe → show VK, down-drag → dismiss) is no longer
autostarted: removed from the install.sh autostart wiring and from the live
`autostart.lua`, the running daemon was killed, and --verify now ASSERTS the
hook is absent. The virtual keyboard itself is untouched: `SUPER+U`, the
tablet bar button, and the 3-finger tap (`texp-vk toggle`) all keep working,
and re-enabling the swipe is one line in autostart.lua (documented).

**Done this round (2026-09-02, v1.2.0): portrait/tablet bar declutter.**

User: "竖屏顶部栏图标过多会遮盖" then "或者简化, laptop 就是默认多图标, tablet 模式就是简化的模式" — the bar layout is now MODE-driven:

- LAPTOP = default full bar (restored verbatim on every tablet→laptop switch).
- TABLET = simplified bar: essentials only (`omarchy.menu`, `workspaces`,
  `clock`, `tray`, `network`, `audio`, `power`, `maxt.tablet-experience`)
  plus the plugin's own two quick toggles (input method EN⇄中 via
  `fcitx5-remote -t`, and the virtual-keyboard button) and a **⋮** overflow
  button whose popup lists every hidden bar icon (tap = mount it back at its
  original slot, `bringBackBarWidget`), plus the existing window-manage /
  rotation sections. All config changes go through the shell's own
  `mutateShellConfig` (the same sanctioned path omarchy uses for
  transparency) — no omarchy package files are touched.
- **Restart/crash-proof state**: the verbatim pre-tablet layout is carried IN
  shell.json as `bar.layoutSnapshot` (a key Bar.qml ignores), replaced
  atomically with the pared `bar.layout` in ONE config write. Restore =
  `layout = layoutSnapshot` + delete, again one write. No separate state
  file, no PersistentProperties racing a plugin reload, self-healing on the
  1.5 s poll: a shell killed mid-tablet always recovers the original layout.
- **IPC/UI**: `getState` now reports `tabletLayoutActive` + `overflowWidgets`;
  new `bringBackBarWidget <id>` and `restoreBarIcons` methods. Layout
  mutations are deferred through a small FIFO (mutations issued inside an
  IPC handler are ignored by the shell's config writer; deferring onto a
  plain event-loop turn fixes it).
- **Verified live** (this machine): laptop full 4/5/8 → tablet pared 3/1/4 +
  snapshot key present + overflow lists 9 widgets (max.scene, keyboard-
  layout, indicators, system-update, weather, agents, bluetooth, tailscale,
  monitor) → `bringBackBarWidget omarchy.weather` puts weather back at its
  original center slot → `restoreBarIcons` brings the exact full layout back
  and drops the snapshot (<0.25 s) → setMode laptop auto-restores → shell
  restart in tablet leaves a consistent state (auto-laptop via keyboard
  presence restores to full; the pared+snapshot combination is intact if the
  mode survives).

**Done this round (2026-09-02, v1.1.0):** four user issues from real-device use.

1. **Laptop mode must always return to the default angle** — already shipped in
   v0.7.1/v0.7.2 (`pendingLaptopReset`/`tryLaptopReset`); re-verified live on
   the current session: tablet → sensor 90° (transform 1) → `setRotation 3`
   (transform 3) → Laptop → **transform 0**, plus a rapid tablet⇄laptop stress
   toggle mid-rotation also lands on 0. The tablet rotation preset is kept for
   the next tablet entry, only the DISPLAY is reset.

2. **After reboot the virtual keyboard bottom up-swipe stopped working** — root
   cause found on this machine: the gesture daemons (`texp-vk` / `texp-touch`)
   crashed instantly at login with `PermissionError` on `/dev/input/event*`
   (the desktop user has no read access: not in group `input`, no logind
   uaccess ACLs — `/etc/group` input line is empty and input nodes are
   `root:input 660`). Three-part fix:
   - `install.sh` now grants evdev access: a project udev rule
     (`/etc/udev/rules.d/99-tablet-experience-input.rules`,
     `TAG+="uaccess"` on `event*`) + `udevadm trigger` (logind honours it at
     device-add on later boots), plus `usermod -aG input $USER` — the
     guaranteed path for every login from then on. `uninstall.sh` removes the
     rule (byte-match only); `--verify` checks both.
   - both daemons now scan resiliently (skip unreadable nodes instead of
     crashing on event0), retry while the failure looks like missing
     permissions (infinite, 3 s; logged at most every 30 s), and only exit
     when /dev/input is empty entirely.
   - Activation verified live: after the user ran install.sh (sudo), the
     daemons were restarted under the new group
     (`newgrp input -c 'texp-vk daemon'` … — newgrp is the faithful current-
     session equivalent of the next login's group set) and BOTH went live:
     `texp-vk: watching /dev/input/event15 (Wacom HID 525D Finger); …` and
     `texp-touch: watching /dev/input/event15 (Wacom HID 525D Finger)`. Live
     testing also caught and fixed a path bug I introduced in the hardened
     texp-touch discovery (it returned the bare `event15` name instead of
     `/dev/input/event15`). At the next login/reboot the autostart hooks run
     the same daemons with the group already present — no newgrp needed.

3. **Tablet-mode top-bar toggle** — with no mouse there is no hover to reveal
   Omarchy's (optional) hidden/transparent top bar, so Service.qml now owns a
   thin full-width Top-layer edge strip (`maxt-tablet-bar-strip`, layerrule
   `zindex 3` above the bar): in tablet mode, tap when the bar is hidden
   (strip 16 px, faint grab pill) → show; tap again (strip shrinks to 5 px) →
   hide. It drives the official `omarchy-toggle-bar` (bar-off flag + syncHidden
   IPC) and mirrors the flag via the same probe Bar.qml uses (FileView on
   `~/.local/state/omarchy/toggles`). New IPC: `toggleBar` /
   `setBarHidden <on|off|toggle>`; `getState` now reports `barHidden`.
   Verified live: strip surface maps at (0,0,800x5) in tablet mode, grows to
   800x16 on `setBarHidden on`, bar parks at (0,-30) and returns on show.

4. **fcitx5 input-method switch must be reachable** — the built-in
   keyboard-layout widget only cycles xkb layouts, not fcitx input methods, and
   fcitx5's own switch is hidden, so the bar widget gained an IM button
   (**tablet mode only**, per user follow-up: laptop keeps the hardware
   keyboard and fcitx5's own trigger; tablet needs a touch entry): shows the
   active method (EN / 中 / other via `fcitx5-remote -n` mapping) and toggles
   with one tap (`fcitx5-remote -t`), polled every 1.5 s while visible.
   Live-verified the fcitx5 side: `-t` switches rime ⇄ keyboard-us, `-n`
   reports the active method; in laptop mode the button and its poller are
   hidden/unmounted.

**Done this round (2026-08-29, v0.7.2):** two UX fixes from the physical test pass. (1) The top-bar keyboard icon is now **tablet-mode only** (`visible: root.tablet` on vkButton; D-Bus state polling gated the same way) — in laptop the widget is a single button again (verified live: bar widget 37px → 71px ↔ 37px across modes via `debugBarGeometry`). (2) Laptop-mode display reset (v0.7.1) hardened: the reset to 0° is now queued (`pendingLaptopReset` + `tryLaptopReset()` retried from `rotateProcess.onStreamFinished`) instead of being silently dropped when a rotation from tablet mode is still in flight — the earlier `if (!rotateProcess.running)` guard could skip it entirely. Verified live: enter tablet (sensor→90°), ⟲ manual (180°), back to laptop → monitor + touch transform both 0; rapid tablet→laptop toggle mid-rotation also lands on 0.

**Done this round (2026-08-29, v0.7.0):** user asked for the simplest possible virtual-keyboard control — no (re)building a hide button into squeekboard (stock us/us_wide layouts ship **no** hide key at all; bottom-right is ⏎ Return — verified against both the installed 1.43.1 binary's embedded layout and current gitlab master). Added a dedicated **keyboard icon** to the always-mounted bar widget (fa-keyboard U+F11C, glyph verified in the bar font): click toggles squeekboard through `texp-vk toggle` (same path as SUPER+U / up-swipe, starts squeekboard on demand), and the icon highlights while the keyboard is visible by polling squeekboard's D-Bus `.Visible` every 1.5 s (350 ms right after a click) — same single source of truth texp-vk already uses, so icon, gesture, and shortcut never disagree. Layout: two WidgetButtons share one bar slot via a Row; popup, mode logic, and IPC untouched.

**Done this round (2026-08-29, v0.5.0):** two user issues fixed. (1) laptop mode had lost the bar entry (v0.4 hid the whole widget) → the button is always mounted now: laptop shows `Laptop` + a popup with Laptop/Tablet/rotation, tablet shows `窗口` + the full manage section. (2) in scrolling layout, tapping didn't focus windows → Hyprland touch NEVER focuses (Touch.cpp routes events to the surface under the finger but keeps keyboard focus), which only becomes obvious in scrolling; texp-touch now dispatches `hl.dsp.focus` on single-finger taps on a visible window (verified against the live session: activewindow follows the tap). Workspace-layout persistence and visible-only targeting unchanged.
**Earlier same day:** Wanxiang LTS gram 语言模型 installed — `~/.local/share/fcitx5/rime/wanxiang-lts-zh-hans.gram` (420MB, from `amzxyz/RIME-LMDG` release `LTS`), fcitx5 restarted, the `error opening gram db` journal error is gone, `rime_deployer --build` clean. No sudo needed. **Also done (sudo via fingerprint):** `gst-plugins-good` installed (`v4l2src` pipeline verified: `gst-launch-1.0 v4l2src … jpegdec` clean 3 frames); `intel-ipu6` + `intel-ipu6-isys` UNLOADED live and blacklisted (`/etc/modprobe.d/blacklist-ipu6.conf`) — junk `/dev/video0–63` gone (68 → 4 video nodes; UVC RGB/IR still at 64–67, recaptured 1280x720 MJPG frames OK).

0. **🎯 IMPORTANT — relogin to activate: the plugin's new v0.2.0 code (auto-orient, keyboard watcher, auto-switch) only loads on a fresh omarchy-shell (hot reload doesn't swap service QML — see AUDIT).** At that point the bar button, camera (wireplumber), gestures autostart, and plugin state all come up together.
1. **After relogin:** verify `tablet-experience Service LOADED v2` in journal; test `SUPER+SHIFT+R` rotation cycle + touch mapping; bar button left/right click; `SUPER+SHIFT+U`; menu → Tablet; then opt-in `omarchy-shell maxt.tablet-experience setAutoOrient on` + `setAutoSwitch on` (calibrate with `texp-orient --watch` first, then `setMode tablet`).
2. **Camera:** webcamtests.com in Chromium (libcamera now present after relogin).
3. **squeekboard typing + Rime** (`nihao` → candidates) — Phase 4 verification.
4. **User device tests:** fingerprint unlock; BT pair; speaker/mic.
5. **Optional:** ~~`gst-plugins-good`~~ ✅; ~~ipu6 blacklist~~ ✅ (68→4 video nodes); ~~Wanxiang LTS gram~~ ✅ — all done 2026-08-29.
6. **Tablet window manage — physical pass (live now, only in Tablet mode):** switch to tablet (SUPER+SHIFT+U), the bar shows `窗口`. Tap a window first, then: ✕ close / ➜ move-to-workspace grid (current workspace highlighted) / Dwindle·Scrolling switch — each move/layout should pop an Omarchy notification. Verify the target is the window you last touched; verify 2-finger tap still closes panels/windows.
7. Later: **Phase 11 two-finger validation** (no login needed, daemon already live): put two fingers together on screen → tap = close; swipe left/right = workspace; swipe down = menu. Gesture work is otherwise frozen — window manage is the official tablet close path now.

## Repository layout

```
omarchy-tablet-experience/            ← repo root = plugin root (marketplace contract)
├── manifest.json                  ← plugin manifest (service + bar-widget)
├── Service.qml                    ← Laptop/Tablet state machine + IPC
├── BarWidget.qml                  ← always-mounted bar button + popup
├── install.sh / uninstall.sh      ← one-command setup/teardown (reversible)
├── scripts/                       ← helper daemons (auto-installed to ~/.local/bin)
│   ├── texp-vk             ← VK toggle + bottom-edge swipe daemon
│   ├── texp-touch          ← multi-touch gestures + last-touch tracking
│   ├── texp-close          ← close panels/overlays/touched window (touch Esc)
│   ├── texp-window         ← tablet actions (close/move/layout; visible targets only)
│   ├── texp-rotate         ← rotation helper (+ touch-device transform sync)
│   ├── texp-orient         ← IIO accel posture probe (--watch to calibrate)
│   ├── texp-kbdetect       ← folio-keyboard USB presence (sysfs, no udev)
│   └── texp-bar-probe      ← uinput diagnostic (bar touch-hit verification)
├── config/hypr/tablet-experience.lua  ← Hyprland binds/swipe (installed + hooked)
├── AUDIT.md                      ← Phase 0 audit + progress log
├── DEBUG-TOUCH-BAR.md            ← top-bar touch investigation record
├── PHASE12-HARDWARE.md           ← hardware bring-up (camera UVC, IPU6 dead end)
└── LICENSE
```