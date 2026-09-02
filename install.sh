#!/usr/bin/env bash
# ============================================================================
# install.sh — Omarchy Tablet Experience: one-command system-side setup.
#
# The QML plugin itself installs with the standard Omarchy one-liner:
#     omarchy plugin add https://github.com/gmaxxxie/omarchy-tablet-experience.git --enable
# (the repo root IS the plugin folder; see manifest.json at the repository root)
#
# This script covers the NON-QML parts a detachable 2-in-1 needs on
# Arch/Omarchy, and is safe to run from either the dev clone or the plugin
# directory that `omarchy plugin add` created:
#
#   1. helper daemons -> ~/.local/bin/texp-{vk,rotate,orient,kbdetect,touch,close,window,bar-probe}
#   2. Hyprland hooks  -> touch workspace swipe, SUPER+U (VK), SUPER+SHIFT+U (mode
#                        toggle), SUPER+SHIFT+R (rotation cycle) in hyprland.lua
#   3. autostart hooks -> gesture + touch daemons launch on login
#   4. optional packages: required = squeekboard iio-sensor-proxy python-evdev;
#      --with-ime adds fcitx5-rime + CJK fonts; --with-camera adds libcamera
#
# Everything is reversible: modified files get *.bak.<timestamp> backups and
# uninstall.sh undoes every change. Run --dry-run first to preview.
#
# Usage:
#   ./install.sh                 install scripts + hooks + required packages
#   ./install.sh --no-packages   skip pacman (manual package install)
#   ./install.sh --with-ime      also install Chinese IME (fcitx5-rime + fonts)
#   ./install.sh --with-camera   also install libcamera (UVC camera in browsers)
#   ./install.sh --dry-run       preview only, change nothing
#   ./install.sh --verify        post-upgrade self-check (what would break)
# ============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
DRY_RUN=0
WITH_IME=0
WITH_CAMERA=0
DO_PACKAGES=1
VERIFY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --with-ime)  WITH_IME=1 ;;
    --with-camera) WITH_CAMERA=1 ;;
    --verify)    VERIFY=1 ;;
    -h|--help)   sed -n '2,42p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then printf '    would run: %s\n' "$*"; else "$@"; fi }

