local fs = require("sapling.fs")
local state_module = require("sapling.explorer.state")

local M = {}

local function base_directory_for_action(entry)
  if not entry then
    return state_module.normalize_root()
  end

  if entry.type == "directory" then
    return entry.path
  end

  return fs.dirname(entry.path)
end

local function get_paste_target_directory(ctx)
  local entry = ctx.tree.get_entry_at_cursor()

  if not entry then
    return state_module.normalize_root()
  end

  if entry.type == "directory" then
    return entry.path
  end

  return fs.dirname(entry.path)
end

local function refresh_after_path_change(ctx, path)
  local state = state_module.state

  if path and fs.is_within(state_module.normalize_root(), path) then
    state.current_selection_path = path
  end

  state_module.mark_git_dirty()
  state_module.mark_filter_dirty()
  ctx.render.maybe_render_or_defer(ctx)
end

local function input_targets_directory(input)
  return type(input) == "string" and input:match("[/\\]$") ~= nil
end

local function copy_to_registers(text)
  vim.fn.setreg('"', text)
  pcall(vim.fn.setreg, "+", text)
  pcall(vim.fn.setreg, "*", text)
end

function M.move_cursor(ctx, delta)
  local state = state_module.state

  if state.edit.active then
    return
  end

  if not state_module.is_valid_win(state.winid) or #state.entries == 0 then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.winid)
  local line = math.max(1, math.min(#state.entries, (cursor[1] - state_module.get_header_line_count()) + delta))
  local entry = state.entries[line]

  if entry then
    state.current_selection_path = entry.path
    ctx.render.render(ctx)
  end
end

function M.move_to_top(ctx)
  local state = state_module.state

  if state.edit.active then
    return
  end

  if not state_module.is_valid_win(state.winid) or #state.entries == 0 then
    return
  end

  state.current_selection_path = state.entries[1].path
  ctx.render.render(ctx)
end

function M.move_to_bottom(ctx)
  local state = state_module.state

  if state.edit.active then
    return
  end

  if not state_module.is_valid_win(state.winid) or #state.entries == 0 then
    return
  end

  state.current_selection_path = state.entries[#state.entries].path
  ctx.render.render(ctx)
end

function M.select_mouse(ctx)
  if state_module.state.edit.active then
    return
  end

  ctx.tree.select_entry_from_mouse(ctx)
end

function M.show_help(ctx)
  local state = state_module.state

  if state_module.is_valid_win(state.help_winid) then
    ctx.help.close_help()
    return
  end

  ctx.help.open_help()
end

function M.open_mouse(ctx)
  if state_module.state.edit.active then
    return
  end

  local entry = ctx.tree.select_entry_from_mouse(ctx)
  if entry then
    M.open_selected(ctx)
  end
end

function M.open_selected(ctx)
  local state = state_module.state

  if state.edit.active then
    state_module.notify("Write or refresh the buffer edits before opening entries", vim.log.levels.WARN)
    return
  end

  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  state.current_selection_path = entry.path

  if entry.type == "directory" then
    if state.filter.active then
      ctx.render.render(ctx)
      return
    end

    local key = fs.path_key(entry.path)
    state.expanded_paths[key] = not state.expanded_paths[key]
    ctx.render.render(ctx)
    return
  end

  local target_win = ctx.window.get_target_window()
  local edit_path = fs.relative(state_module.normalize_root(), entry.path) or entry.path
  vim.api.nvim_set_current_win(target_win)
  vim.cmd(("edit %s"):format(vim.fn.fnameescape(edit_path)))
  state.last_file_window = target_win
  state.current_file_path = entry.path

  if state_module.is_valid_win(state.winid) then
    ctx.render.render(ctx)
  end
end

function M.collapse_or_parent(ctx)
  local state = state_module.state

  if state.edit.active then
    return
  end

  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  if state.filter.active then
    return
  end

  if entry.type == "directory" and state.expanded_paths[fs.path_key(entry.path)] then
    state.expanded_paths[fs.path_key(entry.path)] = nil
    state.current_selection_path = entry.path
    ctx.render.render(ctx)
    return
  end

  local parent = fs.dirname(entry.path)
  local root = state_module.normalize_root()

  if parent and fs.is_within(root, parent) and not fs.path_equal(parent, root) then
    state.current_selection_path = parent
    ctx.render.render(ctx)
  end
end

function M.edit_buffer(ctx)
  if state_module.state.filter.active then
    ctx.filter.clear(ctx)
  end

  if not state_module.supports_edit_buffer() then
    state_module.notify("Set file_edit_mode = 'buffer' or 'mixed' to use editable tree mode", vim.log.levels.WARN)
    return
  end

  ctx.window.ensure_window(ctx)
  ctx.edit.enter_edit_at_path(ctx, state_module.state.current_selection_path)
end

function M.filter(ctx)
  ctx.window.ensure_window(ctx)
  ctx.filter.focus(ctx)
end

function M.create_file(ctx)
  local state = state_module.state
  local entry = ctx.tree.get_entry_at_cursor()

  if state_module.uses_buffer_file_ops() then
    ctx.edit.insert_edit_line(ctx, ctx.edit.default_new_path(entry).file)
    return
  end

  local base_dir = base_directory_for_action(entry)
  local relative_base = fs.relative(state_module.normalize_root(), base_dir)
  local default_text = relative_base ~= "" and (relative_base .. "/") or ""

  ctx.prompt.prompt_input(ctx, {
    prompt = "New file: ",
    default = default_text,
  }, function(input)
    local path = fs.resolve(state_module.normalize_root(), input)
    local create_directory = input_targets_directory(input)
    local ok, err

    if create_directory then
      ok, err = fs.create_dir(path)
    else
      ok, err = fs.create_file(path)
    end

    if not ok then
      state_module.notify(err, vim.log.levels.ERROR)
      return
    end

    if create_directory then
      state.expanded_paths[fs.path_key(path)] = true
    end

    refresh_after_path_change(ctx, path)
  end)
end

function M.create_dir(ctx)
  local state = state_module.state
  local entry = ctx.tree.get_entry_at_cursor()

  if state_module.uses_buffer_file_ops() then
    ctx.edit.insert_edit_line(ctx, ctx.edit.default_new_path(entry).directory)
    return
  end

  local base_dir = base_directory_for_action(entry)
  local relative_base = fs.relative(state_module.normalize_root(), base_dir)
  local default_text = relative_base ~= "" and (relative_base .. "/") or ""

  ctx.prompt.prompt_input(ctx, {
    prompt = "New directory: ",
    default = default_text,
  }, function(input)
    local path = fs.resolve(state_module.normalize_root(), input)
    local ok, err = fs.create_dir(path)

    if not ok then
      state_module.notify(err, vim.log.levels.ERROR)
      return
    end

    state.expanded_paths[fs.path_key(path)] = true
    refresh_after_path_change(ctx, path)
  end)
end

function M.rename_selected(ctx)
  local state = state_module.state
  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  if state_module.uses_buffer_file_ops() then
    ctx.edit.enter_edit_at_path(ctx, entry.path)
    return
  end

  ctx.prompt.prompt_input(ctx, {
    prompt = "Rename to: ",
    default = entry.name,
  }, function(input)
    local destination = fs.join(fs.dirname(entry.path), input)
    if fs.path_equal(entry.path, destination) then
      return
    end

    local ok, err = fs.rename(entry.path, destination)
    if not ok then
      state_module.notify(err, vim.log.levels.ERROR)
      return
    end

    if entry.type == "directory" and state.expanded_paths[fs.path_key(entry.path)] then
      state.expanded_paths[fs.path_key(entry.path)] = nil
      state.expanded_paths[fs.path_key(destination)] = true
    end

    refresh_after_path_change(ctx, destination)
  end)
end

function M.move_selected(ctx)
  local state = state_module.state
  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  if state_module.uses_buffer_file_ops() then
    ctx.edit.enter_edit_at_path(ctx, entry.path)
    return
  end

  local default_path = fs.relative(state_module.normalize_root(), entry.path) or entry.name

  ctx.prompt.prompt_input(ctx, {
    prompt = "Move to: ",
    default = default_path,
  }, function(input)
    local destination = fs.resolve(state_module.normalize_root(), input)
    if fs.path_equal(entry.path, destination) then
      return
    end

    local ok, err = fs.rename(entry.path, destination)
    if not ok then
      state_module.notify(err, vim.log.levels.ERROR)
      return
    end

    if entry.type == "directory" and state.expanded_paths[fs.path_key(entry.path)] then
      state.expanded_paths[fs.path_key(entry.path)] = nil
      state.expanded_paths[fs.path_key(destination)] = true
    end

    refresh_after_path_change(ctx, destination)
  end)
end

function M.copy_selected(ctx)
  local state = state_module.state

  if state.edit.active then
    state_module.notify("Copy is unavailable while editing the tree buffer", vim.log.levels.WARN)
    return
  end

  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  state.clipboard = {
    mode = "copy",
    path = entry.path,
  }

  state_module.notify(("Copied %s"):format(entry.name))
end

function M.copy_absolute_path(ctx)
  local state = state_module.state

  if state.edit.active then
    state_module.notify("Copy absolute path is unavailable while editing the tree buffer", vim.log.levels.WARN)
    return
  end

  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  copy_to_registers(entry.path)
  state_module.notify(("Copied path: %s"):format(entry.path))
end

function M.cut_selected(ctx)
  local state = state_module.state

  if state.edit.active then
    state_module.notify("Cut is unavailable while editing the tree buffer", vim.log.levels.WARN)
    return
  end

  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  state.clipboard = {
    mode = "cut",
    path = entry.path,
  }

  state_module.notify(("Cut %s"):format(entry.name))
end

function M.paste_clipboard(ctx)
  local state = state_module.state

  if state.edit.active then
    state_module.notify("Paste is unavailable while editing the tree buffer", vim.log.levels.WARN)
    return
  end

  if not state.clipboard then
    state_module.notify("Clipboard is empty", vim.log.levels.WARN)
    return
  end

  local source_path = state.clipboard.path
  if not fs.exists(source_path) then
    state_module.notify(("Clipboard path no longer exists: %s"):format(source_path), vim.log.levels.ERROR)
    state.clipboard = nil
    return
  end

  local target_dir = get_paste_target_directory(ctx)
  local destination = fs.join(target_dir, fs.basename(source_path))

  if fs.path_equal(source_path, destination) then
    state_module.notify("Source and destination are the same", vim.log.levels.WARN)
    return
  end

  local ok, err
  if state.clipboard.mode == "cut" then
    ok, err = fs.rename(source_path, destination)
  else
    ok, err = fs.copy(source_path, destination)
  end

  if not ok then
    state_module.notify(err, vim.log.levels.ERROR)
    return
  end

  if state.clipboard.mode == "cut" then
    state.clipboard = nil
  end

  if fs.is_directory(destination) then
    state.expanded_paths[fs.path_key(destination)] = true
  end

  refresh_after_path_change(ctx, destination)
end

function M.delete_selected(ctx)
  local state = state_module.state
  local entry = ctx.tree.get_entry_at_cursor()
  if not entry then
    return
  end

  if state_module.uses_buffer_file_ops() then
    ctx.edit.delete_current_edit_line(ctx, entry.path)
    return
  end

  local label = fs.relative(state_module.normalize_root(), entry.path) or entry.name
  ctx.prompt.prompt_confirm(ctx, {
    prompt = ("Are you sure you want to delete '%s'?"):format(label),
  }, function()
    local ok, err = fs.remove(entry.path)
    if not ok then
      state_module.notify(err, vim.log.levels.ERROR)
      return
    end

    state.expanded_paths[fs.path_key(entry.path)] = nil
    state.current_selection_path = fs.dirname(entry.path)
    state_module.mark_git_dirty()
    state_module.mark_filter_dirty()
    ctx.render.render(ctx)
  end)
end

function M.apply_edit_buffer(ctx)
  ctx.edit.apply_edit_buffer(ctx)
end

function M.refresh(ctx)
  local state = state_module.state

  if state.edit.active then
    ctx.edit.refresh_or_discard_edit(ctx, function()
      state_module.reset_edit_state()
      state_module.set_explorer_modifiable(false)
      ctx.keymaps.apply_buffer_keymaps(state.bufnr, ctx)
      state_module.mark_git_dirty()
      ctx.render.start_refresh_timer(ctx)
      ctx.render.render(ctx)
    end)
    return
  end

  state_module.mark_git_dirty()
  state_module.mark_filter_dirty()
  ctx.render.render(ctx)
end

function M.reveal_current_file(ctx)
  M.open(ctx)

  if not ctx.tree.sync_current_file(ctx, { render = true }) then
    state_module.notify("Current file is outside the explorer root", vim.log.levels.WARN)
  end
end

function M.toggle_ignored(ctx)
  local state = state_module.state
  local manages_gitignored = state.config.git.enabled
  local next_visible = not (manages_gitignored and state.config.git.show_ignored or state.config.tree.show_hidden)

  if manages_gitignored then
    state.config.git.show_ignored = next_visible
  end

  state.config.tree.show_hidden = next_visible
  ctx.render.maybe_render_or_defer(ctx)

  if manages_gitignored then
    if next_visible then
      state_module.notify("Showing gitignored and hidden files")
    else
      state_module.notify("Hiding gitignored and hidden files")
    end
  elseif next_visible then
    state_module.notify("Showing hidden files")
  else
    state_module.notify("Hiding hidden files")
  end
end

function M.open(ctx)
  local state = state_module.state

  ctx.window.ensure_window(ctx)
  ctx.render.start_refresh_timer(ctx)

  if state.config.follow_current_file.enabled then
    if ctx.tree.sync_current_file(ctx, { render = true }) then
      return
    end
  end

  ctx.render.render(ctx)
end

function M.close(ctx)
  local state = state_module.state

  if state.edit.active and state_module.is_valid_buf(state.bufnr) and vim.bo[state.bufnr].modified then
    ctx.edit.refresh_or_discard_edit(ctx, function()
      state_module.reset_edit_state()
      state_module.set_explorer_modifiable(false)
      ctx.keymaps.apply_buffer_keymaps(state.bufnr, ctx)
      ctx.window.close_window(ctx)
    end)
    return
  end

  ctx.window.close_window(ctx)
end

function M.toggle(ctx)
  if state_module.is_valid_win(state_module.state.winid) then
    M.close(ctx)
    return
  end

  M.open(ctx)
end

function M.callback_map(ctx)
  return {
    select = function()
      M.select_mouse(ctx)
    end,
    move_down = function()
      M.move_cursor(ctx, 1)
    end,
    move_up = function()
      M.move_cursor(ctx, -1)
    end,
    move_top = function()
      M.move_to_top(ctx)
    end,
    move_bottom = function()
      M.move_to_bottom(ctx)
    end,
    open = function()
      M.open_selected(ctx)
    end,
    open_mouse = function()
      M.open_mouse(ctx)
    end,
    collapse_or_parent = function()
      M.collapse_or_parent(ctx)
    end,
    edit_buffer = function()
      M.edit_buffer(ctx)
    end,
    create_file = function()
      M.create_file(ctx)
    end,
    create_dir = function()
      M.create_dir(ctx)
    end,
    rename = function()
      M.rename_selected(ctx)
    end,
    move = function()
      M.move_selected(ctx)
    end,
    copy = function()
      M.copy_selected(ctx)
    end,
    copy_absolute_path = function()
      M.copy_absolute_path(ctx)
    end,
    paste = function()
      M.paste_clipboard(ctx)
    end,
    cut = function()
      M.cut_selected(ctx)
    end,
    delete = function()
      M.delete_selected(ctx)
    end,
    filter = function()
      M.filter(ctx)
    end,
    refresh = function()
      M.refresh(ctx)
    end,
    reveal_current = function()
      M.reveal_current_file(ctx)
    end,
    toggle_ignored = function()
      M.toggle_ignored(ctx)
    end,
    show_help = function()
      M.show_help(ctx)
    end,
    close = function()
      M.close(ctx)
    end,
  }
end

return M
