# hyprland-rice

My daily driver: **Hyprland** on CachyOS with a shell I built in
**[Quickshell](https://quickshell.org)**. It started as "make my waybar a bit
nicer" and turned into a whole desktop. Loosely inspired by
[noctalia](https://github.com/noctalia-dev/noctalia-shell) and
[end-4's dots](https://github.com/end-4/dots-hyprland), but smaller, built
around how I actually use my laptop.

Everything takes its colours from the wallpaper. Pick a new one with
`SUPER+B` and the bar, notifications, terminal, Firefox and window borders all
follow.

> This repo *is* my `~/.config`. The `.gitignore` is an allowlist, so only the
> folders that make up the rice are tracked. Everything else in there (browsers,
> Discord, …) stays out.

---

## What's in it

**The bar** (`quickshell/`)
- Workspaces: hover one for a **live preview** of its windows, click to jump
- Clock with a calendar · active window title
- **Music**: track, progress and a live **cava** visualiser; the card has an
  **Apple Music search** through [Cider](https://cider.sh) (`SUPER+U`)
- Wi-Fi card with a **VPN tab**: Tailscale (exit nodes too), OpenVPN/WireGuard
  profiles, one-click `.ovpn` import, Proton VPN
- Volume, Bluetooth, battery with a power menu, updates (repo + AUR), tray
- Battery warnings at 15 % and 5 % (the pill pulses red)

**Around the bar**
- **Notifications**: toasts and a notification centre. Replaces dunst.
  Do Not Disturb still lets critical ones through.
- **OSD** for volume, mic and brightness keys
- **App launcher** (`SUPER+Space`): fuzzy search, most-used first, maths via qalc
- **Wallpaper picker** (`SUPER+B`): shows each wallpaper's pywal palette
  *before* you apply it
- **Workspace overview** (`SUPER+Tab`): every workspace live, drag windows
  between them, middle-click to close
- **Sidebar** (`SUPER+A`): quick toggles, sliders, media, system stats, a todo
  list and a local **Ollama** chat
- **Notes** (`SUPER+M`): reads my Obsidian vault right in a sidebar, with
  wikilinks and checkboxes
- **Keybind cheatsheet** (`SUPER+H`): built live from `hyprland.lua`, so it's
  never out of date

**Media keys**: Play with nothing loaded shuffles my Apple Music *Heavy
Rotation* mix. I'm lazy and I like it.

**Also here:** kitty, fish + starship, Neovim (LazyVim), cava, btop, fastfetch,
GTK/Qt theming. `quickshell/TODO.md` is my running list of what's done and
what's next.

## Keybinds (the ones worth knowing)

| Keys | What |
| --- | --- |
| `SUPER+H` | **All** keybinds, so you don't need this table |
| `SUPER+T` / `SUPER+Enter` | Terminal |
| `SUPER+Space` | Launcher |
| `SUPER+Tab` | Workspace overview |
| `SUPER+A` | Sidebar (dashboard + assistant) |
| `SUPER+M` | Notes |
| `SUPER+B` | Wallpaper picker |
| `SUPER+U` | Music search (starts Cider if needed) |
| `SUPER+O` | Show / hide the bar |
| `SUPER+Z` | Restart the shell |
| `SUPER+I` / `+Shift` / `+Ctrl` | Restore notification / clear all / Do Not Disturb |

---

## Getting it running

I run **CachyOS** (Arch-based). It should work on any Arch with an AUR helper;
other distros will need to translate the package names.

**Versions I'm on:** Hyprland 0.57 (needs **0.55+**, the config is the new
**Lua** format) · Quickshell 0.3.2.

### 1. Packages

```sh
# from the repos (on plain Arch, a few of these, e.g. quickshell or awww, may be AUR)
sudo pacman -S --needed \
  hyprland quickshell hyprlock hypridle hyprshot grim \
  kitty fish starship neovim btop fastfetch cava \
  awww pipewire wireplumber playerctl brightnessctl \
  networkmanager impala bluez bluez-utils pavucontrol \
  upower power-profiles-daemon polkit-kde-agent \
  wl-clipboard libnotify libqalculate pacman-contrib curl \
  dolphin ttf-jetbrains-mono-nerd

# from the AUR
paru -S python-pywal colorz python-pywalfox hyprmon-bin
```

**Optional**, only for the features that use them:

| Package | For |
| --- | --- |
| `cider` (AUR) | Music search + Heavy Rotation shuffle |
| `ollama` (+ `ollama pull llama3.2`) | Sidebar assistant |
| `tailscale`, `networkmanager-openvpn` | VPN tab |
| Proton VPN app | "Open Proton VPN" button |
| Obsidian | Notes sidebar (it just reads markdown, Obsidian itself is optional) |

### 2. Put the files in place

```sh
# back up what you have first!
git clone https://github.com/V1perZerofy/hyprland-rice.git ~/hyprland-rice
cp -rn ~/hyprland-rice/. ~/.config/
```

(On a fresh install you can also clone straight into an empty `~/.config`.)

### 3. One-time setup

```sh
# Quickshell is the notification daemon, so keep dunst from grabbing it
systemctl --user mask dunst.service

# wallpapers live here; the picker and setwall.sh read this folder
mkdir -p ~/Pictures/wallpaper        # …and put some wallpapers in it

# first palette (after that, just use SUPER+B)
~/.config/scripts/setwall.sh ~/Pictures/wallpaper/<some-image>
```

Log into Hyprland. The bar, OSD and notifications start on their own
(`qs -n -d` in the autostart).

### 4. Feature setup (only if you want them)

- **Cider:** in Cider, Settings → Connectivity, turn on the API and create a
  token. Save it to `~/.config/quickshell/cider-token`. Without that file the
  bar borrows the first token from Cider's own config.
- **Tailscale switch in the bar:** run `sudo tailscale set --operator=$USER`
  once (the VPN tab shows that command with a Copy button).
- **Ollama:** `systemctl enable --now ollama` and pull a model. The model
  button in the sidebar cycles through whatever you have.
- **Monitors:** I manage layouts with HyprMon (`hypr/hyprmon.lua`). Yours will
  differ: run `hyprmon` or edit the monitor section in `hyprland.lua`.

## Make it yours

A few paths are mine. Change them to match your setup:

| What | Where |
| --- | --- |
| Wallpaper folder `~/Pictures/wallpaper` | `quickshell/WallpaperPicker.qml` (`dir`) |
| Obsidian vault `~/Documents/Obsidian Vault` | `quickshell/Notes.qml` (`vault`) |
| Mix that Play starts ("Heavy Rotation") | `quickshell/services/Cider.qml` (`mixName`) |
| Assistant model `llama3.2` | `quickshell/sidebar/Assistant.qml` (`model`) |
| Apps on keybinds (firefox, dolphin, PrusaSlicer, …) | `hypr/hyprland.lua` |
| Font, sizes, corner radius | `quickshell/services/Theme.qml` |

## Known quirks

- **colorz on Python 3.14:** the AUR `colorz` package may be built for an
  older Python, and then `wal --backend colorz` fails. Fix:
  `paru -S --rebuild colorz` (or copy `colorz.py` into
  `~/.local/lib/python3.14/site-packages`).
- **Greyscale wallpapers:** colorz can't get a palette from near-black-and-white
  images. `setwall.sh` falls back to wal's default backend; a handful still
  fail and just keep the old colours.
- **No notifications while the shell is down**, because dunst is masked.
  `SUPER+N` starts it, `SUPER+Z` restarts it.
- **Hyprland's Lua dispatcher** silently ignores arguments it doesn't know. If
  you script against it, check `/usr/share/hypr/stubs/hl.meta.lua`.

## Credits

- [Quickshell](https://quickshell.org) and [Hyprland](https://hypr.land),
  which make all of this possible
- [noctalia](https://github.com/noctalia-dev/noctalia-shell) and
  [end-4](https://github.com/end-4/dots-hyprland) for the inspiration
- [pywal](https://github.com/dylanaraps/pywal) for the colours
- [LazyVim](https://www.lazyvim.org) for the Neovim base
- The cava shaders keep their authors' credits in the files
- [Claude](claude.ai) for helping me navigate all of this and helping me learn faster
