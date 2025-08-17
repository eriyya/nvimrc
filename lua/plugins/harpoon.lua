return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = {
    save_on_toggle = true,
  },
  config = function()
    require('harpoon'):setup({})
  end,
}
