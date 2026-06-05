local state_module = require("sapling.explorer.state")

local M = {}

local action_callbacks = {}

function M.set_action_callbacks(callbacks)
  action_callbacks = callbacks or {}
end

function M.clear_buffer_keymaps(bufnr)
  local state = state_module.state
  local known_actions = vim.tbl_extend("force", vim.deepcopy(state_module.default_keymaps), state.config.keymaps)

  for _, mappings in pairs(known_actions) do
    if mappings and type(mappings) == "table" then
      for _, lhs in ipairs(mappings) do
        pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
      end
    end
  end

  for _, lhs in ipairs({ "i", "I", "gI", "<Insert>" }) do
    pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
  end

  pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
  pcall(vim.keymap.del, "i", "<Esc>", { buffer = bufnr })
end

function M.apply_buffer_keymaps(bufnr, ctx)
  local state = state_module.state

  M.clear_buffer_keymaps(bufnr)

  if state.edit.active then
    local open_mappings = state.config.keymaps.open
    if open_mappings and type(open_mappings) == "table" then
      for _, lhs in ipairs(open_mappings) do
        if lhs == "<CR>" then
          vim.keymap.set("n", lhs, function()
            if not ctx.edit.expand_directory_in_edit_mode(ctx) then
              state_module.notify("Press Enter on a directory to expand it in edit mode", vim.log.levels.WARN)
            end
          end, {
            buffer = bufnr,
            nowait = true,
            noremap = true,
            silent = true,
            desc = "sapling: expand directory in edit mode",
          })
        end
      end
    end

    vim.keymap.set({ "n", "i" }, "<Esc>", function()
      ctx.edit.cancel_edit_session(ctx)
    end, {
      buffer = bufnr,
      nowait = true,
      noremap = true,
      silent = true,
      desc = "sapling: cancel edit mode",
    })

    return
  end

  local mapping_options = {
    buffer = bufnr,
    nowait = true,
    noremap = true,
    silent = true,
  }

  if state.filter.active then
    for _, lhs in ipairs({ "i", "I", "gI", "<Insert>" }) do
      vim.keymap.set("n", lhs, function()
        ctx.filter.focus(ctx)
      end, vim.tbl_extend("force", mapping_options, {
        desc = "sapling: focus filter",
      }))
    end

    vim.keymap.set("n", "<Esc>", function()
      ctx.filter.clear(ctx)
    end, vim.tbl_extend("force", mapping_options, {
      desc = "sapling: clear filter",
    }))
  end

  for action, callback in pairs(action_callbacks) do
    local mappings = state.config.keymaps[action]

    if mappings and type(mappings) == "table" then
      for _, lhs in ipairs(mappings) do
        vim.keymap.set("n", lhs, callback, vim.tbl_extend("force", mapping_options, {
          desc = ("sapling: %s"):format(action:gsub("_", " ")),
        }))
      end
    end
  end
end

return M