# ------------------------------------------------------------------- verify
# Post-upgrade self-check: reports every dependency that broke after an
# Omarchy/Hyprland update WITHOUT touching anything. Exit 1 if anything failed.
if [ "$VERIFY" -eq 1 ]; then
  FAIL=0
  ok()   { printf '\033[1;32m  [ok]\033[0m  %s\n' "$*"; }
  bad()  { printf '\033[1;31m  [FAIL]\033[0m %s\n' "$*"; FAIL=1; }
  echo "== tablet-experience --verify (read-only) =="

  # scripts present and matching the repo copy
  for src in "$REPO_ROOT"/scripts/texp-*; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    if [ -x "$BIN_DIR/$name" ] && cmp -s "$src" "$BIN_DIR/$name"; then
      ok "$name in $BIN_DIR (matches repo)"
    elif [ -x "$BIN_DIR/$name" ]; then
      bad "$name differs from repo — re-run install.sh"
    else
      bad "$name missing — re-run install.sh"
    fi
  done

  # hypr hooks
  grep -qF 'require("hypr.tablet-experience")' "$HYPR_DIR/hyprland.lua" 2>/dev/null \
    && ok "hyprland.lua: require hook present" \
    || bad "hyprland.lua: missing require hook — re-run install.sh"
  [ -f "$HYPR_DIR/tablet-experience.lua" ] \
    && ok "$HYPR_DIR/tablet-experience.lua present" \
    || bad "hypr config missing — re-run install.sh"
  grep -qF 'o.launch_on_start("texp-touch daemon")' "$HYPR_DIR/autostart.lua" 2>/dev/null \
    && ok "autostart: texp-touch daemon hook" \
    || bad "autostart: texp-touch hook missing — re-run install.sh"
  grep -qF 'o.launch_on_start("texp-vk daemon")' "$HYPR_DIR/autostart.lua" 2>/dev/null \
    && bad "autostart: texp-vk daemon hook present (bottom-swipe gesture is off by default) — remove the line or re-run install.sh" \
    || ok "autostart: no texp-vk daemon hook (bottom-swipe gesture disabled)"

  # plugin enabled by omarchy
  if omarchy plugin list --json 2>/dev/null | grep -q '"maxt.tablet-experience"'; then
    ok "plugin enabled in omarchy"
  else
    bad "plugin not enabled — omarchy plugin enable maxt.tablet-experience"
  fi

  # plugin QML must use the current texp-* helper names, and no second plugin
  # folder may shadow it: a stale copy (or a leftover backup dir with the same
  # manifest id) makes the shell serve OLD code — rotation / window-manage /
  # auto-switch then fail silently (omarchy-kbdetect-spam in the journal).
  PLUGINS_DIR="$HOME/.config/omarchy/plugins"
  PLUGIN_DIR="$PLUGINS_DIR/maxt.tablet-experience"
  if [ -d "$PLUGIN_DIR" ]; then
    if grep -rEq --include='*.qml' 'omarchy-(vk|touch|close|window|rotate|orient|kbdetect|bar-probe)' \
        "$PLUGIN_DIR" 2>/dev/null; then
      bad "plugin QML still calls omarchy-* helpers — copy Service.qml/BarWidget.qml from the repo"
    else
      ok "plugin QML uses texp-* helpers"
    fi
    DUPS="$(grep -rl 'maxt.tablet-experience' "$PLUGINS_DIR"/*/manifest.json 2>/dev/null \
            | grep -v "^$PLUGIN_DIR/manifest.json$" || true)"
    if [ -n "$DUPS" ]; then
      bad "duplicate plugin folder shadows the plugin: $(echo "$DUPS" | tr '\n' ' ')— move it out of $PLUGINS_DIR"
    else
      ok "no duplicate plugin folder shadows the plugin"
    fi
  else
    bad "plugin dir missing — omarchy plugin add <git-url> --enable"
  fi

  # keybinds actually registered in the live Hyprland session
  if command -v hyprctl >/dev/null && hyprctl binds -j >/dev/null 2>&1; then
    BINDS="$(hyprctl binds -j 2>/dev/null)"
    for desc in 'Toggle virtual keyboard' 'Toggle Laptop/Tablet mode' 'Rotate screen'; do
      echo "$BINDS" | grep -qF "$desc" \
        && ok "keybind live: $desc" \
        || bad "keybind missing: $desc (config not loaded — check hyprland.lua)"
    done
  else
    warn "hyprctl unavailable — skip live keybind check (session not running?)"
  fi

  # daemons running
  pgrep -f "$BIN_DIR/texp-touch daemon" >/dev/null 2>&1 \
    && ok "texp-touch daemon running" || warn "texp-touch daemon not running (starts at next login)"

  # input-device access (gesture daemons need /dev/input/event*)
  if [ -f /etc/udev/rules.d/99-tablet-experience-input.rules ] \
      && grep -q 'TAG+="uaccess"' /etc/udev/rules.d/99-tablet-experience-input.rules; then
    ok "input-device udev rule present (uaccess)"
  else
    bad "input-device udev rule missing — re-run install.sh (sudo needed)"
  fi
  if id -nG "$USER" | grep -qw input; then
    ok "user in group 'input'"
  else
    bad "user not in group 'input' — re-run install.sh (effective next login)"
  fi

  if [ "$FAIL" -eq 1 ]; then
    echo; echo "FAILURES FOUND — re-run: $0   (or --no-packages --dry-run to preview)"; exit 1
  fi
  echo; echo "ALL CHECKS PASSED — the plugin is intact after this upgrade."; exit 0
fi

# Backup a file ONLY when we are about to change it and no identical backup
# exists yet (prevents backup spam on repeated installs).
backup_file() {
  local f="$1" bak
  [ -e "$f" ] || return 0
  for bak in "${f}.bak."*; do
    [ -e "$bak" ] && cmp -s "$f" "$bak" && return 0
  done
  bak="${f}.bak.$(date +%Y%m%d%H%M%S)"
  run cp -a "$f" "$bak" && [ "$DRY_RUN" -eq 1 ] || log "backup: $f -> $bak"
}

