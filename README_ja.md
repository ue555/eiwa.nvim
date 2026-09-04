# eiwa.nvim

> [!WARNING]
> **このプラグインは現在開発中です。** API、設定、動作は予告なく変更される
> 可能性があります。翻訳機能はまだ実装されていません。

英語から日本語への翻訳を目的とした、Neovimネイティブの対話UIです。
現段階では翻訳Providerを実装せず、UI、セッション、Goプロセス、
ストリーミング通信、キャンセルの基盤までを実装しています。

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

| コマンド | 内容 |
|---|---|
| `:Eiwa` | UIを開く、または閉じる |
| `:EiwaClose` | 履歴を残してUIを閉じる |
| `:EiwaClear` | 現在の履歴を削除する |
| `:EiwaCancel` | 実行中のリクエストを中断する |
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

翻訳機能の代わりに、現段階では
`Translation backend is not implemented yet.`と表示します。

## ライセンス

MIT
