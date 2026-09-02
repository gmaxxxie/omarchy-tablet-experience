# Omarchy Tablet Experience

**Laptop / Tablet mode for detachable 2-in-1s** on Omarchy (Quattro) + Hyprland.
Developed and verified on a Lenovo ThinkPad X12 Detachable Gen 1 — sensor
rotation, virtual-keyboard gestures, keyboard auto mode-switch, and a
touch-first window-manage popup, all in one plugin.

Chinese version: [README.zh-CN.md](README.zh-CN.md) · Development log: [DEVELOPMENT.md](DEVELOPMENT.md)

![Tablet-mode window-manage popup](preview.png)

## Features

- **Laptop ⇄ Tablet state machine** — persistent across shell reloads, OSD
  feedback, IPC-controlled.
- **Rotation** — 4-way manual cycle (`SUPER+SHIFT+R`), sensor auto-follow
  (iio-sensor-proxy), or stepwise ⟲/⟳ 90° buttons in the tablet popup.
  **Entering tablet mode never rotates the display by itself** (v1.4): the
  screen stays where it is; rotation happens only explicitly, or through the
  sensor when the `auto` preset is on. Touch calibration is rotated along
  with the screen (Hyprland does not do this itself). **Selecting Laptop
  mode always returns the display to the default 0° landscape** — even
  mid-rotation, the reset is queued until the current rotation finishes.
- **Virtual keyboard** — squeekboard via `SUPER+U`, the **tablet bar button**
  (live show/hide state), or a 3-finger tap (`texp-touch`). The bottom-edge
  up-swipe gesture (texp-vk daemon) is **disabled by default since v1.2.1**;
  re-enable by adding `o.launch_on_start("texp-vk daemon")` to
  `~/.config/hypr/autostart.lua`. `install.sh` grants the desktop user evdev
  access (udev `uaccess` rule + `input` group) so the gesture daemons can
  read the touchscreen after reboots.
- **Tablet simplified bar (v1.2)** — LAPTOP mode keeps the default full bar;
  TABLET mode pares it to essentials (menu · workspaces · clock · tray ·
  network · audio · power · this widget) and the rest (weather, indicators,
  bluetooth, tailscale, display, updater, scene switcher, keyboard layout, …)
  moves behind the plugin's **⋮ overflow popup**: quick access to the two
  tablet essentials stays on the bar (input-method EN⇄中 + virtual keyboard),
  the popup lists every hidden bar icon (tap to mount it back) plus window
  manage & rotation. Each icon in the popup is an **on/off toggle** (✓ = on
  the bar, tap to hide; empty = hidden, tap to show) and **Hide all / Show
  all** switches the whole set instantly — all within tablet mode. The
  pre-tablet layout is carried inside shell.json (`bar.layoutSnapshot`,
  invisible to the bar), so it restores verbatim on laptop and survives shell
  restarts and crashes.
- **Input-method quick switch** — shows the active fcitx5 input method
  (EN / 中 / …) and toggles it with one tap (`fcitx5-remote -t`) — the
  convenient EN⇄中 switch the hidden fcitx5 indicator could not provide.
- **Voice input (v1.5, ⏎ v1.6, tablet mode)** — a **mic icon** in the
  tablet bar opens a bottom hold-to-talk button (tap the icon again to
  close it). Press & hold the button to dictate through **voxtype** (local
  ASR, no cloud), release to transcribe and type the text at your cursor —
  full CJK support via `wtype`. A **⏎ Enter button** underneath presses
  Return to submit the dictated line (chat / terminal / search box). Live
  recording / transcribing state is shown on the button and reflects the
  F9 / SUPER+CTRL+X hotkeys too.
