-- Enable the editor offset on startup
-- vim.api.nvim_create_autocmd('User', {
--   pattern = 'VeryLazy',
--   callback = function()
--     require('custom.editor-offset').toggle()
--   end,
-- })

-- inline-fold uses extmarks with inline virt_text and conceal
-- which causes rendering issues (ghost text) in vscode-neovim
if not vim.g.vscode then
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
end
