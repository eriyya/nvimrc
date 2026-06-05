if vim.g.loaded_sapling then
  return
end

vim.g.loaded_sapling = 1

local commands = {
  SaplingToggle = {
    method = "toggle",
    desc = "Toggle the sapling file explorer",
  },
  SaplingOpen = {
    method = "open",
    desc = "Open the sapling file explorer",
  },
  SaplingReveal = {
    method = "reveal_current_file",
    desc = "Reveal the current file in sapling",
  },
  SaplingRefresh = {
    method = "refresh",
    desc = "Refresh the sapling file explorer",
  },
  SaplingToggleIgnored = {
    method = "toggle_ignored",
    desc = "Toggle gitignored files in sapling",
  },
}

for name, definition in pairs(commands) do
  vim.api.nvim_create_user_command(name, function()
    require("sapling")[definition.method]()
  end, {
    desc = definition.desc,
  })
end
