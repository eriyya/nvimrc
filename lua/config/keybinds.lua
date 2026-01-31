local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local util = require('util')
local fn = util.fn

local key = function(mode, keys, func, desc, opts)
  opts = opts or { silent = true, vscode = true }
  if not opts.vscode and vim.g.vscode then
    return
  end
  vim.keymap.set(mode, keys, func, { desc = desc, silent = opts.silent })
end

--------------------------
------ Insert Mode -------
--------------------------

key('i', 'kj', '<Esc>', 'Leave insert mode')
key('i', 'jk', '<Esc>', 'Leave insert mode')

-------------------------
------ Normal Mode ------
-------------------------

key('n', '<leader>fc', function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, win_conf = pcall(vim.api.nvim_win_get_config, win)
    if ok and win_conf.relative ~= '' then
      vim.api.nvim_win_close(win, true)
    end
  end
end, 'Close all floating windows', { vscode = false })

key('n', '<Space>', '<Nop>', 'Disable space key')

key('n', '<leader>ud', '<cmd>UndotreeToggle<CR>', 'Toggle UndoTree')

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

key('n', 'H', '^', 'Goto start of line')
key('n', 'L', '$', 'Goto end of line')
key('o', 'H', '^', 'Goto start of line')
key('o', 'L', '$', 'Goto end of line')

key('n', '<C-h>', ':nohlsearch<CR>', 'Remove highlight')
key('n', '<leader>y', '"+y', 'Yank to system clipboard')
key('n', '<leader>w', ':w<CR>', 'Save file')

