local M = {}

-- Filetypes that should use ESLint fix-all after formatting
local eslint_filetypes = {
  'javascript',
  'javascriptreact',
  'typescript',
  'typescriptreact',
  'vue',
  'svelte',
  'astro',
}

-- ESLint config file patterns
local eslint_config_files = {
  '.eslintrc',
  '.eslintrc.js',
  '.eslintrc.cjs',
  '.eslintrc.yaml',
  '.eslintrc.yml',
  '.eslintrc.json',
  'eslint.config.js',
  'eslint.config.mjs',
  'eslint.config.cjs',
  'eslint.config.ts',
  'eslint.config.mts',
  'eslint.config.cts',
}

--- Check if ESLint is configured for the current project
--- @param bufnr number
--- @return boolean
local function has_eslint_config(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == '' then
    return false
  end

  local found = vim.fs.find(eslint_config_files, {
    upward = true,
    type = 'file',
    path = vim.fs.dirname(bufname),
  })

  return #found > 0
end

--- Check if ESLint LSP client is attached to buffer
--- @param bufnr number
--- @return vim.lsp.Client|nil
local function get_eslint_client(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'eslint' })
  return clients[1]
end

--- Apply ESLint fix-all to the buffer
--- @param bufnr number
--- @param eslint_client vim.lsp.Client
local function apply_eslint_fixes(bufnr, eslint_client)
  -- Verify buffer is still valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  eslint_client:request('workspace/executeCommand', {
    command = 'eslint.applyAllFixes',
    arguments = {
      {
        uri = vim.uri_from_bufnr(bufnr),
        version = vim.lsp.util.buf_versions[bufnr],
      },
    },
  }, function(err)
    if err then
      vim.notify('ESLint fix-all failed: ' .. tostring(err), vim.log.levels.WARN)
    end
  end, bufnr)
end

--- Format the current buffer using Conform, then apply ESLint fixes if applicable
--- @param opts? { async?: boolean, bufnr?: number }
function M.format(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local async = opts.async ~= false

  local conform = require('conform')
  local filetype = vim.bo[bufnr].filetype

  -- Check ESLint eligibility upfront (before async operations)
  local should_run_eslint = vim.tbl_contains(eslint_filetypes, filetype) and has_eslint_config(bufnr)
  local eslint_client = should_run_eslint and get_eslint_client(bufnr) or nil

  -- Determine formatters available (excluding utility formatters)
  local ignored_formatters = { 'codespell', 'trim_whitespace' }
  local formatters = conform.list_formatters(bufnr)
  local has_real_formatter = false

  for _, formatter in ipairs(formatters) do
    if not vim.tbl_contains(ignored_formatters, formatter.name) then
      has_real_formatter = true
      break
    end
  end

  -- Format with Conform
  -- 'fallback': Use LSP only if no conform formatters ran
  -- 'first': Use LSP first, then conform formatters (for filetypes without dedicated formatters)
  local lsp_format = has_real_formatter and 'fallback' or 'first'

  conform.format({
    bufnr = bufnr,
    lsp_format = lsp_format,
    async = async,
    timeout_ms = 3000,
  }, function(err)
    if err then
      vim.notify('Format error: ' .. err, vim.log.levels.ERROR)
      return
    end

    -- Apply ESLint fixes after Conform formatting completes
    -- Order: Prettier (via Conform) -> ESLint fix (code quality fixes)
    if eslint_client then
      vim.schedule(function()
        apply_eslint_fixes(bufnr, eslint_client)
      end)
    end
  end)
end

return M
