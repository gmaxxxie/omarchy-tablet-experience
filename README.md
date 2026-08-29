# Omarchy Tablet Experience (ThinkPad X12)

Project home for building a **Laptop / Tablet mode** extension on Omarchy 4.0.1 + Hyprland 0.56.2 for the **Lenovo ThinkPad X12 Detachable Gen 1**.

> **Current stage: PHASE 5+7/8 — rotation working (SUPER+SHIFT+R cycles); Laptop/Tablet state machine + Omarchy bar-widget plugin live (`maxt.tablet-experience`); Phase 12 camera verified via UVC**
> Working location: `~/.config/omarchy/plugins/` (the plugin), source/docs live in this folder.

## Status board

| Phase | Feature | Status |
|---|---|---|
| 0 | Hardware/software audit | ✅ `AUDIT.md` |
| 1 | Touchscreen basic support | ✅ recognized + enabled; bar-touch issue **resolved via reboot** (runtime wedge, see `DEBUG-TOUCH-BAR.md`) |
| 2 | Native workspace swipe | ✅ edge-swipe verified working (user-tested), `gestures:workspace_swipe_touch=true` |
| 3 | Input method (Chinese) | ✅ fcitx5 + Rime + Wanxiang deployed + **LTS gram 语言模型已装入** (~400MB, 无 sudo) |
| 4 | Virtual keyboard | 🟡 squeekboard (extra) core path **working**: D-Bus toggle ✓, bottom-edge up-swipe show ✓ (user-tested), `SUPER+U` bind ✓; pending autostart + touch/Chinese input verification |
| 5–11 | rotation / state / UI / auto-switch | 🟡 P5 ✅ · P7/8 ✅ · P6/9/10 wired on disk (auto-orient + kb watcher + auto-switch, opt-in) ⏳ activate at next login · **P11 ✅ `omarchy-touch` multi-touch daemon (synthetics-tested, live, needs 2-finger pass)** |
| 12 | **Hardware full bring-up (esp. camera)** | 🟡 camera **verified via UVC** (RGB MJPG + IR, see `PHASE12-HARDWARE.md`); IPU6 CSI confirmed dead end. libcamera now installed → browser test pending relogin. Fingerprint enrolled+live, BT scan verified, audio sinks/sources present |

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
| `~/.config/hypr/autostart.lua` | added `o.launch_on_start("omarchy-vk daemon")` (Phase 4 persistence) | `autostart.lua.bak.*` |
| `~/.local/bin/omarchy-rotate` + `scripts/omarchy-rotate` | Phase 5 — rotation helper (transform 0/90/180/270) + OSD | (repo archive) |
| `~/.local/bin/omarchy-orient` + `scripts/omarchy-orient` | Phase 6 — IIO accel posture probe (sysfs, zero deps) | (repo archive) |
| `config/hypr/tablet-experience.lua` (this repo) | Phase 5 — archived copy incl. `SUPER+SHIFT+R` rotation-cycle bind | — |
| `PHASE12-HARDWARE.md` (this repo) | NEW — camera UVC verification + IPU6 dead-end analysis, fingerprint/BT/audio status | — |
| `~/.config/fcitx5/profile` | added `rime` as 2nd input method | `profile.bak.1787928474` |
| `~/.local/share/fcitx5/rime/` | NEW — Wanxiang v17.7.1 files | (download from GitHub releases) |

**Packages added (official `extra`, all removable):** fcitx5-rime, librime(+data), noto-fonts-cjk, wqy-microhei, python-pywayland (diagnostic tool — remove later), squeekboard, python-evdev (gesture daemon dep).

## Current runtime state (2026-08-29)

