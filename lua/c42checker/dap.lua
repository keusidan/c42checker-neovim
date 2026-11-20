local lsp = require("c42checker.lsp")

local M = {}

function M.find_codelldb()
  local found = vim.fn.exepath("codelldb")
  if found ~= "" then
    return found
  end
  local candidates = {
    vim.fn.stdpath("data") .. "/mason/bin/codelldb",
    "/opt/homebrew/bin/codelldb",
    "/usr/local/bin/codelldb",
  }
  for _, p in ipairs(candidates) do
    if vim.fn.executable(p) == 1 then
      return p
    end
  end
  local vscode_globs = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/vadimcn.vscode-lldb-*/adapter/codelldb"), false, true)
  if type(vscode_globs) == "table" and #vscode_globs > 0 then
    table.sort(vscode_globs)
    local latest = vscode_globs[#vscode_globs]
    if vim.fn.executable(latest) == 1 then
      return latest
    end
  end
  return "codelldb"
end

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
          local codelldb_bin = M.find_codelldb()
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
