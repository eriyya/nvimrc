local tsls = 'typescript-language-server'
local cssls = 'css-lsp'

local ft_to_lsp = {
  lua = { 'lua-language-server', 'selene' },
  typescript = tsls,
  typescriptreact = tsls,
  javascript = tsls,
  javascriptreact = tsls,
  html = 'html-lsp',
  css = cssls,
  scss = cssls,
  less = cssls,
  json = 'json-lsp',
  jsonc = 'json-lsp',
  yaml = 'yaml-language-server',
  markdown = 'marksman',
  zig = 'zls',
  rust = 'rust-analyzer',
}

local ft_list = vim.tbl_keys(ft_to_lsp)

vim.api.nvim_create_autocmd({ 'BufReadPre', 'FileType' }, {
  pattern = ft_list,
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if not ft_to_lsp[ft] then
      return
    end
    local lsp = ft_to_lsp[ft]
    if not require('mason-registry').is_installed(lsp[1]) then
      local servers = lsp
      if type(lsp) == 'table' then
        servers = table.concat(lsp, ' ')
      end
      vim.cmd('MasonInstall ' .. servers)
    end
  end,
})
