local config_module = require("sapling.config")
local fs = require("sapling.fs")

local M = {}

M.namespace = vim.api.nvim_create_namespace("sapling")
M.diagnostics_namespace = vim.api.nvim_create_namespace("sapling.edit")
M.edit_padding_text = "  "
M.header_lines = 1

M.state = {
  config = config_module.defaults(),
  root = nil,
  bufnr = nil,
  winid = nil,
  refresh_timer = nil,
  prompt = nil,
  help_bufnr = nil,
  help_winid = nil,
  entries = {},
  current_selection_path = nil,
  current_file_path = nil,
  clipboard = nil,
  expanded_paths = {},
  last_file_window = nil,
  augroup = nil,
  filter = {
    query = "",
    active = false,
    focused = false,
    bufnr = nil,
    winid = nil,
    saved_expanded_paths = nil,
    index = nil,
    index_root = nil,
    index_dirty = true,
    running = false,
    token = 0,
    backend = "lua",
  },
  edit = {
    active = false,
    pending_reload = false,
    saving = false,
    snapshot_entries = {},
    snapshot_lines = {},
  },
  git = {
    exact = {},
    exact_counts = {},
    aggregate = {},
    aggregate_counts = {},
    repo_root = nil,
    root = nil,
    dirty = true,
    running = false,
    token = 0,
  },
}

M.default_keymaps = config_module.defaults().keymaps
M.action_labels = {
  select = "Select entry",
  move_down = "Move down",
  move_up = "Move up",
  move_top = "Move to top",
  move_bottom = "Move to bottom",
  open = "Open / expand",
  open_mouse = "Open / toggle clicked entry",
  collapse_or_parent = "Collapse / parent",
  edit_buffer = "Edit buffer",
  create_file = "Create file",
  create_dir = "Create directory",
  rename = "Rename",
  move = "Move",
  copy = "Copy",
  copy_absolute_path = "Copy absolute path",
  paste = "Paste",
  cut = "Cut",
  delete = "Delete",
  filter = "Filter tree",
  refresh = "Refresh",
  reveal_current = "Reveal current file",
  toggle_ignored = "Toggle ignored / hidden files",
  show_help = "Show help",
  close = "Close explorer",
}

function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "sapling" })
end

function M.is_valid_buf(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr) or false
end

function M.is_valid_win(winid)
  return winid and vim.api.nvim_win_is_valid(winid) or false
end

function M.supports_edit_buffer()
  local mode = M.state.config.file_edit_mode
  return mode == "buffer" or mode == "mixed"
end

function M.uses_buffer_file_ops()
  return M.state.config.file_edit_mode == "buffer"
end

function M.validate_config()
  if M.state.config.file_edit_mode ~= "mixed" then
    return
  end

  if #M.get_action_mappings("edit_buffer") == 0 then
    M.notify(
      "file_edit_mode = 'mixed' needs an edit_buffer keymap or require('sapling').edit_buffer() to enter editable tree mode",
      vim.log.levels.WARN
    )
  end
end

function M.show_directory_arrows()
  return M.state.config.tree.show_arrows ~= false
end

function M.is_hidden_entry_name(name)
  for _, hidden_name in ipairs(M.state.config.tree.hidden_files or {}) do
    if hidden_name == name then
      return true
    end
  end

  return false
end

function M.get_action_mappings(action)
  local mappings = M.state.config.keymaps[action]

  if mappings == false or not mappings then
    return {}
  end

  return mappings
end

function M.get_clipboard_summary()
  if not M.state.clipboard then
    return nil
  end

  local verb = M.state.clipboard.mode == "cut" and "Cut" or "Copy"
  return ("%s: %s"):format(verb, fs.basename(M.state.clipboard.path))
end

function M.tag_buffer(bufnr, kind)
  vim.b[bufnr].sapling = true
  vim.b[bufnr].sapling_kind = kind
end

local function is_buffer_kind(bufnr, kind)
  return M.is_valid_buf(bufnr) and vim.b[bufnr].sapling == true and vim.b[bufnr].sapling_kind == kind
