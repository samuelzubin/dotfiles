return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      ruff = {
        init_options = {
          settings = {
            lint = {
              ignore = {
                "DTZ001",
                "BLE001",
                "PLR1730",
              },
            },
          },
        },
      },
    },
  },
}
