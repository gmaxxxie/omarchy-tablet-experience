# Omarchy Tablet Experience (ThinkPad X12)

Project home for building a **Laptop / Tablet mode** extension on Omarchy 4.0.1 + Hyprland 0.56.2 for the **Lenovo ThinkPad X12 Detachable Gen 1**.

> **Current stage: PHASE 5+7/8 — rotation working (SUPER+CTRL+0..3); Laptop/Tablet state machine + Omarchy bar-widget plugin live (`maxt.tablet-experience`); Phase 12 camera verified via UVC**
> Working location: `~/.config/omarchy/plugins/` (the plugin), source/docs live in this folder.

## Status board

| Phase | Feature | Status |
|---|---|---|
| 0 | Hardware/software audit | ✅ `AUDIT.md` |
| 1 | Touchscreen basic support | ✅ recognized + enabled; bar-touch issue **resolved via reboot** (runtime wedge, see `DEBUG-TOUCH-BAR.md`) |
| 2 | Native workspace swipe | ✅ edge-swipe verified working (user-tested), `gestures:workspace_swipe_touch=true` |
| 3 | Input method (Chinese) | ✅ fcitx5 + Rime + Wanxiang installed & deployed (see below) |
| 4 | Virtual keyboard | 🟡 squeekboard (extra) core path **working**: D-Bus toggle ✓, bottom-edge up-swipe show ✓ (user-tested), `SUPER+U` bind ✓; pending autostart + touch/Chinese input verification |
| 5–11 | rotation / state / UI / auto-switch | 🟡 P5 ✅ rotation script+binds · P7/8 ✅ mode state machine + bar widget + menu + `SUPER+SHIFT+U` · P6/9/10 ⏳ |
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
| `config/hypr/tablet-experience.lua` (this repo) | Phase 5 — archived copy incl. `SUPER+CTRL+0..3` rotation binds | — |
| `PHASE12-HARDWARE.md` (this repo) | NEW — camera UVC verification + IPU6 dead-end analysis, fingerprint/BT/audio status | — |
| `~/.config/fcitx5/profile` | added `rime` as 2nd input method | `profile.bak.1787928474` |
| `~/.local/share/fcitx5/rime/` | NEW — Wanxiang v17.7.1 files | (download from GitHub releases) |

**Packages added (official `extra`, all removable):** fcitx5-rime, librime(+data), noto-fonts-cjk, wqy-microhei, python-pywayland (diagnostic tool — remove later), squeekboard, python-evdev (gesture daemon dep).

## Current runtime state (2026-08-29)

**Phase 5 — manual rotation (done, pending user touch-check):** `omarchy-rotate`
(script + OSD, live at `~/.local/bin/`, archived at `scripts/omarchy-rotate`)
rotates eDP-1 via `hyprctl eval "hl.monitor({...})"` — all 4 transforms
verified roundtrip. Binds `SUPER+CTRL+0..3` → 0°/90°/180°/270°, added to
`tablet-experience.lua` (archived at `config/hypr/tablet-experience.lua`),
config reloaded clean, binds registered. Touch/pen mapping follows the
monitor automatically (`input:touchdevice:output=Auto`), awaiting physical
verification.

**Phase 6 — auto-rotation (iio-sensor-proxy now installed; wiring pending):**
IIO accel_3d live (g=(−0.35,−6.61,−8.21), dominant −z ⇒ `normal`). Probe
`omarchy-orient` (sysfs; `--watch` to calibrate) classifies postures. Next:
wiring orientation→transform through the state machine (Phase 7 service hook).

**Phases 7+8 — Laptop/Tablet state machine + Omarchy plugin (done, live):**
plugin `maxt.tablet-experience` (`service`+`bar-widget`) at
`~/.config/omarchy/plugins/` (archived `plugin-source/`):
- **Service.qml** — persistent mode (`PersistentProperties reloadableId`,
  `laptop|tablet` + `tabletRotation` preset off/0°/180°), idempotent apply
  (OSD + optional rotate on enter-tablet), Charm IPC:
  `omarchy-shell maxt.tablet-experience {getState|getMode|toggle|setMode|setRotation}`
- **BarWidget.qml** — mode button (left=toggle, right=rotation-preset ring);
  nerd glyphs verified in JetBrainsMono Nerd Font
- Menu rows `tablet.*` in `~/.config/omarchy/extensions/omarchy-menu.jsonc`
- Bind `SUPER+SHIFT+U` → toggle (`SUPER+T` and friends already taken)
- Enabled `--section right`; full IPC roundtrip tested, zero shell errors;
  persistence survives shell reloads by design (same as omarchy.battery)

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

1. **Phase 5+8 user verification (physical):** rotate via `SUPER+CTRL+1/2/3/0` and confirm touch/pen mapping per orientation; watch the new bar button → left-click toggles Laptop/Tablet (OSD), right-click cycles the rotation preset; `SUPER+SHIFT+U` toggles too; menu → Tablet submenu.
2. **Relogin, then browser camera test:** libcamera is installed — after next relogin test webcamtests.com in Chromium. Then iio-sensor-proxy wiring (Phase 6): `monitor-sensor` calibration → optional auto-orientation hook into the service.
3. **Verify input through squeekboard:** touch a key in a foot/editor/browser — confirms Wayland key injection; then fcitx5 Rime pinyin via VK (Ctrl+Space, type `nihao` → candidates).
4. **User device tests:** unlock via fingerprint; pair a BT device; speaker/mic playback+record.
5. **Gesture daemon autostart persisted** (`autostart.lua` — takes effect next login; current daemon already running). Confirm gesture feel on next login.
6. Optional cleanups: blacklist `intel-ipu6` modules (remove 64 junk video nodes), `gst-plugins-good` for gst pipelines.
7. Later phases: 6 auto-orientation (after install), 9 udev keyboard watcher → 10 auto-switch (opt-in), 11 gestures, 12 remaining device tests.

## Repository layout

```
omarchy-tablet-experience/
├── README.md               ← you are here
├── AUDIT.md                ← Phase 0 audit (hardware/software/plugin API)
├── DEBUG-TOUCH-BAR.md      ← full record of the top-bar touch investigation
├── scripts/
│   ├── omarchy-vk      ← gesture daemon+toggle (archived; live at ~/.local/bin)
│   ├── omarchy-rotate  ← Phase 5 rotation helper (0/90/180/270 + OSD)
│   └── omarchy-orient  ← Phase 6 IIO accel posture probe (--watch to calibrate)
├── config/hypr/tablet-experience.lua   ← archived copy of the live hypr config
├── plugin-source/
│   └── maxt.tablet-experience/  ← Phase 7/8 Quattro plugin (Service + BarWidget + manifest)
└── (later) panel extras, udev watcher, auto-switch
```