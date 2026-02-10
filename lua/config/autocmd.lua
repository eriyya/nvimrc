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
  callback = function()
    if vim.bo[vim.api.nvim_get_current_buf()].filetype == 'neo-tree' then
      vim.opt.number = false
    else
      vim.cmd([[set nu nornu]])
    end
  end,
})
autocmd('InsertLeave', {
  group = 'LineNumbers',
  callback = function()
    if vim.bo[vim.api.nvim_get_current_buf()].filetype == 'neo-tree' then
      vim.opt.number = false
    else
      vim.cmd([[set nu rnu]])
    end
  end,
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
autocmd('FileType', {
  group = augroup('wrap_spell', { clear = true }),
  pattern = { 'text', 'plaintex', 'typst', 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    if not vim.g.vscode then
      vim.opt_local.spell = true
    end
  end,
})

-- Reset terminal mouse mode on exit to prevent mouse events leaking to shell
autocmd('VimLeave', {
  group = 'General',
  callback = function()
    vim.o.mouse = ''
    -- Send escape sequences to disable mouse tracking
    io.stdout:write('\x1b[?1000l') -- Disable mouse click tracking
    io.stdout:write('\x1b[?1002l') -- Disable mouse drag tracking
    io.stdout:write('\x1b[?1003l') -- Disable all mouse tracking
    io.stdout:write('\x1b[?1006l') -- Disable SGR extended mouse mode
  end,
})
