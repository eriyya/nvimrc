vim.opt.timeoutlen = 300
vim.opt.updatetime = 300

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = -1 -- Will use the value of shiftwidth
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.o.number = true
vim.wo.number = true
vim.opt.number = true
vim.opt.termguicolors = true

vim.opt.ruler = false
vim.opt.numberwidth = 2
vim.opt.mouse = 'a'
vim.opt.smartcase = true
vim.opt.ignorecase = true
vim.opt.fillchars = { eob = ' ' }
vim.opt.inccommand = 'split'

-- Line wrapping
vim.opt.wrap = true
vim.opt.breakindent = true
vim.opt.showbreak = string.rep(' ', 3) -- Make it so that long lines wrap smartly
vim.opt.linebreak = true

vim.opt.cursorline = true
vim.opt.showmode = true -- hide mode since it's shown in the statusbar

vim.opt.signcolumn = 'yes'
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.undofile = true

vim.opt.shortmess:append({ W = true, I = true, c = true, C = true })
vim.opt.winminwidth = 5 -- Minimum window width

vim.opt.list = true
---@diagnostic disable-next-line: missing-fields
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.scrolloff = 10

vim.o.signcolumn = 'yes'
vim.o.completeopt = 'menuone,noselect'
vim.o.commentstring = '' -- Set to empty string for treesitter aware commenting in mini.comment
vim.o.laststatus = 3

vim.g.markdown_fenced_languages = {
  'html',
  'css',
  'javascript',
  'typescript',
  'bash=sh',
  'json',
  'lua',
}

if require('util').IS_WINDOWS then
  vim.opt.shell = 'pwsh'
end

vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)