end

function M.clear_edit_diagnostics()
  if M.is_valid_buf(M.state.bufnr) then
    vim.diagnostic.reset(M.diagnostics_namespace, M.state.bufnr)
  end
end

function M.force_explorer_normal_mode()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "i" or mode == "ic" or mode == "ix" or mode == "R" or mode == "Rc" or mode == "Rx" then
    pcall(vim.cmd, "stopinsert")
  end
end

function M.stop_refresh_timer()
  if M.state.refresh_timer then
    M.state.refresh_timer:stop()
    M.state.refresh_timer:close()
    M.state.refresh_timer = nil
  end
end

function M.get_header_line_count()
  if M.state.edit.active then
    return M.header_lines
  end

  if M.state.filter.active then
    return M.header_lines + 1
  end

  return M.header_lines
end

function M.get_filter_display_line()
  return ("Filter: %s"):format(M.state.filter.query or "")
end

function M.reset_git_state()
  M.state.git.token = M.state.git.token + 1
  M.state.git.exact = {}
  M.state.git.exact_counts = {}
  M.state.git.aggregate = {}
  M.state.git.aggregate_counts = {}
  M.state.git.repo_root = nil
  M.state.git.root = nil
  M.state.git.dirty = true
  M.state.git.running = false
end

function M.mark_git_dirty()
  M.state.git.dirty = true
end

function M.mark_filter_dirty()
  local filter = M.state.filter
  filter.index_dirty = true
end

function M.reset_edit_state()
  M.state.edit.active = false
  M.state.edit.pending_reload = false
  M.state.edit.saving = false
  M.state.edit.snapshot_entries = {}
  M.state.edit.snapshot_lines = {}
end

function M.normalize_root()
  local root = fs.cwd()

  if not fs.path_equal(root, M.state.root) then
    M.state.root = root
    M.state.expanded_paths = {}
    M.state.current_selection_path = nil
    M.state.current_file_path = nil
    M.reset_git_state()
    M.state.filter.index = nil
    M.state.filter.index_root = nil
    M.state.filter.saved_expanded_paths = nil
    M.mark_filter_dirty()
  end

  return M.state.root
end

function M.is_explorer_buffer(bufnr)
  return is_buffer_kind(bufnr, "explorer")
end

function M.is_popup_buffer(bufnr)
  return is_buffer_kind(bufnr, "popup")
end

function M.is_help_buffer(bufnr)
  return is_buffer_kind(bufnr, "help")
end

function M.is_sapling_aux_buffer(bufnr)
  return M.is_popup_buffer(bufnr) or M.is_help_buffer(bufnr)
end

function M.is_floating_win(winid)
  if not M.is_valid_win(winid) then
    return false
  end

  local config = vim.api.nvim_win_get_config(winid)
  return config.relative ~= ""
end

function M.is_normal_file_buffer(bufnr)
  if not M.is_valid_buf(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end

  local stat = fs.stat(name)
  return stat and stat.type == "file" or false
end

function M.get_current_file_path(bufnr)
  if not bufnr then
    if M.is_valid_win(M.state.last_file_window) then
      bufnr = vim.api.nvim_win_get_buf(M.state.last_file_window)
    else
      bufnr = vim.api.nvim_get_current_buf()
    end
  end

  if M.is_explorer_buffer(bufnr) and M.is_valid_win(M.state.last_file_window) then
    bufnr = vim.api.nvim_win_get_buf(M.state.last_file_window)
  end

  if not M.is_normal_file_buffer(bufnr) then
    return nil
  end

  return fs.normalize(vim.api.nvim_buf_get_name(bufnr))
end

function M.set_explorer_modifiable(enabled)
  if not M.is_valid_buf(M.state.bufnr) then
    return
  end

  vim.bo[M.state.bufnr].modifiable = enabled
end

function M.merge_config(opts)
  M.state.config = config_module.merge(opts)
end

return M
