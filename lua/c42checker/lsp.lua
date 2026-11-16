local M = {}

local ns = vim.api.nvim_create_namespace("c42checker")

M.state = {
  client_id = nil,
  root_dir = nil,
  running = false,
  steps = {},
  toggles = {},
  tools = {},
  last_report = nil,
  on_update = nil,
}

function M.find_lsp_binary(configured_path)
  if configured_path and configured_path ~= "" and vim.fn.executable(configured_path) == 1 then
    return configured_path
  end
  if vim.fn.executable("c42checker-lsp") == 1 then
    return vim.fn.exepath("c42checker-lsp")
  end
  local candidates = {
    vim.fn.expand("~/.local/bin/c42checker-lsp"),
    vim.fn.expand("~/.cargo/bin/c42checker-lsp"),
  }
  for _, p in ipairs(candidates) do
    if vim.fn.executable(p) == 1 then
      return p
    end
  end
  return nil
end

function M.find_root(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local start = fname ~= "" and vim.fs.dirname(fname) or vim.fn.getcwd()
  local found = vim.fs.find({ "Makefile", "makefile", ".git", ".c42checker" }, {
    upward = true,
    path = start,
  })
  if found and #found > 0 then
    return vim.fs.dirname(found[1])
  end
  return vim.fn.getcwd()
end

local function update_quickfix(diags)
  local qf = {}
  for _, d in ipairs(diags or {}) do
    table.insert(qf, {
      filename = d.file,
      lnum = d.line or 1,
      col = d.col or 1,
      text = string.format("[%s] %s", d.source or "c42checker", d.message or ""),
      type = d.severity == "warning" and "W" or "E",
    })
  end
  vim.fn.setqflist(qf, "r")
end

function M.ensure_client(opts, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bin = M.find_lsp_binary(opts.lsp_path)
  if not bin then
    vim.notify(
      "[c42checker] c42checker-lsp が見つかりません。c42checker-base をインストールして PATH に通してください。",
      vim.log.levels.ERROR
    )
    return nil
  end

  local root_dir = M.find_root(bufnr)
  if M.state.client_id then
    local client = vim.lsp.get_client_by_id(M.state.client_id)
    if client and not client:is_stopped() then
      if not vim.lsp.buf_is_attached(bufnr, M.state.client_id) then
        vim.lsp.buf_attach_client(bufnr, M.state.client_id)
      end
      return M.state.client_id
    end
  end

  local handlers = {
    ["$/c42checker/stage"] = function(_, result)
      if result and M.state.on_update then
        M.state.on_update("stage", result)
      end
    end,
    ["$/c42checker/stepStart"] = function(_, result)
      if result and M.state.on_update then
        M.state.on_update("stepStart", result)
      end
    end,
    ["$/c42checker/stepResult"] = function(_, result)
      if result then
        M.state.steps[result.id] = result
        if M.state.on_update then
          M.state.on_update("stepResult", result)
        end
      end
    end,
    ["$/c42checker/protoSynced"] = function(_, result)
      if result and result.message then
        vim.notify("[c42checker] " .. result.message, vim.log.levels.INFO)
      end
    end,
  }

  local id = vim.lsp.start({
    name = "c42checker-lsp",
    cmd = { bin },
    root_dir = root_dir,
    init_options = { c42checker = opts.settings or {} },
    handlers = handlers,
    on_attach = function(client, _)
      M.state.client_id = client.id
      M.state.root_dir = root_dir
    end,
  }, { bufnr = bufnr })

  M.state.client_id = id
  M.state.root_dir = root_dir
  return id
end

function M.execute(opts, cmd, arg, cb)
  local id = M.ensure_client(opts)
  if not id then
    return
  end
  local client = vim.lsp.get_client_by_id(id)
  if not client then
    return
  end
  client.request("workspace/executeCommand", {
    command = cmd,
    arguments = arg and { arg } or {},
  }, function(err, res)
    if err then
      vim.notify("[c42checker] LSP エラー: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
    end
    if cb then
      cb(err, res)
    end
  end)
end

function M.run_pipeline(opts, req, cb)
  M.state.running = true
  M.state.steps = {}
  if M.state.on_update then
    M.state.on_update("start", req or {})
  end
  M.execute(opts, "c42checker.run", req or {}, function(err, res)
    M.state.running = false
    if not err and res then
      M.state.last_report = res
      local all_diags = {}
      for _, r in ipairs(res.results or {}) do
        M.state.steps[r.id] = r
        for _, d in ipairs(r.diags or {}) do
          table.insert(all_diags, d)
        end
      end
      if opts.use_quickfix ~= false then
        update_quickfix(all_diags)
      end
    end
    if M.state.on_update then
      M.state.on_update("done", res)
    end
    if cb then
      cb(err, res)
    end
  end)
end

function M.update_settings(opts)
  if not M.state.client_id then
    return
  end
  local client = vim.lsp.get_client_by_id(M.state.client_id)
  if client and not client:is_stopped() then
    client.notify("workspace/didChangeConfiguration", {
      settings = { c42checker = opts.settings or {} },
    })
  end
end

M.namespace = ns

return M
