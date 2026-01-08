---@diagnostic disable: undefined-global
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type Snacks.Config
  opts = {
    quickfile = { enabled = true },
    bigfile = { enabled = true },
    git = { enabled = true },
    dashboard = { enabled = false },
    explorer = { enabled = false },
    indent = { enabled = false },
    input = { enabled = true },
    picker = {
      enabled = true,
      actions = {
        confirm_relative = function(picker, item)
          picker:close()
          if item and item.file then
            -- Normalize path to use forward slashes (cross-platform)
            local file = item.file:gsub('\\', '/')
            -- Convert to relative path if within cwd
            local relative = vim.fn.fnamemodify(file, ':.')
            -- Normalize the result as well (fnamemodify may return backslashes on Windows)
            relative = relative:gsub('\\', '/')
            -- Use relative path only if it doesn't start with .. or / (i.e., within cwd)
            local path_to_open = relative
            if vim.startswith(relative, '..') or vim.startswith(relative, '/') then
              path_to_open = file
            end
            vim.cmd('edit ' .. vim.fn.fnameescape(path_to_open))
            if item.pos then
              pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], (item.pos[2] or 1) - 1 })
            end
          end
        end,
      },
      sources = {
        files = { confirm = 'confirm_relative' },
        buffers = { confirm = 'confirm_relative' },
        grep = { confirm = 'confirm_relative' },
        lsp_definitions = { confirm = 'confirm_relative' },
        lsp_declarations = { confirm = 'confirm_relative' },
        lsp_references = { confirm = 'confirm_relative' },
        lsp_implementations = { confirm = 'confirm_relative' },
        lsp_type_definitions = { confirm = 'confirm_relative' },
        lsp_symbols = { confirm = 'confirm_relative' },
        lsp_incoming_calls = { confirm = 'confirm_relative' },
        lsp_outgoing_calls = { confirm = 'confirm_relative' },
        diagnostics = { confirm = 'confirm_relative' },
        diagnostics_buffer = { confirm = 'confirm_relative' },
      },
    },
    notifier = { enabled = true, timeout = 2000 },
    scope = { enabled = false },
    scroll = { enabled = false },
    scratch = { enabled = false },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    image = { enabled = true },
    profiler = { enabled = false },
    lazygit = { enabled = true },
    styles = {
      notification = {
        wo = { wrap = true }, -- Wrap notifications
      },
    },
  },
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print to use snacks for `:=` command
      end,
    })
  end,
}
