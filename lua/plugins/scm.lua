return {
  -- Git
  { 'tpope/vim-fugitive' },
  { 'sindrets/diffview.nvim' },
  -- Jujutsu
  {
    'NicolasGB/jj.nvim',
    config = function()
      require('jj').setup({})
    end,
  },
  {
    'julienvincent/hunk.nvim',
    cmd = { 'DiffEditor' },
    config = function()
      require('hunk').setup()
    end,
  },
}
