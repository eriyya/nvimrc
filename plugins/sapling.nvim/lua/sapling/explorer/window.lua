local state_module = require("sapling.explorer.state")

local M = {}

function M.handle_explorer_write(ctx)
  local state = state_module.state

  if state.edit.saving then
    state_module.notify("sapling is already applying changes", vim.log.levels.WARN)
    return
  end

  if not state.edit.active then
    if state_module.is_valid_buf(state.bufnr) then
      vim.bo[state.bufnr].modified = false
    end
    return
  end

  ctx.actions.apply_edit_buffer(ctx)
end

function M.configure_window(winid)
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].cursorline = true
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].foldcolumn = "0"
  vim.wo[winid].statusline = ""
  vim.wo[winid].statuscolumn = ""
  vim.wo[winid].wrap = false
  vim.wo[winid].winfixwidth = true
end

function M.ensure_buffer(ctx)
  local state = state_module.state

  if state_module.is_valid_buf(state.bufnr) then
    return state.bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  state.bufnr = bufnr

  vim.api.nvim_buf_set_name(bufnr, "sapling://explorer")
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "sapling"
  state_module.tag_buffer(bufnr, "explorer")

  vim.api.nvim_buf_create_user_command(bufnr, "SaplingRefreshBuffer", function()
    ctx.actions.refresh(ctx)
  end, { desc = "Refresh the sapling tree" })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      M.handle_explorer_write(ctx)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      if state.edit.active then
        ctx.render.render_edit_buffer_decorations(ctx, bufnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    callback = function()
      if state.bufnr == bufnr then
        state.bufnr = nil
      end

      if state.winid and not state_module.is_valid_win(state.winid) then
        state.winid = nil
      end

      state_module.clear_edit_diagnostics()
      state_module.reset_edit_state()
    end,
  })

  return bufnr
end

function M.ensure_window(ctx)
  local state = state_module.state

  if state_module.is_valid_win(state.winid) and vim.api.nvim_win_get_buf(state.winid) == state.bufnr then
    return state.winid
  end

  local bufnr = M.ensure_buffer(ctx)
  local previous_win = vim.api.nvim_get_current_win()

  if not state_module.is_explorer_buffer(vim.api.nvim_win_get_buf(previous_win)) then
    state.last_file_window = previous_win
  end

  if state.config.window.side == "right" then
    vim.cmd("botright vertical split")
  else
    vim.cmd("topleft vertical split")
  end

  local winid = vim.api.nvim_get_current_win()
  state.winid = winid

  vim.api.nvim_win_set_buf(winid, bufnr)
  vim.api.nvim_win_set_width(winid, state.config.window.width)
  M.configure_window(winid)
  ctx.keymaps.apply_buffer_keymaps(bufnr, ctx)

  if not state_module.is_explorer_buffer(vim.api.nvim_win_get_buf(previous_win)) then
    state.last_file_window = previous_win
  end

  return winid
end

function M.close_window(ctx)
  local state = state_module.state

  ctx.filter.reset()
  ctx.prompt.close_prompt(ctx)
  ctx.help.close_help()
  state_module.stop_refresh_timer()

  if state_module.is_valid_win(state.winid) then
    local winid = state.winid
    state.winid = nil
    vim.api.nvim_win_close(winid, true)
  end
end

function M.find_non_explorer_window()
  local state = state_module.state

  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if state_module.is_valid_win(winid) and winid ~= state.winid then
      local bufnr = vim.api.nvim_win_get_buf(winid)
      if not state_module.is_explorer_buffer(bufnr)
        and not state_module.is_sapling_aux_buffer(bufnr)
        and not state_module.is_floating_win(winid)
      then
        return winid
      end
    end
  end

  return nil
end

function M.open_file_window_from_explorer()
  local state = state_module.state
  local explorer_win = state.winid

  if state.config.window.side == "right" then
    vim.cmd("leftabove vsplit")
  else
    vim.cmd("rightbelow vsplit")
  end

  local file_win = vim.api.nvim_get_current_win()

  if state_module.is_valid_win(explorer_win) then
    vim.api.nvim_win_set_width(explorer_win, state.config.window.width)
    M.configure_window(explorer_win)
  end

  state.last_file_window = file_win
  return file_win
end

function M.get_target_window()
  local state = state_module.state

  if state_module.is_valid_win(state.last_file_window) and vim.api.nvim_win_get_buf(state.last_file_window) ~= state.bufnr then
    return state.last_file_window
  end

  local current_win = vim.api.nvim_get_current_win()

  if not state_module.is_explorer_buffer(vim.api.nvim_win_get_buf(current_win)) then
    state.last_file_window = current_win
    return current_win
  end

  local winid = M.find_non_explorer_window()
  if winid then
    state.last_file_window = winid
    return winid
  end

  return M.open_file_window_from_explorer()
end

return M
