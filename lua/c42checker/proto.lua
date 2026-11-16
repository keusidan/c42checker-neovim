local lsp = require("c42checker.lsp")

local M = {}

function M.sync(opts, sync_opts)
  sync_opts = sync_opts or {}
  local apply = sync_opts.apply ~= false
  lsp.execute(opts, "c42checker.syncPrototypes", {
    header = sync_opts.header,
    apply = apply,
    insertMarkers = sync_opts.insert_markers or false,
  }, function(err, res)
    if err or not res then
      return
    end
    vim.schedule(function()
      if res.status == "needs-markers" then
        vim.ui.select({ "マーカーを挿入して反映する", "キャンセル" }, {
          prompt = res.message or "auto prototypes マーカーが見つかりません",
        }, function(choice)
          if choice == "マーカーを挿入して反映する" then
            M.sync(opts, { header = sync_opts.header, apply = true, insert_markers = true })
          end
        end)
        return
      end
      local level = res.status == "error" and vim.log.levels.ERROR or vim.log.levels.INFO
      vim.notify("[c42checker] " .. (res.message or res.status), level)
      if apply and res.status == "ok" and not res.unchanged then
        vim.cmd("checktime")
      end
    end)
  end)
end

return M
