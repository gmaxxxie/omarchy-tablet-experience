# Omarchy Tablet Experience — PHASE 0 Audit Report

Date: 2026-08-28 · Device: Lenovo ThinkPad X12 Detachable Gen 1 · Session: Wayland (uwsm) via SDDM
**Nothing was modified during this phase.**

## 1. Versions

| Component | Version | Notes |
|---|---|---|
| Omarchy | 4.0.1-1 | Quattro package layout (`/usr/share/omarchy`, `$OMARCHY_PATH` set) |
| Hyprland | 0.56.2 | v0.56.2, no plugins loaded; **hyprlang deprecated since 0.55 → Lua config API** |
| Quickshell | 0.3.1-1 | Hosts `omarchy-shell` (single long-running process) |
| OS | Arch Linux | SDDM + uwsm session, Wayland `wayland-1` |

Omarchy config layout confirmed: Lua Hyprland config (`~/.config/hypr/*.lua`), shell config `~/.config/omarchy/shell.json`, plugins `~/.config/omarchy/plugins/<id>/`.

## 2. Hardware inventory (as seen by Hyprland)

- **Monitor:** `eDP-1`, 1920x1280@60Hz at 0x0, scale 1.6, **transform 0**, Chimei Innolux 0x1249
- **Touchscreen:** `wacom-hid-525d-finger` (Touch) — already recognized, `hl.virtual keyboard` absent
- **Pen:** `wacom-hid-525d-pen` (Tablet, 259.2x172.8mm)
- **Keyboard:** `Darfon Thinkpad X12 Detachable Gen 1 Folio case` (multiple input nodes event4–9) — **USB device `17ef:60fe`** ⇒ attach/detach = USB plug/unplug (reliable udev signal)
- **Switches:** `Lid Switch`, `ThinkPad Extra Buttons` (Libinput switches)
- **IIO sensors (raw, /dev/iio:device*):**
  - `iio:device0` = `accel_3d` — live (values change on read), scale 9.806e-3 m/s²/LSB ⇒ ~1g total, sane
  - `iio:device1` = `gyro_3d`
  - `iio:device2` = `hinge` — exposes `in_angl0:hinge`, `in_angl1:screen`, `in_angl2:keyboard` (10 Hz sampling) — **raw = 0, needs buffer/poll verification; iio-sensor-proxy does NOT expose hinge angle by standard**

## 3. Sensors / orientation stack

| Item | Status |
|---|---|
| iio-sensor-proxy | **NOT installed** (available in official `extra`, 3.9-1) |
| monitor-sensor | not available (comes with iio-sensor-proxy) |
| Accelerometer | works, exposed via IIO; iio-sensor-proxy will pick it up |

## 4. Input method status (IMPORTANT — differs from assumption)

- **IBus: NOT installed.**
- **Fcitx5 5.1.21 IS installed and running** — managed by Omarchy itself (`omarchy-fcitx5.service`, "XCompose sequences", `Restart=always`).
  - `INPUT_METHOD=fcitx`, `XMODIFIERS=@im=fcitx`, `SDL_IM_MODULE=fcitx`, `QT_IM_MODULE=fcitx`; `GTK_IM_MODULE` unset (GTK Wayland text-input path)
  - `fcitx5-gtk`, `fcitx5-qt` installed; `waylandim` addon present ⇒ text-input-v3 works for Wayland GTK/Qt apps
- **Risk:** migrating to IBus means replacing Omarchy's own managed IM. Decision point for the user (see §9).

## 5. Virtual keyboard status

- **No VK installed** (no maliit / squeekboard / wvkbd).
- Candidates:
  - **Fcitx5 built-in DBus VK addon** — `virtualkeyboard.conf` present (Category UI, UIType=OnScreenKeyboard, OnDemand) — zero new packages
  - **Hyprland built-in virtual keyboard** — Hyprland exposes device `hl-virtual-keyboard-fcitx5` (`main: yes`); Hyprland has native virtual-keyboard integration
  - **Squeekboard** — official `extra`, 1.43.1-5
  - **Maliit** — AUR only (`maliit-keyboard` 2.3.1-3); user preference weighted, but AUR dependency

