local M = {}

-- Configuration
M.config = {
  width = 40,
  side = 'left', -- 'left' or 'right'
  filetype = 'EditorOffset',
  -- Filetypes to ignore when counting main editor windows
  ignored_filetypes = {
    'neo-tree',
    'NvimTree',
    'Trouble',
    'trouble',
    'qf', -- quickfix
    'help',
    'fugitive',
    'fugitiveblame',
    'git',
    'gitcommit',
    'DiffviewFiles',
    'DiffviewFileHistory',
    'dap-repl',
    'dapui_console',
    'dapui_watches',
    'dapui_stacks',
    'dapui_breakpoints',
    'dapui_scopes',
    'toggleterm',
    'terminal',
    'snacks_terminal',
    'lazy',
    'mason',
    'notify',
    'noice',
    'TelescopePrompt',
    'lspsagafinder',
    'lspsagarename',
    'lspsagacodeaction',
    'Outline',
    'aerial',
    'undotree',
    'diff',
  },
}

-- State
local state = {
  bufnr = nil,
  winid = nil,
  augroup = nil,
  enabled = false, -- Whether the user wants the offset to be shown
  suspended = false, -- Whether the offset is temporarily hidden
}

--- Create the scratch buffer for the offset
local function create_buffer()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].bufhidden = 'hide'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = M.config.filetype
  vim.bo[bufnr].modifiable = false

  state.bufnr = bufnr
  return bufnr
end

--- Set window options for the offset window
local function set_window_options(winid)
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = 'no'
  vim.wo[winid].cursorline = false
  vim.wo[winid].cursorcolumn = false
  vim.wo[winid].foldcolumn = '0'
  vim.wo[winid].spell = false
  vim.wo[winid].list = false
  vim.wo[winid].wrap = false
  vim.wo[winid].winfixwidth = true
  vim.wo[winid].statuscolumn = ''
end

--- Check if a filetype should be ignored when counting main windows
---@param ft string
---@return boolean
local function is_ignored_filetype(ft)
  if ft == M.config.filetype then
    return true
  end
  for _, ignored in ipairs(M.config.ignored_filetypes) do
    if ft == ignored then
      return true
    end
  end
  return false
end

--- Check if NeoTree is currently open
local function is_neotree_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == 'neo-tree' then
      return true
    end
  end
  return false
end

--- Count the number of main horizontal (side-by-side) editor windows
--- Ignores bottom panels, sidebars, and other special windows
---@return number
local function count_main_horizontal_windows()
  local wins = vim.api.nvim_list_wins()
  local main_wins = {}

  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype

    -- Skip ignored filetypes
    if not is_ignored_filetype(ft) then
      local config = vim.api.nvim_win_get_config(win)
      -- Skip floating windows
      if config.relative == '' then
        table.insert(main_wins, win)
      end
    end
  end

  -- Now filter to only count windows that are horizontally arranged (side by side)
  -- We do this by checking if windows share the same row range
  if #main_wins <= 1 then
    return #main_wins
  end

  -- Get the positions of all main windows
  local win_info = {}
  for _, win in ipairs(main_wins) do
    local pos = vim.api.nvim_win_get_position(win)
    local height = vim.api.nvim_win_get_height(win)
    table.insert(win_info, {
      win = win,
      row = pos[1],
      col = pos[2],
      height = height,
      row_end = pos[1] + height,
    })
  end

  -- Find windows that overlap vertically (meaning they are side-by-side horizontally)
  -- Group windows by their vertical overlap
  local horizontal_count = 0
  local counted = {}

  for i, w1 in ipairs(win_info) do
    if not counted[i] then
      local group_count = 1
      counted[i] = true

      for j, w2 in ipairs(win_info) do
        if i ~= j and not counted[j] then
          -- Check if windows overlap vertically (share row space)
          local overlap = math.min(w1.row_end, w2.row_end) - math.max(w1.row, w2.row)
          -- Consider them side-by-side if they overlap by at least 50% of the smaller window's height
          local min_height = math.min(w1.height, w2.height)
          if overlap > min_height * 0.5 then
            group_count = group_count + 1
            counted[j] = true
          end
        end
      end

      -- Track the maximum number of side-by-side windows found
      if group_count > horizontal_count then
        horizontal_count = group_count
      end
    end
  end

  return horizontal_count
