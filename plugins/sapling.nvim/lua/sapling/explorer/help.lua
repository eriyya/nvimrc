local state_module = require("sapling.explorer.state")

local M = {}

function M.close_help()
  local state = state_module.state

  if state_module.is_valid_win(state.help_winid) then
    local help_winid = state.help_winid
    state.help_winid = nil
    vim.api.nvim_win_close(help_winid, true)
  end

  if state.help_bufnr and not state_module.is_valid_buf(state.help_bufnr) then
    state.help_bufnr = nil
  end
end

function M.ensure_help_buffer()
  local state = state_module.state

  if state_module.is_valid_buf(state.help_bufnr) then
    return state.help_bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  state.help_bufnr = bufnr

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "sapling-help"
  state_module.tag_buffer(bufnr, "help")

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    callback = function()
      if state.help_bufnr == bufnr then
        state.help_bufnr = nil
      end
    end,
  })

  return bufnr
end

function M.build_help_lines()
  local state = state_module.state
  local items = {}
  local clipboard_summary = state_module.get_clipboard_summary()

  for action, label in pairs(state_module.action_labels) do
    local mappings = state_module.get_action_mappings(action)

    if #mappings > 0 then
      items[#items + 1] = {
        label = label,
        text = ("%s  %s"):format(table.concat(mappings, ", "), label),
      }
    end
  end

  table.sort(items, function(left, right)
    return left.label < right.label
  end)

  local lines = {
    "sapling",
    "",
  }

  if clipboard_summary then
    lines[#lines + 1] = clipboard_summary
    lines[#lines + 1] = ""
  end

  if state_module.supports_edit_buffer() then
    lines[#lines + 1] = ("file_edit_mode: %s"):format(state.config.file_edit_mode)
    lines[#lines + 1] = ""
  end

  for _, item in ipairs(items) do
    lines[#lines + 1] = item.text
  end

  return lines
end

function M.render_help()
  local bufnr = M.ensure_help_buffer()
  local lines = M.build_help_lines()

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  vim.api.nvim_buf_clear_namespace(bufnr, state_module.namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, 0, 0, {
    end_col = #lines[1],
    hl_group = "SaplingHelpTitle",
  })
end

function M.open_help()
  local state = state_module.state

  M.render_help()

  if state_module.is_valid_win(state.help_winid) then
    vim.api.nvim_set_current_win(state.help_winid)
    return
  end

  local width = math.max(28, math.floor(vim.o.columns * 0.4))
  local height = math.max(10, math.floor(vim.o.lines * 0.5))
  local row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  state.help_winid = vim.api.nvim_open_win(state.help_bufnr, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  vim.wo[state.help_winid].number = false
  vim.wo[state.help_winid].relativenumber = false
  vim.wo[state.help_winid].signcolumn = "no"
  vim.wo[state.help_winid].foldcolumn = "0"
  vim.wo[state.help_winid].statusline = ""
  vim.wo[state.help_winid].wrap = false

  vim.keymap.set("n", "q", M.close_help, {
    buffer = state.help_bufnr,
    noremap = true,
    silent = true,
  })

  local help_close = state_module.get_action_mappings("show_help")[1] or "?"
  vim.keymap.set("n", help_close, M.close_help, {
    buffer = state.help_bufnr,
    noremap = true,
    silent = true,
  })
end

return M
