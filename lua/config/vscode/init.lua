if vim.g.vscode then
  local vscode = require('vscode')
  vim.notify = vscode.notify

  local actions = require('config.vscode.actions')
  actions.keybinds()

  -- Force VS Code to re-sync decorations when buffer changes externally
  -- This helps prevent ghost text artifacts from external file edits (e.g., opencode)
  vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'BufWritePost' }, {
    callback = function()
      vim.defer_fn(function()
        vscode.action('editor.action.forceRetokenize')
      end, 50)
    end,
  })
end

return {
  -----------------
  --- MINI.NVIM ---
  -----------------
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Trailspace
      require('mini.trailspace').setup()

      -- Comments
      require('mini.comment').setup({
        mappings = {
          comment = 'gc',
          comment_line = 'gcc',
          comment_visual = 'gc',
          textobject = 'gc',
        },
      })

      local ai = require('mini.ai')
      ai.setup({
        n_lines = 500,
        -- Custom textobjects (from LazyVim)
        custom_textobjects = {
          t = { '<([%p%w]-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' }, -- tags
          d = { '%f[%d]%d+' }, -- digits
        },
      })

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup({
        -- Reverse the whitespace behaviour for brackets
        custom_surroundings = {
          ['('] = {
            output = function()
              return { left = '(', right = ')' } -- no space
            end,
          },
          [')'] = {
            output = function()
              return { left = '( ', right = ' )' } -- with space
            end,
          },
          ['{'] = {
            output = function()
              return { left = '{', right = '}' } -- no space
            end,
          },
          ['}'] = {
            output = function()
              return { left = '{ ', right = ' }' } -- with space
            end,
          },
          ['['] = {
            output = function()
              return { left = '[', right = ']' } -- no space
            end,
          },
          [']'] = {
            output = function()
              return { left = '[ ', right = ' ]' } -- with space
            end,
          },
        },
      })
    end,
  },
  ---------------
  --- HARPOON ---
  ---------------
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      {
        '<leader>ma',
        function()
          vim.notify('Added current file to Harpoon marks: ' .. vim.fn.expand('%:t'))
          require('harpoon'):list():add()
        end,
        desc = '[Harpoon]: Add current file',
      },
      {
        '<leader>j',
        function()
          require('harpoon'):list():select(1)
        end,
        desc = '[Harpoon]: Goto mark 1',
      },
      {
        '<leader>k',
        function()
          require('harpoon'):list():select(2)
        end,
        desc = '[Harpoon]: Goto mark 2',
      },
      {
        '<leader>l',
        function()
          require('harpoon'):list():select(3)
        end,
        desc = '[Harpoon]: Goto mark 3',
      },
      {
        '<leader>h',
        function()
          require('harpoon'):list():select(4)
        end,
        desc = '[Harpoon]: Goto mark 4',
      },
    },
    opts = {
      save_on_toggle = true,
    },
    config = function()
      require('harpoon'):setup({})
    end,
  },
}
