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
--- @return boolean
local function has_eslint_config()
  local found = vim.fs.find(eslint_config_files, {
    upward = true,
    type = 'file',
    path = vim.fn.expand('%:p:h'),
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

--- Format the current buffer using Conform, then apply ESLint fixes if applicable
--- @param opts? { async?: boolean, bufnr?: number }
function M.format(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local async = opts.async or false

  local conform = require('conform')
  local filetype = vim.bo[bufnr].filetype

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
  -- Use LSP as fallback only if no dedicated formatter exists
  local lsp_format = has_real_formatter and 'fallback' or 'last'

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

    -- After formatting, apply ESLint fixes for JS/TS files if:
    -- 1. The filetype is an ESLint-supported filetype
    -- 2. The project has an ESLint config
    -- 3. ESLint LSP is attached
    if vim.tbl_contains(eslint_filetypes, filetype) then
      if has_eslint_config() then
        local eslint_client = get_eslint_client(bufnr)
        if eslint_client then
          -- Use vim.schedule to ensure buffer is in correct state
          vim.schedule(function()
            local ok, err_msg = pcall(vim.cmd, 'silent LspEslintFixAll')
            if not ok then
              vim.notify('ESLint fix-all failed: ' .. tostring(err_msg), vim.log.levels.WARN)
            end
          end)
        end
      end
    end
  end)
end

return M
