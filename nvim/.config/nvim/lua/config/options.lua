-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
vim.g.autoformat = false
vim.diagnostic.enable(false)
-- no full-width cursorline bar (it's opaque against a transparent terminal bg)
vim.opt.cursorlineopt = "number"
