local M = {}

local os_uname = vim.loop.os_uname()

M.OS = os_uname.sysname
M.IS_WINDOWS = M.OS:find('Windows') and true or false
M.IS_UNIX = M.OS == 'Linux' or M.OS == 'Darwin'
M.IS_WSL = M.IS_UNIX and os_uname.release:find('Microsoft') and true or false

---@param f function
M.fn = function(f, ...)
  local args = { ... }
  return function(...)
    return f(unpack(args), ...)
  end
end

---@param cond function
---@param a boolean
---@param b boolean
function M.ternary(cond, a, b)
  if cond then
    return a
  end
  return b
end

---@param func function
---@param tbl table
M.tbl_some = function(func, tbl)
  for _, v in ipairs(tbl) do
    if func(v) then
      return true
    end
  end
  return false
end

---@param func function
---@param catch? fun(res: unknown)
M.try = function(func, catch)
  local ok, result = pcall(func)
  if not ok and catch then
    return catch(result)
  end
end

return M
