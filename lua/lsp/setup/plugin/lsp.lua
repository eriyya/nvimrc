require('mason').setup()

local function enable_lsp(lsp_servers)
  for _, lsp in ipairs(lsp_servers) do
    local conf_path = 'lsp.' .. lsp
    if pcall(require, conf_path) then
      vim.lsp.config(lsp, require(conf_path))
    end
  end
  vim.lsp.enable(lsp_servers)
end

enable_lsp({
  'lua_ls',
  'ts_ls',
  'eslint',
  'html',
  'cssls',
  'jsonls',
  'marksman',
})

-- Setup conform
require('conform').setup({
  formatters_by_ft = {
    lua = { 'stylua' },
  },
  default_format_opts = {
    lsp_format = 'fallback',
    timeout_ms = 3000,
  },
})

-- Setup nvim-lint
require('lint').linters_by_ft = {
  lua = { 'selene' },
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
    format = function(diagnostic)
      local severity = diagnostic.severity
      local icon = virtual_icons[severity]
      return icon .. '  ' .. diagnostic.message
    end,
  },
  severity_sort = true,
  float = {
    source = true,
  },
})
