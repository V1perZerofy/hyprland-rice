-- Languages for the rice itself: Quickshell (QML) and Hyprland.
return {
  -- QML: qmlls ships with Qt, not mason. Quickshell writes the import paths
  -- (incl. the config's own qs.* modules) into ~/.config/quickshell/.qmlls.ini.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        qmlls = {
          mason = false,
          cmd = { "qmlls6" },
        },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, {
        "qmljs",
        "hyprlang",
        "fish",
        "rasi",
        "java",
      })
    end,
  },
}
