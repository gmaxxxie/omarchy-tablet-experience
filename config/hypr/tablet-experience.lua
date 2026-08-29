-- Tablet Experience plugin — generated configuration.
-- Phase 2: native touch workspace swipe (restored after bar-touch fix).
-- Phase 4: Super+U toggles squeekboard (on-screen keyboard); touch devices
--          get the same toggle via bottom-edge upward swipe (omarchy-vk daemon).
-- Phase 5: manual screen rotation — Super+Ctrl+0..3 (omarchy-rotate); touch/
--          pen mapping follows automatically (input:touchdevice:output=Auto).
hl.config({
  gestures = {
    workspace_swipe_touch = true,
    workspace_swipe_touch_invert = false,
  },
})

hl.bind("SUPER + U", hl.dsp.exec_cmd("omarchy-vk toggle"), {
  description = "Toggle virtual keyboard (squeekboard)",
})

hl.bind("SUPER + SHIFT + U", hl.dsp.exec_cmd("omarchy-shell maxt.tablet-experience toggle"), {
  description = "Toggle Laptop/Tablet mode (tablet experience)",
})

hl.bind("SUPER + CTRL + 0", hl.dsp.exec_cmd("omarchy-rotate 0"), {
  description = "Rotate screen: landscape 0°",
})
hl.bind("SUPER + CTRL + 1", hl.dsp.exec_cmd("omarchy-rotate 1"), {
  description = "Rotate screen: portrait 90°",
})
hl.bind("SUPER + CTRL + 2", hl.dsp.exec_cmd("omarchy-rotate 2"), {
  description = "Rotate screen: flipped 180°",
})
hl.bind("SUPER + CTRL + 3", hl.dsp.exec_cmd("omarchy-rotate 3"), {
  description = "Rotate screen: portrait 270°",
})
