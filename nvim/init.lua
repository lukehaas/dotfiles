-- Set Space as the global and local leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Basic options (default to 4 spaces)
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.undofile = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8

-- Clipboard & search
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Theme: built-in catppuccin picks Mocha or Latte from 'background', which
-- Neovim detects from the terminal. Clear the Normal background so the
-- terminal's own background (Espresso or E-Ink white) shows through.
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "catppuccin",
  callback = function()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    normal.bg = nil
    normal.ctermbg = nil
    vim.api.nvim_set_hl(0, "Normal", normal)
  end,
})
vim.cmd.colorscheme("catppuccin")

-- Set 2-space indentation for specific languages
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact", "html", "css", "json", "yaml", "lua" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
  end,
})

-- Keymap
-- Clear search highlights by pressing Esc in Normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- Keep text highlighted in Visual mode after indenting (< or >) so you can repeat it
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Open Neovim's built-in file explorer by pressing Space + e
vim.keymap.set("n", "<leader>e", "<cmd>Explore<CR>", { desc = "Open file explorer" })
