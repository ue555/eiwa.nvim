# eiwa.nvim

英語から日本語への翻訳を目的とした、Neovimネイティブの対話UIです。
Goバックエンドから英日翻訳HTTP APIを呼び出し、日本語を履歴に表示します。
既定の接続先は `http://127.0.0.1:8000/translate` です。

## このPCのローカル翻訳APIと連携する

Windows用バックエンドはビルド済みです。再ビルドする場合：

```powershell
Set-Location 'C:\Users\zeroz\dev\eiwa.nvim'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

翻訳APIが停止している場合は、別途起動してください。APIが既に起動中なら不要です。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\zeroz\ai\eiwa\scripts\start_background_api.ps1
```

lazy.nvimでは、調整したローカルのプラグインを指定します。

```lua
{
  dir = "C:/Users/zeroz/dev/eiwa.nvim",
  name = "eiwa.nvim",
  config = function()
    require("eiwa").setup({
      api = {
        endpoint = "http://127.0.0.1:8000/translate",
        timeout = 90, -- 秒
        style = "source", -- source / polite / plain
        glossary = { ["working tree"] = "作業ツリー" },
      },
    })
  end,
}
```

`:Eiwa` で開き、英文を入力してEnterを押すと訳文が表示されます。
`require("eiwa").submit("English text")` からも送信できます。
別のプラグイン管理方式では、このディレクトリをruntimepathへ登録して
`require("eiwa").setup()` を呼び出してください。既定設定だけでもローカルAPIに接続します。

APIは一括応答のため、生成完了後に全文を表示します。Ctrl+CでHTTP待機とUIの要求を中断できますが、
API側のGPU計算が完了するまでは次の要求が503になる場合があります。設定変更はNeovim再起動後に反映されます。
NeovimからはGoが通信するので、ブラウザー用のCORS設定は不要です。

## 機能

- Lua 5.1 / LuaJIT 2.1互換のNeovim UI
- 上部の読み取り専用履歴と下部の入力欄
- フロート、右分割、下分割、新規タブの4表示形式
- JSON Linesを使用したGoバックエンドとの非同期通信
- ストリーミング表示とリクエストのキャンセル
- ウィンドウを閉じてもセッション履歴を保持
- Apple Silicon、Linux amd64、Linux arm64向けビルド

## 必要要件

- Neovim 0.10以降
- バックエンドをローカルビルドする場合はGo 1.21以降

## インストール

### lazy.nvim

```lua
{
  "ue555/eiwa.nvim",
  build = "scripts/install-agent.sh",
  config = function()
    require("eiwa").setup()
  end,
}
```

### nvpm

```json
{
  "url": "ue555/eiwa.nvim",
  "build": "scripts/install-agent.sh"
}
```

## 設定

```lua
require("eiwa").setup({
  window = {
    position = "float", -- float, right, bottom, tab
    width = 0.8,
    height = 0.8,
    split_width = 0.4,
    split_height = 0.35,
    input_height = 3,
    border = "rounded",
  },
  history = {
    max_messages = 100,
  },
  keymaps = {
    submit = "<CR>",
    cancel = "<C-c>",
    close = "q",
  },
})
```

## コマンド

| コマンド          | 内容                               |
| ----------------- | ---------------------------------- |
| `:Eiwa`           | UIを開く、または閉じる             |
| `:EiwaClose`      | 履歴を残してUIを閉じる             |
| `:EiwaClear`      | 現在の履歴を削除する               |
| `:EiwaCancel`     | 実行中のリクエストを中断する       |
| `:EiwaNewSession` | リクエストを中断して履歴を削除する |

入力欄では`Enter`で送信、`Ctrl+C`で中断、`Esc`で閉じます。
ノーマルモードでは`q`で閉じます。`PgUp`と`PgDn`で履歴を移動します。

## Goバックエンド

現在のOS・CPUに対応するバイナリをGitHub Releasesから取得します。
まだリリースがない場合は、ローカルのGoでビルドします。

```sh
scripts/install-agent.sh
```

現在の環境向けにビルドします。

```sh
scripts/build.sh
```

全対応環境向けにクロスビルドします。

```sh
scripts/build.sh --all
```

Goバックエンドは `POST /translate` に `text`、`style`、`glossary` を送り、
応答の `translation` を表示します。接続失敗、タイムアウト、APIのエラーを履歴に表示します。
CLIでは `eiwa-agent serve --endpoint URL --timeout 90s --style polite --glossary '{"term":"訳語"}'`
を利用できます。UI開発用の仮応答は `--provider placeholder` で明示的に選択できます。

検証：`go test -timeout 20s ./...`、
`nvim --headless -u tests/minimal_init.lua -l tests/run.lua`。
起動中のローカルAPIとの実通信検証は
`nvim --headless -u tests/minimal_init.lua -l tests/live_api.lua`。

## ライセンス

MIT
