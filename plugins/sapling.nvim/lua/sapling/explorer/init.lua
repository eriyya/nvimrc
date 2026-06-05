local state_module = require("sapling.explorer.state")
local keymaps = require("sapling.explorer.keymaps")
local help = require("sapling.explorer.help")
local prompt = require("sapling.explorer.prompt")
local tree = require("sapling.explorer.tree")
local filter = require("sapling.explorer.filter")
local render = require("sapling.explorer.render")
local window = require("sapling.explorer.window")
local edit = require("sapling.explorer.edit")
local actions = require("sapling.explorer.actions")

local M = {}

local ctx = {
  keymaps = keymaps,
  help = help,
  prompt = prompt,
  tree = tree,
  filter = filter,
  render = render,
  window = window,
  edit = edit,
  actions = actions,
}

local function register_action_callbacks()
  keymaps.set_action_callbacks(actions.callback_map(ctx))
end

function M.move_cursor(delta)
  actions.move_cursor(ctx, delta)
end

function M.select_mouse()
  actions.select_mouse(ctx)
end

function M.move_to_top()
  actions.move_to_top(ctx)
end

function M.move_to_bottom()
  actions.move_to_bottom(ctx)
end

function M.show_help()
  actions.show_help(ctx)
end

function M.open_mouse()
  actions.open_mouse(ctx)
end

function M.open_selected()
  actions.open_selected(ctx)
end

function M.collapse_or_parent()
  actions.collapse_or_parent(ctx)
end

function M.edit_buffer()
  actions.edit_buffer(ctx)
end

function M.filter()
  actions.filter(ctx)
end

function M.create_file()
  actions.create_file(ctx)
end

function M.create_dir()
  actions.create_dir(ctx)
end

function M.rename_selected()
  actions.rename_selected(ctx)
end

function M.move_selected()
  actions.move_selected(ctx)
end

function M.copy_selected()
  actions.copy_selected(ctx)
end

function M.cut_selected()
  actions.cut_selected(ctx)
end

function M.copy_absolute_path()
  actions.copy_absolute_path(ctx)
end

function M.paste_clipboard()
  actions.paste_clipboard(ctx)
end

function M.delete_selected()
  actions.delete_selected(ctx)
end

function M.apply_edit_buffer()
  actions.apply_edit_buffer(ctx)
end

function M.refresh()
  actions.refresh(ctx)
end

function M.reveal_current_file()
  actions.reveal_current_file(ctx)
end

function M.toggle_ignored()
  actions.toggle_ignored(ctx)
end

function M.open()
  actions.open(ctx)
end

function M.close()
  actions.close(ctx)
end

function M.toggle()
  actions.toggle(ctx)
end

function M.setup(opts)
  state_module.merge_config(opts)
  state_module.validate_config()
  state_module.reset_git_state()
  state_module.stop_refresh_timer()

  register_action_callbacks()

  if state_module.is_valid_buf(state_module.state.bufnr) then
    keymaps.apply_buffer_keymaps(state_module.state.bufnr, ctx)
  end

  if state_module.state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state_module.state.augroup)
  end

  state_module.state.augroup = vim.api.nvim_create_augroup("SaplingExplorer", { clear = true })

  vim.api.nvim_create_autocmd("WinEnter", {
    group = state_module.state.augroup,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      local bufnr = vim.api.nvim_win_get_buf(winid)

      if state_module.is_explorer_buffer(bufnr) then
        window.configure_window(winid)
        return
      end

      if state_module.is_sapling_aux_buffer(bufnr) or state_module.is_floating_win(winid) then
        return
      end

      state_module.state.last_file_window = winid
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = state_module.state.augroup,
    callback = function(args)
      if state_module.is_explorer_buffer(args.buf) or state_module.is_sapling_aux_buffer(args.buf) then
        return
      end

      vim.schedule(function()
        tree.refresh_current_file_state(args.buf)

        if state_module.state.edit.active then
          state_module.state.edit.pending_reload = true
          return
        end

        if not state_module.state.config.follow_current_file.enabled then
          if state_module.is_valid_buf(state_module.state.bufnr) then
            render.render(ctx)
          end
          return
        end

        tree.sync_current_file(ctx, { bufnr = args.buf, render = true })
      end)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = state_module.state.augroup,
    callback = function(args)
      if state_module.is_explorer_buffer(args.buf) then
        return
      end

      state_module.mark_git_dirty()

      if state_module.state.edit.active then
        state_module.state.edit.pending_reload = true
        return
      end

      if state_module.is_valid_buf(state_module.state.bufnr) then
        render.render(ctx)
      end
    end,
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = state_module.state.augroup,
    callback = function()
      state_module.normalize_root()

      if state_module.state.edit.active then
        state_module.state.edit.pending_reload = true
        return
      end

      if state_module.is_valid_win(state_module.state.winid) then
        render.render(ctx)
      end
    end,
  })
end

M.setup({})

return M
