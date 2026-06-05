local Job = require("plenary.job")
local fs = require("sapling.fs")
local state_module = require("sapling.explorer.state")

local M = {}

local FILTER_PREFIX = "Filter: "

local function normalize_text(text)
  return (text or ""):gsub("\\", "/"):lower()
end

local function finish(callback, ...)
  local args = { ... }
  vim.schedule(function()
    callback(unpack(args))
  end)
end

local function fuzzy_match(candidate, query)
  if query == "" then
    return true
  end

  local query_index = 1
  for index = 1, #candidate do
    if candidate:sub(index, index) == query:sub(query_index, query_index) then
      query_index = query_index + 1
      if query_index > #query then
        return true
      end
    end
  end

  return false
end

local function new_index(root)
  return {
    root = root,
    nodes = {},
    root_children = {},
    root_child_set = {},
  }
end

local function ensure_child(child_list, child_set, relative)
  if child_set[relative] then
    return
  end

  child_set[relative] = true
  child_list[#child_list + 1] = relative
end

local function ensure_node(index, relative, entry_type)
  local node = index.nodes[relative]
  if node then
    if entry_type == "directory" then
      node.type = "directory"
    end
    return node
  end

  local name = relative:match("([^/]+)$") or relative
  local parent_relative = relative:match("^(.*)/[^/]+$") or ""
  local path = fs.join(index.root, relative)
  node = {
    name = name,
    path = path,
    relative = relative,
    search_text = normalize_text(relative),
    type = entry_type,
    parent_relative = parent_relative ~= "" and parent_relative or nil,
    children = {},
    child_set = {},
  }
  index.nodes[relative] = node

  if parent_relative == "" then
    ensure_child(index.root_children, index.root_child_set, relative)
  else
    local parent = ensure_node(index, parent_relative, "directory")
    ensure_child(parent.children, parent.child_set, relative)
  end

  return node
end

local function add_index_entry(index, relative, entry_type)
  if not relative or relative == "" then
    return
  end

  local normalized = relative:gsub("\\", "/")
  if entry_type == "directory" and normalized:sub(-1) == "/" then
    normalized = normalized:sub(1, -2)
  end

  local segments = vim.split(normalized, "/", { plain = true, trimempty = true })
  local current = ""

  for segment_index, segment in ipairs(segments) do
    current = current == "" and segment or (current .. "/" .. segment)
    ensure_node(index, current, segment_index == #segments and entry_type or "directory")
  end
end

local function sort_children(index)
  local function compare(left_relative, right_relative)
    local left = index.nodes[left_relative]
    local right = index.nodes[right_relative]

    if left.type ~= right.type then
      return left.type == "directory"
    end

    return left.name:lower() < right.name:lower()
  end

  table.sort(index.root_children, compare)
  for _, node in pairs(index.nodes) do
    table.sort(node.children, compare)
  end
end

local function build_index_from_lines(root, lines)
  local index = new_index(root)

  for _, line in ipairs(lines) do
    if line ~= "" then
      local entry_type = line:sub(-1) == "/" and "directory" or "file"
      add_index_entry(index, line, entry_type)
    end
  end

  sort_children(index)
  return index
end

local function collect_index_with_lua(root)
  local index = new_index(root)

  local function walk(path, relative_prefix)
    for _, child in ipairs(fs.scandir(path)) do
      local relative = relative_prefix ~= "" and (relative_prefix .. "/" .. child.name) or child.name
      add_index_entry(index, relative, child.type)

      if child.type == "directory" then
        walk(child.path, relative)
      end
    end
  end

  walk(root, "")
  sort_children(index)
  return index
end

local function start_fd_job(root, callback)
  local ok = pcall(function()
    Job:new({
      command = "fd",
      cwd = root,
      args = {
        ".",
        "--type",
        "file",
        "--type",
        "directory",
        "--hidden",
        "--no-ignore",
        "--path-separator",
        "/",
      },
      on_exit = function(job, code)
        finish(callback, code, job:result())
      end,
    }):start()
  end)

  if not ok then
    finish(callback, 1, {})
  end
end

local function restore_focus_to_explorer()
  local state = state_module.state
  if state_module.is_valid_win(state.winid) and vim.api.nvim_get_current_win() == state.filter.winid then
    pcall(vim.api.nvim_set_current_win, state.winid)
  end
end

local function close_input_window()
  local filter = state_module.state.filter

  filter.focused = false
  restore_focus_to_explorer()
  state_module.force_explorer_normal_mode()

  if state_module.is_valid_win(filter.winid) then
    pcall(vim.api.nvim_win_close, filter.winid, true)
  end

  if filter.bufnr and not state_module.is_valid_buf(filter.bufnr) then
    filter.bufnr = nil
  end

  if filter.winid and not state_module.is_valid_win(filter.winid) then
    filter.winid = nil
  end
end

local function refresh_explorer_keymaps(ctx)
  local state = state_module.state
  if ctx and state_module.is_valid_buf(state.bufnr) then
    ctx.keymaps.apply_buffer_keymaps(state.bufnr, ctx)
  end
end

local function write_filter_query_from_buffer(ctx)
  local state = state_module.state
  local filter = state.filter

  if not state_module.is_valid_buf(filter.bufnr) then
    return
  end

  local line = vim.api.nvim_buf_get_lines(filter.bufnr, 0, 1, false)[1] or ""
  if filter.query == line then
    return
  end

  filter.query = line
  ctx.render.render(ctx)
end

local function configure_filter_window(winid)
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].foldcolumn = "0"
  vim.wo[winid].statusline = ""
  vim.wo[winid].statuscolumn = ""
  vim.wo[winid].wrap = false
  vim.wo[winid].cursorline = false
end

local function filter_input_width()
  local state = state_module.state
  local width = state_module.is_valid_win(state.winid) and vim.api.nvim_win_get_width(state.winid) or state.config.window.width
  return math.max(1, width - #FILTER_PREFIX)
end

local function ensure_input_window(ctx)
  local state = state_module.state
  local filter = state.filter

  if not filter.active or not state_module.is_valid_win(state.winid) then
    return
  end

  if state_module.is_valid_win(filter.winid) and state_module.is_valid_buf(filter.bufnr) then
    vim.api.nvim_win_set_config(filter.winid, {
      relative = "win",
      win = state.winid,
      row = 0,
      col = #FILTER_PREFIX,
      width = filter_input_width(),
      height = 1,
    })
    vim.api.nvim_set_current_win(filter.winid)
    vim.api.nvim_win_set_cursor(filter.winid, { 1, #filter.query })
    configure_filter_window(filter.winid)
    filter.focused = true
    vim.cmd("noautocmd startinsert!")
    return
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  filter.bufnr = bufnr

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].filetype = "sapling"
  state_module.tag_buffer(bufnr, "popup")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { filter.query })

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "win",
    win = state.winid,
    row = 0,
    col = #FILTER_PREFIX,
    width = filter_input_width(),
    height = 1,
    style = "minimal",
    border = "none",
    focusable = true,
    noautocmd = true,
  })

  filter.winid = winid
  filter.focused = true
  configure_filter_window(winid)
  vim.api.nvim_win_set_cursor(winid, { 1, #filter.query })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    callback = function()
      if filter.bufnr == bufnr then
        filter.bufnr = nil
      end
      if filter.winid and not state_module.is_valid_win(filter.winid) then
        filter.winid = nil
      end
      filter.focused = false
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      write_filter_query_from_buffer(ctx)
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      if filter.focused and vim.api.nvim_get_current_buf() ~= bufnr then
        close_input_window()
      end
    end,
    once = true,
  })

  local exit_to_tree = function()
    if filter.query == "" then
      M.clear(ctx)
      return
    end

    close_input_window()
  end

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = bufnr,
    callback = function()
      if not filter.focused or vim.api.nvim_get_current_buf() ~= bufnr then
        return
      end

      vim.schedule(function()
        if filter.focused and state_module.is_valid_buf(bufnr) and vim.api.nvim_get_current_buf() == bufnr then
          exit_to_tree()
        end
      end)
    end,
  })

  vim.keymap.set({ "i", "n" }, "<CR>", exit_to_tree, {
    buffer = bufnr,
    noremap = true,
    silent = true,
  })

  vim.keymap.set({ "i", "n" }, "<Esc>", function()
    M.clear(ctx)
  end, {
    buffer = bufnr,
    noremap = true,
    silent = true,
  })

  vim.cmd("noautocmd startinsert!")
