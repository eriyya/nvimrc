if vim.g.vscode then
  local vscode = require('vscode')
  vim.notify = vscode.notify

  ---Show Harpoon marks in a vscode quick pick
  local function show_harpoon_quickpick()
    local ok, harpoon = pcall(require, 'harpoon')
    if not ok then
      vscode.notify('Harpoon not loaded', vim.log.levels.WARN)
      return
    end

    local list = harpoon:list()
    local marks = {}

    for i, item in pairs(list.items) do
      if type(i) == 'number' and item and item.value then
        table.insert(marks, {
          index = i,
          path = item.value,
          filename = vim.fn.fnamemodify(item.value, ':t'),
          relative = vim.fn.fnamemodify(item.value, ':~:.'),
        })
      end
    end

    table.sort(marks, function(a, b)
      return a.index < b.index
    end)

    if #marks == 0 then
      vscode.notify('No Harpoon marks set', vim.log.levels.INFO)
      return
    end

    local js_code = [[
      return new Promise((resolve) => {
        const quickPick = vscode.window.createQuickPick();
        quickPick.placeholder = 'Select a Harpoon mark (↑↓ to reorder, X to remove)';
        quickPick.matchOnDescription = true;

        const moveUpButton = {
          iconPath: new vscode.ThemeIcon('arrow-up'),
          tooltip: 'Move up'
        };
        const moveDownButton = {
          iconPath: new vscode.ThemeIcon('arrow-down'),
          tooltip: 'Move down'
        };
        const removeButton = {
          iconPath: new vscode.ThemeIcon('close'),
          tooltip: 'Remove from Harpoon'
        };

        const createItems = (marks) => marks.map((mark, idx) => {
          const buttons = [];
          if (idx > 0) buttons.push(moveUpButton);
          if (idx < marks.length - 1) buttons.push(moveDownButton);
          buttons.push(removeButton);
          return {
            label: `${mark.index}: ${mark.filename}`,
            description: mark.relative,
            index: mark.index,
            path: mark.path,
            arrayIndex: idx,
            buttons: buttons
          };
        });

        let currentMarks = [...args.marks];
        quickPick.items = createItems(currentMarks);

        let resolved = false;

        quickPick.onDidTriggerItemButton((e) => {
          if (resolved) return;
          const tooltip = e.button.tooltip;
          const itemIndex = e.item.index;
          const arrayIdx = e.item.arrayIndex;

          if (tooltip === 'Remove from Harpoon') {
            resolved = true;
            quickPick.hide();
            resolve({ action: 'remove', index: itemIndex });
          } else if (tooltip === 'Move up' && arrayIdx > 0) {
            resolved = true;
            quickPick.hide();
            const swapWithIndex = currentMarks[arrayIdx - 1].index;
            resolve({ action: 'swap', index1: itemIndex, index2: swapWithIndex });
          } else if (tooltip === 'Move down' && arrayIdx < currentMarks.length - 1) {
            resolved = true;
            quickPick.hide();
            const swapWithIndex = currentMarks[arrayIdx + 1].index;
            resolve({ action: 'swap', index1: itemIndex, index2: swapWithIndex });
          }
        });

        quickPick.onDidAccept(() => {
          if (resolved) return;
          resolved = true;
          const selected = quickPick.selectedItems[0];
          quickPick.hide();
          if (selected) {
            resolve({ action: 'select', index: selected.index });
          } else {
            resolve({ action: 'none' });
          }
        });

        quickPick.onDidHide(() => {
          quickPick.dispose();
          if (!resolved) {
            resolved = true;
            resolve({ action: 'none' });
          }
        });

        quickPick.show();
      });
    ]]

    local function handle_result(err, result)
      if err then
        vscode.notify('Error showing Harpoon menu: ' .. err, vim.log.levels.ERROR)
        return
      end

      if type(result) ~= 'table' or not result.action then
        return
      end

      if result.action == 'select' then
        harpoon:list():select(result.index)
      elseif result.action == 'remove' then
        harpoon:list():remove_at(result.index)
        vscode.notify('Removed mark ' .. result.index, vim.log.levels.INFO)
        vim.defer_fn(show_harpoon_quickpick, 100)
      elseif result.action == 'swap' then
        local items = list.items
        local temp = items[result.index1]
        items[result.index1] = items[result.index2]
        items[result.index2] = temp
        vim.defer_fn(show_harpoon_quickpick, 100)
      end
    end

    vscode.eval_async(js_code, {
      args = { marks = marks },
      callback = handle_result,
    })
  end

  --- VSCode keymaps

  vim.keymap.set('n', '<leader>ml', show_harpoon_quickpick, {
    desc = '[Harpoon]: Show marks (VSCode Quick Pick)',
  })

  vim.keymap.set('n', '<leader>f', function()
    vscode.action('editor.action.formatDocument')
  end, { desc = '[LSP] Format document (VSCode)' })
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
