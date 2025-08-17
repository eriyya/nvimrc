local M = {}

local os_uname = vim.loop.os_uname()

M.OS = os_uname.sysname
M.IS_WINDOWS = M.OS:find('Windows') and true or false
M.IS_UNIX = M.OS == 'Linux' or M.OS == 'Darwin'
M.IS_WSL = M.IS_UNIX and os_uname.release:find('Microsoft') and true or false

M.fn = function(f, ...)
  local args = { ... }
  return function(...)
    return f(unpack(args), ...)
  end
end

function M.tbl_some(func, tbl)
  for _, v in ipairs(tbl) do
    if func(v) then
      return true
    end
  end
  return false
end

function M.ternary(cond, a, b)
  if cond then
    return a
  end
  return b
end

M.accept_ai_suggestion = function(fallback)
  local suggestion = require('supermaven-nvim.completion_preview')
  if suggestion.has_suggestion() then
    suggestion.on_accept_suggestion()
  elseif fallback then
    fallback()
  end
end

return M