**Phase 5 — manual rotation (done, pending user touch-check):** `omarchy-rotate`
(script + OSD, live at `~/.local/bin/`, archived at `scripts/omarchy-rotate`)
rotates eDP-1 via `hyprctl eval "hl.monitor({...})"` — all 4 transforms
verified roundtrip. Binds `SUPER+SHIFT+R` → rotate to next orientation
(0°/90°/180°/270° cycle, `omarchy-rotate next`), added to
`tablet-experience.lua` (archived at `config/hypr/tablet-experience.lua`),
config reloaded clean, binds registered. Touch/pen mapping follows the
monitor automatically (`input:touchdevice:output=Auto`), awaiting physical
verification. (Original `SUPER+CTRL+0..3` binds REMOVED — they collided with
omarchy's `SUPER+CTRL+1..9` bar-panel keybinds; see AUDIT.)

**Phase 6 — auto-rotation (iio-sensor-proxy now installed; wiring pending):**
IIO accel_3d live (g=(−0.35,−6.61,−8.21), dominant −z ⇒ `normal`). Probe
`omarchy-orient` (sysfs; `--watch` to calibrate) classifies postures. Next:
wiring orientation→transform through the state machine (Phase 7 service hook).

**Phases 7+8 — Laptop/Tablet state machine + Omarchy plugin (done, live):** plugin v0.2.0
(on disk; **Phase 6 auto-orientation + Phase 9 keyboard watcher + Phase 10
auto-switch wiring included but pending activation — see the hot-reload note
below**):
- **Service.qml** — persistent mode (`PersistentProperties reloadableId`,
  `laptop|tablet` + `tabletRotation` preset off/0°/180°), idempotent apply
  (OSD + optional rotate on enter-tablet), Charm IPC:
  `omarchy-shell maxt.tablet-experience {getState|getMode|toggle|setMode|setRotation}`
- **v0.2.0 additions (phase 6/9/10):** `autoOrient` (opt-in; polls
  `net.hadess.SensorProxy.AccelerometerOrientation` via busctl every 1.5s,
  applies normal→0°/left-up→90°/bottom-up→180°/right-up→270° silently,
  tablet-mode only), `autoSwitchMode` (opt-in; USB 17ef:60fe attach/detach
  via `omarchy-kbdetect` → laptop/tablet), IPC
  `setAutoOrient`/`setAutoSwitch`, extended getState. Boot marker log line on
  activation: `tablet-experience Service LOADED v2`.
- **BarWidget.qml** — mode button (left=toggle, right=rotation-preset ring);
  nerd glyphs verified in JetBrainsMono Nerd Font
- Menu rows `tablet.*` in `~/.config/omarchy/extensions/omarchy-menu.jsonc`
- Bind `SUPER+SHIFT+U` → toggle (`SUPER+T` and friends already taken)
- Enabled `--section right`; IPC verified live for phase 7/8 methods; phase
  6/9/10 methods verified by offline `quickshell -p` load (parses +
  instantiates cleanly).

**PLATFORM FINDING (recorded):** Omarchy service-plugin QML hot-reload does
NOT swap service code — the component is cached per URL; disable→enable and
`shell rescanPlugins` keep serving the ORIGINAL instance (verified: new IPC
methods absent, boot `console.log` missing after multiple reload cycles). New
plugin code applies only on a full omarchy-shell restart (next login).
`omarchy-shell` CLI itself is unaffected. This also means: keep the plugin
stable between logins; verify changes after a relogin.

**Phase 11 — multi-touch gestures (`omarchy-touch`, live, needs your 2-finger pass):**
passive evdev daemon (no grab) on the Wacom finger device; gestures only
run CLI/hyprctl (never synthesise input): **2-finger tap = VK toggle ·
2-finger swipe LEFT/RIGHT = workspace +1/-1 · 2-finger swipe DOWN = omarchy
menu**. hyprpm route considered and skipped (no gesture plugin for
Hyprland 0.56.2; external daemons as MVP dep rejected). Live-capture
protocol finding (2026-08-29): the panel IS true multi-touch (S0/S1/S2);
single-touch streams are slot-less (bare events imply slot 0), multi-touch
frames carry `ABS_MT_SLOT` per contact. The tracker is slot-keyed with
last-seen-slot fallback; the earlier "no SLOT events" claim (omarchy-vk
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
- Gesture daemon: `~/.local/bin/omarchy-vk daemon` (also archived at `scripts/omarchy-vk` in this repo) — bottom 12% up-swipe → show; kb-visible + start ≥68% downward drag → dismiss; threshold/zone constants at top of file
- Wacom touch quirk: reports `ABS_MT_TRACKING_ID` **without** `ABS_MT_SLOT` events (fixed in daemon: tracks by touch-id)
- fcitx5 service enabled → auto-start on next login

## Next actions

**Done this round (2026-08-29):** Wanxiang LTS gram 语言模型 installed —
`~/.local/share/fcitx5/rime/wanxiang-lts-zh-hans.gram` (420MB, from
`amzxyz/RIME-LMDG` release `LTS`), fcitx5 restarted, the `error opening gram
db` journal error is gone, `rime_deployer --build` clean. No sudo needed.
**Also done (sudo via fingerprint):** `gst-plugins-good` installed
(`v4l2src` pipeline verified: `gst-launch-1.0 v4l2src … jpegdec` clean
3 frames); `intel-ipu6` + `intel-ipu6-isys` UNLOADED live and blacklisted
(`/etc/modprobe.d/blacklist-ipu6.conf`) — junk `/dev/video0–63` gone
(68 → 4 video nodes; UVC RGB/IR still at 64–67, recaptured 1280x720 MJPG
frames OK).

0. **🎯 IMPORTANT — relogin to activate: the plugin's new v0.2.0 code (auto-orient, keyboard watcher, auto-switch) only loads on a fresh omarchy-shell (hot reload doesn't swap service QML — see AUDIT).** At that point the bar button, camera (wireplumber), gestures autostart, and plugin state all come up together.
1. **After relogin:** verify `tablet-experience Service LOADED v2` in journal; test `SUPER+SHIFT+R` rotation cycle + touch mapping; bar button left/right click; `SUPER+SHIFT+U`; menu → Tablet; then opt-in `omarchy-shell maxt.tablet-experience setAutoOrient on` + `setAutoSwitch on` (calibrate with `omarchy-orient --watch` first, then `setMode tablet`).
2. **Camera:** webcamtests.com in Chromium (libcamera now present after relogin).
3. **squeekboard typing + Rime** (`nihao` → candidates) — Phase 4 verification.
4. **User device tests:** fingerprint unlock; BT pair; speaker/mic.
5. **Optional:** ~~`gst-plugins-good`~~ ✅; ~~ipu6 blacklist~~ ✅ (68→4 video nodes); ~~Wanxiang LTS gram~~ ✅ — all done 2026-08-29.
6. Later: **Phase 11 two-finger validation** (no login needed, daemon already live): put two fingers together on screen → tap = VK; swipe left/right = workspace; swipe down = menu. If the panel drops concurrent contacts (packet-style attribution sees one), I'll re-tune or fall back to a 2-finger-tap-only mode.

## Repository layout

```
omarchy-tablet-experience/
├── README.md               ← you are here
├── AUDIT.md                ← Phase 0 audit (hardware/software/plugin API)
├── DEBUG-TOUCH-BAR.md      ← full record of the top-bar touch investigation
├── scripts/
│   ├── omarchy-vk      ← gesture daemon+toggle (archived; live at ~/.local/bin)
│   ├── omarchy-rotate  ← Phase 5/6 rotation helper (-s silent for auto-orient)
│   ├── omarchy-orient  ← Phase 6 IIO accel posture probe (--watch to calibrate)
│   ├── omarchy-kbdetect ← Phase 9 folio-keyboard USB presence (sysfs, no udev rules)
│   ├── omarchy-touch  ← Phase 11 multi-touch gestures (tap2=close, tap3=VK, no grab)
│   └── omarchy-close  ← close panels/overlays, else focused window (touch Esc)
├── config/hypr/tablet-experience.lua   ← archived copy of the live hypr config
├── plugin-source/
│   └── maxt.tablet-experience/  ← Phase 7–10 Quattro plugin (Service + BarWidget + manifest)
└── (later) panel extras, udev watcher, auto-switch
```