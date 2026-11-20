local lsp = require("c42checker.lsp")

local M = {}

local win_id = nil
local buf_id = nil
local log_win_id = nil
local log_buf_id = nil

local STEP_ORDER = {
  { id = "cFormatter", label = "c_formatter_42 (整形)", stage = 1 },
  { id = "norminette", label = "norminette", stage = 1 },
  { id = "normExtra", label = "Norm (*) 規則", stage = 1 },
  { id = "makefile", label = "Makefile (Norm III.11)", stage = 1 },
  { id = "warnings", label = "警告強化ビルド (clang)", stage = 1 },
  { id = "clangTidy", label = "clang-tidy", stage = 1 },
  { id = "scanBuild", label = "scan-build", stage = 1 },
  { id = "gccAnalyzer", label = "gcc -fanalyzer", stage = 1 },
  { id = "asanUbsan", label = "ASan + UBSan", stage = 2 },
  { id = "tsan", label = "ThreadSanitizer", stage = 2 },
  { id = "msan", label = "MemorySanitizer", stage = 2 },
  { id = "valgrind", label = "valgrind", stage = 2 },
  { id = "leaks", label = "leaks (macOS)", stage = 2 },
  { id = "cbmc", label = "cbmc", stage = 2 },
  { id = "framaC", label = "frama-c", stage = 2 },
}

local line_to_step = {}

local function status_icon(st)
  if st == "pass" then
    return "✓"
  elseif st == "fail" then
    return "✗"
  elseif st == "skip" then
    return "-"
  elseif st == "running" then
    return "…"
  end
  return " "
end

function M.render(opts)
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    return
  end
  local lines = {}
  line_to_step = {}
  local checks = (opts.settings and opts.settings.checks) or {}

  table.insert(lines, " c42checker  [r]実行 [s]単体 [Space]切替 [l]ログ [q]閉じる")
  table.insert(lines, " ──────────────────────────────────────────────────────────")
  if lsp.state.running then
    table.insert(lines, " 状態: 実行中...")
  elseif lsp.state.last_report then
    local ok = lsp.state.last_report.ok
    table.insert(lines, ok and " 状態: PASS" or " 状態: FAIL")
  else
    table.insert(lines, " 状態: 待機中")
  end
  table.insert(lines, "")

  local cur_stage = 0
  for _, item in ipairs(STEP_ORDER) do
    if item.stage ~= cur_stage then
      cur_stage = item.stage
      table.insert(lines, string.format(" ── 段階 %d ──", cur_stage))
    end
    local enabled = checks[item.id]
    if enabled == nil then
      enabled = false
    end
    local res = lsp.state.steps[item.id]
    local icon = status_icon(res and res.status or nil)
    local ms = res and res.ms and string.format(" (%dms)", res.ms) or ""
    local reason = res and res.reason and ("  " .. res.reason) or ""
    local box = enabled and "[x]" or "[ ]"
    table.insert(lines, string.format(" %s %s %-24s%s%s", box, icon, item.label, ms, reason))
    line_to_step[#lines] = item.id
  end

  vim.bo[buf_id].modifiable = true
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  vim.bo[buf_id].modifiable = false
end

local function show_log_for_current_line()
  local cur = vim.api.nvim_win_get_cursor(win_id)[1]
  local step_id = line_to_step[cur]
  if not step_id then
    return
  end
  local res = lsp.state.steps[step_id]
  if not res then
    vim.notify("[c42checker] まだ実行結果がありません: " .. step_id, vim.log.levels.INFO)
    return
  end
  if not log_buf_id or not vim.api.nvim_buf_is_valid(log_buf_id) then
    log_buf_id = vim.api.nvim_create_buf(false, true)
  end
  local text = res.log or ""
  if text == "" and res.reason then
    text = res.reason .. "\n" .. (res.hint or "")
  end
  local log_lines = vim.split(text, "\n", { plain = true })
  vim.bo[log_buf_id].modifiable = true
  vim.api.nvim_buf_set_lines(log_buf_id, 0, -1, false, log_lines)
  vim.bo[log_buf_id].modifiable = false

  if not log_win_id or not vim.api.nvim_win_is_valid(log_win_id) then
    local width = math.floor(vim.o.columns * 0.75)
    local height = math.floor(vim.o.lines * 0.5)
    log_win_id = vim.api.nvim_open_win(log_buf_id, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
      border = "rounded",
      title = " c42checker Log: " .. step_id .. " ",
      title_pos = "center",
    })
    vim.keymap.set("n", "q", function()
      if log_win_id and vim.api.nvim_win_is_valid(log_win_id) then
        vim.api.nvim_win_close(log_win_id, true)
      end
    end, { buffer = log_buf_id, silent = true })
  end
end

function M.open(opts)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_set_current_win(win_id)
    M.render(opts)
    return
  end

  buf_id = vim.api.nvim_create_buf(false, true)
  vim.bo[buf_id].bufhidden = "wipe"
  vim.bo[buf_id].filetype = "c42checker-panel"

  local width = math.min(72, math.floor(vim.o.columns * 0.8))
  local height = 25
  win_id = vim.api.nvim_open_win(buf_id, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " 42 Check (c42checker) ",
    title_pos = "center",
  })

  lsp.state.on_update = function(kind, payload)
    vim.schedule(function()
      if kind == "stepStart" and payload and payload.id then
        lsp.state.steps[payload.id] = { id = payload.id, status = "running" }
      end
      M.render(opts)
    end)
  end

  local map = function(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf_id, silent = true })
  end

  map("q", function()
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
      win_id = nil
    end
  end)

  map("<Space>", function()
    local cur = vim.api.nvim_win_get_cursor(win_id)[1]
    local step_id = line_to_step[cur]
    if not step_id then
      return
    end
    opts.settings = opts.settings or {}
    opts.settings.checks = opts.settings.checks or {}
    opts.settings.checks[step_id] = not opts.settings.checks[step_id]
    lsp.update_settings(opts)
    M.render(opts)
  end)

  map("r", function()
    lsp.run_pipeline(opts, {})
  end)

  map("<CR>", function()
    lsp.run_pipeline(opts, {})
  end)

  map("s", function()
    local cur = vim.api.nvim_win_get_cursor(win_id)[1]
    local step_id = line_to_step[cur]
    if not step_id then
      return
    end
    lsp.state.steps[step_id] = { id = step_id, status = "running" }
    M.render(opts)
    lsp.execute(opts, "c42checker.runStep", { stepId = step_id }, function(_, res)
      vim.schedule(function()
        if res then
          lsp.state.steps[step_id] = res
        end
        M.render(opts)
      end)
    end)
  end)

  map("l", show_log_for_current_line)

  map("c", function()
    lsp.execute(opts, "c42checker.cancel", {})
  end)

  M.render(opts)
end

return M
