local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local util = require('util')
local fn = util.fn

local key = function(mode, keys, func, desc, silent)
  silent = silent or true
  vim.keymap.set(mode, keys, func, { desc = desc, silent = silent })
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
end, 'Close all floating windows')

key('n', '<Space>', '<Nop>', 'Disable space key')

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

-- Editor Offset
key('n', '<leader>eo', function()
  require('custom.editor-offset').toggle()
end, 'Toggle editor offset sidebar')

-- Lazygit
key('n', '<leader>G', require('snacks.lazygit').open, 'Toggle Lazygit')

-- Telescope
key('n', '<C-p>', '<cmd>Telescope find_files<CR>', 'Find files')
key('n', '<C-b>', '<cmd>Telescope buffers<CR>', 'Find buffers')

-- Tabs
key('n', '<A-1>', '<cmd>BufferGoto 1<CR>', 'Go to tab 1')
key('n', '<A-2>', '<cmd>BufferGoto 2<CR>', 'Go to tab 2')
key('n', '<A-3>', '<cmd>BufferGoto 3<CR>', 'Go to tab 3')
key('n', '<A-4>', '<cmd>BufferGoto 4<CR>', 'Go to tab 4')
key('n', '<A-5>', '<cmd>BufferGoto 5<CR>', 'Go to tab 5')
key('n', '<A-6>', '<cmd>BufferGoto 6<CR>', 'Go to tab 6')
key('n', '<A-7>', '<cmd>BufferGoto 7<CR>', 'Go to tab 7')
key('n', '<A-8>', '<cmd>BufferGoto 8<CR>', 'Go to tab 8')
key('n', '<A-9>', '<cmd>BufferGoto 9<CR>', 'Go to tab 9')
key('n', '<A-0>', '<cmd>BufferLast<CR>', 'Go to last tab')

key('n', '<A-,>', '<cmd>BufferPrevious<CR>', 'Go to previous tab')
key('n', '<A-.>', '<cmd>BufferNext<CR>', 'Go to next tab')

key('n', '<A-<>', '<cmd>BufferMovePrevious<CR>', 'Move tab left')
key('n', '<A->>', '<cmd>BufferMoveNext<CR>', 'Move tab right')

key('n', '<A-c>', '<cmd>BufferClose<CR>', 'Close current tab')
key('n', '<A-p>', '<cmd>BufferPick<CR>', 'Pick a tab to go to')

key('v', '<leader>f', '=', 'Vim format (when no LSP)')
key('v', 'H', '^', 'Goto start of line (VISUAL MODE)')
key('v', 'L', '$', 'Goto end of line (VISUAL MODE)')
key('v', '<leader>y', '"+y', 'Yank selection to system clipboard (VISUAL MODE)')
key('v', '<A-j>', ":move '>+1<CR>gv=gv", 'Move selection down')
key('v', '<A-k>', ":move '<-2<CR>gv=gv", 'Move selection up')
key('v', '<C-k>', '<Esc>', 'Leave visual mode')

if not vim.g.vscode then
  key('n', '<leader>if', '<cmd>InlineFoldToggle<CR>', 'Toggle CSS class inline fold')

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
  end, 'Accept AI suggestions')

  -- Fuzzy find files
  key('n', '<leader>/', function()
    local telescope = require('telescope.builtin')
    local telescope_themes = require('telescope.themes')
    telescope.current_buffer_fuzzy_find(telescope_themes.get_dropdown({
      previewer = false,
    }))
  end, 'Fuzzy find in current buffer')

  -- Live Grep
  key('n', '<leader>rg', function()
    local telescope = require('telescope.builtin')
    telescope.live_grep({
      prompt_title = 'Live Grep',
    })
  end, 'Live Grep')
  -----------------
  ----- Neorg -----
  -----------------
  key('n', '<leader>no', '<cmd>NeorgWorkspace<CR>', 'Open Neorg workspace picker')

  ------------------
  ----- Snacks -----
  ------------------
  local snacks = require('snacks')

  key('n', '<leader>bd', function()
    snacks.bufdelete()
  end, '[Snacks] Delete Buffer')
  key('n', '<leader>gb', snacks.git.blame_line, '[Snacks] Git Blame Line')
  key({ 'n', 't' }, '<leader>;', function()
    snacks.terminal()
  end, '[Snacks] Toggle Terminal')

  --------------------------
  ------     LSP     -------
  --------------------------

  key('n', 'K', function()
    vim.lsp.buf.hover({ border = 'rounded' })
  end, '[LSP] Show hover docs')

  autocmd('LspAttach', {
    group = augroup('UserLspConfig', { clear = true }),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)

      -- Use centralized format function (handles Conform + ESLint fix-all)
      key('n', '<leader>f', function()
        require('lsp.util.format').format()
      end, '[LSP] Format document')

      -- Navigation
      key('n', 'gd', '<cmd>Telescope lsp_definitions<CR>', '[LSP] Goto Definition')
      key('n', 'gD', vim.lsp.buf.declaration, '[LSP] Goto Declaration')
      key('n', 'gr', ':Lspsaga finder ref<CR>', '[LSP] Find references')
      key('n', 'gI', '<cmd>Telescope lsp_implementations<CR>', '[LSP] Goto Implementation')
      key('n', '<leader>D', '<cmd>Telescope lsp_type_definitions<CR>', '[LSP] Goto Type Definition')

      -- Symbols
      key('n', '<C-s>', '<cmd>Telescope lsp_document_symbols<CR>', '[LSP] Document Symbols')
      key('n', '<leader>ws', '<cmd>Telescope lsp_dynamic_workspace_symbols<CR>', '[LSP] Workspace Symbols')

      -- Call hierarchy
      key('n', '<leader>ci', '<cmd>Telescope lsp_incoming_calls<CR>', '[LSP] Incoming calls')
      key('n', '<leader>co', '<cmd>Telescope lsp_outgoing_calls<CR>', '[LSP] Outgoing calls')

      -- Info & actions
      key('n', '<leader>rn', ':Lspsaga rename<CR>', '[LSP] Rename')
      key({ 'n', 'x' }, '<leader>a', ':Lspsaga code_action<CR>', '[LSP] Code Action')
      key({ 'i' }, '<C-k>', vim.lsp.buf.signature_help, '[LSP] Show signature help')
      -- key('n', 'K', '<cmd>Lspsaga hover_doc', '[LSP] Show hover docs')

      -- Diagnostics
      key('n', '<leader>e', vim.diagnostic.open_float, '[LSP] Show line diagnostics')
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
end

-- VScode specific keybinds
if vim.g.vscode then
  local vscode = require('vscode')
  key('n', '<leader>f', function()
    vscode.action('editor.action.formatDocument')
  end, '[VScode] Format Document')
end
