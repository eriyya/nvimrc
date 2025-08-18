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

-- Supermaven accept inline suggestion
key('i', '<C-l>', function()
  local suggestion = require('supermaven-nvim.completion_preview')
  if suggestion.has_suggestion() then
    suggestion.on_accept_suggestion()
  end
end, 'Accept AI suggestions')

-------------------------
------ Normal Mode ------
-------------------------

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

-- Trouble
key('n', '<leader>td', ':TodoTrouble<CR>', 'Show Trouble todo list')
key('n', '<leader>tt', ':Trouble diagnostics toggle win.relative=win<CR>', 'Show Trouble diagnostic list')

-- NeoTree
key('n', '<C-n>', '<cmd>Neotree toggle<CR>', 'Toggle NeoTree')

-- Telescope
key('n', '<C-p>', '<cmd>Telescope find_files<CR>', 'Find files')
key('n', '<C-b>', '<cmd>Telescope buffers<CR>', 'Find buffers')

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

--------------------------
------ Visual Mode -------
--------------------------

key('v', '<leader>f', '=', 'Vim format (when no LSP)')
key('v', 'H', '^', 'Goto start of line (VISUAL MODE)')
key('v', 'L', '$', 'Goto end of line (VISUAL MODE)')
key('v', '<leader>y', '"+y', 'Yank selection to system clipboard (VISUAL MODE)')
key('v', '<A-j>', ":move '>+1<CR>gv=gv", 'Move selection down')
key('v', '<A-k>', ":move '<-2<CR>gv=gv", 'Move selection up')
key('v', '<C-k>', '<Esc>', 'Leave visual mode')

--------------------------
-------- Harpoon ---------
--------------------------

local harpoon = require('harpoon')

key('n', '<leader>m', function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, '[Harpoon]: Show mark menu')
key('n', '<leader>h', function()
  harpoon:list():add()
end, '[Harpoon]: Add current file')
key('n', '<leader>J', function()
  harpoon:list():select(1)
end, '[Harpoon]: Goto mark 1')
key('n', '<leader>K', function()
  harpoon:list():select(2)
end, '[Harpoon]: Goto mark 2')
key('n', '<leader>L', function()
  harpoon:list():select(3)
end, '[Harpoon]: Goto mark 3')
key('n', '<leader>H', function()
  harpoon:list():select(4)
end, '[Harpoon]: Goto mark 4')

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

autocmd('LspAttach', {
  group = augroup('UserLspConfig', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    local format = function()
      require('conform').format({
        bufnr = vim.api.nvim_get_current_buf(),
        lsp_format = 'fallback',
        async = false,
        timeout_ms = 3000,
      })

      if client and client.name == 'eslint' then
        vim.cmd('silent LspEslintFixAll')
      end
    end

    key('n', '<leader>f', format, '[LSP] Format document')
    key('n', 'gd', '<cmd>Telescope lsp_definitions<CR>', '[LSP] Goto Definitions')
    key('n', 'gr', ':Lspsaga finder ref<CR>', '[LSP] Find references')
    key('n', 'gI', '<cmd>Telescope lsp_implementations<CR>', '[LSP] Goto Implementations')
    key('n', '<leader>D', '<cmd>Telescope lsp_type_definitions<CR>', '[LSP] Goto Type Definitions')
    key('n', '<C-s>', '<cmd>Telescope lsp_document_symbols<CR>', '[LSP] Document Symbols')
    key('n', '<leader>ws', '<cmd>Telescope lsp_dynamic_workspace_symbols<CR>', '[LSP] Workspace Symbols')
    key('n', 'K', vim.lsp.buf.hover, '[LSP] Show hover docs')
    key('n', '<leader>rn', ':Lspsaga rename<CR>', '[LSP] Rename')
    key({ 'n', 'x' }, '<leader>a', ':Lspsaga code_action<CR>', '[LSP] Code Action')
    key({ 'i' }, '<C-k>', vim.lsp.buf.signature_help, '[LSP] Show signature help')

    key('n', '[d', fn(vim.diagnostic.jump, { count = -1, float = true }), '[LSP] Goto prev diagnostic')
    key('n', ']d', fn(vim.diagnostic.jump, { count = 1, float = true }), '[LSP] Goto next diagnostic')

    -- Toggle inlay hints
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      key('n', '<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }))
      end, 'Toggle Inlay Hints')
    end
  end,
})
