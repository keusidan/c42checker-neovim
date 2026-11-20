local lsp = require("c42checker.lsp")
local ui = require("c42checker.ui")
local proto = require("c42checker.proto")
local dap_mod = require("c42checker.dap")

local M = {}

local is_mac = vim.fn.has("mac") == 1

M.defaults = {
  lsp_path = nil,
  use_quickfix = true,
  auto_attach = true,
  settings = {
    targetDir = ".",
    failFast = "stage",
    checks = {
      cFormatter = false,
      norminette = true,
      normExtra = true,
      makefile = true,
      warnings = true,
      clangTidy = true,
      scanBuild = true,
      gccAnalyzer = true,
      asanUbsan = true,
      tsan = false,
      msan = false,
      valgrind = not is_mac,
      leaks = is_mac,
      cbmc = false,
      framaC = false,
    },
  },
}

M.opts = vim.deepcopy(M.defaults)

function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts or {})

  if M.opts.auto_attach then
    local grp = vim.api.nvim_create_augroup("c42checker", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = grp,
      pattern = { "c", "h" },
      callback = function(ev)
        lsp.ensure_client(M.opts, ev.buf)
      end,
    })
  end
end

function M.run(selected)
  local req = selected and { selected = selected } or {}
  lsp.run_pipeline(M.opts, req, function(_, report)
    if not report then
      return
    end
    vim.schedule(function()
      if report.ok then
        vim.notify("[c42checker] 全ステップが通りました", vim.log.levels.INFO)
      else
        local reason = report.stoppedAt and report.stoppedAt.reason or "失敗しました"
        vim.notify("[c42checker] 失敗: " .. reason, vim.log.levels.WARN)
      end
    end)
  end)
end

function M.run_step(step_id)
  lsp.execute(M.opts, "c42checker.runStep", { stepId = step_id }, function(_, res)
    if not res then
      return
    end
    vim.schedule(function()
      lsp.state.steps[step_id] = res
      ui.render(M.opts)
      vim.notify(string.format("[c42checker] %s: %s", step_id, res.status), vim.log.levels.INFO)
    end)
  end)
end

function M.panel()
  lsp.ensure_client(M.opts)
  ui.open(M.opts)
end

function M.sync_prototypes(sync_opts)
  proto.sync(M.opts, sync_opts)
end

function M.regenerate_compdb()
  lsp.execute(M.opts, "c42checker.regenerateCompdb", {}, function(_, res)
    if res then
      vim.schedule(function()
        if res.ok then
          vim.notify(string.format("[c42checker] compile_commands.json を生成しました (%d 件)", res.entries or 0), vim.log.levels.INFO)
        else
          vim.notify("[c42checker] 生成失敗: " .. (res.error or ""), vim.log.levels.ERROR)
        end
      end)
    end
  end)
end

function M.clean()
  lsp.execute(M.opts, "c42checker.cleanWorkDir", {}, function(_, res)
    if res and res.ok then
      vim.schedule(function()
        vim.notify("[c42checker] .c42checker/ を削除しました", vim.log.levels.INFO)
      end)
    end
  end)
end

function M.cancel()
  lsp.execute(M.opts, "c42checker.cancel", {})
end

function M.debug(skip_checks)
  dap_mod.debug(M.opts, skip_checks)
end

return M
