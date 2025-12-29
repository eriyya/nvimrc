return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    {
      '<leader>m',
      function()
        require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())
      end,
      desc = '[Harpoon]: Show mark menu',
    },
    {
      '<leader>h',
      function()
        require('harpoon'):list():add()
      end,
      desc = '[Harpoon]: Add current file',
    },
    {
      '<leader>J',
      function()
        require('harpoon'):list():select(1)
      end,
      desc = '[Harpoon]: Goto mark 1',
    },
    {
      '<leader>K',
      function()
        require('harpoon'):list():select(2)
      end,
      desc = '[Harpoon]: Goto mark 2',
    },
    {
      '<leader>L',
      function()
        require('harpoon'):list():select(3)
      end,
      desc = '[Harpoon]: Goto mark 3',
    },
    {
      '<leader>H',
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
