-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

local disabled_plugins = {
  'gzip',
  'matchit',
  'matchparen',
  'netrwPlugin',
  'tarPlugin',
  'tohtml',
  'tutor',
  'zipPlugin',
}

if require('util').IS_WINDOWS then
  table.insert(disabled_plugins, 'man')
end

local plugin_spec = 'plugins'
if vim.g.vscode then
  plugin_spec = 'config/vscode/init'
end

-- Setup lazy.nvim
require('lazy').setup({
  spec = { import = plugin_spec },
  pkg = {
    -- sources = {
    --   'lazy',
    --   'packspec',
    -- },
  },
  performance = {
    rtp = {
      disabled_plugins = disabled_plugins,
    },
  },
})
