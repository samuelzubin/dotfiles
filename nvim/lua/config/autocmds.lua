-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  pattern = { "scratch" }, -- Replace or add your scratch buffer's filetype/pattern
  callback = function(args)
    local bufnr = args.buf

    -- 1. Disable diagnostics (errors & warnings) for this buffer
    vim.diagnostic.enable(false, { bufnr = bufnr })

    -- 2. Stop LSP client attachment (prevents code intelligence/completions from the LSP)
    vim.b[bufnr].lsp_enabled = false
    
    -- 3. Disable completion engines (Blink.cmp / nvim-cmp) locally for this buffer
    -- For blink.cmp:
    if vim.b[bufnr].blink_enabled ~= nil then
      vim.b[bufnr].blink_enabled = false
    end
    
    -- If using nvim-cmp, you can toggle it via buffer setup if needed, 
    -- or alternatively disable cmp-buffer/cmp-lsp sources for this specific buffer.
  end,
})
