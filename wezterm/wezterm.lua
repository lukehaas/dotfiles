local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Theme: "dark" or "eink", set by the `theme` command. Watching the file
-- makes WezTerm reload when it changes. `theme sync` creates it at shell
-- start, so it is only missing before the first shell ever runs.
local theme_file = (os.getenv("XDG_STATE_HOME") or (wezterm.home_dir .. "/.local/state")) .. "/theme"
local theme = "dark"
local f = io.open(theme_file, "r")
if f then
  theme = f:read("l") or "dark"
  f:close()
  wezterm.add_to_config_reload_watch_list(theme_file)
end

local mocha = wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]
mocha.background = "#11111b"

config.color_schemes = {
  ["Catppuccin Espresso"] = mocha,
}

config.color_schemes["E-Ink"] = {
  foreground = "#000000",
  background = "#ffffff",
  cursor_bg = "#000000",
  cursor_fg = "#ffffff",
  cursor_border = "#000000",
  selection_fg = "#000000",
  selection_bg = "#b8b8b8",
  ansi = { "#e8e8e8", "#d70000", "#008f00", "#b07000", "#0050e0", "#b000b0", "#008ca0", "#000000" },
  brights = { "#666666", "#ff2020", "#00a800", "#d75f00", "#2070ff", "#d000d0", "#00a8c0", "#333333" },
}

config.adjust_window_size_when_changing_font_size = false
config.enable_tab_bar = false

if theme == "eink" then
  config.color_scheme = "E-Ink"
  config.bold_brightens_ansi_colors = "No"
  config.cursor_blink_rate = 0
  config.animation_fps = 1
  config.font_size = 17.0
else
  config.color_scheme = "Catppuccin Espresso"
  config.font_size = 15.0
end

config.window_background_opacity = 1.0

config.window_decorations = "RESIZE"

config.max_fps = 120
-- config.font = wezterm.font("DejaVuSansM Nerd Font Mono")
config.font = wezterm.font("JetBrains Mono", { weight = "DemiBold" })
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
  { key = 'LeftArrow', mods = 'CMD|OPT', action = wezterm.action.SendKey { key = 'LeftArrow', mods = 'ALT|SHIFT' } },
  { key = 'RightArrow', mods = 'CMD|OPT', action = wezterm.action.SendKey { key = 'RightArrow', mods = 'ALT|SHIFT' } },
  { key = 'Enter', mods = 'SHIFT', action = wezterm.action.SendString('\x1b\r') },
}

config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true


-- config.inactive_pane_hsb = {
--   saturation = 0.0,
--   brightness = 0.5,
-- }


-- config.macos_window_background_blur = 50

-- config.window_frame.font_size = 13.0


return config
