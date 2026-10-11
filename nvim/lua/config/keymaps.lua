-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit insert mode with jk" })

vim.keymap.set({ "i", "t", "c" }, "jk", function()
  -- Command-line mode
  if vim.fn.getcmdtype() ~= "" then
    return "<C-c><C-c>"
  end
  -- Terminal mode
  if vim.bo.buftype == "terminal" then
    return [[<C-\><C-n>]]
  end
  -- Insert mode
  return "<Esc>"
end, { expr = true, desc = "Universal exit with jk" })
