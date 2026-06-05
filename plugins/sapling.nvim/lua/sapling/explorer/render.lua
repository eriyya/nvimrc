local fs = require("sapling.fs")
local git = require("sapling.git")
local state_module = require("sapling.explorer.state")

local M = {}

local devicons_module = nil
local devicons_checked = false

function M.ensure_highlights()
  local function first_background(names)
    for _, name in ipairs(names) do
      local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })

      if ok and hl and hl.bg then
        return hl.bg
      end
    end

    return nil
  end

  local selection_bg = first_background({ "PmenuSel", "Visual", "StatusLine", "ColorColumn", "CursorLine" }) or 238
  local current_file_bg = first_background({ "ColorColumn", "CursorLine", "LineNr", "StatusLine" }) or 236

  vim.api.nvim_set_hl(0, "SaplingDirectory", { default = true, link = "Directory" })
  vim.api.nvim_set_hl(0, "SaplingGitModified", { default = true, link = "Changed" })
  vim.api.nvim_set_hl(0, "SaplingGitUntracked", { default = true, link = "Added" })
  vim.api.nvim_set_hl(0, "SaplingGitIgnored", { default = true, link = "Comment" })
  vim.api.nvim_set_hl(0, "SaplingHidden", { default = true, link = "Comment" })
  vim.api.nvim_set_hl(0, "SaplingSelection", {
    fg = nil,
    bg = selection_bg,
  })
  vim.api.nvim_set_hl(0, "SaplingCurrentFile", {
    fg = nil,
    bg = current_file_bg,
  })
  vim.api.nvim_set_hl(0, "SaplingHelpTitle", { default = true, link = "Title" })
  vim.api.nvim_set_hl(0, "SaplingFilterLabel", { default = true, link = "Title" })
end

function M.get_devicons()
  if devicons_checked then
    return devicons_module
  end

  devicons_checked = true

  local ok, module = pcall(require, "nvim-web-devicons")
  if ok then
    devicons_module = module
  end

  return devicons_module
end

function M.get_icon(entry)
  local state = state_module.state

  if not state.config.icons.enabled then
    return "", nil
  end

  if entry.type == "directory" then
    return "󰉋", "SaplingDirectory"
  end

  if state.config.icons.provider == "nvim-web-devicons" then
    local devicons = M.get_devicons()

    if devicons then
      local icon, hl = devicons.get_icon(entry.name, nil, { default = true })
      return icon or "", hl
    end
  end

  return "", nil
end

function M.get_status_display(status, count, entry_type)
  local suffix = ""
  if entry_type == "directory" and type(count) == "number" and count > 0 then
    suffix = tostring(count)
  end

  if status == "modified" then
    return (" [~%s]"):format(suffix), "SaplingGitModified"
  end

  if status == "untracked" then
    return (" [+%s]"):format(suffix), "SaplingGitUntracked"
  end

  if status == "ignored" then
    return (" [!%s]"):format(suffix), "SaplingGitIgnored"
  end

  return "", nil
end

function M.get_tree_marker(entry)
  if entry.type ~= "directory" then
    return " "
  end

  if not state_module.show_directory_arrows() then
    return " "
  end

  return entry.expanded and "▾" or "▸"
end

function M.get_name_highlight(entry)
  if entry.git_status == "modified" then
    return "SaplingGitModified"
  end

  if entry.git_status == "untracked" then
    return "SaplingGitUntracked"
  end

  if entry.git_status == "ignored" then
    return "SaplingGitIgnored"
  end

  if entry.is_hidden then
    return "SaplingHidden"
  end

  if entry.type == "directory" then
    return "SaplingDirectory"
  end

  return nil
end

