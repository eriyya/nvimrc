return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    {
      '<leader>ml',
      function()
        require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())
      end,
      desc = '[Harpoon]: Show mark menu',
    },
    {
      '<leader>ma',
      function()
        require('harpoon'):list():add()
      end,
      desc = '[Harpoon]: Add current file',
    },
    {
      '<leader>j',
      function()
        require('harpoon'):list():select(1)
      end,
      desc = '[Harpoon]: Goto mark 1',
    },
    {
      '<leader>k',
      function()
        require('harpoon'):list():select(2)
      end,
      desc = '[Harpoon]: Goto mark 2',
    },
    {
      '<leader>l',
      function()
        require('harpoon'):list():select(3)
      end,
      desc = '[Harpoon]: Goto mark 3',
    },
    {
      '<leader>h',
      function()
        require('harpoon'):list():select(4)
      end,
      desc = '[Harpoon]: Goto mark 4',
    },
  },
  opts = {
    save_on_toggle = true,
  },
  config = function()
    require('harpoon'):setup({})
  end,
}
