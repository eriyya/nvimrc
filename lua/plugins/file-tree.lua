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
    opts = function(_, opts)
      local function on_move(data)
        Snacks.rename.on_rename_file(data.source, data.destination)
      end
      local events = require('neo-tree.events')
      opts.event_handlers = opts.event_handlers or {}
      vim.list_extend(opts.event_handlers, {
        { event = events.FILE_MOVED, handler = on_move },
        { event = events.FILE_RENAMED, handler = on_move },
      })

      return {
        event_handlers = opts.event_handlers,
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
      }
    end,
  },
}
