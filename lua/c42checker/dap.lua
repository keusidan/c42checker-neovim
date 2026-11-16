local lsp = require("c42checker.lsp")

local M = {}

function M.debug(opts, skip_checks)
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    vim.notify("[c42checker] nvim-dap がインストールされていません", vim.log.levels.ERROR)
    return
  end

  local req = {
    debugBuild = not skip_checks,
    debugBuildOnly = skip_checks == true,
  }

  vim.notify("[c42checker] デバッグ用ビルドを実行中...", vim.log.levels.INFO)
  lsp.run_pipeline(opts, req, function(err, report)
    if err or not report or not report.ok then
      vim.schedule(function()
        vim.notify("[c42checker] チェックまたはデバッグビルドに失敗しました", vim.log.levels.ERROR)
      end)
      return
    end
    lsp.execute(opts, "c42checker.getContext", {}, function(ctx_err, ctx)
      if ctx_err or not ctx then
        return
      end
      vim.schedule(function()
        if not dap.adapters.codelldb then
          local codelldb_bin = vim.fn.exepath("codelldb")
          if codelldb_bin == "" then
            codelldb_bin = "codelldb"
          end
          dap.adapters.codelldb = {
            type = "server",
            port = "${port}",
            executable = {
              command = codelldb_bin,
              args = { "--port", "${port}" },
            },
          }
        end
        dap.run({
          name = "c42checker: Debug",
          type = "codelldb",
          request = "launch",
          program = ctx.debugProgram,
          args = ctx.runArgs or {},
          cwd = ctx.root,
          stopOnEntry = false,
        })
      end)
    end)
  end)
end

return M
