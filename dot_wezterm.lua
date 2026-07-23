-- Pull in the wezterm API
local wezterm = require 'wezterm'
local mux = wezterm.mux
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()
local keys = {}
local mouse_bindings = {}
local launch_menu = {}

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 10
config.font = wezterm.font_with_fallback {
  'CaskaydiaCove Nerd Font Mono', -- patched Cascadia with Nerd Font icons
  'Cascadia Mono',
  'Consolas',
}
config.color_scheme = 'Monokai Pro Ristretto (Gogh)'

-- makes my cursor blink
config.default_cursor_style = 'BlinkingBar'

config.enable_kitty_keyboard = true

-- One config for every platform: detect at runtime instead of forking files.
local is_windows = wezterm.target_triple:find('windows') ~= nil

-- Aesthetics: slight transparency; Acrylic blur where Windows supports it.
config.window_background_opacity = 0.95
if is_windows then
  config.win32_system_backdrop = 'Acrylic'
end
config.window_padding = { left = 8, right = 8, top = 4, bottom = 4 }

-- Layered space background + supernova animation lives in a separate module.
-- Currently disabled because the per-frame set_config_overrides cost during nova
-- playback noticeably impacts terminal responsiveness. Set ENABLE_BACKGROUND to true
-- and revisit perf when ready (see ~/.config/wezterm/background.lua for tuning notes).
local ENABLE_BACKGROUND = false
if ENABLE_BACKGROUND then
  dofile(wezterm.home_dir .. '/.config/wezterm/background.lua').apply(config, wezterm)
end

-- Tab bar: fancy bar with title-formatting hook (defined at bottom of file).
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = true
config.tab_max_width = 32

-- Leader key: Ctrl-Space — no TUI, readline, vim, or shell binds this, so no conflicts.
-- Press Ctrl-Space, release, then a bound key within 1s.
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
  -- Splits (leader + |  or  leader + -)
  -- Side-by-side split. '\' alone (no shift) is the reliable binding — sidesteps
  -- shifted-glyph detection issues. '|' and 'Shift+\' kept as fallbacks.
  { key = '\\', mods = 'LEADER',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '|',  mods = 'LEADER',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '\\', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  -- '-' is reported as either the literal char or the key name 'Minus' depending on kitty keyboard protocol state. Bind both so it always fires.
  { key = '-',     mods = 'LEADER',   action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  { key = 'Minus', mods = 'LEADER',   action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  -- Pane focus (vim motions)
  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  -- Pane resize (leader + shift + hjkl)
  { key = 'H', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Left',  5 } },
  { key = 'J', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Down',  5 } },
  { key = 'K', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Up',    5 } },
  { key = 'L', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
  -- Tabs
  { key = 't', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = false } },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  -- Reorder current tab in the tab bar. Use shifted char ('N') with mods='LEADER' only —
  -- adding SHIFT to mods conflicts with the implicit shift in the char and the binding misses.
  { key = 'N', mods = 'LEADER', action = act.MoveTabRelative(1) },
  { key = 'P', mods = 'LEADER', action = act.MoveTabRelative(-1) },
  -- Rename current tab (tmux convention: leader + ,). Empty input keeps current name.
  { key = ',', mods = 'LEADER', action = act.PromptInputLine {
      description = 'Rename tab:',
      action = wezterm.action_callback(function(window, _pane, line)
        if line and #line > 0 then window:active_tab():set_title(line) end
      end),
  }},
  -- Workspaces (wezterm's tmux-like sessions)
  { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  { key = 's', mods = 'LEADER', action = act.SwitchWorkspaceRelative(1) },
  { key = 'S', mods = 'LEADER|SHIFT', action = act.PromptInputLine {
      description = 'New workspace name:',
      action = wezterm.action_callback(function(window, pane, line)
        if line then window:perform_action(act.SwitchToWorkspace { name = line }, pane) end
      end),
  }},
  -- Quick-select (hint-mode jumps to URLs/hashes) and copy-mode (vim-like buffer scroll)
  { key = 'f', mods = 'LEADER', action = act.QuickSelect },
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
  -- Existing: paste from clipboard
  { key = 'V', mods = 'CTRL',   action = act.PasteFrom 'Clipboard' },
}

-- Leader + 1..9 to jump directly to a tab
for i = 1, 9 do
  table.insert(config.keys, { key = tostring(i), mods = 'LEADER', action = act.ActivateTab(i - 1) })
end


-- There are mouse binding to mimc Windows Terminal and let you copy
-- To copy just highlight something and right click. Simple
mouse_bindings = {
  {
    event = { Down = { streak = 3, button = 'Left' } },
    action = wezterm.action.SelectTextAtMouseCursor 'SemanticZone',
    mods = 'NONE',
  },
 {
  event = { Down = { streak = 1, button = "Right" } },
  mods = "NONE",
  action = wezterm.action_callback(function(window, pane)
   local has_selection = window:get_selection_text_for_pane(pane) ~= ""
   if has_selection then
    window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
    window:perform_action(act.ClearSelection, pane)
   else
    window:perform_action(act({ PasteFrom = "Clipboard" }), pane)
   end
  end),
 },
}
-- Assign after the table is populated (previously assigned while empty).
config.mouse_bindings = mouse_bindings

-- Windows machines with WSL: launch new tabs/windows into the first WSL
-- distro's login shell (zsh + starship) with proper \\wsl$ cwd handling.
-- Pure Windows and native Linux machines keep wezterm's default local shell.
if is_windows then
  local wsl_domains = wezterm.default_wsl_domains()
  if #wsl_domains > 0 then
    config.default_domain = wsl_domains[1].name
  end
end

-- Tab title: "<index>  <title>". Prefers an explicit tab title (set via Ctrl-Space ,)
-- over the running pane's process title, so renamed tabs stick.
wezterm.on('format-tab-title', function(tab, _tabs, _panes, _config, _hover, _max_width)
  local title = (tab.tab_title and #tab.tab_title > 0) and tab.tab_title or tab.active_pane.title
  local index = tab.tab_index + 1
  return string.format(' %d  %s ', index, title)
end)

return config