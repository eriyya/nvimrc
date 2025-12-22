local function neorg_markdown_preview(suffix, open_preview)
  local dst = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.:r') .. suffix -- same name but with suffix
  vim.cmd(string.format([[Neorg export to-file %s]], string.gsub(dst, ' ', [[\ ]])))
  vim.schedule(function()
    vim.cmd.edit(dst)
    if suffix == '.md' and open_preview then
      vim.cmd([[MarkdownPreview]]) -- https://github.com/iamcco/markdown-preview.nvim
    end
  end)
end

return {
  {
    'nvim-neorg/neorg',
    lazy = true,
    ft = 'norg',
    cmd = 'NeorgWorkspace',
    version = '*',
    dependencies = {
      'pysan3/pathlib.nvim',
      'nvim-neorg/lua-utils.nvim',
    },
    config = function()
      require('neorg').setup({
        load = {
          ['core.defaults'] = {},
          ['core.dirman'] = {
            config = {
              workspaces = {
                notes = '~/notes',
                work = '~/work',
              },
              default_workspace = 'notes',
            },
          },
          ['core.qol.todo_items'] = {},
          ['core.export'] = {},
          ['core.esupports.indent'] = {},
          ['core.concealer'] = {
            config = {
              icon_preset = 'varied',
            },
          },
        },
      })

      vim.api.nvim_create_autocmd('BufEnter', {
        group = 'Neorg',
        pattern = '*.norg',
        desc = 'Setup buffer settings for Norg files',
        callback = function()
          vim.keymap.set('n', '<leader>t', '<Plug>(neorg.qol.todo-items.todo.task-cycle)', { buffer = true })
        end,
      })

      vim.api.nvim_create_user_command('NeorgMarkdown', function()
        neorg_markdown_preview('.md', true)
      end, {})
    end,
  },
  {
    lazy = true,
    cmd = 'MarkdownPreview',
    ft = { 'markdown', 'norg' },
    'iamcco/markdown-preview.nvim',
    build = 'cd app && yarn install',
  },
  {
    lazy = true,
    'MeanderingProgrammer/render-markdown.nvim',
    opts = {
      file_types = { 'markdown', 'Avante' },
    },
    ft = { 'markdown', 'Avante' },
  },
}