end

function M.get_prefix()
  return FILTER_PREFIX
end

function M.is_active()
  return state_module.state.filter.active
end

function M.has_query()
  return state_module.state.filter.query ~= ""
end

function M.reset_index()
  local filter = state_module.state.filter
  filter.index = nil
  filter.index_root = nil
  filter.index_dirty = true
  filter.running = false
  filter.backend = "lua"
end

function M.request_index(ctx)
  local state = state_module.state
  local filter = state.filter
  local root = state_module.normalize_root()

  if filter.running then
    return
  end

  if filter.index and filter.index_root and fs.path_equal(filter.index_root, root) and not filter.index_dirty then
    return
  end

  filter.index_dirty = false
  filter.index_root = root
  filter.token = filter.token + 1
  local token = filter.token

  if vim.fn.executable("fd") ~= 1 then
    filter.running = false
    filter.index = collect_index_with_lua(root)
    filter.backend = "lua"
    return
  end

  filter.running = true
  start_fd_job(root, function(code, result)
    if token ~= filter.token then
      return
    end

    filter.running = false

    if code == 0 then
      filter.index = build_index_from_lines(root, result)
      filter.backend = "fd"
    else
      filter.index = collect_index_with_lua(root)
      filter.backend = "lua"
    end

    if state.edit.active then
      state.edit.pending_reload = true
      return
    end

    if state_module.is_valid_buf(state.bufnr) then
      ctx.render.render(ctx)
    end
  end)
