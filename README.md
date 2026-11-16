# c42checker-neovim

42 Tokyo (C / 42 Norm) 向けの検証・ビルド・プロトタイプ同期・デバッグ支援を行う Neovim プラグインです。
バックエンドとして [c42checker-base](https://github.com/keusidan/c42checker-base) (`c42checker-lsp`) を使用します。

## 要件

* Neovim >= 0.10
* `c42checker-lsp` (`c42checker-base` をビルドして `PATH` に配置)
* 検証ツール: `norminette`, `clang`, `clang-tidy`, `scan-build`, `gcc`, `valgrind`, `universal-ctags`, `c_formatter_42` 等
* デバッグ連携 (任意): `nvim-dap` + `codelldb`

## インストール (`lazy.nvim`)

```lua
{
  "keusidan/c42checker-neovim",
  ft = { "c", "h" },
  config = function()
    require("c42checker").setup({})
  end,
}
```

## コマンド

* `:C42Panel` — フローティングパネルを開く (`r` 実行 / `s` 単体実行 / `<Space>` トグル / `l` ログ表示 / `c` 中止 / `q` 閉じる)
* `:C42Run` — チェック済みのステップを段階的に実行
* `:C42RunStep <stepId>` — 指定したステップのみ実行
* `:C42SyncPrototypes` — ヘッダにプロトタイプを自動反映
* `:C42Compdb` — `compile_commands.json` / `.clangd` を再生成
* `:C42Debug` / `:C42Debug!` — `nvim-dap` (`codelldb`) でデバッグ実行 (`!` でチェックをスキップ)
* `:C42Clean` — `.c42checker/` を削除
* `:C42Cancel` — 実行中の検査を中止

## テスト

```bash
nvim --headless -u NONE -l tests/run_tests.lua
```