## 6. Keyboard attach/detach mechanism (X12)

1. **Primary (recommended):** USB presence of `17ef:60fe` (`Lenovo Thinkpad X12 Detachable Gen 1 Folio case`) → udev add/remove events + sysfs check. Deterministic and simple.
2. **Secondary:** IIO `hinge` sensor angles (`keyboard` axis) — needs live verification (values currently 0).
3. **Secondary:** `Lid Switch` libinput device exists.
Omarchy's `omarchy hw clamshell` = lid-closed AND external-monitors — NOT the keyboard-detach signal.

## 7. Hyprland native capabilities (this exact version)

- **Touchscreen workspace swipe: AVAILABLE natively.**
  - `gestures:workspace_swipe_touch` = false (exists), `gestures:workspace_swipe_touch_invert` = false, `gestures:workspace_swipe_distance` = 300, `gestures:workspace_swipe_cancel_ratio` = 0.5
  - **`gestures:workspace_swipe_touch_edge` does NOT exist** in 0.56.2 (old tutorial syntax obsolete)
- **Trackpad 1:1 gestures:** new system via `hl.gesture({fingers, direction, action, mods, scale})` (Lua)
- **Runtime mutation mechanism (confirmed):** `hyprctl eval "<lua>"` — Omarchy's own `omarchy toggle touchscreen` uses `hyprctl eval "hl.device({name=..., enabled=...})"`. The plugin will use the same mechanism for transforms/touch mapping at runtime.
- **Rotation:** `hl.monitor({output="eDP-1", transform=N})` in Lua + reload; touch mapping via `input:touchdevice:transform` / `input:touchdevice:output=[[Auto]]` (both options exist). Phase 5 must verify touch sync per orientation.
- **Touch options:** `input:touchdevice:enabled` = true (exists).

## 8. Omarchy plugin API (Quattro, schemaVersion 1) — CONFIRMED against local install

- Location: `~/.config/omarchy/plugins/<plugin-id>/`
- Kinds ↔ files: `bar-widget`→BarWidget.qml · `panel`→Panel.qml · `overlay`→Overlay.qml · `menu`→Menu.qml · `service`→Service.qml · `bar`→Bar.qml
- Manifest fields: `schemaVersion`, `id`, `name`, `version`, `author`, `license`, `description`, `kinds[]`, `entryPoints{}`, kind config (e.g. `barWidget`: `displayName/category/allowMultiple/defaultSection`; `panel` may set `keepLoaded: true` — see `omarchy.osd`)
- Commands: `omarchy plugin clone|add|enable|disable|remove|list --json|validate <dir>`; runtime IPC `omarchy-shell shell summon <id> '{}'` / `hide` / `rescanPlugins`
- Persistence primitive: **`PersistentProperties { reloadableId: "..." }`** (used by omarchy.battery) — survive shell reloads; the Omarchy-native state mechanism to use
- Service pattern: `Service.qml` = headless `Item` + Timer + `Process` + `Connections` (see `omarchy.battery`)
- Bar-widget pattern: `BarWidget.qml` + nested `Panel.qml` via `Loader`, `WidgetButton`, `KeyboardPanel`, `PanelKeyCatcher`; same `moduleName` in all files (see `omarchy.clock` clone tutorial)
- **Quickshell native Hyprland module available:** `Quickshell.Hyprland` (Ipc: `monitors`/`workspaces`/`toplevels` models, `dispatch()`, `rawEvent`, `parse`) — no need to shell out for IPC, though `Process`+`hyprctl` also works
- Menu: extend `~/.config/omarchy/extensions/omarchy-menu.jsonc` (dotted ids, `icon/label/action/checked`, hot-reload)
- Bar placement: `omarchy bar move <id> --section <s>` or edit `shell.json` `bar.layout`

## 9. Deviations / decisions required

