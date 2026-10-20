return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          pick = function(cmd, opts)
            if cmd == "files" then
              -- include dotfiles; .git is still excluded by the picker
              opts = vim.tbl_extend("keep", opts or {}, { hidden = true })
            end
            return LazyVim.pick(cmd, opts)()
          end,
          header = [[
    _   __                _         
   / | / /__  ____ _   __(_)___ ___ 
  /  |/ / _ \/ __ \ | / / / __ `__ \
 / /|  /  __/ /_/ / |/ / / / / / / /
/_/ |_/\___/\____/|___/_/_/ /_/ /_/ 
]],
          -- stylua: ignore
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = " ", key = "n", desc = "New File",       action = ":ene | startinsert" },
            { icon = " ", key = "f", desc = "Find File",      action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = " ", key = "c", desc = "Config",         action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = " ", key = "q", desc = "Quit",           action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          {
            section = "startup",
            icon = "󱐋 ",
          },
        },
      },
    },
  },
}
