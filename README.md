# Hyprland rice

Hyprland (Lua config) + a custom [Quickshell](https://quickshell.org) shell,
themed from the wallpaper with pywal. This repo is `~/.config` itself; the
`.gitignore` is an allowlist, so only the folders below are tracked.

| Folder | What |
| --- | --- |
| `hypr/` | Hyprland (`hyprland.lua`), hyprlock, hypridle, HyprMon, OSD script — see `hypr/README.md` |
| `quickshell/` | Bar, notifications, OSD, launcher, wallpaper picker, sidebars, overview — see `quickshell/TODO.md` |
| `kitty/`, `fish/`, `starship.toml` | Terminal, shell, prompt |
| `wal/`, `scripts/` | pywal templates; `setwall.sh` sets wallpaper + palette |
| `nvim/` | Neovim (LazyVim) |
| `cava/`, `btop/`, `fastfetch/` | Tools |
| `gtk-3.0/`, `gtk-4.0/`, `qt5ct/` | Toolkit theming |
| `systemd/` | User units (dunst masked: Quickshell is the notification daemon) |

## Keybinds

`SUPER+H` shows every keybind, read live from `hypr/hyprland.lua`.
Highlights: `SUPER+Space` launcher · `SUPER+Tab` overview · `SUPER+A` sidebar ·
`SUPER+M` notes · `SUPER+B` wallpaper · `SUPER+U` music search.

## Dependencies (Arch / CachyOS)

hyprland, quickshell, hyprlock, hypridle, hyprshot, kitty, fish, starship,
awww (wallpaper daemon), python-pywal, pywalfox, cava, brightnessctl,
wireplumber (`wpctl`), playerctl, networkmanager, impala, wl-clipboard,
libnotify, libqalculate, ttf-jetbrains-mono-nerd.
Optional: Cider (Apple Music search / Heavy Rotation), Ollama (sidebar
assistant), tailscale + networkmanager-openvpn (VPN tab).

## Using it on another machine

```sh
git clone <this repo> ~/rice && cp -rn ~/rice/. ~/.config/   # or clone straight into an empty ~/.config
```
Paths assume the user's home is `$HOME`; wallpapers are read from
`~/Pictures/wallpaper`.
