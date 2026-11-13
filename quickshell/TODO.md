# Quickshell — task list

Ideas and loose ends for this shell. Tick things off as they land.
Restart after edits with `SUPER+Z` — the file watcher doesn't always notice
changes. Always start with `qs -n` so a crash-restart can't leave two bars.

## Done

- [x] Bar (replaces waybar): clock, window title, workspaces, media, tray, bell,
      updates, monitors, Wi-Fi, sound, Bluetooth, battery
- [x] Drop-down cards: calendar, media, updates, Wi-Fi, sound, Bluetooth, power
- [x] OSD for volume / mic / brightness (`Osd.qml`, driven by `hypr/scripts/osd.sh`)
- [x] Notification daemon + centre (replaces dunst; dunst.service is masked)
- [x] App launcher with fuzzy search, most-used ranking, qalc maths (`SUPER+space`)
- [x] Wallpaper picker with cached thumbnails, filter, random (`SUPER+B`)
- [x] Workspace previews: hover a chip → live mini-map of that workspace
      (`modules/WorkspacePreview.qml`); click a window to focus it
- [x] Left sidebar (`SUPER+A`, replaces eww): Dashboard (toggles, sliders, media,
      system stats, todo.txt) + Assistant (streaming Ollama chat)
- [x] Wallpaper picker shows each wallpaper's pywal palette + a bar mock-up
      before applying (`scripts/wal-palettes.py`)
- [x] Cava visualiser in the media pill while something plays (`services/Cava.qml`)
- [x] VPN tab in the Wi-Fi card: Tailscale (switch, peers, exit node), NetworkManager
      OpenVPN/WireGuard profiles, hand-started openvpn, one-click .ovpn import
- [x] Markdown notes sidebar (`SUPER+M`, `Notes.qml`): Obsidian vault browser,
      wikilinks, clickable task boxes, quick edit, pin to reserve space
- [x] Apple Music search in the media card via Cider's local API (services/Cider.qml):
  catalog/library, play now / next / later, album/playlist/artist drill-in; SUPER+U opens it
- [x] Keybind cheatsheet on SUPER+H (Keybinds.qml + scripts/keybinds.py): reads
  hyprland.lua on every open, groups and describes binds, type to filter
- [x] Play with nothing loaded in Cider (media keys, pill middle-click, card button)
  shuffles your Heavy Rotation mix (falls back to recently played songs);
  starts Cider first if needed
- [x] Battery warnings: notification at 15 % and 5 % (critical, shows even in
  Do Not Disturb), battery pill pulses red; once per discharge
- [x] Workspace overview on SUPER+Tab (Overview.qml): live previews, click to go,
  drag a window onto a workspace to move it, middle-click closes, ←→↑↓ Enter 1–9
- [x] Settings overlay on SUPER+comma (SettingsPanel.qml, services/Settings.qml):
  bar top/bottom, bar + pill opacity, size, module toggles, 24 h clock, weather
  place + units; saved to ~/.local/state/quickshell-settings.json
- [x] Weather pill + card (Open-Meteo): now, 12 hours, 5 days

## Left sidebar

- [ ] Night light tile (needs `hyprsunset`, not installed)
- [ ] Mini calendar / upcoming events on the dashboard
- [ ] Assistant: per-chat sessions, regenerate, copy-code buttons
- [ ] Assistant: "ask about clipboard / selected text" shortcut
- [ ] Faster replies: Ollama on the Iris Xe GPU (Vulkan) instead of CPU

## Notes sidebar

- [ ] Backlinks ("linked from") at the bottom of a note
- [ ] Callouts (`> [!note]`) and tags as coloured chips
- [ ] Inline images (`![[img.png]]`)
- [ ] Full-text search across the vault (rg), not just titles
- [ ] New note from template (99_Templates) / daily note button
- [ ] Remember scroll position per note

## Workspace previews


## Next up

- [ ] **System stats pill** in the bar (stats exist in the sidebar now); card with top processes
- [ ] **Screenshot / recording card**: region / window / screen via hyprshot,
      red recording dot in the bar

## Launcher