1. **IME:** Task assumed IBus; system runs Omarchy-managed Fcitx5, no IBus. Recommendation: **keep Fcitx5** (already the Omarchy default, zero migration risk); verify Chinese input in GTK/Qt/Chromium/terminal in Phase 3, and let the VK interoperate with it. Migrating to IBus = replacing Omarchy's own service, contradicts "do not modify Omarchy core / do not replace IME" — leaving the decision to the user.
2. **Virtual keyboard:** zero-new-package path = fcitx5 DBus VK addon + Hyprland built-in VK. Squeekboard (extra) = external alternative. Maliit = AUR only.
3. **Auto-switch signal:** use USB `17ef:60fe` presence (udev), not the hinge IIO sensor (unverified).

## 10. Recommended implementation path (matches task order)

1. Phase 1: native touchscreen config (already recognized; enable `omarchy toggle touchscreen`; test tap/scroll/drag/select; window rules for float-on-touch where sensible)
2. Phase 2: `gestures:workspace_swipe_touch = true` via generated Lua + reload (or `hyprctl eval`)
3. Phase 3: verify Fcitx5 Chinese input (GTK/Qt/Chromium/terminal) — no changes expected
4. Phase 4: evaluate fcitx5 VK + Hyprland built-in VK first; Squeekboard as alternative
5. Phase 5: manual rotation via `hyprctl eval`/Lua reload; verify 0/90/180/270 + touch mapping each time
6. Phase 6: `iio-sensor-proxy` (extra pkg) + orientation → Tablet mode only
7. Phase 7: manual Laptop/Tablet mode (state via `PersistentProperties`, idempotent apply)
8. Phase 8: plugin `maxt.tablet-experience` — kinds `service` + `bar-widget` (+nested `Panel.qml`); menu via `omarchy-menu.jsonc`
9. Phase 9: udev/USB-keyboard attach/detach watcher (small helper + D-Bus or file watch into Service)
10. Phase 10: auto-switch (opt-in)
11. Phase 11: optional multi-touch gestures — hyprpm checks against 0.56.2 only (no plugins loaded today; no third-party daemon as MVP dependency)
12. **Phase 12 (追加, user): 硬件全启动，尤其摄像头** — inventory all hw not covered by Phase 0; make every device fully usable.
    - **摄像头 (highest priority):** Syntek `174f:118f` — **UVC path VERIFIED** (RGB+IR frames, see `PHASE12-HARDWARE.md`); IPU6 CSI stack (`isys` nodes `/dev/video0–63`) confirmed **dead end** on this board (secure mode + sensor behind USB bridge). Remaining: `libcamera` install for portal/browser use + user browser test.
    - Fingerprint `06cb:00bd` Synaptics Prometheus → fprintd enroll/test.
    - Bluetooth `8087:0026` AX201 → verify scan/pair.
    - Audio sof-hda-dsp → capture+playback test (mic/headphone/HDMI).
    - Any other device reported by `lsusb`/`hyprctl devices` not yet exercised.
    - Guardrails apply: official packages or justified vendor files, removable, documented.

## 11. Guardrails (unchanged from task)

- Only touch `~/.config/omarchy/plugins/<id>/`, `~/.config/hypr/` user files (with backups), `extensions/omarchy-menu.jsonc`, and an isolated state dir. Never `/usr/share/omarchy/`.
- New packages only when justified: iio-sensor-proxy (extra) at Phase 6 minimum.
- No destructive changes, no duplicate VKs, no obsolete gesture frameworks.

## 12. Progress log

### 2026-08-28 — Phase 1, Phase 2, IM & fonts

**Phase 1 — Touchscreen (DONE):** `wacom-hid-525d-finger` recognized, `input:touchdevice:enabled=true`, transform 0, output Auto. No drivers installed — native support only.

**Phase 2 — Workspace swipe (DONE):** created plugin-owned `~/.config/hypr/tablet-experience.lua` (required from `hyprland.lua`, backup at `hyprland.lua.bak.1787928342`). Enabled `gestures:workspace_swipe_touch=true` (+ `workspace_swipe_touch_invert=false`). Confirmed via `hyprctl getoption` and zero `configerrors`.