append_if_missing() { # $1 file  $2 exact line
  local f="$1" line="$2"
  [ -f "$f" ] || { warn "not found: $f (skipped)"; return 0; }
  if grep -qF -- "$line" "$f"; then
    log "already present in $f: $line"
  else
    backup_file "$f"
    run sh -c "printf '\n%s\n' \"\$1\" >> \"\$2\"" _ "$line" "$f"
    log "appended to $f: $line"
  fi
}

[ "$DRY_RUN" -eq 1 ] && log "DRY RUN — nothing will be changed"

# ---------------------------------------------------------------- packages
if [ "$DO_PACKAGES" -eq 1 ]; then
  if command -v pacman >/dev/null 2>&1; then
    REQUIRED=(squeekboard iio-sensor-proxy python-evdev)
    [ "$WITH_IME" -eq 1 ]    && REQUIRED+=(fcitx5-rime librime noto-fonts-cjk wqy-microhei)
    [ "$WITH_CAMERA" -eq 1 ] && REQUIRED+=(libcamera)
    MISSING=()
    for p in "${REQUIRED[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || MISSING+=("$p"); done
    if [ "${#MISSING[@]}" -gt 0 ]; then
      log "installing packages: ${MISSING[*]} (may prompt for sudo)"
      run sudo pacman -S --needed --noconfirm "${MISSING[@]}"
    else
      log "packages already installed"
    fi
  else
    warn "pacman not found — install dependencies manually: ${REQUIRED[*]:-squeekboard iio-sensor-proxy python-evdev}"
  fi
else
  log "skipping packages (--no-packages)"
fi

# ------------------------------------------------------- helper scripts
log "installing helper daemons to $BIN_DIR"
run mkdir -p "$BIN_DIR"
for src in "$REPO_ROOT"/scripts/texp-*; do
  [ -f "$src" ] || continue
  dst="$BIN_DIR/$(basename "$src")"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    backup_file "$dst"
    run rm -f "$dst"
  fi
  run install -m 0755 "$src" "$dst"
  log "install: $dst"
done

# ------------------------------------------- input-device access (evdev)
# The gesture daemons (texp-vk / texp-touch) read the touchscreen from
# /dev/input/event* as the desktop user. On Arch those nodes are root:input
# 660, and after a reboot the desktop user may have no read access (group
# `input` empty / logind uaccess ACLs never granted) — the daemons then die
# at login and the virtual-keyboard bottom up-swipe stops working. Two
# complementary grants, both idempotent:
#   1. a project udev rule tags the event nodes with `uaccess` so
#      systemd-logind grants the ACTIVE seat session read ACLs (guaranteed
#      at device-add on the next boot; install-time trigger is best-effort);
#   2. the user is added to the `input` group — the guaranteed path, applies
#      to every session started after this point (login/reboot).
# For the CURRENT session right after install, restart the daemons under the
# new group:  newgrp input -c 'texp-vk daemon'   (and texp-touch)
INPUT_RULE=/etc/udev/rules.d/99-tablet-experience-input.rules
INPUT_RULE_CONTENT='# Tablet Experience (maxt.tablet-experience) - grant the active seat
# session read access to /dev/input/event* so the gesture daemons
# (texp-vk / texp-touch) can watch the touchscreen. Managed by
# install.sh/uninstall.sh; identical to the stock uaccess tag Arch
# applies to joysticks/sound devices.
SUBSYSTEM=="input", KERNEL=="event*", TAG+="uaccess"
'
needs_rule=$(if [ -f "$INPUT_RULE" ] && cmp -s <(printf '%s' "$INPUT_RULE_CONTENT") "$INPUT_RULE"; then echo 0; else echo 1; fi)
if [ "$needs_rule" = "1" ]; then
  if [ -f "$INPUT_RULE" ] && ! grep -q 'TAG+="uaccess"' "$INPUT_RULE"; then
    warn "$INPUT_RULE exists but does not look like ours — leaving it alone"
  else
    log "installing udev rule: $INPUT_RULE"
    run sh -c 'printf "%s\n" "$1" | sudo tee "$2" >/dev/null' _ "$INPUT_RULE_CONTENT" "$INPUT_RULE"
    log "reloading udev rules + retriggering input devices (grants read ACLs now)"
    run sudo udevadm control --reload
    run sudo udevadm trigger --subsystem-match=input
  fi
