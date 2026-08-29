-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Catch-all for any display not configured explicitly below.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Two LG 3440x1440 ultrawides stacked VERTICALLY.
-- At scale 1.25 each panel is 2752x1152 logical px, so the lower monitor
-- starts at y = 1152. Swap the two positions to flip which one is on top.
hl.monitor({ output = "HDMI-A-1", mode = "3440x1440@59.99", position = "0x0",    scale = omarchy_monitor_scale })
hl.monitor({ output = "DP-1",     mode = "3440x1440@75.05", position = "0x1152", scale = omarchy_monitor_scale })
