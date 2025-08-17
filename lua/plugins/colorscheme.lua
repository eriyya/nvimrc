return {
  'tiagovla/tokyodark.nvim',
  priority = 1000,
  opts = {
    transparent_background = true,
    styles = {
      comments = { italic = false }, -- style for comments
      keywords = { italic = false }, -- style for keywords
      identifiers = { italic = false }, -- style for identifiers
      functions = { italic = false }, -- style for functions
      variables = { italic = false }, -- style for variables
    },
  },
  config = function(_, opts)
    require('tokyodark').setup(opts) -- calling setup is optional
    vim.cmd([[colorscheme tokyodark]])
  end,
}
