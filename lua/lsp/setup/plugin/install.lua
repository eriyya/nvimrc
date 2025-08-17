local util = require('util')
local tsls = { 'typescript-language-server', 'eslint-lsp' }
local cssls = 'css-lsp'

local ft_to_lsp = {
  lua = { 'lua-language-server' },
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
    local registry = require('mason-registry')
    local servers = util.ternary(type(lsp) == 'table', lsp, { lsp })
    servers = vim.tbl_filter(function(v)
      return not registry.is_installed(v)
    end, servers)
    if #servers > 0 then
      vim.cmd('MasonInstall ' .. table.concat(servers, ' '))
    end
  end,
})
