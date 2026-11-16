if vim.g.loaded_c42checker then
  return
end
vim.g.loaded_c42checker = true

local function c42()
  return require("c42checker")
end

vim.api.nvim_create_user_command("C42Run", function()
  c42().run()
end, { desc = "c42checker: チェック済みの項目を実行" })

vim.api.nvim_create_user_command("C42RunStep", function(opts)
  c42().run_step(opts.args)
end, { nargs = 1, desc = "c42checker: 指定ステップのみ実行" })

vim.api.nvim_create_user_command("C42Panel", function()
  c42().panel()
end, { desc = "c42checker: パネルを開く" })

vim.api.nvim_create_user_command("C42SyncPrototypes", function()
  c42().sync_prototypes({ apply = true })
end, { desc = "c42checker: ヘッダにプロトタイプを反映" })

vim.api.nvim_create_user_command("C42Compdb", function()
  c42().regenerate_compdb()
end, { desc = "c42checker: compile_commands.json / .clangd を再生成" })

vim.api.nvim_create_user_command("C42Debug", function(opts)
  c42().debug(opts.bang)
end, { bang = true, desc = "c42checker: nvim-dap でデバッグ実行 (! でチェックをスキップ)" })

vim.api.nvim_create_user_command("C42Clean", function()
  c42().clean()
end, { desc = "c42checker: .c42checker/ を削除" })

vim.api.nvim_create_user_command("C42Cancel", function()
  c42().cancel()
end, { desc = "c42checker: 実行を中止" })
