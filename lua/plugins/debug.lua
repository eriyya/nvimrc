return {
  event = { 'BufReadPre', 'BufNewFile' },
  'mfussenegger/nvim-dap',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'rcarriga/nvim-dap-ui',
    'theHamsta/nvim-dap-virtual-text',
    'mxsdev/nvim-dap-vscode-js',
  },
  config = function()
    local dap = require('dap')
    local ui = require('dapui')

    require('nvim-dap-virtual-text').setup({})

    -- setup adapters
    require('dap-vscode-js').setup({
      debugger_path = vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter',
      debugger_cmd = { 'js-debug-adapter' },
      adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost' },
    })

    -- custom adapter for running tasks before starting debug
    local custom_adapter = 'pwa-node-custom'
    dap.adapters[custom_adapter] = function(cb, config)
      if config.preLaunchTask then
        local async = require('plenary.async')
        local notify = require('notify').async

        async.run(function()
          ---@diagnostic disable-next-line: missing-parameter
          notify('Running [' .. config.preLaunchTask .. ']').events.close()
        end, function()
          vim.fn.system(config.preLaunchTask)
          config.type = 'pwa-node'
          dap.run(config)
        end)
      end
    end

    -- language config
    for _, language in ipairs({ 'typescript', 'javascript' }) do
      dap.configurations[language] = {
        {
          name = 'Launch',
          type = 'pwa-node',
          request = 'launch',
          program = '${file}',
          rootPath = '${workspaceFolder}',
          cwd = '${workspaceFolder}',
          sourceMaps = true,
          skipFiles = { '<node_internals>/**' },
          protocol = 'inspector',
          console = 'integratedTerminal',
        },
        {
          name = 'Attach to node process',
          type = 'pwa-node',
          request = 'attach',
          rootPath = '${workspaceFolder}',
          processId = require('dap.utils').pick_process,
        },
        {
          name = 'Debug Main Process (Electron)',
          type = 'pwa-node',
          request = 'launch',
          program = '${workspaceFolder}/node_modules/.bin/electron',
          args = {
            '${workspaceFolder}/dist/index.js',
          },
          outFiles = {
            '${workspaceFolder}/dist/*.js',
          },
          resolveSourceMapLocations = {
            '${workspaceFolder}/dist/**/*.js',
            '${workspaceFolder}/dist/*.js',
          },
          rootPath = '${workspaceFolder}',
          cwd = '${workspaceFolder}',
          sourceMaps = true,
          skipFiles = { '<node_internals>/**' },
          protocol = 'inspector',
          console = 'integratedTerminal',
        },
        {
          name = 'Compile & Debug Main Process (Electron)',
          type = custom_adapter,
          request = 'launch',
          preLaunchTask = 'npm run build-ts',
          program = '${workspaceFolder}/node_modules/.bin/electron',
          args = {
            '${workspaceFolder}/dist/index.js',
          },
          outFiles = {
            '${workspaceFolder}/dist/*.js',
          },
          resolveSourceMapLocations = {
            '${workspaceFolder}/dist/**/*.js',
            '${workspaceFolder}/dist/*.js',
          },
          rootPath = '${workspaceFolder}',
          cwd = '${workspaceFolder}',
          sourceMaps = true,
          skipFiles = { '<node_internals>/**' },
          protocol = 'inspector',
          console = 'integratedTerminal',
        },
      }
    end

    dap.listeners.after.event_initialized['dapui_config'] = function()
      ui.open()
    end

    dap.listeners.before.event_terminated['dapui_config'] = function()
      ui.close()
    end

    dap.listeners.before.event_exited['dapui_config'] = function()
      ui.close()
    end
  end,
}
