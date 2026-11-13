-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- hyprland/hyprlock/hypridle .conf files are hyprlang (hyprland.lua stays Lua)
vim.filetype.add({
  pattern = {
    [".*/hypr/.*%.conf"] = "hyprlang",
  },
})

-- mason's bin dir on PATH from the start (mason itself loads lazily), so
-- parser rebuilds after plugin updates find its tree-sitter CLI
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH
