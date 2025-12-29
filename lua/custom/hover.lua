local M = {}

-- Severity icons (matching lsp/init.lua)
local severity_icons = {
  [vim.diagnostic.severity.ERROR] = '',
  [vim.diagnostic.severity.WARN] = '',
  [vim.diagnostic.severity.INFO] = '',
  [vim.diagnostic.severity.HINT] = '',
}

local severity_labels = {
  [vim.diagnostic.severity.ERROR] = 'Error',
  [vim.diagnostic.severity.WARN] = 'Warning',
  [vim.diagnostic.severity.INFO] = 'Info',
  [vim.diagnostic.severity.HINT] = 'Hint',
}

local severity_hl = {
  [vim.diagnostic.severity.ERROR] = 'DiagnosticError',
  [vim.diagnostic.severity.WARN] = 'DiagnosticWarn',
  [vim.diagnostic.severity.INFO] = 'DiagnosticInfo',
  [vim.diagnostic.severity.HINT] = 'DiagnosticHint',
}

--- Format diagnostics into lines with highlight info
---@param diagnostics table[]
---@return string[] lines
---@return table[] highlights Array of {line, hl_group}
local function format_diagnostics(diagnostics)
  if #diagnostics == 0 then
    return {}, {}
  end

  local lines = {}
  local highlights = {}

  -- Add header
  table.insert(lines, 'Diagnostics:')
  table.insert(highlights, { line = 0, hl_group = 'Bold' })
  table.insert(lines, '')

  for _, diag in ipairs(diagnostics) do
    local icon = severity_icons[diag.severity] or ''
    local label = severity_labels[diag.severity] or 'Unknown'
    local hl_group = severity_hl[diag.severity] or 'Normal'
    local source = diag.source and (' [' .. diag.source .. ']') or ''

    -- Add severity line: "icon Label [source]"
    local severity_line = string.format('%s %s%s', icon, label, source)
    local line_idx = #lines
    table.insert(lines, severity_line)

    -- Highlight the entire severity line
    table.insert(highlights, {
      line = line_idx,
      hl_group = hl_group,
    })

    -- Add message (handle multi-line messages)
    for msg_line in diag.message:gmatch('[^\r\n]+') do
      local msg_line_idx = #lines
      local formatted_msg = '  ' .. msg_line
      table.insert(lines, formatted_msg)

      -- Highlight message with same color
      table.insert(highlights, {
        line = msg_line_idx,
        hl_group = hl_group,
      })
    end

    table.insert(lines, '')
  end

  return lines, highlights
end

--- Extract content from LSP hover result
---@param result table|nil
---@return string[]
local function extract_hover_content(result)
  if not result or not result.contents then
    return {}
  end

  local contents = result.contents

  -- Handle MarkupContent
  if type(contents) == 'table' and contents.kind then
    if contents.kind == 'markdown' then
      local lines = {}
      for line in contents.value:gmatch('[^\r\n]+') do
        table.insert(lines, line)
      end
      return lines
    elseif contents.kind == 'plaintext' then
      local lines = {}
      for line in contents.value:gmatch('[^\r\n]+') do
        table.insert(lines, line)
      end
      return lines
    end
  end

  -- Handle string content
  if type(contents) == 'string' then
    local lines = {}
    for line in contents:gmatch('[^\r\n]+') do
      table.insert(lines, line)
    end
    return lines
  end

  -- Handle MarkedString array
  if type(contents) == 'table' and #contents > 0 then
    local lines = {}
    for _, item in ipairs(contents) do
      if type(item) == 'string' then
        for line in item:gmatch('[^\r\n]+') do
          table.insert(lines, line)
        end
      elseif type(item) == 'table' and item.value then
        if item.language then
          table.insert(lines, '```' .. item.language)
        end
        for line in item.value:gmatch('[^\r\n]+') do
          table.insert(lines, line)
        end
        if item.language then
          table.insert(lines, '```')
        end
      end
    end
    return lines
  end

  return {}
end

--- Apply highlights to buffer using extmarks
---@param bufnr number
---@param highlights table[]
local function apply_highlights(bufnr, highlights)
  local ns = vim.api.nvim_create_namespace('hover_diagnostics')

  for _, hl in ipairs(highlights) do
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, hl.line, 0, {
      end_row = hl.line,
      end_col = 0,
      hl_eol = true,
      line_hl_group = hl.hl_group,
      priority = 200, -- Higher priority to override markdown highlighting
    })
  end
end

--- Show hover with diagnostics
function M.hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1 -- 0-indexed

  -- Get diagnostics for current line
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })

  -- Sort by severity (errors first)
  table.sort(diagnostics, function(a, b)
    return a.severity < b.severity
  end)

  local diag_lines, diag_highlights = format_diagnostics(diagnostics)

  -- Get LSP clients that support hover
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/hover' })

  if #clients == 0 then
    -- No LSP hover support, just show diagnostics if any
    if #diag_lines > 0 then
      local float_bufnr = vim.lsp.util.open_floating_preview(diag_lines, '', {
        focus_id = 'hover_with_diag',
        border = 'rounded',
      })
      apply_highlights(float_bufnr, diag_highlights)
    end
    return
  end

  -- Make LSP hover request
  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)

  vim.lsp.buf_request(bufnr, 'textDocument/hover', params, function(err, result, ctx, config)
    -- Run in main loop to avoid issues
    vim.schedule(function()
      local hover_lines = extract_hover_content(result)
      local combined = {}
      local combined_highlights = {}

      -- Add hover content first
      if #hover_lines > 0 then
        for _, line_content in ipairs(hover_lines) do
          table.insert(combined, line_content)
        end
      end

      -- Add separator if we have both
      if #hover_lines > 0 and #diag_lines > 0 then
        table.insert(combined, '')
        table.insert(combined, '---')
      end

      -- Add diagnostics at the bottom
      if #diag_lines > 0 then
        local offset = #combined
        for _, line_content in ipairs(diag_lines) do
          table.insert(combined, line_content)
        end
        -- Offset highlight line numbers since diagnostics are after hover content
        for _, hl in ipairs(diag_highlights) do
          table.insert(combined_highlights, {
            line = hl.line + offset,
            hl_group = hl.hl_group,
          })
        end
      end

      -- Show floating window if we have content
      if #combined > 0 then
        -- Use markdown filetype for syntax highlighting
        local float_bufnr = vim.lsp.util.open_floating_preview(combined, 'markdown', {
          focus_id = 'hover_with_diag',
          border = 'rounded',
        })

        -- Apply diagnostic highlights after buffer is set up
        -- Use vim.defer_fn to ensure markdown processing is complete
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(float_bufnr) then
            apply_highlights(float_bufnr, combined_highlights)
          end
        end, 0)
      end
    end)
  end)
end

return M
