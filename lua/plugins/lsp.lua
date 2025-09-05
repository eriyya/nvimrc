local util = require('util')
local tsls = { 'typescript-language-server', 'eslint-lsp', 'prettierd', 'js-debug-adapter' }
local cssls = 'css-lsp'

local ft_to_lsp = {
  lua = { 'lua-language-server', 'selene' },
  typescript = tsls,
  typescriptreact = tsls,
  javascript = tsls,
  javascriptreact = tsls,
  html = 'html-lsp',
  css = cssls,
  scss = cssls,
  less = cssls,
  json = 'json-lsp',
  jsonc = 'json-lsp',
  yaml = 'yaml-language-server',
  markdown = 'marksman',
  zig = 'zls',
  rust = 'rust-analyzer',
  go = 'gopls',
  c = 'clangd',
  cpp = 'clangd',
  ps1 = 'powershell-editor-services',
}

local ft_list = vim.tbl_keys(ft_to_lsp)

vim.api.nvim_create_autocmd({ 'BufReadPre', 'FileType' }, {
  pattern = ft_list,
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if not ft_to_lsp[ft] then
      return
    end
    local lsp = ft_to_lsp[ft]
    local registry = require('mason-registry')

    local servers = util.ternary(type(lsp) == 'table', lsp, { lsp })
    servers = vim.tbl_filter(function(v)
      return not registry.is_installed(v)
    end, servers)

    if not registry.is_installed('codespell') then
      table.insert(servers, 'codespell')
    end

    if #servers > 0 then
      vim.cmd('MasonInstall ' .. table.concat(servers, ' '))
    end
  end,
})

--- Call LSP server setup code
vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
  once = true,
  callback = function()
    require('lsp').init()
  end,
})

return {
  -----------
  -- Mason --
  -----------
  { 'williamboman/mason.nvim', event = { 'VeryLazy' } },
  -------------
  -- LspSaga --
  -------------
  { 'nvimdev/lspsaga.nvim', event = 'LspAttach' },
  ---------------
  -- blink.cmp --
  ---------------
  {
    'saghen/blink.cmp',
    event = { 'BufReadPre', 'BufNewFile' },
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
  { 'mfussenegger/nvim-lint', event = { 'BufReadPre', 'BufNewFile' } },
  -------------
  -- Conform --
  -------------
  {
    'stevearc/conform.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },
  -------------
  -- Trouble --
  -------------
  {
    'folke/trouble.nvim',
    event = { 'LspAttach' },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },
  ------------
  -- Fidget --
  ------------
  {
    'j-hui/fidget.nvim',
    event = { 'LspNotify', 'LspProgress', 'LspAttach' },
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
}
