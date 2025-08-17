vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    lazy = false, -- neo-tree will lazily load itself
    opts = {
      filesystem = {
        follow_current_file = {
          enabled = true,
        },
        window = {
          mappings = {
            ['o'] = 'open',
          },
        },
      },
      buffers = {
        follow_current_file = {
          enabled = true,
        },
      },
    },
  },
}
