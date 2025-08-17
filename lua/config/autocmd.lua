local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

augroup('General', { clear = true })

-- Highlight on yank
autocmd('TextYankPost', {
  group = augroup('YankHighlight', { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = 'IncSearch', timeout = 350 })
  end,
})

-- Absolute line numbers in insert mode and relative in normal mode
augroup('LineNumbers', { clear = true })
autocmd('InsertEnter', {
  group = 'LineNumbers',

  command = ':set nu nornu',
})
autocmd('InsertLeave', {
  group = 'LineNumbers',
  command = ':set nu rnu',
})

-- Disable continue comment on new line
autocmd('BufEnter', {
  group = 'General',
  desc = 'Disable New Line Comment',
  callback = function()
    vim.opt.formatoptions:remove('c')
    vim.opt.formatoptions:remove('r')
    vim.opt.formatoptions:remove('o')
  end,
})

-- wrap and check for spell in text filetypes
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('wrap_spell', { clear = true }),
  pattern = { 'text', 'plaintex', 'typst', 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})
