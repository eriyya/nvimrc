return {
  lazy = true,
  event = 'InsertEnter',
  'supermaven-inc/supermaven-nvim',
  config = function()
    require('supermaven-nvim').setup({
      disable_keymaps = true,
    })
    -- vim.api.nvim_set_hl(0, 'CmpItemKindSupermaven', { fg = '#6CC644' })
  end,
}
