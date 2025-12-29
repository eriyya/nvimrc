-- Disable netrw early (before any plugins load)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

if vim.loader then
  vim.loader.enable()
end

require('config.lazy')
require('config')