key('n', '<A-j>', "<cmd>execute 'move .+' . v:count1<cr>==", 'Move Down')
key('n', '<A-k>', "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", 'Move Up')
key('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', 'Move Down')
key('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', 'Move Up')
key('v', '<A-j>', ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", 'Move Down')
key('v', '<A-k>', ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", 'Move Up')

-- Increment/Decrement numbers
key('n', '<C-z>', '<C-a>', 'Increment number under cursor')
-- key('n', '<C-x>', '<C-x>', 'Decrement number under cursor')

-- Trouble
key('n', '<leader>td', ':TodoTrouble<CR>', 'Show Trouble todo list')
key('n', '<leader>tt', ':Trouble diagnostics toggle win.relative=win<CR>', 'Show Trouble diagnostic list')

-- NeoTree
key('n', '<C-n>', '<cmd>Neotree toggle<CR>', 'Toggle NeoTree')

-- Fuzzy find files
key('n', '<leader>/', function()
  local telescope = require('telescope.builtin')
  local telescope_themes = require('telescope.themes')
  telescope.current_buffer_fuzzy_find(telescope_themes.get_dropdown({
    previewer = false,
  }))
end, 'Fuzzy find in current buffer', { vscode = false })

-- AI accept inline suggestion
key('i', '<C-l>', function()
  -- Supermaven
  -- local suggestion = require('supermaven-nvim.completion_preview')
  -- if suggestion.has_suggestion() then
  --   suggestion.on_accept_suggestion()
  -- end

  -- Copilot
  local suggestion = require('copilot.suggestion')
  if suggestion.is_visible() then
    suggestion.accept()
  end
end, 'Accept AI suggestions', { vscode = false })

-- Editor Offset
key('n', '<leader>eo', function()
  require('custom.editor-offset').toggle()
end, 'Toggle editor offset sidebar', { vscode = false })

-- Lazygit
key('n', '<leader>G', function()
  require('snacks.lazygit').open()
end, 'Toggle Lazygit', { vscode = false })

-- Telescope
-- key('n', '<C-p>', '<cmd>Telescope find_files<CR>', 'Find files', { vscode = false })
key('n', '<C-p>', function()
  require('snacks').picker.files()
end, 'Find files', { vscode = false })
-- key('n', '<C-b>', '<cmd>Telescope buffers<CR>', 'Find buffers', { vscode = false })
key('n', '<C-b>', function()
  require('snacks').picker.buffers()
end, 'Find buffers', { vscode = false })

-- Tabs
key('n', '<leader>1', '<cmd>BufferGoto 1<CR>', 'Go to tab 1')
key('n', '<leader>2', '<cmd>BufferGoto 2<CR>', 'Go to tab 2')
key('n', '<leader>3', '<cmd>BufferGoto 3<CR>', 'Go to tab 3')
key('n', '<leader>4', '<cmd>BufferGoto 4<CR>', 'Go to tab 4')
key('n', '<leader>5', '<cmd>BufferGoto 5<CR>', 'Go to tab 5')
key('n', '<leader>6', '<cmd>BufferGoto 6<CR>', 'Go to tab 6')
key('n', '<leader>7', '<cmd>BufferGoto 7<CR>', 'Go to tab 7')
key('n', '<leader>8', '<cmd>BufferGoto 8<CR>', 'Go to tab 8')
key('n', '<leader>9', '<cmd>BufferGoto 9<CR>', 'Go to tab 9')
key('n', '<leader>0', '<cmd>BufferLast<CR>', 'Go to last tab')

key('n', '<leader>b,', '<cmd>BufferPrevious<CR>', 'Go to previous tab')
key('n', '<leader>b.', '<cmd>BufferNext<CR>', 'Go to next tab')

key('n', '<leader>b<', '<cmd>BufferMovePrevious<CR>', 'Move tab left')
key('n', '<leader>b>', '<cmd>BufferMoveNext<CR>', 'Move tab right')

key('n', '<leader>bc', '<cmd>BufferClose<CR>', 'Close current tab')
key('n', '<leader>bp', '<cmd>BufferPick<CR>', 'Pick a tab to go to')

key('v', '<leader>f', '=', 'Vim format (when no LSP)')
key('v', 'H', '^', 'Goto start of line (VISUAL MODE)')
key('v', 'L', '$', 'Goto end of line (VISUAL MODE)')
key('v', '<leader>y', '"+y', 'Yank selection to system clipboard (VISUAL MODE)')
key('v', '<A-j>', ":move '>+1<CR>gv=gv", 'Move selection down')
key('v', '<A-k>', ":move '<-2<CR>gv=gv", 'Move selection up')
key('v', '<C-k>', '<Esc>', 'Leave visual mode')

------------------
----- Snacks -----
------------------

key('n', '<leader>bd', function()
  require('snacks').bufdelete()
end, '[Snacks] Delete Buffer', { vscode = false })
key('n', '<leader>gb', function()
  require('snacks').git.blame_line()
end, '[Snacks] Git Blame Line', { vscode = false })
key({ 'n', 't' }, '<leader>;', function()
  require('snacks').terminal()
end, '[Snacks] Toggle Terminal', { vscode = false })
key('n', '<leader>mh', function()
  require('snacks').notifier.show_history()
end, '[Snacks] Show Notification History', { vscode = false })

key('n', '<leader>if', '<cmd>InlineFoldToggle<CR>', 'Toggle CSS class inline fold', { vscode = false })

-- Live Grep
key('n', '<leader>rg', function()
  -- local telescope = require('telescope.builtin')
  -- telescope.live_grep({
  --   prompt_title = 'Live Grep',
  -- })
  require('snacks').picker.grep({ cmd = 'rg' })
end, 'Live Grep', { vscode = false })
-----------------
----- Neorg -----
-----------------
key('n', '<leader>no', '<cmd>NeorgWorkspace<CR>', 'Open Neorg workspace picker', { vscode = false })

--------------------------
------     LSP     -------
--------------------------

key('n', 'K', function()
  vim.lsp.buf.hover({ border = 'rounded' })
end, '[LSP] Show hover docs', { vscode = false })

autocmd('LspAttach', {
  group = augroup('UserLspConfig', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    -- Use centralized format function (handles Conform + ESLint fix-all)
    key('n', '<leader>f', function()
      require('lsp.util.format').format()
    end, '[LSP] Format document')

    -- Navigation
    local snacks = require('snacks')
    -- key('n', 'gd', '<cmd>Telescope lsp_definitions<CR>', '[LSP] Goto Definition')
    key('n', 'gd', function()
      snacks.picker.lsp_definitions()
    end, '[LSP] Goto Definition')

    -- key('n', 'gD', vim.lsp.buf.declaration, '[LSP] Goto Declaration')
    key('n', 'gD', function()
      snacks.picker.lsp_declarations()
    end, '[LSP] Goto Declaration')

    -- key('n', 'gr', ':Lspsaga finder ref<CR>', '[LSP] Find references')
    key('n', 'gr', function()
      snacks.picker.lsp_references()
    end, '[LSP] Find references')

    -- key('n', 'gI', '<cmd>Telescope lsp_implementations<CR>', '[LSP] Goto Implementation')
    key('n', 'gI', function()
      snacks.picker.lsp_implementations()
    end, '[LSP] Goto Implementation')

    -- key('n', '<leader>D', '<cmd>Telescope lsp_type_definitions<CR>', '[LSP] Goto Type Definition')
    key('n', '<leader>D', function()
      snacks.picker.lsp_type_definitions()
    end, '[LSP] Goto Type Definition')

    -- Symbols
    -- key('n', '<C-s>', '<cmd>Telescope lsp_document_symbols<CR>', '[LSP] Document Symbols')
    key('n', '<C-s>', function()
      snacks.picker.lsp_symbols({ filter = { default = true } })
    end, '[LSP] Document Symbols')

    key('n', '<leader>ws', '<cmd>Telescope lsp_dynamic_workspace_symbols<CR>', '[LSP] Workspace Symbols')

    -- Call hierarchy
    -- key('n', '<leader>ci', '<cmd>Telescope lsp_incoming_calls<CR>', '[LSP] Incoming calls')
    key('n', '<leader>ci', function()
      snacks.picker.lsp_incoming_calls()
    end, '[LSP] Incoming calls')
    -- key('n', '<leader>co', '<cmd>Telescope lsp_outgoing_calls<CR>', '[LSP] Outgoing calls')
    key('n', '<leader>co', function()
      snacks.picker.lsp_outgoing_calls()
    end, '[LSP] Outgoing calls')

    -- Info & actions
    key('n', '<leader>rn', ':Lspsaga rename<CR>', '[LSP] Rename')
    key({ 'n', 'x' }, '<leader>a', ':Lspsaga code_action<CR>', '[LSP] Code Action')
    key({ 'i' }, '<C-k>', vim.lsp.buf.signature_help, '[LSP] Show signature help')
    -- key('n', 'K', '<cmd>Lspsaga hover_doc', '[LSP] Show hover docs')

    -- Diagnostics
    -- key('n', '<leader>e', vim.diagnostic.open_float, '[LSP] Show line diagnostics')
    key('n', '<leader>e', function()
      snacks.picker.diagnostics_buffer()
    end, '[LSP] Show line diagnostics')
    key('n', '[d', fn(vim.diagnostic.jump, { count = -1, float = true }), '[LSP] Goto prev diagnostic')
    key('n', ']d', fn(vim.diagnostic.jump, { count = 1, float = true }), '[LSP] Goto next diagnostic')
    key('n', '<leader>q', '<cmd>Trouble diagnostics toggle<CR>', '[LSP] Toggle diagnostics list')

    -- Codelens
    key('n', '<leader>cl', vim.lsp.codelens.run, '[LSP] Run codelens')

    -- Toggle inlay hints
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      key('n', '<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }))
      end, '[LSP] Toggle Inlay Hints')
    end

    ---------------
    ----- DAP -----
    ---------------

    key('n', '<leader>db', '<cmd>DapToggleBreakpoint<CR>', '[Debugger] Toggle breakpoint')
    key('n', '<leader>dr', '<cmd>DapContinue<CR>', '[Debugger] Continue/Start')
  end,
})
