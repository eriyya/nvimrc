local config_dir = vim.fn.stdpath('config')

return {
  lazy = true,
  cmd = { 'SaplingToggle', 'SaplingOpen' },
  name = 'sapling',
  dir = config_dir .. '/plugins/sapling.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    file_edit_mode = 'mixed',
    tree = {
      hidden_files = {
        '.git',
        'node_modules',
      },
      show_hidden = false,
      show_arrows = false,
    },
  },
}
