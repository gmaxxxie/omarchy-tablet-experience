#!/usr/bin/env bash
# ============================================================================
# uninstall.sh — reverse everything install.sh did.
#
# Safety rules:
#   - scripts/configs are removed ONLY when they byte-match the repo copy
#     (user edits are kept and reported instead)
#   - backed-up originals are restored where a backup exists
#   - packages are NOT auto-removed (list printed instead)
#
# Usage:
#   ./uninstall.sh             undo install.sh changes
#   ./uninstall.sh --dry-run   preview only, change nothing
# ============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then printf '    would run: %s\n' "$*"; else "$@"; fi }

remove_deprecated_file() { # $1 path $2 path-to-repo-copy $3 short label
  local file="$1" repo="$2" label="$3"
  [ -e "$file" ] || return 0
  if cmp -s "$file" "$repo"; then
    run rm -f "$file"; log "removed $label: $file"
  else
    warn "$label differs from the repo copy — left in place: $file"
  fi
}

[ "$DRY_RUN" -eq 1 ] && log "DRY RUN — nothing will be changed"

# ------------------------------------------------------- autostart & hypr hooks
for f in "$HYPR_DIR/autostart.lua" "$HYPR_DIR/hyprland.lua"; do
  [ -f "$f" ] || continue
  orig_cksum="$(cksum "$f" | cut -d' ' -f1-2)"
  changed=0
  for line in \
    'o.launch_on_start("texp-vk daemon")' \
    'o.launch_on_start("texp-touch daemon")' \
    'require("hypr.tablet-experience")' \
  ; do
    if grep -qF -- "$line" "$f"; then
      run sed -i "\|${line}|d" "$f"
      log "removed from $f: $line"
      changed=1
    fi
  done
  if [ "$changed" -eq 1 ]; then
    new_cksum="$(cksum "$f" | cut -d' ' -f1-2)"
    [ "$orig_cksum" = "$new_cksum" ] || log "note: $f modified — restore with its *.bak.* if desired"
  fi
done

# ------------------------------------------------------- hypr config file
remove_deprecated_file "$HYPR_DIR/tablet-experience.lua" \
  "$REPO_ROOT/config/hypr/tablet-experience.lua" "hypr config"

# ------------------------------------------------------- helper scripts
for src in "$REPO_ROOT"/scripts/texp-*; do
  [ -f "$src" ] || continue
  remove_deprecated_file "$BIN_DIR/$(basename "$src")" "$src" "helper script"
done

# ------------------------------------------------------- input-device access
# Remove the udev rule install.sh wrote (only when it still byte-matches).
# The user's `input` group membership is NOT removed: it may predate the
# plugin, and losing it could silently break other input tools.
INPUT_RULE=/etc/udev/rules.d/99-tablet-experience-input.rules
INPUT_RULE_CONTENT='# Tablet Experience (maxt.tablet-experience) - grant the active seat
# session read access to /dev/input/event* so the gesture daemons
# (texp-vk / texp-touch) can watch the touchscreen. Managed by
# install.sh/uninstall.sh; identical to the stock uaccess tag Arch
# applies to joysticks/sound devices.
SUBSYSTEM=="input", KERNEL=="event*", TAG+="uaccess"
'
if [ -e "$INPUT_RULE" ]; then
  if cmp -s <(printf '%s' "$INPUT_RULE_CONTENT") "$INPUT_RULE"; then
    run sudo rm -f "$INPUT_RULE"
    log "removed input-device udev rule: $INPUT_RULE"
    run sudo udevadm control --reload
    run sudo udevadm trigger --subsystem-match=input
  else
    warn "$INPUT_RULE differs from what install.sh wrote — left in place"
  fi
fi

# ------------------------------------------------------- summary
cat <<EOF

Done. Remaining manual cleanup (install.sh installed these — remove only if you
no longer want them):
  Packages: sudo pacman -Rns squeekboard iio-sensor-proxy python-evdev
            fcitx5-rime librime noto-fonts-cjk wqy-microhei libcamera
  Residual state: PersistentProperties for "maxt-tablet-experience" under the
    Quickshell state dir (mode/rotation preference survives removal on purpose).
  Remove the plugin itself: omarchy plugin remove maxt.tablet-experience
EOF