return {
  -- Git
  { 'tpope/vim-fugitive', cmd = { 'Git', 'G', 'Gstatus', 'Gblame', 'Gpush', 'Gpull', 'Gdiffsplit' } },
  { 'sindrets/diffview.nvim', cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' } },
  -- Jujutsu
  {
    'NicolasGB/jj.nvim',
    cmd = { 'J' },
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
