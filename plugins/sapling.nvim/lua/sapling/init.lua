local explorer = require("sapling.explorer")

local M = {}

function M.setup(opts)
  explorer.setup(opts)
end

function M.toggle()
  explorer.toggle()
end

function M.open()
  explorer.open()
end

function M.refresh()
  explorer.refresh()
end

function M.reveal_current_file()
  explorer.reveal_current_file()
end

function M.toggle_ignored()
  explorer.toggle_ignored()
end

function M.move_to_top()
  explorer.move_to_top()
end

function M.move_to_bottom()
  explorer.move_to_bottom()
end

function M.show_help()
  explorer.show_help()
end

function M.edit_buffer()
  explorer.edit_buffer()
end

function M.filter()
  explorer.filter()
end

function M.copy_absolute_path()
  explorer.copy_absolute_path()
end

return M