function M.request_git_refresh(ctx, root)
  local state = state_module.state

  if not state.config.git.enabled then
    if state.git.repo_root or next(state.git.exact) or next(state.git.aggregate) then
      state_module.reset_git_state()
    end
    return
  end

  if state.git.running then
    return
  end

  if fs.path_equal(state.git.root, root) and not state.git.dirty then
    return
  end

  local token = state.git.token + 1
  state.git.token = token
  state.git.running = true
  state.git.dirty = false
  state.git.root = root

  git.collect_async(root, function(result)
    if token ~= state.git.token then
      return
    end

    state.git.running = false
    state.git.exact = result.exact
    state.git.exact_counts = result.exact_counts
    state.git.aggregate = result.aggregate
    state.git.aggregate_counts = result.aggregate_counts
    state.git.repo_root = result.repo_root
    state.git.root = root

    if state.edit.active then
      state.edit.pending_reload = true
      return
    end

    if state_module.is_valid_buf(state.bufnr) then
      M.render(ctx)
    end
  end)
end

function M.set_buffer_lines(bufnr, lines)
  if not state_module.is_valid_buf(bufnr) then
    return
  end

  local previous = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = previous
end

function M.render_tree_buffer(ctx, bufnr, entries, empty_message)
  local state = state_module.state
  local lines = {}
  local header_line = ctx.tree.build_root_header_line(false)
  local header_lines = ctx.tree.build_header_lines(header_line)
  local root_header_index = #header_lines - 1

  if #entries == 0 then
    lines = { empty_message or "[empty]" }
  else
    for _, entry in ipairs(entries) do
      local indent = string.rep("  ", entry.depth + 1)
      local marker = M.get_tree_marker(entry)
      local icon, _ = M.get_icon(entry)
      local line = ("%s%s %s %s"):format(indent, marker, icon, entry.name)
      table.insert(lines, line)
    end
  end

  lines = ctx.tree.with_root_header(lines, header_line)

  M.set_buffer_lines(bufnr, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, state_module.namespace, 0, -1)

  if state.filter.active then
    local filter_line = header_lines[1]
    vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, 0, 0, {
      end_col = math.min(#ctx.filter.get_prefix(), #filter_line),
      hl_group = "SaplingFilterLabel",
      hl_mode = "combine",
    })
  end

  vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, root_header_index, 0, {
    end_col = #header_line,
    hl_group = "SaplingDirectory",
    hl_mode = "combine",
  })

  for index, entry in ipairs(entries) do
    local line_index = state_module.get_header_line_count() + index - 1
    local icon, icon_hl = M.get_icon(entry)
    local line = lines[line_index + 1]
    local status_text, status_hl = M.get_status_display(entry.git_status, entry.git_count, entry.type)
    local name_hl = M.get_name_highlight(entry)
    local icon_start = icon ~= "" and line:find(icon, 1, true) or nil
    local name_start = line:find(entry.name, 1, true)

    if entry.type == "directory" then
      vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line_index, 0, {
        end_col = #line,
        hl_group = "SaplingDirectory",
        hl_mode = "combine",
      })
    end

    if state.current_file_path and fs.path_equal(entry.path, state.current_file_path) then
      vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line_index, 0, {
        line_hl_group = "SaplingCurrentFile",
        priority = 100,
      })
    end

    if state.current_selection_path and fs.path_equal(entry.path, state.current_selection_path) then
      vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line_index, 0, {
        line_hl_group = "SaplingSelection",
        priority = 200,
      })
    end

    if icon_start and icon_hl then
      vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line_index, icon_start - 1, {
        end_col = icon_start - 1 + #icon,
        hl_group = icon_hl,
      })
    end

    if name_hl and name_start then
      vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line_index, name_start - 1, {
        end_col = name_start - 1 + #entry.name,
        hl_group = name_hl,
      })
    end

    if status_hl and status_text ~= "" then
      vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line_index, 0, {
        virt_text = {
          { status_text, status_hl },
        },
        virt_text_pos = "right_align",
      })
    end
  end
end