**IM — Fcitx5 + Rime + Wanxiang (DONE):**
- Installed (official extra): `fcitx5-rime 5.1.14-1`, `librime 1.17.0-5` (+ rime data pkgs), fonts `noto-fonts-cjk 20240730-1`, `wqy-microhei 0.2.0_beta-12`.
- Wanxiang v17.7.1 base extracted to `~/.local/share/fcitx5/rime/` (user rime dir for fcitx5-rime); schema `wanxiang` (万象拼音 LTS).
- Deployed cleanly: `build/wanxiang.{table,prism,reverse}.bin` present, `build/default.yaml` schema_list → `wanxiang`.
- fcitx5 profile: added `rime` as second IM (Default stays `keyboard-us`); fcitx5 restarted, log confirms `Loaded addon rime`; Wayland native IM protocol: 1.
- Fcitx5 profile backup: `~/.config/fcitx5/profile.bak.*`

**Pending user verification (GUI):** touchscreen tap/scroll/drag/select; edge-swipe workspace switch; switch to Rime (Ctrl+Space) and type Chinese in GTK/Qt/Chromium/terminal; CJK font rendering.

### 2026-08-29 — Phase 2 resumed, Phase 4 (VK) core path

**Top-bar touch: RESOLVED via reboot** — clean re-login restored bar touch
with zero config changes (runtime-state wedge). Details in
`DEBUG-TOUCH-BAR.md`. Swipe re-enabled after the fix:
`gestures:workspace_swipe_touch=true`, user-verified edge-swipe workspace
switching + bar taps both fine.

**Phase 4 — Virtual keyboard (decision + working core):**
- fcitx5 `virtualkeyboard` addon is a **DBus bridge only** (`libvirtualkeyboard.so`
  has no Qt deps; addon desc: "A virtual keyboard backend based on DBus").
  `org.fcitx.Fcitx.VirtualKeyboard1` on `/virtualkeyboard` forwards show/hide
  to an external renderer — useless without one.
- wvkbd = AUR only (excluded). **squeekboard 1.43.1-5 (official extra) chosen.**
- squeekboard IPC: `sm.puri.OSK0` on `/sm/puri/OSK0` — method `SetVisible(b)`,
  readable property `.Visible` (read-then-invert for reliable toggle).
  Renders as layer surface namespace `osk` (0 587 1200 213).
- Gesture daemon `~/.local/bin/omarchy-vk` (python-evdev): passive listen on
  `/dev/input/event15` (no grab), bottom-12% up-swipe → show; while visible,
  downward drag starting ≥68% → dismiss. Tuning constants at file top
  (BOTTOM_RATIO/MOVE_THRESHOLD/DOWN_ZONE_RATIO/DOWN_THRESHOLD).
  **User-verified: bottom up-swipe pops the keyboard.**
- Wacom quirk discovered via event trace: reports ABS_MT_TRACKING_ID **without**
  ABS_MT_SLOT → daemon tracks by touch-id (not slot).
- Bind added to `tablet-experience.lua`: `SUPER+U` → `omarchy-vk toggle`.
- Package additions (extra, removable): squeekboard, python-evdev.

**Pending:** autostart for daemon (`autostart.lua`), touch-key input
verification, Chinese (Rime) input through VK.

**追加需求 (2026-08-29, user): 硬件全启动，尤其摄像头** — 确保全部硬件
可用，优先级：摄像头。现状探测：摄像头硬件存在（USB `174f:118f` Syntek
Integrated RGB Camera），由 **Intel IPU6** 栈驱动（PCI `0000:00:05.0`，
`/dev/video0–13` 已挂载）；**出画（用户空间栈完整性）未验证**。其他已见
硬件待验证项：指纹 `06cb:00bd` Synaptics Prometheus（fprintd）、蓝牙
`8087:0026` AX201、音频 sof-hda-dsp（HDMI/耳机/麦克风节点已出现）。
→ 新增路线图 Phase 12（见 §10）。

