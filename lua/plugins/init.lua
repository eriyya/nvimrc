return {
  { 'nvim-lua/plenary.nvim', priority = 500 },
  -- Auto detect tabstop and shiftwidth
  { 'tpope/vim-sleuth' },
  -- Auto close pairs
  {
    'windwp/nvim-autopairs',
    opts = {
      fast_wrap = {},
      disable_filetype = { 'TelescopePrompt', 'vim' },
    },
  },
}
