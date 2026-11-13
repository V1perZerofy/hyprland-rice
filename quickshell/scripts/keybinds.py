#!/usr/bin/env python3
"""Read every hl.bind(...) from the Hyprland Lua config and print them as JSON
for the keybind cheatsheet (Keybinds.qml), grouped and described.

Descriptions: the bind's trailing `-- comment` if it has one, otherwise one
made from the action (exec_cmd command, dispatcher). The comment line above a
block of binds is kept as `note`. The `for i = 1, 10` workspace loop becomes
one row with the key "1…0".

usage: keybinds.py [config.lua]   ->  [{"group", "binds": [{"keys", "desc", "cmd"}]}]
"""
import json, os, re, sys

path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.config/hypr/hyprland.lua")
src = open(path).read().splitlines()

# local name = "string"  → resolve variables in keys and commands
vars_ = {}
for l in src:
    m = re.match(r'\s*local\s+(\w+)\s*=\s*"([^"]*)"', l)
    if m:
        vars_[m.group(1)] = m.group(2)


def lua_str(expr, loop_key=None):
    """Evaluate a `"a" .. var .. "b"` concatenation."""
    out = ""
    for part in re.findall(r'"(?:[^"\\]|\\.)*"|[A-Za-z_]\w*', expr):
        if part.startswith('"'):
            out += part[1:-1]
        elif loop_key is not None and part in ("key", "i"):
            out += loop_key
        else:
            out += vars_.get(part, part)
    return out


def strip_comment(line):
    """Split `code -- comment`, ignoring "--" inside strings."""
    q = False
    for i, c in enumerate(line):
        if c == '"':
            q = not q
        elif not q and line.startswith("--", i):
            return line[:i].strip(), line[i + 2:].strip()
    return line.strip(), ""


def split_args(s):
    """Split the inside of hl.bind( ... ) at top-level commas."""
    depth, cur, out, q = 0, "", [], False
    for c in s:
        if c == '"':
            q = not q
        if not q:
            if c in "({[":
                depth += 1
            elif c in ")}]":
                depth -= 1
            elif c == "," and depth == 0:
                out.append(cur.strip())
                cur = ""
                continue
        cur += c
    out.append(cur.strip())
    return out


KEY_NAMES = {
    "return": "Enter", "space": "Space", "left": "←", "right": "→", "up": "↑", "down": "↓",
    "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑", "mouse:272": "Left drag", "mouse:273": "Right drag",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic mute", "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −",
    "XF86AudioNext": "Next", "XF86AudioPrev": "Prev", "XF86AudioPlay": "Play", "XF86AudioPause": "Pause",
    "TAB": "Tab", "comma": ",", "Tab": "Tab", "CTRL": "Ctrl", "SHIFT": "Shift", "ALT": "Alt", "SUPER": "Super",
}


def keys_of(combo):
    return [KEY_NAMES.get(k.strip(), k.strip().upper() if len(k.strip()) == 1 else k.strip())
            for k in combo.split("+") if k.strip()]


QS = {  # qs ipc call <target> <fn>
    "launcher toggle": "App launcher", "wallpaper toggle": "Wallpaper picker",
    "notes toggle": "Markdown notes", "music search": "Search music (Cider)",
    "bar toggle": "Show / hide bar", "sidebar toggle": "Dashboard sidebar",
    "notifs restore": "Restore last notification", "notifs closeAll": "Clear notifications",
    "notifs dnd": "Do not disturb", "keybinds toggle": "This cheatsheet",
    "music play": "Play / pause", "overview toggle": "Workspace overview", "settings toggle": "Settings",
}


