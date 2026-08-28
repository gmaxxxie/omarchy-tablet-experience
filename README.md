# Omarchy Tablet Experience (ThinkPad X12)

Project home for building a **Laptop / Tablet mode** extension on Omarchy 4.0.1 + Hyprland 0.56.2 for the **Lenovo ThinkPad X12 Detachable Gen 1**.

> **Current stage: PHASE 4 (virtual keyboard) — squeekboard + bottom-swipe gesture working, pending autostart & input verification**
> Working location: `~/.config/omarchy/plugins/` (the plugin), source/docs live in this folder.

## Status board

| Phase | Feature | Status |
|---|---|---|
| 0 | Hardware/software audit | ✅ `AUDIT.md` |
| 1 | Touchscreen basic support | ✅ recognized + enabled; bar-touch issue **resolved via reboot** (runtime wedge, see `DEBUG-TOUCH-BAR.md`) |
| 2 | Native workspace swipe | ✅ edge-swipe verified working (user-tested), `gestures:workspace_swipe_touch=true` |
| 3 | Input method (Chinese) | ✅ fcitx5 + Rime + Wanxiang installed & deployed (see below) |
| 4 | Virtual keyboard | 🟡 squeekboard (extra) core path **working**: D-Bus toggle ✓, bottom-edge up-swipe show ✓ (user-tested), `SUPER+U` bind ✓; pending autostart + touch/Chinese input verification |
| 5–11 | rotation / state / UI / auto-switch | ⏳ pending |
| 12 | **Hardware full bring-up (esp. camera)** | 🔍 user-added: camera = Syntek `174f:118f` via Intel IPU6 (`/dev/video0–13` seen, **output unverified**); fingerprint `06cb:00bd` + BT AX201 + audio pending |

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
| `~/.config/fcitx5/profile` | added `rime` as 2nd input method | `profile.bak.1787928474` |
| `~/.local/share/fcitx5/rime/` | NEW — Wanxiang v17.7.1 files | (download from GitHub releases) |

**Packages added (official `extra`, all removable):** fcitx5-rime, librime(+data), noto-fonts-cjk, wqy-microhei, python-pywayland (diagnostic tool — remove later), squeekboard, python-evdev (gesture daemon dep).

## Current runtime state (2026-08-29)

- `gestures:workspace_swipe_touch = true` (Phase 2, verified)
- VK renderer: **squeekboard** — D-Bus `sm.puri.OSK0.SetVisible`, state property `.Visible` (toggle = read-then-invert)
- Gesture daemon: `~/.local/bin/omarchy-vk daemon` (also archived at `scripts/omarchy-vk` in this repo) — bottom 12% up-swipe → show; kb-visible + start ≥68% downward drag → dismiss; threshold/zone constants at top of file
- Wacom touch quirk: reports `ABS_MT_TRACKING_ID` **without** `ABS_MT_SLOT` events (fixed in daemon: tracks by touch-id)
- fcitx5 service enabled → auto-start on next login

## Next actions

1. **Persist gesture daemon:** add `o.launch_on_start("omarchy-vk daemon")` to `~/.config/hypr/autostart.lua` (after user confirms gesture feel on next login).
2. **Verify input through skeekboard:** touch a key in a foot/editor/browser — confirms Wayland key injection; then fcitx5 Rime pinyin via VK (Ctrl+Space, type `nihao` → candidates).
3. **Phase 12 hardware bring-up begins (user priority): camera first** — IPU6 stack output test → fingerprint (fprintd) → BT → audio.
4. Later phases: 5 rotation, 6 iio-sensor-proxy orientation, 7 Laptop/Tablet state, 8 plugin, 9 udev keyboard watcher, 10 auto-switch, 11 gestures.

## Repository layout

```
omarchy-tablet-experience/
├── README.md               ← you are here
├── AUDIT.md                ← Phase 0 audit (hardware/software/plugin API)
├── DEBUG-TOUCH-BAR.md      ← full record of the top-bar touch investigation
├── scripts/
│   └── omarchy-vk          ← gesture daemon + toggle (archived copy; live at ~/.local/bin/omarchy-vk)
└── (later) plugin-source/  ← the Quattro plugin (service + bar-widget + panel)
```