- **Top-bar tap toggle (tablet mode)** — no mouse means no hover, so a thin
  full-width edge strip above the bar toggles it: tap when hidden → show,
  tap again → hide (drives Omarchy's own `bar-off` flag).
- **Multi-touch gestures** (`texp-touch`, passive evdev listener, no grab) —
  2-finger tap: close panels/window under finger · 2-finger swipe left/right:
  previous/next workspace · 2-finger swipe down: Omarchy menu · single-finger
  tap: focus the tapped window (Hyprland touch never focuses).
- **Keyboard auto mode-switch** — dock the keyboard → laptop mode, detach →
  tablet mode (USB presence, on by default).
- **Tablet window manage** — bar button popup in tablet mode: close the last
  touched window ✕, move it to workspace 1–10, or switch workspace layout
  Dwindle/Scrolling. Targets only visible windows; actions notify.
- **Touch workspace swipe** — native Hyprland gesture enabled by the plugin
  config.
- **Optional Chinese IME** — fcitx5 + Rime via `--with-ime` (see install).

## Requirements

- Omarchy 4.x (Quickshell shell), Hyprland 0.56+ (Lua config API), Arch-based
  system (`pacman` for optional packages).
- A detachable 2-in-1 with a touchscreen, an accelerometer, and a detachable
  keyboard. Defaults target the **ThinkPad X12** (folio keyboard USB
  `17ef:60fe`, Wacom touchscreen); every hardware assumption is overridable —
  see [Configuration](#configuration).

## Install

```sh
# 1. the plugin (QML service + bar widget):
omarchy plugin add https://github.com/gmaxxxie/omarchy-tablet-experience.git --enable

# 2. system side (helper daemons, Hyprland hooks, packages):
~/.config/omarchy/plugins/maxt.tablet-experience/install.sh
```

The repository root is the plugin folder, so after step 1 the clone lives at
`~/.config/omarchy/plugins/maxt.tablet-experience` and `install.sh` runs from
there (it also works from a dev clone).

`install.sh` options:

| Flag | Effect |
|---|---|
| *(none)* | deploy daemons + Hyprland hooks + required packages |
| `--no-packages` | skip pacman (manual package install) |
| `--with-ime` | also install Chinese IME (fcitx5-rime, librime, CJK fonts) |
| `--with-camera` | also install libcamera (UVC camera in browsers) |
| `--dry-run` | preview everything, change nothing |
| `--verify` | post-upgrade self-check (read-only, see Upgrades) |

What it installs: the 8 helper daemons to `~/.local/bin`, a
`tablet-experience.lua` Hyprland config (touch swipe + the three keybinds + the
bar-strip z-index) with a one-line `require` appended to your `hyprland.lua`,
autostart hooks (`texp-vk` / `texp-touch`) in `autostart.lua`, and **the
gesture daemons' evdev access**: a project udev rule tagging `/dev/input/event*`
with `uaccess` (logind grants the active session read ACLs from the next
boot) plus your user added to the `input` group (guaranteed for every login
from now on — `newgrp input -c 'texp-vk daemon'` makes the current session
work immediately). Every modified file gets a `*.bak.<timestamp>` first.

**Re-login once** after installing so the shell loads the plugin fresh, then
verify with `install.sh --verify`.

## Usage

| Action | Input |
|---|---|
| Toggle Laptop/Tablet mode | `SUPER+SHIFT+U` (or bar button, left click) |
| Next rotation preset | `SUPER+SHIFT+R` (or bar button, right click) |
| Switch input method (EN ⇄ 中) | **bar button, tablet mode** (shows current IM) |
| Voice input (hold to talk) | **mic bar button (tablet)** → bottom button: press & hold to record, release to transcribe; **⏎ Enter** to submit; mic icon again to close |
| Virtual keyboard | `SUPER+U` · bottom-edge up-swipe · **tablet bar button** |
| Hidden bar icons (tablet) | **⋮ button** → per-icon on/off toggles + Hide all / Show all |
| Virtual keyboard | `SUPER+U` · **bar button (tablet)** · 3-finger tap (bottom-edge up-swipe gesture disabled by default since v1.2.1) |
| Show/hide top bar (tablet mode) | tap the top edge / bar blank area (16 px strip when hidden, 5 px when shown) |
| Close panels / touched window | 2-finger tap |
| Previous / next workspace | 2-finger swipe left / right |
| Omarchy menu | 2-finger swipe down |

In tablet mode the bar button opens the **window-manage popup**: tap a window
first, then Close ✕ / Move to Workspace 1–10 / Dwindle·Scrolling layout.

IPC (`omarchy-shell maxt.tablet-experience <method>`):
`getState` · `getMode` · `toggle` · `setMode <laptop|tablet>` ·
`setRotation <off|auto|0|1|2|3>` · `setAutoOrient <on|off>` ·
`setAutoSwitch <on|off>` · `toggleBar` · `setBarHidden <on|off|toggle>` ·
`voiceInputToggle|voiceInputShow|voiceInputHide` (v1.5).

## Configuration

Hardware defaults target the ThinkPad X12; set any of these in your
environment (e.g. `~/.config/environment.d/60-tablet-experience.conf`) before
login:

| Variable | Meaning | Default |
|---|---|---|
| `OMARCHY_ROTATE_DISPLAY` | display to rotate | first Hyprland monitor |
| `OMARCHY_KB_VENDOR` / `OMARCHY_KB_PRODUCT` | detachable-keyboard USB id | `17ef` / `60fe` |
| `OMARCHY_TOUCH_NAME` | space-separated substrings matching the touch device name | `wacom finger` |

Gesture timing/tolerance constants live at the top of `texp-touch` /
`texp-vk`. Auto mode-switch is on by default; disable with
`setAutoSwitch off`.

## Dependencies

Required (installed by default):

- `squeekboard` — on-screen keyboard
- `iio-sensor-proxy` — accelerometer orientation for auto-rotation
- `python-evdev` — the two gesture daemons

Optional:

- `voxtype` (AUR: `voxtype-bin`) — voice input (tablet hold-to-talk, v1.5);
  also `wtype` for Wayland typing. Already installed on this machine.
- `fcitx5-rime`, `librime`, `noto-fonts-cjk`, `wqy-microhei` (Chinese IME,
  `--with-ime`)
- `libcamera` (UVC camera visible to browsers, `--with-camera`)

The helper scripts themselves need only Python 3 / bash and `hyprctl`.

## Uninstall

```sh
~/.config/omarchy/plugins/maxt.tablet-experience/uninstall.sh   # system side
omarchy plugin remove maxt.tablet-experience                     # the plugin
```

`uninstall.sh` only removes files that byte-match what it installed — anything
you edited is kept and reported. Packages are not auto-removed (list printed).

## Upgrades & safety

- **The plugin never modifies Omarchy package files** — verified
  `pacman -Qkk omarchy` → 0 altered files. Everything lives in user-config
  area and official extension points (`plugins/`, menu jsonc,
  `autostart.lua` `o.launch_on_start`, a 1-line `require` in `hyprland.lua`).
  Package upgrades at worst leave new defaults as `.pacnew` files and the
  hooks go missing — visible, never destructive.
- **After any system upgrade, run the self-check:**

  ```sh
  ~/.config/omarchy/plugins/maxt.tablet-experience/install.sh --verify
  ```

  It checks the 8 helper scripts, the Hyprland hooks, plugin enablement, live
  keybinds and running daemons — read-only, exit 1 on anything broken.
  Recovery is always the same idempotent re-run: `install.sh`.
- Helpers use the reserved `texp-*` prefix so they can never shadow (or be
  shadowed by) official `omarchy-*` tools.

## Repository layout

```
omarchy-tablet-experience/            ← repo root = plugin root
├── manifest.json                  ← plugin manifest (service + bar-widget)
├── Service.qml                    ← state machine + IPC + auto-rotation/switch
├── BarWidget.qml                  ← always-mounted bar button + popup
├── install.sh / uninstall.sh      ← one-command setup/teardown (reversible)
├── scripts/                       ← helper daemons (auto-installed to ~/.local/bin)
│   ├── texp-vk                    ← VK toggle (SUPER+U / bar button; swipe daemon opt-in)
│   ├── texp-touch                 ← multi-touch gestures + last-touch tracking
│   ├── texp-close                 ← close panels/overlays/touched window
│   ├── texp-window                ← tablet actions (close/move/layout)
│   ├── texp-rotate                ← rotation (+ touch-device transform sync)
│   ├── texp-orient                ← IIO accel posture probe
│   ├── texp-kbdetect              ← detachable-keyboard USB presence
│   └── texp-bar-probe             ← uinput diagnostic (bar touch-hit checks)
├── config/hypr/tablet-experience.lua  ← keybinds + touch swipe (installed + hooked)
├── README.md / README.zh-CN.md    ← user docs (EN / ZH)
├── DEVELOPMENT.md                 ← full development log + hardware audit
└── LICENSE
```

## License

MIT — see [LICENSE](LICENSE).