return {
  {
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
        pyright = {
          settings = {
            python = {
              analysis = {
                autoImportCompletions = false,
              },
            },
          },
        },
        clangd = {
          -- same as the LazyVim extra, except --header-insertion=never
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=never",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
        },
      },
    },
  },

  -- jdtls has no setting to stop auto-imports on completion, so drop the
  -- import edits it attaches to completion items before blink applies them.
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        providers = {
          lsp = {
            transform_items = function(_, items)
              for _, item in ipairs(items) do
                if item.client_name == "jdtls" then
                  item.additionalTextEdits = nil
                end
              end
              return items
            end,
          },
        },
      },
    },
  },
}
