local M = {}

local DEFAULT_SETTINGS = {
  ---@type string[]
  excluded_lsp = {},
  ---@type string
  copilot_node_path = '',
}

local SETTINGS_FILE_NAME = 'settings.json'

M.get_settings_path = function()
  return vim.fn.stdpath('config') .. '/' .. SETTINGS_FILE_NAME
end

M.init = function()
  local settings = DEFAULT_SETTINGS
  vim.settings = settings

  if vim.fn.filereadable(M.get_settings_path()) == 0 then
    vim.notify('No settings file found, creating one...', vim.log.levels.WARN)

    local json = vim.fn.json_encode(DEFAULT_SETTINGS)
    local write_ok = pcall(vim.fn.writefile, { json }, M.get_settings_path())

    if not write_ok then
      vim.notify('Failed to create settings file', vim.log.levels.ERROR)
      return
    end
  else
    local filepath = M.get_settings_path()
    local read_ok, json = pcall(vim.fn.readfile, filepath)

    if not read_ok then
      vim.notify('Failed to read settings', vim.log.levels.ERROR)
      return
    end

    local decode_ok, read_settings = pcall(vim.fn.json_decode, json)

    if not decode_ok then
      vim.notify('Failed to decode settings', vim.log.levels.ERROR)
      return
    end

    settings = read_settings
  end

  vim.settings = settings
end

M.save = function()
  local json = vim.fn.json_encode(vim.settings)
  local write_ok = pcall(vim.fn.writefile, { json }, M.get_settings_path())

  if not write_ok then
    vim.notify('Failed to save settings', vim.log.levels.ERROR)
    return
  end
end

if not vim.settings then
  vim.settings = {}
end

return M