end

--- Check if the offset should be suspended (NeoTree open or multiple horizontal windows)
---@return boolean
local function should_suspend()
  if is_neotree_open() then
    return true
  end
  if count_main_horizontal_windows() > 1 then
    return true
  end
  return false
end

--- Update the offset visibility based on current window state
local function update_offset_visibility()
  if not state.enabled then
    return
  end

  local should_hide = should_suspend()

  if should_hide and M.is_open() then
    state.suspended = true
    M.close()
  elseif not should_hide and state.suspended and not M.is_open() then
    state.suspended = false
    M.open()
  end
end

--- Setup autocommands for the offset
local function setup_autocommands()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup('EditorOffset', { clear = true })

  -- Prevent entering the offset window
  vim.api.nvim_create_autocmd('WinEnter', {
    group = state.augroup,
    callback = function()
      if vim.bo.filetype == M.config.filetype then
        -- Move to the next window
        vim.cmd('wincmd p')
        -- If we're still in the offset (no other window), try wincmd w
        if vim.bo.filetype == M.config.filetype then
          vim.cmd('wincmd w')
        end
      end
    end,
  })

  -- Close if it's the last window
  vim.api.nvim_create_autocmd('BufEnter', {
    group = state.augroup,
    callback = function()
      local wins = vim.api.nvim_list_wins()
      if vim.bo.filetype == M.config.filetype and #wins == 1 then
        vim.cmd('quit')
      end
    end,
  })

  -- Handle window close - check if we need to restore offset
  vim.api.nvim_create_autocmd('WinClosed', {
    group = state.augroup,
    callback = function(args)
      local closed_winid = tonumber(args.match)
      if closed_winid == state.winid then
        state.winid = nil
      end

      -- Defer to allow the window to fully close, then check visibility
      vim.defer_fn(function()
        update_offset_visibility()
      end, 10)
    end,
  })

  -- Handle new window creation - check if we need to hide offset
  vim.api.nvim_create_autocmd('WinNew', {
    group = state.augroup,
    callback = function()
      -- Defer to allow the window to be fully configured
      vim.defer_fn(function()
        update_offset_visibility()
      end, 10)
    end,
  })

  -- Handle NeoTree and other special filetypes opening
  vim.api.nvim_create_autocmd('FileType', {
    group = state.augroup,
    pattern = 'neo-tree',
    callback = function()
      vim.defer_fn(function()
        update_offset_visibility()
      end, 10)
    end,
  })

  -- Also check on BufWinEnter for cases where windows are reused
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = state.augroup,
    callback = function()
      vim.defer_fn(function()
        update_offset_visibility()
      end, 10)
    end,
  })
end

--- Check if the offset sidebar is currently open
function M.is_open()
  return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

--- Open the offset sidebar
function M.open()
  if M.is_open() then
    return
  end

  -- Don't open if we should be suspended
  if should_suspend() then
    state.suspended = true
    return
  end

  setup_autocommands()

  local bufnr = create_buffer()

  -- Save current window to return to
  local current_win = vim.api.nvim_get_current_win()

  -- Create the split
  if M.config.side == 'left' then
    vim.cmd('topleft vsplit')
  else
    vim.cmd('botright vsplit')
  end

  -- Get the new window and set buffer
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)
  vim.api.nvim_win_set_width(winid, M.config.width)

  set_window_options(winid)
  state.winid = winid

  -- Return to the original window
  vim.api.nvim_set_current_win(current_win)
end

--- Close the offset sidebar
function M.close()
  if not M.is_open() then
    return
  end

  vim.api.nvim_buf_delete(state.bufnr, { force = true })
  state.winid = nil
end

--- Toggle the offset sidebar
function M.toggle()
  if state.enabled then
    state.enabled = false
    state.suspended = false
    M.close()
  else
    state.enabled = true
    M.open()
  end
end

--- Check if the offset is enabled (user wants it shown)
function M.is_enabled()
  return state.enabled
end

--- Setup with custom configuration
---@param opts table|nil
function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end
  setup_autocommands()
end

-- Initialize autocommands on load
setup_autocommands()

return M