function M.render_edit_buffer_decorations(ctx, bufnr)
  if not state_module.is_valid_buf(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, state_module.namespace, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for line, text in ipairs(lines) do
    if line <= state_module.get_header_line_count() then
      if text ~= "" then
        vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line - 1, 0, {
          end_col = #text,
          hl_group = "SaplingDirectory",
          hl_mode = "combine",
        })
      end
      goto continue
    end

    local entry_type = text:sub(-1) == "/" and "directory" or "file"
    local relative = entry_type == "directory" and text:sub(1, -2) or text
    local path = relative ~= "" and fs.resolve(state_module.normalize_root(), relative) or nil
    local status = path and ctx.tree.get_git_status_for_path(path, entry_type) or nil
    local highlight = nil

    if status == "modified" then
      highlight = "SaplingGitModified"
    elseif status == "untracked" then
      highlight = "SaplingGitUntracked"
    elseif status == "ignored" then
      highlight = "SaplingGitIgnored"
    elseif entry_type == "directory" then
      highlight = "SaplingDirectory"
    end

    if highlight and text ~= "" then
      vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line - 1, 0, {
        end_col = #text,
        hl_group = highlight,
      })
    end

    vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line - 1, 0, {
      virt_text = {
        { state_module.edit_padding_text, "Normal" },
      },
      virt_text_pos = "inline",
    })

    vim.api.nvim_buf_set_extmark(bufnr, state_module.namespace, line - 1, 0, {
      virt_text = {
        { state_module.edit_padding_text, "Normal" },
      },
      virt_text_pos = "eol",
    })

    ::continue::
  end
end

function M.buffer_mode_refresh_requested()
  local state = state_module.state
  return state.edit.active or state.edit.pending_reload
end

function M.maybe_render_or_defer(ctx)
  local state = state_module.state

  if M.buffer_mode_refresh_requested() then
    state.edit.pending_reload = true
    return
  end

  M.render(ctx)
end

function M.start_refresh_timer(ctx)
  local state = state_module.state

  state_module.stop_refresh_timer()

  if state.edit.active then
    return
  end

  local interval = state.config.git.refresh_interval_ms
  if type(interval) ~= "number" or interval <= 0 then
    return
  end

  local uv = vim.uv or vim.loop
  local timer = uv.new_timer()
  if not timer then
    return
  end

  state.refresh_timer = timer
  timer:start(interval, interval, vim.schedule_wrap(function()
    if not state_module.is_valid_win(state.winid) or not state_module.is_valid_buf(state.bufnr) then
      state_module.stop_refresh_timer()
      return
    end

    if state.edit.active then
      state.edit.pending_reload = true
      return
    end

    state_module.mark_git_dirty()
    M.render(ctx)
  end))
end

function M.render(ctx)
  local state = state_module.state
  local bufnr = ctx.window.ensure_buffer(ctx)

  if state.edit.active then
    if state_module.is_valid_win(state.winid) then
      ctx.window.configure_window(state.winid)
    end
    return
  end

  local root = state_module.normalize_root()

  M.ensure_highlights()
  M.request_git_refresh(ctx, root)
  ctx.filter.request_index(ctx)
  ctx.tree.refresh_current_file_state()
  state_module.clear_edit_diagnostics()

  local entries, empty_message = ctx.filter.build_filtered_entries(ctx)
  if not entries then
    entries = {}
    ctx.tree.flatten_tree(root, 0, entries)
  end
  state.entries = entries

  M.render_tree_buffer(ctx, bufnr, entries, empty_message)
  state_module.set_explorer_modifiable(false)
  vim.bo[bufnr].modified = false

  if state_module.is_valid_win(state.winid) then
    ctx.window.configure_window(state.winid)
    ctx.filter.sync_input_window(ctx)

    local target_entry_line = state.current_selection_path and ctx.tree.find_entry_line(state.current_selection_path) or nil
    if not target_entry_line then
      target_entry_line = 1
      if entries[target_entry_line] then
        state.current_selection_path = entries[target_entry_line].path
      else
        state.current_selection_path = nil
      end
    end

    local target_line = state.current_selection_path and (state_module.get_header_line_count() + target_entry_line) or 1
    vim.api.nvim_win_set_cursor(state.winid, { target_line, 0 })
  end
end

return M
