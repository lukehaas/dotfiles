local wezterm = require("wezterm")

local config = wezterm.config_builder()

local custom = wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]
custom.background = "#11111b"

config.color_schemes = {
  ["Catppuccin Espresso"] = custom,
}

config.adjust_window_size_when_changing_font_size = false
config.color_scheme = "Catppuccin Espresso"
config.enable_tab_bar = false
config.font_size = 15.0

config.window_background_opacity = 1.0

config.window_decorations = "RESIZE"

config.max_fps = 120
-- config.font = wezterm.font("DejaVuSansM Nerd Font Mono")
config.font = wezterm.font("JetBrainsMono NFP", { weight = "DemiBold" })
-- config.window_frame = {
--   font = wezterm.font("Hack Nerd Font", { weight = "DemiBold" }),
-- }

-- Disable mouse reporting in tmux when highlighting
-- config.bypass_mouse_reporting_modifiers = "SHIFT"

-- config.window_padding = {
--   left = '1cell',
--   right = '1cell',
--   top = '0.5cell',
--   bottom = '0.5cell',
-- }

config.line_height = 1.3

config.initial_cols = 180
config.initial_rows = 60

config.keys = {
  {
    key = 'Backspace',
    mods = 'CMD',
    action = wezterm.action.SendKey { key = 'u', mods = 'CTRL' },
  },
  {
    key = 'Enter',
    mods = 'SHIFT',
    action = wezterm.action.SendString('\x1b[13;2u'),
  }
}

config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

-- enable clickable link
config.mouse_bindings = {
  -- Cmd+Click to open links (macOS)
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}


-- config.inactive_pane_hsb = {
--   saturation = 0.0,
--   brightness = 0.5,
-- }


-- config.macos_window_background_blur = 50

-- config.window_frame.font_size = 13.0


return config
