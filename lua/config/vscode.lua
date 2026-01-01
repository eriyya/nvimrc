if vim.g.vscode then
  local vscode = require('vscode')
  vim.notify = vscode.notify
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
        '<leader>ml',
        function()
          -- TODO: Implement vscode harpoon menu
          require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())
        end,
        desc = '[Harpoon]: Show mark menu',
      },
      {
        '<leader>ma',
        function()
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
