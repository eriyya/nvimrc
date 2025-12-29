return {
  -- Auto detect tabstop and shiftwidth
  { 'tpope/vim-sleuth', event = { 'BufReadPre', 'BufNewFile' } },
  -- Auto close pairs
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {
      fast_wrap = {},
      disable_filetype = { 'TelescopePrompt', 'vim' },
    },
  },
}
