local M = {}

local defaults = {
  file_edit_mode = "prompt",
  window = {
    side = "left",
    width = 32,
  },
  root = {
    strategy = "cwd",
  },
  tree = {
    show_arrows = true,
    show_hidden = false,
    hidden_files = {},
  },
  follow_current_file = {
    enabled = true,
    focus = false,
  },
  icons = {
    enabled = true,
    provider = "nvim-web-devicons",
  },
  git = {
    enabled = true,
    show_ignored = true,
    refresh_interval_ms = 1500,
  },
  keymaps = {
    select = { "<LeftMouse>" },
    move_down = { "j" },
    move_up = { "k" },
    move_top = { "gg" },
    move_bottom = { "G" },
    open = { "<CR>", "o", "l" },
    open_mouse = { "<2-LeftMouse>" },
    collapse_or_parent = { "h" },
    edit_buffer = { "e" },
    create_file = { "a" },
    create_dir = { "A" },
    rename = { "r" },
    move = { "m" },
    copy = { "y" },
    copy_absolute_path = { "Y" },
    paste = { "p" },
    cut = { "c" },
    delete = { "d" },
    filter = { "f" },
    refresh = { "R" },
    reveal_current = { "." },
    toggle_ignored = { "H" },
    show_help = { "?" },
    close = { "q" },
  },
}

local function normalize_mapping_list(value)
  if value == false then
    return false
  end

  if type(value) == "string" then
    return { value }
  end

  if type(value) ~= "table" then
    return nil
  end

  local mappings = {}

  for _, lhs in ipairs(value) do
    if type(lhs) == "string" and lhs ~= "" then
      table.insert(mappings, lhs)
    end
  end

  return mappings
end

local function normalize_string_list(value)
  if type(value) == "string" then
    return value ~= "" and { value } or {}
  end

  if type(value) ~= "table" then
    return nil
  end

  local values = {}

  for _, item in ipairs(value) do
    if type(item) == "string" and item ~= "" then
      values[#values + 1] = item
    end
  end

  return values
end

function M.defaults()
  return vim.deepcopy(defaults)
end

function M.merge(opts)
  local merged = vim.tbl_deep_extend("force", M.defaults(), opts or {})
  local default_keymaps = M.defaults().keymaps
  local user_keymaps = opts and opts.keymaps or {}

  merged.keymaps = vim.deepcopy(default_keymaps)

  for action, value in pairs(user_keymaps) do
    local normalized = normalize_mapping_list(value)

    if normalized == false then
      merged.keymaps[action] = false
    elseif normalized ~= nil then
      merged.keymaps[action] = normalized
    end
  end

  local user_tree = opts and opts.tree or nil
  local user_hidden_files = user_tree and user_tree.hidden_files or nil
  if user_hidden_files == nil then
    user_hidden_files = user_tree and user_tree.hidden_directories or nil
  end

  local normalized_hidden_files = normalize_string_list(user_hidden_files)
  if normalized_hidden_files ~= nil then
    merged.tree.hidden_files = normalized_hidden_files
  end

  return merged
end

return M
