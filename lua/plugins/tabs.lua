local eo = require('custom.editor-offset')

return {
  'romgrk/barbar.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  init = function()
    vim.g.barbar_auto_setup = false
  end,
  opts = {
    sidebar_filetypes = {
      ['neo-tree'] = { event = 'BufWipeout' },
      [eo.config.filetype] = { event = 'BufWipeout' },
      undotree = {
        text = 'undotree',
      },
      sort = {
        ignore_case = true,
      },
    },
    icons = {
      buffer_index = true,
      alternate = { buffer_index = true },
      current = { buffer_index = true },
      inactive = { buffer_index = true },
      visible = { buffer_index = true },
    },
  },
  version = '^1.0.0',
}
