local fs = require("sapling.fs")
local state_module = require("sapling.explorer.state")

local M = {}

local function build_edit_line(entry)
  local relative = fs.relative(state_module.normalize_root(), entry.path) or entry.name
  if entry.type == "directory" then
    return relative .. "/"
  end
  return relative
end

local function build_edit_lines(entries)
  local lines = {}

  for _, entry in ipairs(entries) do
    table.insert(lines, build_edit_line(entry))
  end

  return lines
end

local function is_strict_descendant(parent, path)
  if not parent or not path or fs.path_equal(parent, path) then
    return false
  end

  return fs.is_within(parent, path)
end

function M.refresh_or_discard_edit(ctx, callback)
  local state = state_module.state

  if not state.edit.active then
    callback()
    return
  end

  ctx.prompt.prompt_confirm(ctx, {
    prompt = "Discard pending buffer edits?",
  }, function()
    callback()
  end)
end

function M.replace_buffer_without_undo(bufnr, lines)
  if not state_module.is_valid_buf(bufnr) then
    return
  end

  local original_undolevels = vim.bo[bufnr].undolevels
  vim.bo[bufnr].undolevels = -1
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].undolevels = original_undolevels
end

function M.start_edit_session(ctx)
  local state = state_module.state
  local bufnr = ctx.window.ensure_buffer(ctx)
  if state.edit.active then
    return
  end

  ctx.prompt.close_prompt(ctx)
  ctx.help.close_help()
  state_module.clear_edit_diagnostics()
  state_module.stop_refresh_timer()

  state.edit.active = true
  state.edit.pending_reload = false
  state.edit.saving = false
  state.edit.snapshot_entries = vim.deepcopy(state.entries)
  state.edit.snapshot_lines = build_edit_lines(state.entries)

  state_module.set_explorer_modifiable(true)
  vim.api.nvim_buf_clear_namespace(bufnr, state_module.namespace, 0, -1)
  M.replace_buffer_without_undo(bufnr, ctx.tree.with_root_header(state.edit.snapshot_lines, ctx.tree.build_root_header_line(true)))
  vim.bo[bufnr].modified = false
  ctx.render.render_edit_buffer_decorations(ctx, bufnr)

  if state_module.is_valid_win(state.winid) then
    ctx.window.configure_window(state.winid)
  end

  ctx.keymaps.apply_buffer_keymaps(bufnr, ctx)
end

function M.finish_edit_session(ctx)
  local state = state_module.state
  local bufnr = ctx.window.ensure_buffer(ctx)

  state_module.clear_edit_diagnostics()
  state_module.reset_edit_state()
  state_module.set_explorer_modifiable(false)
  vim.bo[bufnr].modified = false
  ctx.keymaps.apply_buffer_keymaps(bufnr, ctx)
  state_module.mark_git_dirty()
  ctx.render.start_refresh_timer(ctx)
  ctx.render.render(ctx)
end

function M.cancel_edit_session(ctx)
  local state = state_module.state

  if not state.edit.active or not state_module.is_valid_buf(state.bufnr) then
    return
  end

  local cursor_line = state_module.is_valid_win(state.winid) and vim.api.nvim_win_get_cursor(state.winid)[1] or nil
  local header_lines = state_module.get_header_line_count()
  if cursor_line and cursor_line > header_lines then
    local entry = state.edit.snapshot_entries[cursor_line - header_lines]
    if entry then
      state.current_selection_path = entry.path
    end
  end

  state_module.force_explorer_normal_mode()
  state_module.clear_edit_diagnostics()
  state_module.reset_edit_state()
  state_module.set_explorer_modifiable(false)
  vim.bo[state.bufnr].modified = false
  ctx.keymaps.apply_buffer_keymaps(state.bufnr, ctx)
  ctx.render.start_refresh_timer(ctx)
  ctx.render.render(ctx)
end

