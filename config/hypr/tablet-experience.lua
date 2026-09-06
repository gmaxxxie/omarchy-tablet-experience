-- Tablet Experience plugin — generated configuration.
-- Phase 2: native touch workspace swipe (restored after bar-touch fix).
-- Phase 4: Super+U toggles squeekboard (on-screen keyboard); touch devices
--          get the same toggle via bottom-edge upward swipe (texp-vk daemon).
-- Phase 5: rotation — Super+Shift+R cycles orientation (texp-rotate next),
--          touch/pen mapping follows automatically (input:touchdevice output
--          Auto). NOTE: Super+Ctrl+0..3 previously used here clashed with
--          omarchy's Bar-panel keybinds (keycode-bound); removed.
--
-- v1.17 layer rules — MIXED forms, each where it works:
--   * `zindex` is a LEGACY STRING-ONLY effect (there is no functional
--     `hl.layer_rule` field for it — using it errors with
--     "unknown field 'zindex'"), so the top-bar strip rule stays in the
--     string form inside hl.config.
--   * `above_lock` is NOT applied by the string form (verified by
--     pixel-sampling a locked screenshot), so the lock-screen rules use the
--     functional hl.layer_rule() form.
--   Both forms coexist in this file; the keyboard renders above the lock
--   while the strip still floats above the bar.
--
--   * maxt-tablet-bar-strip : keep the tablet top-bar toggle strip above the
--     omarchy top bar so its shown-state tap reaches it (v1.1).
--   * wvkbd                  : render the virtual keyboard ABOVE the
--     Quickshell ext-session-lock surface (the Omarchy lock screen) and keep
--     it interactive, so the lock screen can show it for password entry.
--     Keyboard focus stays on the lock surface — exactly what the password
--     field needs. `above_lock`: 2 = visible above + interactive on lock.
--   * maxt-tablet-vk-toggle  : the lock-screen "keyboard" button (shown while
--     locked and the keyboard is collapsed) also renders above the lock.
hl.config({
  gestures = {
    workspace_swipe_touch = true,
    workspace_swipe_touch_invert = false,
  },
  layerrule = {
    "zindex 3, maxt-tablet-bar-strip",
  },
})

hl.layer_rule({
  match = { namespace = "wvkbd" },
  above_lock = 2,
})

hl.layer_rule({
  match = { namespace = "maxt-tablet-vk-toggle" },
  above_lock = 2,
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
