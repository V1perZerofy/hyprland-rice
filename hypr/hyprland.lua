-- Hyprland Lua config (migrated from hyprland.conf for Hyprland 0.55+)
-- Reference: https://wiki.hypr.land/Configuring/Start/

------------------------------------------------------------
---- PYWAL COLORS ----
------------------------------------------------------------
-- The old config did `source = ~/.cache/wal/colors-hyprland.conf`, which is a
-- hyprlang file and can't be `require`d from Lua. Instead we read pywal's plain
-- `~/.cache/wal/colors` (16 hex lines) at load time and rebuild the colors.
-- This re-applies automatically every time Hyprland reloads after `wal` runs.

local function wal_colors()
	local c = {}
	local home = os.getenv("HOME") or ""
	local f = io.open(home .. "/.cache/wal/colors", "r")
	if f then
		for line in f:lines() do
			local hex = line:gsub("#", ""):gsub("%s", "")
			if #hex >= 6 then
				c[#c + 1] = "rgb(" .. hex:sub(1, 6) .. ")"
			end
		end
		f:close()
	end
	return c
end

local wal = wal_colors()
-- pywal color0..color15 -> wal[1]..wal[16]; fall back to a neutral grey.
local function color(n)
	return wal[n + 1] or "rgb(595959)"
end
local background = color(0)

------------------------------------------------------------
---- MONITORS ----
------------------------------------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Per-monitor layout is owned by HyprMon (hyprmon.lua, required at the bottom).
-- This catch-all only applies to outputs HyprMon has no rule for.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

------------------------------------------------------------
---- MY PROGRAMS ----
------------------------------------------------------------
local terminal = "kitty"
local fileManager = "dolphin"

------------------------------------------------------------
---- AUTOSTART ----
------------------------------------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
	hl.exec_cmd("hyprlock")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("qs -n -d")
	hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
	hl.exec_cmd("hypridle")
end)

------------------------------------------------------------
---- ENVIRONMENT VARIABLES ----
------------------------------------------------------------
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- hl.env("XCURSOR_SIZE", "24")
-- hl.env("HYPRCURSOR_SIZE", "24")

------------------------------------------------------------
---- LOOK AND FEEL ----
------------------------------------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,

		border_size = 2,

		col = {
			-- old: col.active_border = $color1 $color10 90deg
			active_border = { colors = { color(1), color(10) }, angle = 90 },
			-- old: col.inactive_border = $background
			inactive_border = background,
		},

		resize_on_border = false,
		allow_tearing = false,

		layout = "dwindle",
	},

	decoration = {
		rounding = 5,
		rounding_power = 2,

		active_opacity = 0.975,
		inactive_opacity = 0.8,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a, -- rgba(1a1a1aee)
		},

		blur = {
			enabled = true,
			size = 7,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},

	dwindle = {
		preserve_split = true,
	},

	master = {
		new_status = "master",
	},

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},

	input = {
		kb_layout = "de",

		follow_mouse = 1,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = true,
		},
	},
})

-- Animation curves, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.1, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

------------------------------------------------------------
---- INPUT DEVICES / GESTURES ----
------------------------------------------------------------
-- See https://wiki.hypr.land/Configuring/Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Per-device config
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

-- Disable touchscreen
hl.device({ name = "elan901c:00-04f3:2c4e", enabled = false })

------------------------------------------------------------
---- KEYBINDINGS ----
------------------------------------------------------------
local mainMod = "SUPER"

-- Programs
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("qs ipc call launcher toggle")) -- app launcher
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("qs ipc call wallpaper toggle")) -- wallpaper picker
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call notes toggle")) -- markdown notes sidebar
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("qs ipc call music search")) -- Apple Music search (Cider) in the media card
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("qs ipc call keybinds toggle")) -- keybind cheatsheet
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("qs ipc call overview toggle")) -- workspace overview
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("pkill -x qs; sleep 1; qs -n -d")) -- restart bar (-n: never two copies)
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("cider --ozone-platform=wayland"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("prusa-slicer"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("~/.config/hypr/scripts/code-here.sh"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("qs ipc call bar toggle")) -- toggle bar visibility
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs -n -d")) -- start bar if not running

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move focused window with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Fullscreen / maximize
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Switch / move-to workspaces with mainMod (+ SHIFT) + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	-- movetoworkspacesilent -> move without following (follow = false)
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Relative workspace switching
hl.bind(mainMod .. " + ALT + right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + ALT + left", hl.dsp.focus({ workspace = "r-1" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys (locked = active on lockscreen, repeating = key repeat)
-- osd.sh changes the value and shows the Quickshell OSD.
local osd = "~/.config/hypr/scripts/osd.sh "
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osd .. "vol-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osd .. "vol-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(osd .. "vol-mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(osd .. "mic-mute"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(osd .. "bright-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osd .. "bright-down"), { locked = true, repeating = true })

-- Media keys (requires playerctl)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc call music play || playerctl play-pause"), { locked = true }) -- nothing loaded: shuffle recently played
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("qs ipc call music play || playerctl play-pause"), { locked = true }) -- nothing loaded: shuffle recently played
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Quickshell sidebar (its Dashboard tab has the todo list)
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call sidebar toggle")) -- dashboard + Ollama sidebar

-- Notifications (Quickshell notification centre)
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call notifs restore")) -- bring back last dismissed
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("qs ipc call notifs closeAll")) -- clear all on screen
hl.bind(mainMod .. " + CTRL + I", hl.dsp.exec_cmd("qs ipc call notifs dnd")) -- do not disturb

------------------------------------------------------------
---- WINDOWS AND WORKSPACES ----
------------------------------------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Ignore maximize requests from all apps.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "float-cider",
	match = { class = "^([Cc]ider)$" },
	float = true,
})

hl.window_rule({
	name = "float-zenity",
	match = { class = "^([Zz]enity)$" },
	float = true,
})

-- hyprmon: managed monitor profile include
require("hyprmon")
