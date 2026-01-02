local util = require('util')

local M = {}

local function enable_lsp(lsp_servers)
  lsp_servers = vim.tbl_filter(function(lsp)
    return not vim.tbl_contains(vim.settings.excluded_lsp, lsp)
  end, lsp_servers)

  for _, lsp in ipairs(lsp_servers) do
    util.try(function()
      local conf = require('lsp.' .. lsp)
      local capabilities = conf.capabilities
      conf.capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)
      vim.lsp.config(lsp, conf)
    end)
  end

  vim.lsp.enable(lsp_servers)
end

M.init = function()
  if vim.g.vscode then
    return
  end

  require('mason').setup()

  enable_lsp({
    'lua_ls',
    'ts_ls',
    'eslint',
    'html',
    'cssls',
    'jsonls',
    'marksman',
    'zls',
    'rust_analyzer',
    'powershell_es',
    'gopls',
    'clangd',
    'tailwindcss',
  })

  -- Setup conform
  require('conform').setup({
    formatters_by_ft = {
      -- Global formatters (run on all filetypes)
      ['*'] = { 'codespell' },
      ['_'] = { 'trim_whitespace' },

      -- Lua
      lua = { 'stylua' },

      -- JavaScript/TypeScript family (prettierd is faster, fallback to prettier)
      javascript = { 'prettierd', 'prettier', stop_after_first = true },
      javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      typescript = { 'prettierd', 'prettier', stop_after_first = true },
      typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      vue = { 'prettierd', 'prettier', stop_after_first = true },
      svelte = { 'prettierd', 'prettier', stop_after_first = true },
      astro = { 'prettierd', 'prettier', stop_after_first = true },

      -- Web
      html = { 'prettierd', 'prettier', stop_after_first = true },
      css = { 'prettierd', 'prettier', stop_after_first = true },
      scss = { 'prettierd', 'prettier', stop_after_first = true },
      less = { 'prettierd', 'prettier', stop_after_first = true },
      json = { 'prettierd', 'prettier', stop_after_first = true },
      jsonc = { 'prettierd', 'prettier', stop_after_first = true },
      yaml = { 'prettierd', 'prettier', stop_after_first = true },

      -- Markdown
      markdown = { 'prettierd', 'prettier', stop_after_first = true },
    },
    default_format_opts = {
      lsp_format = 'fallback',
      timeout_ms = 3000,
    },
  })

  -- Setup nvim-lint
  require('lint').linters_by_ft = {
    lua = { 'selene' },
    yaml = { 'actionlint' },
  }

  -- Show lint errors on write
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost' }, {
    callback = function()
      require('lint').try_lint()
    end,
  })

  -- Setup LspSaga
  require('lspsaga').setup({
    lightbulb = {
      enabled = false,
      sign = false,
      virtual_text = false,
    },
    finder = {
      -- layout = 'normal',
      methods = {
        tdr = 'textDocument/references',
        tds = 'textDocument/definition',
        tdi = 'textDocument/implementation',
      },
      keys = {
        toggle_or_open = { '<CR>', 'o' },
      },
    },
  })

  -- Set diagnostic icons
  local virtual_icons = {
    [vim.diagnostic.severity.INFO] = '',
    [vim.diagnostic.severity.WARN] = '',
    [vim.diagnostic.severity.ERROR] = '',
    [vim.diagnostic.severity.HINT] = '',
  }

  vim.diagnostic.config({
    virtual_text = {
      prefix = '',
      spacing = 4,
      format = function(diagnostic)
        local severity = diagnostic.severity
        local icon = virtual_icons[severity]
        return icon .. '  ' .. diagnostic.message
      end,
    },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = '',
        [vim.diagnostic.severity.WARN] = '',
        [vim.diagnostic.severity.HINT] = '',
        [vim.diagnostic.severity.INFO] = '',
      },
    },
    underline = true,
    update_in_insert = false, -- Don't update diagnostics in insert mode (less noisy)
    severity_sort = true,
    float = {
      source = true,
      border = 'rounded',
      header = '',
      prefix = '',
    },
  })

  -- Enable inlay hints by default
  vim.lsp.inlay_hint.enable(true)

  -- Codelens support - refresh on certain events
  vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
    callback = function(ev)
      local clients = vim.lsp.get_clients({ bufnr = ev.buf })
      for _, client in ipairs(clients) do
        if client:supports_method('textDocument/codeLens') then
          vim.lsp.codelens.refresh({ bufnr = ev.buf })
          break
        end
      end
    end,
  })
end

return M