Symptom: tapping the Omarchy top bar passes through to the desktop (double-tap opens wallpaper picker); mouse clicks on the bar work. User reports it worked right after system install.

### 2026-08-29 — Phase 12 hardware bring-up: camera verified (UVC), FP/BT/audio audited

**Camera — VERIFIED via UVC path. IPU6 CSI = dead end.** The `174f:118f`
Syntek is a USB camera bridge (SunplusIT) exposing TWO UVC functions:
`/dev/video64` RGB (MJPG ≤2592x1944@30) and `/dev/video66` IR (GREY
640x480@30). Captured real frames (stats: RGB mean≈108/σ≈41, IR mean 48.7/σ
28.3); artifacts in `verify/`. The kernel IPU6 path fails by design on this
board: `IPU6 in secure mode` (CSE refuses), `ov8856 probe error -5` (sensor is
behind the USB bridge), psys runtime-PM fail ⇒ `/dev/video0–63` isys nodes are
useless, AUR ipu6 HAL would not help. Full analysis: `PHASE12-HARDWARE.md`.
**Pending for browser/portal use:** `sudo pacman -S libcamera` (official) so
WirePlumber/portal present the UVC camera (currently hidden from PipeWire's
v4l2 monitor).

**Fingerprint:** fprintd sees Synaptics `06cb:00bd`; `#0: right-index-finger`
already enrolled; sudo PAM prompt verified live (fingerprint timed out in this
headless session — expected). **BT:** AX201 up, 10s scan found 13+ devices
(verified). **Audio:** SOF card 0 + ALC287, sinks (Speaker/HDMI×3) + 2 mics via
WirePlumber (verified); cosmetic RTKit error (no realtime prio).

**Phase 4 persistence:** `~/.config/hypr/autostart.lua` now runs
`omarchy-vk daemon` via `o.launch_on_start` (backup saved) — live daemon still
running from earlier terminal; daemon will auto-start next login.

### 2026-08-29 — Phase 5: manual rotation working (script + binds verified)

Runtime rotation confirmed on Hyprland 0.56.2: `hyprctl eval
'hl.monitor({output="eDP-1", transform=N})'` — all 4 transforms roundtrip
clean (0→1→2→3→0), zero configerrors. Built `omarchy-rotate` (bash, OSD via
`omarchy osd`, `OMARCHY_ROTATE_DISPLAY` env override) → live at
`~/.local/bin/`, archived `scripts/omarchy-rotate`. Binds
`SUPER+CTRL+0/1/2/3` → 0°/90°/180°/270° in `tablet-experience.lua`
(archived `config/hypr/tablet-experience.lua`), `hyprctl reload` ok, binds
registered (verified via `hyprctl binds`). Touch/pen mapping stays `Auto`
(follows transform natively) — **pending physical user verification** in
portrait/flipped orientations.

**Phase 6 prep:** IIO accel_3d live (g=(−0.35,−6.61,−8.21), dominant −z ⇒
`normal`; |g|≈10.55 static bias). Probe `omarchy-orient` (python3, sysfs,
zero deps; `once`/`--json`/`--watch`) classifies normal/bottom-up/left-up/
right-up — archived `scripts/omarchy-orient`, live at `~/.local/bin/`. Sensor
mounting/axis conventions need physical calibration (`--watch`). Wiring into
auto-rotation = Phase 6/7, pending `sudo pacman -S iio-sensor-proxy`.
`iio-sensor-proxy` + `libcamera` both installed by user 2026-08-29.

### 2026-08-29 — Phases 7+8: Laptop/Tablet state machine + Omarchy plugin

Built plugin `maxt.tablet-experience` (`~/.config/omarchy/plugins/`,
archived `plugin-source/`): `service` + `bar-widget` kinds.