else
  log "input-device udev rule already present: $INPUT_RULE"
fi
if id -nG "$USER" | grep -qw input; then
  log "user $USER already in group 'input'"
else
  log "adding $USER to group 'input' (applies at next login/reboot)"
  run sudo usermod -aG input "$USER"
fi

# ------------------------------------------------------- Hyprland hooks
log "wiring Hyprland config ($HYPR_DIR)"
if [ -f "$REPO_ROOT/config/hypr/tablet-experience.lua" ]; then
  dst="$HYPR_DIR/tablet-experience.lua"
  if [ -e "$dst" ] && ! cmp -s "$dst" "$REPO_ROOT/config/hypr/tablet-experience.lua"; then
    backup_file "$dst"
  fi
  run install -m 0644 "$REPO_ROOT/config/hypr/tablet-experience.lua" "$dst"
  log "install: $dst"
else
  warn "config/hypr/tablet-experience.lua missing from repo — skipping"
fi
append_if_missing "$HYPR_DIR/hyprland.lua" 'require("hypr.tablet-experience")'

# --------------------------------------------------------- autostart hooks
if [ -f "$HYPR_DIR/autostart.lua" ]; then
  log "wiring autostart hooks"
  # v1.2.1: the texp-vk bottom-swipe GESTURE is disabled by default (user
  # request) — the on-screen keyboard still toggles via SUPER+U / the bar
  # button / the 3-finger tap, which use `texp-vk toggle` and need no daemon.
  # Re-enable the swipe with:  o.launch_on_start("texp-vk daemon")
  append_if_missing "$HYPR_DIR/autostart.lua" 'o.launch_on_start("texp-touch daemon")'
else
  warn "$HYPR_DIR/autostart.lua not found — daemons will not autostart (start them manually)"
fi

# ---------------------------------------------------------------- summary
log "done."
cat <<EOF

Next steps:
  1. Re-login (or \`omarchy restart shell\` + recovery) — service QML loads
     only on a fresh shell; verify with:
       journalctl --user -u omarchy-shell | grep 'tablet-experience Service LOADED'
  2. Toggle mode: SUPER+SHIFT+U  (or omarchy-shell maxt.tablet-experience toggle)
  3. Rotation: SUPER+SHIFT+R; auto mode switches ON by default — keyboard
     attach -> laptop, detach -> tablet (disable with setAutoSwitch off).
  4. Input-method quick switch + top-bar tap toggle: available in tablet mode
     (bar buttons; tap the top edge to show/hide the top bar).

  Input-device access: a udev rule (/etc/udev/rules.d/99-tablet-experience-input.rules)
  tagged /dev/input/event* with uaccess and you were added to group 'input',
  so the gesture daemons can read the touchscreen after reboots. The udev
  rule is honoured at the next device-add (boot); the group applies to every
  login from now on. Already logged in and want it now? Restart the daemons
  under the new group:
      newgrp input -c 'texp-vk daemon'
      newgrp input -c 'texp-touch daemon'

  Hardware overrides (export before login, e.g. ~/.config/environment.d/):
    OMARCHY_ROTATE_DISPLAY   display to rotate (default: first Hyprland monitor)
    OMARCHY_KB_VENDOR        detachable-keyboard USB vendor id  (default 17ef)
    OMARCHY_KB_PRODUCT       detachable-keyboard USB product id (default 60fe)
    OMARCHY_TOUCH_NAME       space-separated substrings matching the touch
                             device name (default: "wacom finger")

  Uninstall: $REPO_ROOT/uninstall.sh
  Remove plugin: omarchy plugin remove maxt.tablet-experience
EOF