- [ ] Pinned / favourite apps row
- [ ] Desktop-entry actions (e.g. "New private window") on Shift+Enter or →
- [ ] Prefix modes: `>` run shell command, `?` web search, `:` emoji, `/` files
- [ ] Clipboard history mode (cliphist)
- [ ] Unit conversion prints decimals instead of qalc's mixed units
      ("3 mi + 188 yd …") — find the right qalc setting
- [ ] Window switcher mode (search open windows, focus on Enter)

## Wallpaper picker

- [ ] Subfolders / multiple wallpaper directories
- [ ] Animated preview for gifs (AnimatedImage on hover)
- [ ] Per-monitor wallpaper once a second monitor is connected

## Notifications

- [ ] Group by app in the centre (collapsible)
- [ ] Inline reply field for apps that support it (`hasInlineReply`)
- [ ] Persist history across full restarts (write to ~/.local/state)
- [ ] Per-app rules (mute / always-silent), like dunst's `[rules]`
- [ ] Notification sound for critical notifications

## VPN

- [ ] Delete / rename imported profiles from the tab (now: `nmcli connection delete <name>`)
- [ ] Proton server picker (country / fastest) via the Proton app's NetworkManager profiles
- [ ] Kill-switch toggle (block traffic when the VPN drops)
- [ ] Tailscale: login flow (`tailscale up` URL) and MagicDNS names in the peer list

## Bar polish

- [ ] Wi-Fi password prompt in the card (no impala round-trip for new networks)
- [ ] Hover tooltips (e.g. full window title, update list preview)
- [ ] Night light toggle (hyprsunset)
- [ ] Keyboard layout / caps-lock indicator

## Bigger projects

- [ ] Lock screen in the same style (replace hyprlock) via WlSessionLock
- [ ] Logout / power overlay (full-screen, like wlogout) on `SUPER+Escape`
- [ ] Polkit agent (replace polkit-kde-authentication-agent-1)

## Known issues / notes

- **colorz workaround**: the AUR package was built for Python 3.13 (system is
  3.14). Worked around by copying colorz.py to
  ~/.local/lib/python3.14/site-packages. Proper fix: `paru -S --rebuild colorz`,
  then delete that copy.
  All 16 current wallpapers are cached, so they still work.

- qs 0.3.2 sometimes crashes while shutting down (in QWindow::unsetCursor);
  its crash handler then restarts it. Harmless with `qs -n`.
- Don't name QML functions after built-in Item properties (`focus`, `visible`,
  `state`, …): the property shadows the function and calls fail silently.

- `Quickshell.Networking` finds no devices with NetworkManager 1.58 on qs 0.3.2,
  so Wi-Fi uses `services/Net.qml` (nmcli). Revisit after a quickshell update.
- After restarting PipeWire (`systemctl --user restart pipewire …`) the bar
  keeps a dead PipeWire connection (volume card / OSD stop updating):
  restart it with SUPER+Z.
- Hyprland uses the Lua config: dispatches must be Lua, e.g.
  `Hyprland.dispatch('hl.dsp.focus({workspace="3"})')`.
- With dunst masked, notifications go nowhere while qs isn't running.
  Undo: `systemctl --user unmask dunst.service`.
- Old setup archived (waybar, eww, dunst, rofi configs, the pre-Quickshell
  hyprland.lua and its backups): `~/config-archive/2026-11-11/`.
- **Greyscale wallpapers**: colorz can't get enough colours from near-greyscale
  images, so setwall.sh and the picker fall back to wal's default backend. 5
  wallpapers fail with both (planet with rings, building with square windows,
  man with guitar, person on a wall, flowers painting: magick can't read it).
  Applying one of these changes the wallpaper but keeps the old colours.

## Music (Cider)
- Dedicated API token: create one in Cider → Settings → Connectivity and save
  it to ~/.config/quickshell/cider-token (now borrows the Cider Remote token)
- Lyrics view (check whether Cider's API exposes lyrics), queue view with reordering
- Like / rating buttons, repeat & shuffle toggles in the card
- Keyboard navigation (↑/↓) through results
