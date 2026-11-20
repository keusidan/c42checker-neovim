vim.opt.rtp:prepend(vim.fn.getcwd())

local c42 = require("c42checker")
local lsp = require("c42checker.lsp")
local dap = require("c42checker.dap")

local lsp_bin = os.getenv("C42CHECKER_LSP") or "/home/ponzu/tmp/c42checker-base/target/release/c42checker-lsp"
c42.setup({
  lsp_path = lsp_bin,
  auto_attach = false,
})

assert(c42.defaults.settings.checks.leaks ~= nil, "leaks default check should exist")
assert(type(dap.find_codelldb()) == "string", "find_codelldb should return a string")

-- Verify plugin commands are registered
vim.cmd("runtime plugin/c42checker.lua")
local cmds = vim.api.nvim_get_commands({})
for _, name in ipairs({ "C42Run", "C42RunStep", "C42Panel", "C42SyncPrototypes", "C42Compdb", "C42Debug", "C42Clean", "C42Cancel" }) do
  assert(cmds[name] ~= nil, "Missing command: " .. name)
end

if vim.fn.executable(lsp_bin) == 1 then
  assert(lsp.find_lsp_binary(lsp_bin) == lsp_bin, "LSP binary should be found")

  -- Verify LSP client starts and responds to detectTools
  local done = false
  local got_steps = 0
  local id = lsp.ensure_client(c42.opts)
  assert(id ~= nil, "LSP client failed to start")

  lsp.execute(c42.opts, "c42checker.detectTools", {}, function(err, res)
    assert(err == nil, "detectTools error: " .. vim.inspect(err))
    assert(res ~= nil and res.steps ~= nil, "detectTools response missing steps")
    got_steps = #res.steps
    done = true
  end)

  local ok = vim.wait(5000, function()
    return done
  end, 20)
  assert(ok, "Timed out waiting for LSP detectTools response")
  assert(got_steps == 15, "Expected 15 steps, got " .. tostring(got_steps))
  print("PASS: c42checker-neovim headless tests (15 steps via c42checker-lsp)")
else
  print("PASS: c42checker-neovim headless unit tests (c42checker-lsp not built; LSP integration skipped)")
end

vim.cmd("qa!")
