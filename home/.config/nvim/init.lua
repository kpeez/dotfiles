-- ===========================================
-- NEOVIM CONFIGURATION
-- ===========================================

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ===========================================
-- SETTINGS
-- ===========================================

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.number = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.showmatch = true
vim.opt.colorcolumn = "80"

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.smartindent = true
vim.opt.linebreak = true
vim.opt.mouse = "a"

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.updatetime = 250
vim.opt.timeoutlen = 300


vim.opt.scrolloff = 8
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true

-- ===========================================
-- KEYMAPS
-- ===========================================

vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = "Save file" })
vim.keymap.set('n', '<C-s>', ':w<CR>', { desc = "Save file" })
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = "Move to left window" })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = "Move to lower window" })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = "Move to upper window" })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = "Move to right window" })
vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = "Quit" })
vim.keymap.set('n', '<leader>nh', ':nohlsearch<CR>', { desc = "Clear search highlight" })

-- ===========================================
-- PLUGINS
-- ===========================================

require("lazy").setup({
  -- Color Scheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({ flavour = "mocha" })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- File Tree
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file tree" },
    },
    opts = {
      filesystem = {
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = "open_current",
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
      window = { width = 35, mappings = { ["<space>"] = "none" } },
    },
  },

  -- Fuzzy finder: runs fzf, fd and rg, and shows hidden files by default
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "FzfLua",
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Find buffers" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
    },
    opts = {},
  },

  -- LSP. Neovim 0.12 maps K, grr, gra, grn, gri, grt and grx itself.
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { { "mason-org/mason.nvim", opts = {} }, "neovim/nvim-lspconfig" },
    opts = { ensure_installed = { "lua_ls" } },
    config = function(_, opts)
      vim.lsp.config("lua_ls", {
        settings = { Lua = { diagnostics = { globals = { "vim" } } } },
      })
      require("mason-lspconfig").setup(opts)
      vim.diagnostic.config({ virtual_text = true })
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf, desc = "Go to definition" })
        end,
      })
    end,
  },

  -- Autocompletion: LSP, path, snippet and buffer sources in one plugin
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        preset = "enter",
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    },
  },

  -- Status Line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "catppuccin" } },
  },

  -- Buffer tabs
  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({})
      vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>")
      vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>")
    end,
  },

  -- Git signs
  { "lewis6991/gitsigns.nvim", config = true },

  -- QoL plugins
  { "windwp/nvim-autopairs", event = "InsertEnter", config = true },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
  { "folke/which-key.nvim", event = "VeryLazy", config = true },
  { "folke/todo-comments.nvim", dependencies = { "nvim-lua/plenary.nvim" }, opts = {} },

  -- Dashboard
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local dashboard = require("alpha.themes.dashboard")
      dashboard.section.header.val = {
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
      }
      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", ":FzfLua files<CR>"),
        dashboard.button("r", "  Recent files", ":FzfLua oldfiles<CR>"),
        dashboard.button("e", "  File explorer", ":Neotree toggle<CR>"),
        dashboard.button("q", "  Quit", ":qa<CR>"),
      }
      require("alpha").setup(dashboard.config)
    end,
  },
})
