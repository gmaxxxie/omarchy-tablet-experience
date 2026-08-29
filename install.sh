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
#   1. helper daemons -> ~/.local/bin/omarchy-{vk,rotate,orient,kbdetect,touch,close,window,bar-probe}
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
# ============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
DRY_RUN=0
WITH_IME=0
WITH_CAMERA=0
DO_PACKAGES=1

for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --with-ime)  WITH_IME=1 ;;
    --with-camera) WITH_CAMERA=1 ;;
    -h|--help)   sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then printf '    would run: %s\n' "$*"; else "$@"; fi }

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
for src in "$REPO_ROOT"/scripts/omarchy-*; do
  [ -f "$src" ] || continue
  dst="$BIN_DIR/$(basename "$src")"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    backup_file "$dst"
    run rm -f "$dst"
  fi
  run install -m 0755 "$src" "$dst"
  log "install: $dst"
done

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
  append_if_missing "$HYPR_DIR/autostart.lua" 'o.launch_on_start("omarchy-vk daemon")'
  append_if_missing "$HYPR_DIR/autostart.lua" 'o.launch_on_start("omarchy-touch daemon")'
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

  Hardware overrides (export before login, e.g. ~/.config/environment.d/):
    OMARCHY_ROTATE_DISPLAY   display to rotate (default: first Hyprland monitor)
    OMARCHY_KB_VENDOR        detachable-keyboard USB vendor id  (default 17ef)
    OMARCHY_KB_PRODUCT       detachable-keyboard USB product id (default 60fe)
    OMARCHY_TOUCH_NAME       space-separated substrings matching the touch
                             device name (default: "wacom finger")

  Uninstall: $REPO_ROOT/uninstall.sh
  Remove plugin: omarchy plugin remove maxt.tablet-experience
EOF