local M = {}

-- Configuration
M.config = {
  width = 40,
  side = 'left', -- 'left' or 'right'
  filetype = 'EditorOffset',
}

-- State
local state = {
  bufnr = nil,
  winid = nil,
  augroup = nil,
  enabled = false, -- Whether the user wants the offset to be shown
  suspended = false, -- Whether the offset is temporarily hidden (e.g., NeoTree is open)
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

  -- Handle window close to clean up state and detect NeoTree closing
  vim.api.nvim_create_autocmd('WinClosed', {
    group = state.augroup,
    callback = function(args)
      local closed_winid = tonumber(args.match)
      if closed_winid == state.winid then
        state.winid = nil
      end

      -- Check if NeoTree was closed and we need to restore offset
      -- Defer to allow the window to fully close
      vim.defer_fn(function()
        if state.enabled and state.suspended and not is_neotree_open() then
          state.suspended = false
          M.open()
        end
      end, 10)
    end,
  })

  -- Handle NeoTree opening - suspend editor offset
  vim.api.nvim_create_autocmd('FileType', {
    group = state.augroup,
    pattern = 'neo-tree',
    callback = function()
      if state.enabled and M.is_open() then
        state.suspended = true
        M.close()
      end
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

  -- Don't open if NeoTree is currently open
  if is_neotree_open() then
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

  vim.api.nvim_win_close(state.winid, true)
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
