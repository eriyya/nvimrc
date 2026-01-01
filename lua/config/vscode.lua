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

    table.sort(marks, function(a, b) return a.index < b.index end)

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

  vim.keymap.set('n', '<leader>ml', show_harpoon_quickpick, {
    desc = '[Harpoon]: Show marks (VSCode Quick Pick)',
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
          o = ai.gen_spec.treesitter({ -- code block
            a = { '@block.outer', '@conditional.outer', '@loop.outer' },
            i = { '@block.inner', '@conditional.inner', '@loop.inner' },
          }),
          f = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }), -- function
          c = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }),       -- class
          t = { '<([%p%w]-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' },           -- tags
          d = { '%f[%d]%d+' },                                                          -- digits
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
  ------------------
  --- TREESITTER ---
  ------------------
  {
    'nvim-treesitter/nvim-treesitter',
    version = false,
    build = ':TSUpdate',
    cmd = { 'TSUpdateSync', 'TSUpdate', 'TSInstall' },
    init = function(plugin)
      require('lazy.core.loader').add_to_rtp(plugin)
      require('nvim-treesitter.query_predicates')
    end,
    opts = {
      highlight = {
        enable = true,
        use_languagetree = true,
      },
      indent = { enable = false },
      ensure_installed = {
        'diff',
        'norg',
        'go',
        'gomod',
        'gowork',
        'gosum',
        'bash',
        'css',
        'cpp',
        'c_sharp',
        'dockerfile',
        'html',
        'javascript',
        'json',
        'lua',
        'python',
        'rust',
        'scss',
        'lua',
        'toml',
        'tsx',
        'typescript',
        'yaml',
        'markdown',
        'markdown_inline',
        'jsdoc',
        'zig',
      },
    },
    dependencies = {
      {
        'windwp/nvim-ts-autotag',
        config = function()
          require('nvim-ts-autotag').setup({
            opts = {
              enable_close = true,
              enable_rename = true,
              enable_close_on_slash = true,
            },
          })
        end,
      },
      {
        'nvim-treesitter/nvim-treesitter-textobjects',
        init = function()
          -- disable rtp plugin, as we only need its queries for mini.ai
          -- In case other textobject modules are enabled, we will load them
          -- once nvim-treesitter is loaded
          require('lazy.core.loader').disable_rtp_plugin('nvim-treesitter-textobjects')
          load_textobjects = true
        end,
      },
      {
        'nvim-treesitter/nvim-treesitter-context',
        opts = {
          max_lines = 1,
          trim_scope = 'inner',
        },
      },
    },
    config = function(_, opts)
      if type(opts.ensure_installed) == 'table' then
        ---@type table<string, boolean>
        local added = {}
        opts.ensure_installed = vim.tbl_filter(function(lang)
          if added[lang] then
            return false
          end
          added[lang] = true
          return true
        end, opts.ensure_installed)
      end
      require('nvim-treesitter.configs').setup(opts)

      if load_textobjects then
        -- PERF: no need to load the plugin, if we only need its queries for mini.ai
        if opts.textobjects then
          for _, mod in ipairs({ 'move', 'select', 'swap', 'lsp_interop' }) do
            if opts.textobjects[mod] and opts.textobjects[mod].enable then
              local Loader = require('lazy.core.loader')
              Loader.disabled_rtp_plugins['nvim-treesitter-textobjects'] = nil
              local plugin = require('lazy.core.config').plugins['nvim-treesitter-textobjects']
              require('lazy.core.loader').source_runtime(plugin.dir, 'plugin')
              break
            end
          end
        end
      end
    end,
  },
  -------------------
  --- SNACKS.NVIM ---
  -------------------
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type Snacks.Config
    opts = {
      quickfile = { enabled = true },
      bigfile = { enabled = true },
      git = { enabled = false },
      dashboard = { enabled = false },
      explorer = { enabled = false },
      indent = { enabled = false },
      input = { enabled = false },
      picker = { enabled = false },
      notifier = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false },
      scratch = { enabled = false },
      statuscolumn = { enabled = true },
      words = { enabled = true },
      image = { enabled = false },
      profiler = { enabled = false },
      lazygit = { enabled = false },
    },
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
  }
}
