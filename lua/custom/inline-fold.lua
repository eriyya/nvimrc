local M = {}

M.config = {
  filetypes = {
    'html',
    'xhtml',
    'javascriptreact',
    'typescriptreact',
    'vue',
    'svelte',
    'astro',
    'php',
  },
  min_fold_length = 0,
}

local state = {
  ns_id = nil,
  augroup = nil,
  enabled_buffers = {},
}

local function ensure_namespace()
  if not state.ns_id then
    state.ns_id = vim.api.nvim_create_namespace('inline_fold')
  end
  return state.ns_id
end

--- Create highlight group for hiding text
local function setup_highlights()
  vim.api.nvim_set_hl(0, 'InlineFoldHidden', { link = 'Ignore' })
  vim.api.nvim_set_hl(0, 'InlineFoldPlaceholder', { link = 'Comment' })
end

--- Check if a filetype is supported
---@param ft string
---@return boolean
local function is_supported_filetype(ft)
  for _, supported in ipairs(M.config.filetypes) do
    if ft == supported then
      return true
    end
  end
  return false
end

--- Get Treesitter matches for class attributes in buffer
---@param bufnr number
---@param start_row number|nil 0-indexed start row (nil for entire buffer)
---@param end_row number|nil 0-indexed end row (nil for entire buffer)
---@return table[] matches Array of {line, start_col, end_col, value}
local function get_treesitter_matches(bufnr, start_row, end_row)
  local matches = {}

  -- Get the parser for this buffer
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return matches
  end

  -- Parse the tree
  local trees = parser:parse()
  if not trees or #trees == 0 then
    return matches
  end

  local lang = parser:lang()

  -- Build language-specific queries
  local queries = {}

  -- TSX/JSX query
  if lang == 'tsx' or lang == 'javascript' or lang == 'typescript' then
    table.insert(
      queries,
      [[
      (jsx_attribute
        (property_identifier) @attr_name
        (string
          (string_fragment) @attr_value))
    ]]
    )
  end

  -- HTML query
  if lang == 'html' then
    table.insert(
      queries,
      [[
      (attribute
        (attribute_name) @attr_name
        (quoted_attribute_value
          (attribute_value) @attr_value))
    ]]
    )
  end

  -- Vue uses HTML for template
  if lang == 'vue' then
    table.insert(
      queries,
      [[
      (attribute
        (attribute_name) @attr_name
        (quoted_attribute_value
          (attribute_value) @attr_value))
    ]]
    )
  end

  local root = trees[1]:root()

  for _, query_string in ipairs(queries) do
    local query_ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
    if query_ok and query then
      for _, match, _ in query:iter_matches(root, bufnr, start_row or 0, end_row or -1) do
        local attr_name_node = nil
        local attr_value_node = nil

        for id, nodes in pairs(match) do
          local node = type(nodes) == 'table' and nodes[1] or nodes
          local capture_name = query.captures[id]
          if capture_name == 'attr_name' then
            attr_name_node = node
          elseif capture_name == 'attr_value' then
            attr_value_node = node
          end
        end

        if attr_name_node and attr_value_node then
          local attr_name = vim.treesitter.get_node_text(attr_name_node, bufnr)
          if attr_name == 'class' or attr_name == 'className' then
            local value = vim.treesitter.get_node_text(attr_value_node, bufnr)
            local sr, sc, _, ec = attr_value_node:range()

            if #value >= M.config.min_fold_length then
              table.insert(matches, {
                line = sr,
                start_col = sc,
                end_col = ec,
                value = value,
              })
            end
          end
        end
      end
    end
  end

  return matches
end

--- Create folds for entire buffer
---@param bufnr number
local function create_buffer_folds(bufnr)
  local ns_id = ensure_namespace()

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local matches = get_treesitter_matches(bufnr)
  for _, match in ipairs(matches) do
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, match.line, match.start_col, {
      end_col = match.end_col,
      conceal = '…',
      hl_group = 'Comment',
    })
  end
end

--- Clear all folds for a buffer
---@param bufnr number
local function clear_buffer_folds(bufnr)
  local ns_id = ensure_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

local function setup_autocommands()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup('InlineFold', { clear = true })

  vim.api.nvim_create_autocmd('BufWritePost', {
    group = state.augroup,
    callback = function(args)
      if state.enabled_buffers[args.buf] then
        create_buffer_folds(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = state.augroup,
    callback = function(args)
      if state.enabled_buffers[args.buf] then
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(args.buf) and state.enabled_buffers[args.buf] then
            create_buffer_folds(args.buf)
          end
        end, 100)
      end
    end,
  })

  -- Cleanup when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = state.augroup,
    callback = function(args)
      state.enabled_buffers[args.buf] = nil
    end,
  })
end

--- Enable inline fold for a specific buffer
---@param bufnr number|nil Buffer number, defaults to current
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ft = vim.bo[bufnr].filetype
  if not is_supported_filetype(ft) then
    return
  end

  local ok = pcall(vim.treesitter.get_parser, bufnr)
  if not ok then
    vim.notify('Treesitter parser not available for this buffer', vim.log.levels.WARN)
    return
  end

  setup_highlights()
  setup_autocommands()

  -- Set conceallevel for this buffer's windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      vim.wo[win].conceallevel = 2
      vim.wo[win].concealcursor = '' -- reveal on all cursor modes
    end
  end

  state.enabled_buffers[bufnr] = true
  create_buffer_folds(bufnr)
end

--- Disable inline fold for a specific buffer
---@param bufnr number|nil Buffer number, defaults to current
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  state.enabled_buffers[bufnr] = nil
  clear_buffer_folds(bufnr)
end

--- Toggle inline fold for a specific buffer
---@param bufnr number|nil Buffer number, defaults to current
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if state.enabled_buffers[bufnr] then
    M.disable(bufnr)
  else
    M.enable(bufnr)
  end
end

--- Refresh folds in current buffer
---@param bufnr number|nil Buffer number, defaults to current
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if state.enabled_buffers[bufnr] then
    create_buffer_folds(bufnr)
  end
end

--- Check if inline fold is enabled for a buffer
---@param bufnr number|nil Buffer number, defaults to current
---@return boolean
function M.is_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return state.enabled_buffers[bufnr] == true
end

--- Setup with custom configuration
---@param opts table|nil
function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end

  setup_autocommands()

  vim.api.nvim_create_user_command('InlineFoldEnable', function()
    M.enable()
  end, { desc = 'Enable inline class folding for current buffer' })

  vim.api.nvim_create_user_command('InlineFoldDisable', function()
    M.disable()
  end, { desc = 'Disable inline class folding for current buffer' })

  vim.api.nvim_create_user_command('InlineFoldToggle', function()
    M.toggle()
  end, { desc = 'Toggle inline class folding for current buffer' })

  vim.api.nvim_create_user_command('InlineFoldRefresh', function()
    M.refresh()
  end, { desc = 'Refresh inline class folds in current buffer' })
end

return M
