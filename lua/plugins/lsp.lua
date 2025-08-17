local dirpath = vim.fn.stdpath('config')

return {
  name = 'LspSetup',
  event = { 'BufReadPre', 'BufNewFile' },
  dir = vim.fn.resolve(dirpath .. '/lua/lsp/setup'),
  dependencies = {
    -----------
    -- Mason --
    -----------
    { 'williamboman/mason.nvim' },
    -------------
    -- LspSaga --
    -------------
    { 'nvimdev/lspsaga.nvim' },
    ---------------
    -- blink.cmp --
    ---------------
    {
      'saghen/blink.cmp',
      dependencies = {
        {
          'folke/lazydev.nvim',
          ft = 'lua',
          opts = {
            library = {
              { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
            },
          },
        },
      },
      version = '1.*',
      ---@module 'blink.cmp'
      ---@type blink.cmp.Config
      opts = {
        keymap = {
          preset = 'super-tab',
          ['<C-j>'] = {
            function(cmp)
              cmp.show({})
            end,
          },
        },
        completion = { documentation = { auto_show = false } },
        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = 'normal',
        },
        sources = {
          default = { 'lazydev', 'lsp', 'path', 'snippets', 'buffer' },
          providers = {
            lazydev = {
              name = 'LazyDev',
              module = 'lazydev.integrations.blink',
              score_offset = 100,
            },
          },
        },

        fuzzy = { implementation = 'prefer_rust_with_warning' },
      },
      opts_extend = { 'sources.default' },
    },
    ---------------
    -- nvim-lint --
    ---------------
    { 'mfussenegger/nvim-lint' },
    -------------
    -- Conform --
    -------------
    {
      'stevearc/conform.nvim',
      opts = {},
    },
    -------------
    -- Trouble --
    -------------
    {
      'folke/trouble.nvim',
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      opts = {},
    },
    ------------
    -- Fidget --
    ------------
    {
      'j-hui/fidget.nvim',
      opts = {
        progress = {
          display = {
            render_limit = 3,
          },
        },
        notification = {
          window = {
            winblend = 0,
          },
        },
      },
    },
  },
}
