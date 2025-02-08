-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap
map.del({ "x", "n" }, ",")

-- disable macro recording of neovim
map.set("n", "q", "<Nop>", { noremap = true })

local wk = require("which-key")
map.set("n", ",", '<cmd>lua require("which-key").show(",", {mode = "n", auto = true})<cr>')
wk.add({
  { ",w", "<cmd>w<cr>", desc = "Save current buffer" },
  { ",h", "<cmd>noh<cr>", desc = "Disable highlight until next search" },
  {
    ",t",
    function()
      require("lazyvim.util.terminal").open({})
    end,
    desc = "Floting terminal",
  },
  { "<leader>;", "<cmd>Dashboard<cr>", desc = "Dashboard" },
})