end

function M.sync_input_window(ctx)
  local filter = state_module.state.filter
  if not filter.focused then
    return
  end

  if not state_module.is_valid_win(state_module.state.winid) then
    close_input_window()
    return
  end

  ensure_input_window(ctx)
end

function M.focus(ctx)
  local state = state_module.state
  local filter = state.filter

  if state.edit.active then
    state_module.notify("Filter is unavailable while editing the tree buffer", vim.log.levels.WARN)
    return
  end

  if not filter.active then
    filter.active = true
    filter.saved_expanded_paths = vim.deepcopy(state.expanded_paths)
    refresh_explorer_keymaps(ctx)
    ctx.render.render(ctx)
  end

  M.request_index(ctx)
  ensure_input_window(ctx)
end

function M.clear(ctx)
  local state = state_module.state
  local filter = state.filter

  close_input_window()

  filter.query = ""
  filter.active = false
  filter.focused = false

  if filter.saved_expanded_paths then
    state.expanded_paths = filter.saved_expanded_paths
  end
  filter.saved_expanded_paths = nil
  refresh_explorer_keymaps(ctx)

  if state_module.is_valid_buf(state.bufnr) and state_module.is_valid_win(state.winid) then
    ctx.render.render(ctx)
  end
end

function M.reset(ctx)
  local filter = state_module.state.filter

  close_input_window()

  filter.query = ""
  filter.active = false
  filter.focused = false
  filter.saved_expanded_paths = nil
  refresh_explorer_keymaps(ctx)

  if ctx and state_module.is_valid_buf(state_module.state.bufnr) and state_module.is_valid_win(state_module.state.winid) then
    ctx.render.render(ctx)
  end
end

function M.build_filtered_entries(ctx)
  local state = state_module.state
  local filter = state.filter

  if not filter.active or filter.query == "" then
    return nil, nil
  end

  if not filter.index then
    return {}, "[filtering...]"
  end

  local include = {}
  local query = normalize_text(filter.query)
  local matched = false

  for relative, node in pairs(filter.index.nodes) do
    if not ctx.tree.should_hide_entry(node) and fuzzy_match(node.search_text, query) then
      matched = true

      local current = relative
      while current do
        include[current] = true
        local parent = filter.index.nodes[current]
        current = parent and parent.parent_relative or nil
      end
    end
  end

  if not matched then
    return {}, "[no matches]"
  end

  local function append_entries(relative_paths, depth, entries)
    local produced = false

    for _, relative in ipairs(relative_paths) do
      local node = filter.index.nodes[relative]
      if node and include[relative] and not ctx.tree.should_hide_entry(node) then
        local child_entries = {}
        local has_children = false

        if node.type == "directory" then
          has_children = append_entries(node.children, depth + 1, child_entries)
        end

        entries[#entries + 1] = {
          name = node.name,
          path = node.path,
          type = node.type,
          depth = depth,
          expanded = node.type == "directory" and has_children or false,
          git_status = ctx.tree.get_git_status_for_path(node.path, node.type),
          git_count = ctx.tree.get_git_change_count(node),
          is_hidden = state_module.is_hidden_entry_name(node.name),
        }

        for _, child_entry in ipairs(child_entries) do
          entries[#entries + 1] = child_entry
        end

        produced = true
      end
    end

    return produced
  end

  local entries = {}
  append_entries(filter.index.root_children, 0, entries)
  return entries, #entries == 0 and "[no matches]" or nil
end

return M
