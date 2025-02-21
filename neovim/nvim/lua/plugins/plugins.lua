return {
  --TODO: maybe use hlchunk instead of indent-blankline later

  -- move navic to winbar:
  -- luajit is based on lua5.1, but 'table.move' added on lua 5.3
  -- so i hava to add 'barbecue.nvim' here
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.remove(opts.sections.lualine_c, 4)
    end,
  },
  {
    "utilyre/barbecue.nvim",
    lazy = "VeryLazy",
    event = "BufReadPre",
    dependencies = {
      "neovim/nvim-lspconfig",
      "SmiteshP/nvim-navic",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("barbecue").setup({
        context_follow_icon_color = true,
        show_dirname = false,
        -- show_basename = false,
      })
      require("barbecue.ui").toggle(true)
    end,
  },

  -- jk, jj as Esc in NORMAL mode
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup()
    end,
  },

  -- Configure gruvbox as colorscheme of LazyVim
  { "ellisonleao/gruvbox.nvim" },
  {
    "sainnhe/gruvbox-material",
    priority = 1000,
    config = function()
      vim.g.gruvbox_material_enable_italic = true
      vim.g.gruvbox_material_background = "medium" -- "hard" "medium" "hard"
      vim.g.gruvbox_material_foreground = "mix" -- "material" "mix" "original"
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
    },
  },

  {
    "rmagatti/goto-preview",
    keys = { "gp" },
    config = function()
      require("goto-preview").setup({
        width = 120,
        height = 25,
        default_mappings = true,
        debug = false,
        opacity = nil,
        post_open_hook = nil,
      })
    end,
  },

  -- for rust
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "rust-analyzer",
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      setup = {
        rust_analyzer = function()
          return true
        end,
      },
    },
  },
  {
    "hedyhli/outline.nvim",
    opts = {
      symbols = {
        filter = {
          rust = vim.list_extend(vim.deepcopy(LazyVim.config.kind_filter["default"]), { "Object" }),
        },
      },
    },
  },
  {
    "mrcjkb/rustaceanvim",
    opts = function(_, opts)
      -- save original on_attach
      local original_on_attach = opts.server.on_attach

      opts.server.on_attach = function(client, bufnr)
        -- perferm original on_attach
        if original_on_attach then
          original_on_attach(client, bufnr)
        end

        -- add new keybind
        vim.keymap.set("n", "<leader>ce", function()
          vim.cmd.RustLsp("expandMacro") -- 示例命令
        end, { desc = "Expand Macro", buffer = bufnr })
      end
    end,
  },
}
