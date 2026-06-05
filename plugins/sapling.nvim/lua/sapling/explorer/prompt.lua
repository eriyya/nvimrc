local NuiPopup = require("nui.popup")
local popup_event = require("nui.utils.autocmd").event
local state_module = require("sapling.explorer.state")

local M = {}

local function ensure_confirm_highlights()
  vim.api.nvim_set_hl(0, "SaplingEditCreate", { default = true, link = "Added" })
  vim.api.nvim_set_hl(0, "SaplingEditDelete", { default = true, link = "Removed" })
  vim.api.nvim_set_hl(0, "SaplingEditMove", { default = true, link = "Changed" })
end

function M.close_prompt(ctx)
  local state = state_module.state
  local original_eventignore = vim.o.eventignore

  if state.prompt then
    local prompt = state.prompt
    state.prompt = nil

    local ignored_events = { "WinEnter", "BufEnter", "BufWinEnter" }
    if original_eventignore ~= "" then
      table.insert(ignored_events, 1, original_eventignore)
    end
    vim.o.eventignore = table.concat(ignored_events, ",")

    state_module.force_explorer_normal_mode()

    if state_module.is_valid_win(state.winid) then
      ctx.window.configure_window(state.winid)
    end

    pcall(prompt.unmount, prompt)
  end

  if state_module.is_valid_win(state.winid) and vim.api.nvim_get_current_win() ~= state.winid then
    pcall(vim.api.nvim_set_current_win, state.winid)
  end

  if state_module.is_valid_win(state.winid) then
    ctx.window.configure_window(state.winid)
  end

  vim.o.eventignore = original_eventignore
end