function M.enter_edit_at_path(ctx, path)
  local state = state_module.state

  M.start_edit_session(ctx)

  if not state_module.is_valid_win(state.winid) then
    return
  end

  local target_line = 1
  if path then
    for index, entry in ipairs(state.edit.snapshot_entries) do
      if fs.path_equal(entry.path, path) then
        target_line = state_module.get_header_line_count() + index
        break
      end
    end
  end

  local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
  local line_text = lines[target_line] or ""
  vim.api.nvim_win_set_cursor(state.winid, { target_line, #line_text })
end

function M.insert_edit_line(ctx, text)
  local state = state_module.state

  M.start_edit_session(ctx)

  if not state_module.is_valid_win(state.winid) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.winid)
  local line_index = math.max(0, cursor[1])
  vim.api.nvim_buf_set_lines(state.bufnr, line_index, line_index, false, { text })
  ctx.render.render_edit_buffer_decorations(ctx, state.bufnr)
  vim.api.nvim_win_set_cursor(state.winid, { line_index + 1, #text })
  vim.cmd("startinsert!")
end

function M.delete_current_edit_line(ctx, path)
  local state = state_module.state

  M.start_edit_session(ctx)

  local cursor = vim.api.nvim_win_get_cursor(state.winid)
  local current_line = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
  if #lines == 0 then
    return
  end

  local start_line = current_line
  local end_line = current_line

  if path then
    local target_entry
    for index, entry in ipairs(state.edit.snapshot_entries) do
      if fs.path_equal(entry.path, path) then
        target_entry = { index = state_module.get_header_line_count() + index, entry = entry }
        break
      end
    end

    if target_entry then
      start_line = target_entry.index
      end_line = target_entry.index
      if target_entry.entry.type == "directory" then
        for index = (target_entry.index - state_module.get_header_line_count()) + 1, #state.edit.snapshot_entries do
          local entry = state.edit.snapshot_entries[index]
          if is_strict_descendant(target_entry.entry.path, entry.path) then
            end_line = state_module.get_header_line_count() + index
          else
            break
          end
        end
      end
    end
  end

  vim.api.nvim_buf_set_lines(state.bufnr, start_line - 1, end_line, false, {})
  ctx.render.render_edit_buffer_decorations(ctx, state.bufnr)
  local new_line = math.max(1, math.min(start_line, math.max(1, vim.api.nvim_buf_line_count(state.bufnr))))
  vim.api.nvim_win_set_cursor(state.winid, { new_line, 0 })
end

function M.default_new_path(entry)
  local base_dir

  if not entry then
    base_dir = state_module.normalize_root()
  elseif entry.type == "directory" then
    base_dir = entry.path
  else
    base_dir = fs.dirname(entry.path)
  end

  local relative_base = fs.relative(state_module.normalize_root(), base_dir)
  local prefix = relative_base ~= "" and (relative_base .. "/") or ""

  return {
    file = prefix .. "new-file",
    directory = prefix .. "new-directory/",
  }
end

local function is_directory_expanded_in_edit_snapshot(entry, index)
  local next_entry = state_module.state.edit.snapshot_entries[index + 1]

  if not next_entry then
    return false
  end

  return is_strict_descendant(entry.path, next_entry.path)
end

function M.expand_directory_in_edit_mode(ctx)
  local state = state_module.state

  if not state.edit.active or not state_module.is_valid_buf(state.bufnr) or not state_module.is_valid_win(state.winid) then
    return false
  end

  if vim.bo[state.bufnr].modified then
    state_module.notify("Write or refresh pending edits before expanding directories", vim.log.levels.WARN)
    return true
  end

  local cursor_line = vim.api.nvim_win_get_cursor(state.winid)[1]
  local header_lines = state_module.get_header_line_count()
  if cursor_line <= header_lines then
    return true
  end

  local snapshot_index = cursor_line - header_lines
  local entry = state.edit.snapshot_entries[snapshot_index]

  if not entry or entry.type ~= "directory" then
    return false
  end

  if is_directory_expanded_in_edit_snapshot(entry, snapshot_index) then
    local end_index = snapshot_index

    for index = snapshot_index + 1, #state.edit.snapshot_entries do
      local child = state.edit.snapshot_entries[index]
      if is_strict_descendant(entry.path, child.path) then
        end_index = index
      else
        break
      end
    end

    for path in pairs(state.expanded_paths) do
      if fs.path_equal(path, entry.path) or is_strict_descendant(entry.path, path) then
        state.expanded_paths[path] = nil
      end
    end

    if end_index > snapshot_index then
      for _ = snapshot_index + 1, end_index do
        table.remove(state.edit.snapshot_entries, snapshot_index + 1)
        table.remove(state.edit.snapshot_lines, snapshot_index + 1)
      end
    end

    M.replace_buffer_without_undo(state.bufnr, ctx.tree.with_root_header(state.edit.snapshot_lines, ctx.tree.build_root_header_line(true)))
    vim.bo[state.bufnr].modified = false
    ctx.render.render_edit_buffer_decorations(ctx, state.bufnr)
    vim.api.nvim_win_set_cursor(state.winid, { cursor_line, 0 })
    return true
  end

  state.expanded_paths[fs.path_key(entry.path)] = true

  local subtree_entries = {}
  ctx.tree.flatten_tree(entry.path, entry.depth + 1, subtree_entries)

  if #subtree_entries == 0 then
    return true
  end

  local subtree_lines = build_edit_lines(subtree_entries)
  local new_snapshot_entries = vim.list_extend({}, state.edit.snapshot_entries)
  local new_snapshot_lines = vim.list_extend({}, state.edit.snapshot_lines)

  for offset = #subtree_entries, 1, -1 do
    table.insert(new_snapshot_entries, snapshot_index + 1, subtree_entries[offset])
  end

  for offset = #subtree_lines, 1, -1 do
    table.insert(new_snapshot_lines, snapshot_index + 1, subtree_lines[offset])
  end

  state.edit.snapshot_entries = new_snapshot_entries
  state.edit.snapshot_lines = new_snapshot_lines

  M.replace_buffer_without_undo(state.bufnr, ctx.tree.with_root_header(state.edit.snapshot_lines, ctx.tree.build_root_header_line(true)))
  vim.bo[state.bufnr].modified = false
  ctx.render.render_edit_buffer_decorations(ctx, state.bufnr)
  vim.api.nvim_win_set_cursor(state.winid, { cursor_line, 0 })

  return true
end

local function parse_edit_line(line, index)
  if line == "" then
    return nil, {
      lnum = index - 1,
      col = 0,
      message = "Path cannot be empty",
    }
  end

  local display = line:gsub("\\", "/")
  local entry_type = display:sub(-1) == "/" and "directory" or "file"
  local relative = entry_type == "directory" and display:sub(1, -2) or display

  if relative == "" then
    return nil, {
      lnum = index - 1,
      col = 0,
      message = "Root path cannot be edited directly",
    }
  end

  if relative:match("^/") or relative:match("^%a:[/\\]") then
    return nil, {
      lnum = index - 1,
      col = 0,
      message = "Path must be relative to the explorer root",
    }
  end

  local segments = vim.split(relative, "/", { plain = true, trimempty = false })
  for _, segment in ipairs(segments) do
    if segment == "" then
      return nil, {
        lnum = index - 1,
        col = 0,
        message = "Path cannot contain empty segments",
      }
    end

    if segment == "." or segment == ".." then
      return nil, {
        lnum = index - 1,
        col = 0,
        message = "Path traversal is not allowed",
      }
    end
  end

  local path_valid, path_valid_err = fs.validate_path_segments(relative)
  if not path_valid then
    return nil, {
      lnum = index - 1,
      col = 0,
      message = path_valid_err,
    }
  end

  local root = state_module.normalize_root()
  local absolute = fs.resolve(root, relative)
  if not absolute or not fs.is_within(root, absolute) or fs.path_equal(root, absolute) then
    return nil, {
      lnum = index - 1,
      col = 0,
      message = "Path must stay inside the current root",
    }
  end

  local len_ok, len_err = fs.check_path_length(absolute)
  if not len_ok then
    return nil, {
      lnum = index - 1,
      col = 0,
      message = len_err,
    }
  end

  return {
    index = index,
    raw = display,
    relative = relative,
    path = absolute,
    type = entry_type,
  }
end

local function lcs_matches(old_lines, new_lines)
  local old_count = #old_lines
  local new_count = #new_lines
  local dp = {}

  for old_index = 0, old_count do
    dp[old_index] = {}
    dp[old_index][0] = 0
  end

  for new_index = 0, new_count do
    dp[0][new_index] = 0
  end

  for old_index = 1, old_count do
    for new_index = 1, new_count do
      if old_lines[old_index] == new_lines[new_index] then
        dp[old_index][new_index] = dp[old_index - 1][new_index - 1] + 1
      else
        dp[old_index][new_index] = math.max(dp[old_index - 1][new_index], dp[old_index][new_index - 1])
      end
    end
  end

  local matches = {}
  local old_index = old_count
  local new_index = new_count

  while old_index > 0 and new_index > 0 do
    if old_lines[old_index] == new_lines[new_index] then
      table.insert(matches, 1, { old = old_index, new = new_index })
      old_index = old_index - 1
      new_index = new_index - 1
    elseif dp[old_index - 1][new_index] >= dp[old_index][new_index - 1] then
      old_index = old_index - 1
    else
      new_index = new_index - 1
    end
  end

  return matches
end

local function make_diagnostic(index, message)
  return {
    lnum = math.max(0, index - 1),
    col = 0,
    message = message,
  }
end

local function build_edit_plan()
  local state = state_module.state
  local lines = vim.api.nvim_buf_get_lines(state.bufnr, state_module.get_header_line_count(), -1, false)
  local parsed_entries = {}
  local diagnostics = {}
  local seen_paths = {}

  if state.clipboard and state.clipboard.mode == "cut" then
    diagnostics[#diagnostics + 1] = make_diagnostic(1, "Paste or clear the current cut clipboard before writing buffer edits")
    return nil, diagnostics
  end

  for index, line in ipairs(lines) do
    if vim.trim(line) == "" then
      goto continue
    end

    local parsed, err = parse_edit_line(line, index)
    if err then
      diagnostics[#diagnostics + 1] = err
    else
      local key = fs.normalize(parsed.path)
      if seen_paths[key] then
        diagnostics[#diagnostics + 1] = make_diagnostic(index, ("Duplicate destination path: %s"):format(parsed.relative))
      else
        seen_paths[key] = index
        parsed_entries[#parsed_entries + 1] = parsed
      end
    end

    ::continue::
  end

  if #diagnostics > 0 then
    return nil, diagnostics
  end

  local old_entries = state.edit.snapshot_entries
  local old_lines = state.edit.snapshot_lines
  local new_lines = {}
  for _, entry in ipairs(parsed_entries) do
    new_lines[#new_lines + 1] = entry.raw
  end

  local matches = lcs_matches(old_lines, new_lines)
  matches[#matches + 1] = { old = #old_entries + 1, new = #parsed_entries + 1 }

  local actions = {}
  local old_cursor = 1
  local new_cursor = 1

  for _, match in ipairs(matches) do
    local old_stop = match.old - 1
    local new_stop = match.new - 1
    local pair_count = math.min(old_stop - old_cursor + 1, new_stop - new_cursor + 1)

    for offset = 0, pair_count - 1 do
      local old_entry = old_entries[old_cursor + offset]
      local new_entry = parsed_entries[new_cursor + offset]

      if old_entry.type ~= new_entry.type then
        diagnostics[#diagnostics + 1] = make_diagnostic(
          new_entry.index,
          "Cannot change a file into a directory or vice versa by editing a single line"
        )
      elseif not fs.path_equal(old_entry.path, new_entry.path) then
        actions[#actions + 1] = {
          type = "move",
          src_path = old_entry.path,
          dest_path = new_entry.path,
          entry_type = old_entry.type,
          new_index = new_entry.index,
        }
      end
    end

    for old_index = old_cursor + pair_count, old_stop do
      local old_entry = old_entries[old_index]
      actions[#actions + 1] = {
        type = "delete",
        path = old_entry.path,
        entry_type = old_entry.type,
        old_index = old_index,
      }
    end

    for new_index = new_cursor + pair_count, new_stop do
      local new_entry = parsed_entries[new_index]
      actions[#actions + 1] = {
        type = "create",
        path = new_entry.path,
        entry_type = new_entry.type,
        new_index = new_entry.index,
      }
    end

    old_cursor = match.old + 1
    new_cursor = match.new + 1
  end

  if #diagnostics > 0 then
    return nil, diagnostics
  end

  local move_by_source = {}
  local delete_by_path = {}
  local redundant = {}
  local source_paths = {}

  for index, action in ipairs(actions) do
    if action.type == "move" then
      move_by_source[fs.normalize(action.src_path)] = { action = action, index = index }
      source_paths[fs.normalize(action.src_path)] = true
    elseif action.type == "delete" then
      delete_by_path[fs.normalize(action.path)] = { action = action, index = index }
      source_paths[fs.normalize(action.path)] = true
    end
  end

  for index, action in ipairs(actions) do
    if action.type == "move" or action.type == "delete" then
      local current_path = action.type == "move" and action.src_path or action.path
      local current_key = fs.normalize(current_path)

      for source_key, source_info in pairs(move_by_source) do
        local parent_action = source_info.action
        if parent_action.entry_type == "directory" and source_key ~= current_key and is_strict_descendant(parent_action.src_path, current_path) then
          if action.type == "move" then
            local relative = fs.relative(parent_action.src_path, action.src_path)
            local expected = fs.join(parent_action.dest_path, relative)
            if fs.path_equal(expected, action.dest_path) then
              redundant[index] = true
            else
              diagnostics[#diagnostics + 1] = make_diagnostic(
                action.new_index or 1,
                "Edit parent directory moves on their own; descendant moves are applied automatically"
              )
            end
          else
            diagnostics[#diagnostics + 1] = make_diagnostic(
              action.old_index or 1,
              "Cannot delete an entry inside a directory that is also being moved"
            )
          end
        end
      end

      for source_key, source_info in pairs(delete_by_path) do
        local parent_action = source_info.action
        if parent_action.entry_type == "directory" and source_key ~= current_key and is_strict_descendant(parent_action.path, current_path) then
          if action.type == "delete" then
            redundant[index] = true
          else
            diagnostics[#diagnostics + 1] = make_diagnostic(
              action.new_index or action.old_index or 1,
              "Edit directory deletions on their own; descendant entries are removed with the directory"
            )
          end
        end
      end
    end
  end

  local filtered_actions = {}
  for index, action in ipairs(actions) do
    if not redundant[index] then
      filtered_actions[#filtered_actions + 1] = action
    end
  end
  actions = filtered_actions

  if #diagnostics > 0 then
    return nil, diagnostics
  end

  local destination_paths = {}
  for _, action in ipairs(actions) do
    if action.type == "move" then
      local dest_key = fs.normalize(action.dest_path)

      if action.entry_type == "directory" and is_strict_descendant(action.src_path, action.dest_path) then
        diagnostics[#diagnostics + 1] = make_diagnostic(action.new_index or 1, "Cannot move a directory into itself")
      end

      if destination_paths[dest_key] then
        diagnostics[#diagnostics + 1] = make_diagnostic(action.new_index or 1, "Multiple edits target the same destination path")
      else
        destination_paths[dest_key] = true
      end

      if fs.exists(action.dest_path) and not source_paths[dest_key] and not fs.path_equal(action.src_path, action.dest_path) then
        diagnostics[#diagnostics + 1] = make_diagnostic(action.new_index or 1, ("Destination already exists: %s"):format(action.dest_path))
      end

      if not fs.exists(action.src_path) then
        diagnostics[#diagnostics + 1] = make_diagnostic(action.new_index or 1, ("Source no longer exists: %s"):format(action.src_path))
      end
    elseif action.type == "create" then
      local dest_key = fs.normalize(action.path)
      if destination_paths[dest_key] then
        diagnostics[#diagnostics + 1] = make_diagnostic(action.new_index or 1, "Multiple edits target the same destination path")
      else
        destination_paths[dest_key] = true
      end

      if fs.exists(action.path) and not source_paths[dest_key] then
        diagnostics[#diagnostics + 1] = make_diagnostic(action.new_index or 1, ("Path already exists: %s"):format(action.path))
      end
    else
      if not fs.exists(action.path) then
        diagnostics[#diagnostics + 1] = make_diagnostic(action.old_index or 1, ("Path no longer exists: %s"):format(action.path))
      end
    end
  end

  if #diagnostics > 0 then
    return nil, diagnostics
  end

  return {
    actions = actions,
  }, nil
end

function M.show_edit_diagnostics(diagnostics)
  local state = state_module.state

  state_module.clear_edit_diagnostics()
  vim.diagnostic.set(state_module.diagnostics_namespace, state.bufnr, diagnostics)

  if state_module.is_valid_win(state.winid) and diagnostics[1] then
    pcall(vim.api.nvim_win_set_cursor, state.winid, { diagnostics[1].lnum + 1, diagnostics[1].col })
  end
end

local function remap_expanded_paths(actions)
  local state = state_module.state
  local remapped = {}

  for path, value in pairs(state.expanded_paths) do
    local updated_path = path

    for _, action in ipairs(actions) do
      if action.type == "move" and action.entry_type == "directory" then
        if fs.path_equal(updated_path, action.src_path) then
          updated_path = action.dest_path
        elseif is_strict_descendant(action.src_path, updated_path) then
          local relative = fs.relative(action.src_path, updated_path)
          updated_path = fs.join(action.dest_path, relative)
        end
      elseif action.type == "delete" and action.entry_type == "directory" then
        if fs.path_equal(updated_path, action.path) or is_strict_descendant(action.path, updated_path) then
          updated_path = nil
          break
        end
      end
    end

    if updated_path then
      remapped[fs.path_key(updated_path)] = value
    end
  end

  state.expanded_paths = remapped
end

local function sort_delete_actions(actions)
  table.sort(actions, function(left, right)
    local left_depth = select(2, left.path:gsub("/", ""))
    local right_depth = select(2, right.path:gsub("/", ""))
    return left_depth > right_depth
  end)
end

local function unique_temp_path(path)
  local parent = fs.dirname(path)
  local base = fs.basename(path)
  local counter = 0

  while true do
    counter = counter + 1
    local candidate = fs.join(parent, (".sapling-tmp-%s-%d"):format(base, counter))
    if not fs.exists(candidate) then
      return candidate
    end
  end
end

local function apply_move_actions(actions)
  local remaining = vim.deepcopy(actions)
  local temp_sources = {}

  while #remaining > 0 do
    local progress = false
    local source_keys = {}

    for _, action in ipairs(remaining) do
      source_keys[fs.normalize(temp_sources[action.src_path] or action.src_path)] = true
    end

    local next_remaining = {}

    for _, action in ipairs(remaining) do
      local current_source = temp_sources[action.src_path] or action.src_path
      local destination_key = fs.normalize(action.dest_path)

      if not fs.exists(current_source) then
        return false, ("Move source no longer exists: %s"):format(current_source)
      end

      if not fs.exists(action.dest_path) or not source_keys[destination_key] then
        local ok, err = fs.rename(current_source, action.dest_path)
        if not ok then
          return false, err
        end
        progress = true
      else
        next_remaining[#next_remaining + 1] = action
      end
    end

    remaining = next_remaining

    if not progress then
      local cycle = remaining[1]
      if not cycle then
        break
      end

      local current_source = temp_sources[cycle.src_path] or cycle.src_path
      local temporary_path = unique_temp_path(current_source)
      local ok, err = fs.rename(current_source, temporary_path)
      if not ok then
        return false, err
      end
      temp_sources[cycle.src_path] = temporary_path
    end
  end

  return true
end

local function apply_edit_actions(actions)
  local state = state_module.state
  local delete_actions = {}
  local move_actions = {}
  local create_actions = {}

  for _, action in ipairs(actions) do
    if action.type == "delete" then
      delete_actions[#delete_actions + 1] = action
    elseif action.type == "move" then
      move_actions[#move_actions + 1] = action
    else
      create_actions[#create_actions + 1] = action
    end
  end

  sort_delete_actions(delete_actions)

  for _, action in ipairs(delete_actions) do
    local ok, err = fs.remove(action.path)
    if not ok then
      return false, err
    end
  end

  local ok, err = apply_move_actions(move_actions)
  if not ok then
    return false, err
  end

  for _, action in ipairs(create_actions) do
    local created, create_err
    if action.entry_type == "directory" then
      created, create_err = fs.create_dir(action.path)
      if created then
        state.expanded_paths[fs.path_key(action.path)] = true
      end
    else
      created, create_err = fs.create_file(action.path)
    end

    if not created then
      return false, create_err
    end
  end

  remap_expanded_paths(actions)
  state_module.mark_filter_dirty()
  return true
end

local function action_summary_label(action)
  if action.type == "create" then
    return "CREATE", "SaplingEditCreate"
  end

  if action.type == "delete" then
    return "DELETE", "SaplingEditDelete"
  end

  return "MOVE", "SaplingEditMove"
end

local function action_summary_path(action, root)
  local path

  if action.type == "move" then
    path = fs.relative(root, action.dest_path) or action.dest_path
  else
    path = fs.relative(root, action.path) or action.path
  end

  if action.entry_type == "directory" and path:sub(-1) ~= "/" then
    path = path .. "/"
  end

  return path
end

local function summarize_actions(actions)
  local root = state_module.normalize_root()
  local operation_width = 0

  for _, action in ipairs(actions) do
    local label = action_summary_label(action)
    operation_width = math.max(operation_width, #label)
  end

  local lines = {}
  local highlights = {}

  for _, action in ipairs(actions) do
    local label, hl_group = action_summary_label(action)
    local path = action_summary_path(action, root)
    local line = ("%-" .. tostring(operation_width) .. "s %s"):format(label, path)

    lines[#lines + 1] = line
    highlights[#highlights + 1] = {
      line = #lines - 1,
      start_col = 0,
      end_col = operation_width,
      hl_group = hl_group,
    }
  end

  lines[#lines + 1] = "y: apply  n: cancel"
  return {
    lines = lines,
    highlights = highlights,
  }
end

function M.apply_edit_buffer(ctx)
  local state = state_module.state

  if not state.edit.active or not state_module.is_valid_buf(state.bufnr) then
    return
  end

  local plan, diagnostics = build_edit_plan()

  if diagnostics then
    M.show_edit_diagnostics(diagnostics)
    state_module.notify("Fix the highlighted buffer edits before writing", vim.log.levels.ERROR)
    return
  end

  local actions = plan.actions
  if #actions == 0 then
    M.finish_edit_session(ctx)
    return
  end

  state.edit.saving = true
  ctx.prompt.open_confirm_popup(ctx, summarize_actions(actions), function(proceed)
    if not proceed then
      state.edit.saving = false
      state_module.notify("Canceled applying buffer edits", vim.log.levels.WARN)
      return
    end

    local ok, err = apply_edit_actions(actions)
    state.edit.saving = false

    if not ok then
      state_module.notify(err, vim.log.levels.ERROR)
      state_module.mark_git_dirty()
      state.edit.pending_reload = true
      M.finish_edit_session(ctx)
      return
    end

    local preferred_selection
    for _, action in ipairs(actions) do
      if action.type == "move" then
        preferred_selection = action.dest_path
      elseif action.type == "create" then
        preferred_selection = action.path
      else
        preferred_selection = fs.dirname(action.path)
      end
    end

    if preferred_selection then
      state.current_selection_path = preferred_selection
    end

    M.finish_edit_session(ctx)
  end)
end

return M
