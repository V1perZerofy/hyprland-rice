-- pywal colours (follows the wallpaper; live reload is in config/autocmds.lua)
return {
  {
    "saeedvaziry/wal.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "wal" },
  },
}