function M.prompt_input(ctx, opts, callback)
  local state = state_module.state

  if not state_module.is_valid_win(state.winid) then
    return
  end

  M.close_prompt(ctx)

  local title = opts.prompt or "Input"
  local default_value = opts.default or ""
  local win_width = math.max(20, vim.api.nvim_win_get_width(state.winid) - 4)
  local content_width = math.max(vim.fn.strdisplaywidth(default_value), vim.fn.strdisplaywidth(title))
  local width = math.min(win_width, math.max(24, content_width + 2))
  local target_line = vim.api.nvim_win_get_cursor(state.winid)[1] - 1
  local win_height = vim.api.nvim_win_get_height(state.winid)
  local row = target_line

  if row + 3 > win_height then
    row = math.max(0, target_line - 3)
  end

  local popup = NuiPopup({
    relative = "win",
    win = state.winid,
    enter = true,
    position = {
      row = row,
      col = 1,
    },
    size = {
      width = width,
      height = 1,
    },
    border = {
      style = "rounded",
      text = {
        top = (" %s "):format(title),
        top_align = "left",
      },
    },
    buf_options = {
      bufhidden = "wipe",
      buftype = "nofile",
      modifiable = true,
      readonly = false,
      swapfile = false,
      filetype = "sapling",
    },
    win_options = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
      foldcolumn = "0",
      statusline = "",
      statuscolumn = "",
      wrap = false,
    },
  })

  local submit = function()
    if state.prompt ~= popup then
      return
    end

    local input_value = vim.api.nvim_buf_get_lines(popup.bufnr, 0, 1, false)[1] or ""
    M.close_prompt(ctx)

    if input_value == "" then
      return
    end

    callback(input_value)
  end

  state.prompt = popup
  popup:mount()
  state_module.tag_buffer(popup.bufnr, "popup")
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, { default_value })
  vim.api.nvim_win_set_cursor(popup.winid, { 1, #default_value })
  vim.cmd("noautocmd startinsert!")

  popup:on({ popup_event.BufLeave, popup_event.BufDelete }, function()
    if state.prompt == popup then
      M.close_prompt(ctx)
    end
  end, { once = true })

  vim.keymap.set("i", "<CR>", submit, {
    buffer = popup.bufnr,
    noremap = true,
    silent = true,
  })

  vim.keymap.set("n", "<CR>", submit, {
    buffer = popup.bufnr,
    noremap = true,
    silent = true,
  })

  vim.keymap.set({ "i", "n" }, "<Esc>", function()
    M.close_prompt(ctx)
  end, {
    buffer = popup.bufnr,
    noremap = true,
    silent = true,
  })

  vim.keymap.set("n", "q", function()
    M.close_prompt(ctx)
  end, {
    buffer = popup.bufnr,
    noremap = true,
    silent = true,
  })
end

function M.prompt_confirm(ctx, opts, callback)
  M.prompt_input(ctx, {
    prompt = opts.prompt,
    default = "",
    input_label = opts.input_label or "y/n: ",
  }, function(input)
    local normalized = vim.trim(input):lower()

    if normalized == "y" or normalized == "yes" then
      callback()
    end
  end)
end

function M.open_confirm_popup(ctx, lines, on_submit)
  local state = state_module.state

  if not state_module.is_valid_win(state.winid) then
    return
  end

  M.close_prompt(ctx)

  local popup_lines = lines
  local highlights = nil
  if type(lines) == "table" and lines.lines then
    popup_lines = lines.lines
    highlights = lines.highlights
  end

  ensure_confirm_highlights()

  local win_width = vim.o.columns
  local win_height = vim.o.lines
  local width = 48
  for _, line in ipairs(popup_lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 4)
  end
  width = math.min(width, math.max(28, win_width - 4))

  local height = math.min(math.max(#popup_lines, 8), math.max(4, win_height - 4))

  local popup = NuiPopup({
    relative = "editor",
    enter = true,
    position = {
      row = 0,
      col = 0,
    },
    size = {
      width = width,
      height = height,
    },
    border = {
      style = "rounded",
      text = {
        top = " Write changes ",
        top_align = "left",
      },
    },
    buf_options = {
      bufhidden = "wipe",
      buftype = "nofile",
      modifiable = false,
      readonly = true,
      swapfile = false,
      filetype = "sapling",
    },
    win_options = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
      foldcolumn = "0",
      statusline = "",
      statuscolumn = "",
      wrap = false,
    },
  })

  local clear_confirm_keymaps

  local submit = function(value)
    if state.prompt ~= popup then
      return
    end

    clear_confirm_keymaps()
    M.close_prompt(ctx)
    on_submit(value)
  end

  clear_confirm_keymaps = function()
    if state_module.is_valid_buf(state.bufnr) then
      pcall(vim.keymap.del, "n", "y", { buffer = state.bufnr })
      pcall(vim.keymap.del, "n", "n", { buffer = state.bufnr })
      pcall(vim.keymap.del, "n", "<CR>", { buffer = state.bufnr })
      pcall(vim.keymap.del, "n", "<Esc>", { buffer = state.bufnr })
    end
  end

  state.prompt = popup
  popup:mount()
  state_module.tag_buffer(popup.bufnr, "popup")
  vim.bo[popup.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, popup_lines)
  if highlights then
    for _, item in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(popup.bufnr, state_module.namespace, item.line, item.start_col, {
        end_col = item.end_col,
        hl_group = item.hl_group,
      })
    end
  end
  vim.bo[popup.bufnr].modifiable = false

  local function focus_popup()
    if state.prompt == popup and state_module.is_valid_win(popup.winid) then
      vim.api.nvim_set_current_win(popup.winid)
    end
  end

  focus_popup()
  vim.schedule(focus_popup)

  popup:on({ popup_event.BufLeave, popup_event.BufDelete }, function()
    if state.prompt == popup then
      clear_confirm_keymaps()
      M.close_prompt(ctx)
    end
  end, { once = true })

  vim.keymap.set("n", "y", function()
    submit(true)
  end, { buffer = popup.bufnr, noremap = true, silent = true })
  vim.keymap.set("n", "<CR>", function()
    submit(true)
  end, { buffer = popup.bufnr, noremap = true, silent = true })
  vim.keymap.set("n", "n", function()
    submit(false)
  end, { buffer = popup.bufnr, noremap = true, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    submit(false)
  end, { buffer = popup.bufnr, noremap = true, silent = true })

  if state_module.is_valid_buf(state.bufnr) then
    vim.keymap.set("n", "y", function()
      submit(true)
    end, { buffer = state.bufnr, noremap = true, silent = true, nowait = true })
    vim.keymap.set("n", "n", function()
      submit(false)
    end, { buffer = state.bufnr, noremap = true, silent = true, nowait = true })
    vim.keymap.set("n", "<CR>", function()
      submit(true)
    end, { buffer = state.bufnr, noremap = true, silent = true, nowait = true })
    vim.keymap.set("n", "<Esc>", function()
      submit(false)
    end, { buffer = state.bufnr, noremap = true, silent = true, nowait = true })
  end
end

return M
