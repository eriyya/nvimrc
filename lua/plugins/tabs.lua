return {
  'romgrk/barbar.nvim',
  event = { 'BufWinEnter', 'BufReadPre', 'BufNewFile' },
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  init = function()
    vim.g.barbar_auto_setup = false
  end,
  opts = {
    sidebar_filetypes = {
      ['neo-tree'] = { event = 'BufWipeout' },
      undotree = {
        text = 'undotree',
      },
      sort = {
        ignore_case = true,
      },
    },
  },
  version = '^1.0.0',
}
