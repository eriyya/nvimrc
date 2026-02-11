if not vim.g.vscode then
  return
end

local vscode = require('vscode')
local harpoon_vscode = require('config.vscode.harpoon_vscode')

local M = {}

M.keybinds = function()
  --- VSCode keymaps
  vim.keymap.set('n', '<leader>ml', harpoon_vscode.show_harpoon_quickpick, {
    desc = '[Harpoon]: Show marks (VSCode Quick Pick)',
  })

  vim.keymap.set('n', '<leader>f', function()
    vscode.action('editor.action.formatDocument')
  end, { desc = '[LSP] Format document (VSCode)' })

  vim.keymap.set('n', 'gr', function()
    vscode.action('editor.action.goToReferences')
  end, { desc = '[LSP] Go to references (VSCode)' })

  vim.keymap.set('n', '<leader>rn', function()
    vscode.action('editor.action.rename')
  end, { desc = '[LSP] Symbol rename (VSCode)' })

  vim.keymap.set({ 'n', 'v' }, '<leader>a', function()
    vscode.action('editor.action.quickFix')
  end, { desc = '[LSP] Quick fix (VSCode)' })

  vim.keymap.set('n', 'u', function()
    vscode.action('undo')
  end, { desc = 'Undo (VSCode)' })
end

return M
