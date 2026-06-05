local fs = require("sapling.fs")
local state_module = require("sapling.explorer.state")

local M = {}

function M.get_git_status(entry)
  local git_state = state_module.state.git
  local key = fs.path_key(entry.path)
  local exact_status = git_state.exact[key]

  if entry.type == "directory" then
    return exact_status or git_state.aggregate[key]
  end

  return exact_status
end

function M.get_git_change_count(entry)
  local git_state = state_module.state.git

  if entry.type ~= "directory" then
    return nil
  end

  local key = fs.path_key(entry.path)
  return git_state.exact_counts[key] or git_state.aggregate_counts[key]
end

function M.get_git_status_for_path(path, entry_type)
  local git_state = state_module.state.git
  local key = fs.path_key(path)
  local exact_status = git_state.exact[key]

  if entry_type == "directory" then
    return exact_status or git_state.aggregate[key]
  end

  return exact_status
end

function M.should_hide_entry(entry)
  local state = state_module.state

  if state_module.is_hidden_entry_name(entry.name) and not state.config.tree.show_hidden then
    return true
  end

  if not state.config.git.enabled or state.config.git.show_ignored then
    return false
  end

  return state.git.exact[fs.path_key(entry.path)] == "ignored"
end

function M.flatten_tree(root, depth, entries)
  local state = state_module.state
  local children = fs.scandir(root)

  for _, child in ipairs(children) do
    if not M.should_hide_entry(child) then
      local expanded = child.type == "directory" and state.expanded_paths[fs.path_key(child.path)] or false

      table.insert(entries, {
        name = child.name,
        path = child.path,
        type = child.type,
        depth = depth,
        expanded = expanded,
        git_status = M.get_git_status(child),
        git_count = M.get_git_change_count(child),
        is_hidden = state_module.is_hidden_entry_name(child.name),
      })

      if child.type == "directory" and expanded then
        M.flatten_tree(child.path, depth + 1, entries)
      end
    end
  end
end

function M.ensure_visible_path(path)
  local state = state_module.state
  local normalized_root = state_module.normalize_root()
  local normalized_path = fs.normalize(path)

  if not normalized_path or not fs.is_within(normalized_root, normalized_path) then
    return false
  end

  local current = fs.dirname(normalized_path)
  while current and not fs.path_equal(current, normalized_root) do
    state.expanded_paths[fs.path_key(current)] = true
    current = fs.dirname(current)
  end

  state.current_selection_path = normalized_path
  return true
end

function M.refresh_current_file_state(bufnr)
  local state = state_module.state
  local root = state_module.normalize_root()
  local path = state_module.get_current_file_path(bufnr)

  if path and fs.is_within(root, path) then
    state.current_file_path = path
    return path
  end

  state.current_file_path = nil
  return nil
end

function M.find_entry_line(path)
  for index, entry in ipairs(state_module.state.entries) do
    if fs.path_equal(entry.path, path) then
      return index
    end
  end

  return nil
end

function M.get_root_label()
  local root = state_module.normalize_root()
  local name = fs.basename(root)

  if not name or name == "" then
    name = root
  end

  if not name:match("[/\\]$") then
    name = name .. "/"
  end

  return name
end

function M.build_root_header_line(for_edit_mode)
  local label = M.get_root_label()

  if for_edit_mode then
    return label
  end

  local icon = ""
  if state_module.state.config.icons.enabled then
    icon = "󰉋 "
  end

  if state_module.show_directory_arrows() then
    return ("▾ %s%s"):format(icon, label)
  end

  return ("%s%s"):format(icon, label)
end

function M.build_header_lines(root_header_line)
  local headers = {}

  if state_module.state.filter.active and not state_module.state.edit.active then
    headers[#headers + 1] = state_module.get_filter_display_line()
  end

  headers[#headers + 1] = root_header_line
  return headers
end

function M.with_root_header(lines, header_line)
  local padded = M.build_header_lines(header_line)

  for _, line in ipairs(lines) do
    padded[#padded + 1] = line
  end

  return padded
end

function M.get_entry_at_cursor()
  local state = state_module.state

  if not state_module.is_valid_win(state.winid) then
    return nil
  end

  local line = vim.api.nvim_win_get_cursor(state.winid)[1] - state_module.get_header_line_count()
  if line < 1 then
    return nil
  end

  return state.entries[line]
end

function M.select_entry_at_line(line, ctx)
  local state = state_module.state
  local header_lines = state_module.get_header_line_count()

  if not state_module.is_valid_win(state.winid) or #state.entries == 0 or state.edit.active then
    return nil
  end

  if line <= header_lines then
    return nil
  end

  local clamped_line = math.max(1, math.min(#state.entries, line - header_lines))
  local entry = state.entries[clamped_line]

  if not entry then
    return nil
  end

  state.current_selection_path = entry.path
  ctx.render.render(ctx)
  return entry
end

function M.select_entry_from_mouse(ctx)
  local state = state_module.state

  if not state_module.is_valid_win(state.winid) then
    return nil
  end

  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= state.winid then
    return nil
  end

  return M.select_entry_at_line(mouse.line, ctx)
end

function M.sync_current_file(ctx, options)
  local state = state_module.state
  options = options or {}

  local bufnr = options.bufnr
  local path = M.refresh_current_file_state(bufnr)
  local root = state_module.normalize_root()

  if not path or not fs.is_within(root, path) then
    return false
  end

  M.ensure_visible_path(path)

  if state.edit.active then
    state.edit.pending_reload = true
    return true
  end

  if options.render ~= false or state_module.is_valid_win(state.winid) then
    ctx.render.render(ctx)
  end

  return true
end

return M
