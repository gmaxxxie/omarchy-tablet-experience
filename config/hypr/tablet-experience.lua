-- Tablet Experience plugin — generated configuration.
-- Phase 2: native touch workspace swipe (restored after bar-touch fix).
-- Phase 4: Super+U toggles squeekboard (on-screen keyboard); touch devices
--          get the same toggle via bottom-edge upward swipe (texp-vk daemon).
-- Phase 5: rotation — Super+Shift+R cycles orientation (texp-rotate next),
--          touch/pen mapping follows automatically (input:touchdevice output
--          Auto). NOTE: Super+Ctrl+0..3 previously used here clashed with
--          omarchy's Bar-panel keybinds (keycode-bound); removed.
-- v1.1: keep the tablet top-bar toggle strip (maxt-tablet-bar-strip) above
--       the omarchy top bar so its shown-state tap reaches it.
-- v1.17: `above_lock 2, match:namespace wvkbd` renders the virtual keyboard
--       ABOVE the Quickshell ext-session-lock surface (the Omarchy lock
--       screen) and keeps it interactive, so in tablet mode the lock screen
--       can show wvkbd for password entry. The keyboard focus stays on the
--       lock surface — exactly what the password field needs. (Hyprland
--       layer rule `above_lock`: 2 = visible above + interactive on lock.)
hl.config({
  gestures = {
    workspace_swipe_touch = true,
    workspace_swipe_touch_invert = false,
  },
  layerrule = {
    "zindex 3, maxt-tablet-bar-strip",
    "above_lock 2, match:namespace wvkbd",
  },
})

hl.bind("SUPER + U", hl.dsp.exec_cmd("texp-vk toggle"), {
  description = "Toggle virtual keyboard (squeekboard)",
})

hl.bind("SUPER + SHIFT + U", hl.dsp.exec_cmd("omarchy-shell maxt.tablet-experience toggle"), {
  description = "Toggle Laptop/Tablet mode (tablet experience)",
})

hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("texp-rotate next"), {
  description = "Rotate screen: next orientation (0°→90°→180°→270°)",
})