def _describe(action, loop_key):
    m = re.match(r'hl\.dsp\.exec_cmd\((.*)\)$', action, re.S)
    if m:
        cmd = lua_str(m.group(1))
        q = re.search(r"qs ipc call (\w+ \w+)", cmd)
        if q:
            return QS.get(q.group(1), q.group(1).split()[0]), cmd
        if "pkill -x qs" in cmd:
            return "Restart shell", cmd
        if cmd.startswith("qs "):
            return "Start shell", cmd
        if "osd.sh" in cmd:
            return {"vol-up": "Volume up", "vol-down": "Volume down", "vol-mute": "Mute audio",
                    "mic-mute": "Mute microphone", "bright-up": "Brightness up",
                    "bright-down": "Brightness down"}.get(cmd.split()[-1], cmd), cmd
        if cmd.startswith("playerctl "):
            return {"next": "Next track", "previous": "Previous track",
                    "play-pause": "Play / pause"}.get(cmd.split()[1], cmd), cmd
        prog = os.path.basename(cmd.split()[0])
        named = {"kitty": "Terminal", "dolphin": "File manager", "firefox": "Firefox",
                 "hyprlock": "Lock screen", "hyprshot": "Screenshot (region)",
                 "cider": "Cider (Apple Music)", "prusa-slicer": "PrusaSlicer",
                 "code-here.sh": "VS Code in current folder"}
        return named.get(prog, prog), cmd
    arg = lambda k: (re.search(k + r'\s*=\s*"?([^",}]+)"?', action) or [None, ""])[1].strip()
    if "window.close" in action:
        return "Close window", ""
    if "dsp.exit" in action:
        return "Exit Hyprland", ""
    if "window.float" in action:
        return "Toggle floating", ""
    if "window.fullscreen" in action:
        return "Maximize" if arg("mode") == "maximized" else "Fullscreen", ""
    if "dsp.layout" in action:
        return "Toggle split direction", ""
    if "window.drag" in action:
        return "Move window", ""
    if "window.resize" in action:
        return "Resize window", ""
    if "toggle_special" in action:
        return "Toggle scratchpad", ""
    ws = arg("workspace")
    if "dsp.focus" in action:
        if arg("direction"):
            return "Focus " + arg("direction"), ""
        return {"r+1": "Next workspace", "r-1": "Previous workspace", "e+1": "Next used workspace",
                "e-1": "Previous used workspace"}.get(ws, "Go to workspace" + ("" if loop_key else " " + ws)), ""
    if "window.move" in action:
        if arg("direction"):
            return "Move window " + arg("direction"), ""
        if ws.startswith("special"):
            return "Send window to scratchpad", ""
        return ("Send window to workspace" if loop_key else "Send window to workspace " + ws) + (", stay" if "follow = false" in action else ""), ""
    return re.sub(r"hl\.dsp\.", "", action).split("(")[0], ""


def describe(action, loop_key):
    """→ (description, command, True if the description is a specific one)"""
    desc, cmd = _describe(action, loop_key)
    generic = desc == os.path.basename(cmd.split()[0]) if cmd else "(" in desc or desc.islower()
    return desc, cmd, not generic


def group_of(keys, action, cmd, mouse):
    if mouse or any(k.startswith("Scroll") for k in keys):
        return "Mouse"
    if keys[0] not in ("Super",):
        return "Media & hardware"
    if "qs ipc" in cmd or cmd.startswith("qs ") or "pkill -x qs" in cmd:
        return "Shell"
    if "workspace" in action or "toggle_special" in action:
        return "Workspaces"
    if "dsp.window" in action or "dsp.layout" in action or "direction" in action:
        return "Windows"
    if "dsp.exit" in action or cmd.startswith("hyprlock"):
        return "Session"
    return "Apps"


ORDER = ["Apps", "Shell", "Windows", "Workspaces", "Mouse", "Media & hardware", "Session"]
groups = {g: [] for g in ORDER}
seen = set()
in_loop = False
for l in src:
    s = l.strip()
    if re.match(r"for\s+i\s*=\s*1\s*,\s*10\s+do", s):
        in_loop = True
    elif s == "end":
        in_loop = False
    code, comment = strip_comment(s)
    m = re.match(r"hl\.bind\((.*)\)$", code)
    if not m:
        continue
    args = split_args(m.group(1))
    if len(args) < 2:
        continue
    loop_key = "1 – 0" if in_loop else None
    combo = lua_str(args[0], loop_key)
    keys = keys_of(combo)
    desc, cmd, known = describe(args[1], loop_key)
    if comment and not known:
        # "app launcher (rofi: `menu`)" → drop the note in brackets
        c = re.sub(r"\s*\(.*\)$", "", comment) or comment
        desc = c[0].upper() + c[1:]
    mouse = len(args) > 2 and "mouse = true" in args[2]
    key = (tuple(keys), desc)
    if key in seen:
        continue
    seen.add(key)
    groups[group_of(keys, args[1], cmd, mouse)].append({"keys": keys, "desc": desc, "cmd": cmd})

# play + pause on the same action → one row
media = groups["Media & hardware"]
pp = [b for b in media if b["desc"] == "Play / pause"]
if len(pp) > 1:
    pp[0]["keys"] = [pp[0]["keys"][0] + " / " + pp[1]["keys"][0]]
    media.remove(pp[1])

print(json.dumps([{"group": g, "binds": groups[g]} for g in ORDER if groups[g]], ensure_ascii=False))
