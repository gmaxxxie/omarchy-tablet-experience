-- Tablet Experience (maxt.tablet-experience) — derived SDDM greeter
-- compositor config.
--
-- Same minimal settings as Omarchy's stock /usr/share/sddm/hyprland.lua,
-- plus a one-shot hook that starts the on-screen keyboard for the login
-- screen when the folio keyboard is detached (tablet mode, see
-- /usr/local/bin/texp-sddm-vk). Owned by install.sh; uninstall.sh restores
-- the stock omarchy CompositorCommand so this file is no longer referenced.
--
-- SDDM launches the greeter after the compositor is ready; the greeter's
-- password TextInput takes keyboard focus, so the wvkbd keys injected at the
-- compositor level land in the password field.
hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },

  animations = {
    enabled = false,
  },
})

hl.on("hyprland.start", function()
  hl.exec_cmd("/usr/local/bin/texp-sddm-vk")
end)
