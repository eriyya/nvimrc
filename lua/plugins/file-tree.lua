return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    init = function()
      vim.api.nvim_create_autocmd('VimEnter', {
        callback = function()
          if vim.fn.isdirectory(vim.fn.expand('%')) == 1 then
            vim.cmd('Neotree show')
          end
        end,
      })
    end,
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
