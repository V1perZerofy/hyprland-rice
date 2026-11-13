# nvim

[LazyVim](https://www.lazyvim.org) with a few changes for this rice.

- **Colours** come from pywal (`wal.nvim`) and update live when the wallpaper
  changes.
- **Languages** (LazyVim extras, see `lazyvim.json`): Python, Java (jdtls),
  JSON, YAML, TOML, Markdown, Prettier.
- **QML / Quickshell** (`lua/plugins/rice.lua`): `qmlls` from Qt. Quickshell
  writes the import paths into `~/.config/quickshell/.qmlls.ini` (create the
  empty file once, then restart `qs`).
- **hyprland.lua** gets completion and type checks from Hyprland's own stubs
  via `~/.config/hypr/.luarc.json`.
- Tree-sitter for qmljs, hyprlang, fish, rasi, java; `hypr/*.conf` files are
  hyprlang.

Language servers install through Mason on first use (`:Mason` to check).
Java needs a JDK (21+).
