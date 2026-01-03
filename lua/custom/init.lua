-- Enable the editor offset on startup
-- vim.api.nvim_create_autocmd('User', {
--   pattern = 'VeryLazy',
--   callback = function()
--     require('custom.editor-offset').toggle()
--   end,
-- })

require('custom.inline-fold').setup()
vim.api.nvim_create_autocmd('FileType', {
  pattern = {
    'html',
    'xhtml',
    'javascriptreact',
    'typescriptreact',
    'vue',
    'svelte',
    'astro',
    'php',
  },
  callback = function()
    require('custom.inline-fold').enable()
  end,
})