- **Service.qml** — `PersistentProperties { reloadableId:
  "maxt-tablet-experience" }` holding `mode` (laptop|tablet) and
  `tabletRotation` preset (off|0|2); idempotent applyNext() (OSD via
  `omarchy-osd`, optional `omarchy-rotate` on enter-tablet); Charm
  `IpcHandler target "maxt.tablet-experience"` exposing
  getState/getMode/toggle/setMode/setRotation → reachable as
  `omarchy-shell maxt.tablet-experience …`.
- **BarWidget.qml** — `BarWidget` base + `WidgetButton` (bar left-click
  toggles mode, right-click cycles rotation preset off→180°→0°); nerd glyphs
  U+F03FF tablet / U+F0322 laptop **verified in JetBrainsMono Nerd Font**
  (the bar's resolved `monospace`).
- **Menu** — `tablet.*` rows appended to
  `~/.config/omarchy/extensions/omarchy-menu.jsonc` (toggle + rotate 0/90/
  180/270), hot-reload.
- **Bind** — `SUPER+SHIFT+U` → `omarchy-shell maxt.tablet-experience
  toggle` (SUPER+T/CTRL+T/ALT+T all taken by defaults).
- Validated (`omarchy plugin validate` exit 0), enabled `--section right`,
  IPC full roundtrip tested (toggle laptop⇄tablet, setRotation 2, getState
  accurate), persistent props verified live, zero shell errors in journal.
  Auto-reload on file change confirmed (shell "Local plugin changed,
  reloading" debug lines).

### 2026-08-29 (late) — Phases 6/9/10 wiring + platform hot-reload finding

- **iio-sensor-proxy verified** (installed by user): `monitor-sensor` sees
  the accel, `Orientation changed: normal` events live; D-Bus property
  `net.hadess.SensorProxy.AccelerometerOrientation` readable via
  `busctl --system get-property` → `s "normal"`.
- **Service qml v0.2.0**: `autoOrient` opt-in (1.5s busctl poll only while
  enabled; mapping normal/left-up/bottom-up/right-up → transform 0/1/2/3,
  silent apply, tablet-mode gated, needs one physical calibration pass via
  `omarchy-orient --watch`), `autoSwitchMode` opt-in, extended IPC
  (`setAutoOrient`, `setAutoSwitch`), boot marker `console.log("tablet-
  experience Service LOADED v2")`.
- **omarchy-kbdetect** (sysfs, no udev rules, no deps): reports
  attached/detached for USB 17ef:60fe — live test: `attached` ✓.
- **omarchy-rotate -s**: silent flag for auto-applies (no OSD spam).
- **PLATFORM FINDING**: Omarchy/Quickshell service-plugin hot reload does
  NOT swap QML service code (component cached per URL): `omarchy plugin
  disable`→`enable`, `shell rescanPlugins`, and local-file watcher reloads
  all keep the original instance — verified by (a) new IPC method
  `setAutoOrient` = "Function not found", (b) new boot console.log never
  appearing across cycles, (c) no load errors in journal/qslog. New plugin
  code only activates on a full omarchy-shell restart (next login). Offline
  validation path that DOES work: `quickshell -p <Service.qml>` (parsed +
  instantiated cleanly, `Configuration Loaded`).
- **IME note**: fcitx5 logs repeated `error opening gram db
  wanxiang-lts-zh-hans.gram` — the Wanxiang LTS language-model gram file is
  NOT shipped in the deployment (needs separate download from wanxiang
  GitHub releases; large). TODO, non-blocking for pinyin typing.

Cleared by controlled experiments: `gestures:workspace_swipe_touch` (off → no change), fcitx5 (fully stopped → no change), touch device hardware (raw coords verified correct), fonts/Rime.

Evidence: `hyprctl layers` shows only `omarchy-bar 0 0 1200 30` at top, no overlay; no occlusion. Hyprland 0.56.2 source + Quickshell source review says the bar should be hittable (Quickshell never sets empty input regions). Root cause not found yet.

Action: reboot planned; then re-test bar. Full record: `DEBUG-TOUCH-BAR.md` in project dir.