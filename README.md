# eiwa.nvim

[日本語版 README](README_ja.md)

A native Neovim conversation UI intended for English-to-Japanese translation.
The Go agent connects to an English-to-Japanese HTTP API. The default endpoint
is `http://127.0.0.1:8000/translate`. Start the API separately, then open `:Eiwa`
and submit English text. See [local Windows setup](README_ja.md) for this PC.

Configure the API with:

```lua
require("eiwa").setup({
  api = {
    endpoint = "http://127.0.0.1:8000/translate",
    timeout = 90, -- seconds
    style = "source", -- source, polite, plain
    glossary = { ["working tree"] = "作業ツリー" },
  },
})
```

Windows users can build with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1`.
The agent automatically resolves Windows `.exe` binaries. Restart Neovim after
changing API settings. The API returns a complete translation, displayed after
generation finishes. Cancellation stops HTTP waiting, but API-side GPU work may
continue and temporarily cause HTTP 503 on the next request.

## Features

- Native Lua 5.1/LuaJIT 2.1 Neovim interface
- Read-only conversation history and editable input area
- Float, right split, bottom split, and tab layouts
- Asynchronous JSON Lines communication with a pure-Go agent
- Streaming assistant events and request cancellation
- Session history retained when the window is closed
- Linux amd64, Linux arm64, and Apple Silicon builds

## Requirements

- Neovim 0.10 or later
- Go 1.21 or later when building the agent locally

## Install

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

## Configuration

```lua
require("eiwa").setup({
  command = nil,
  window = {
    position = "float", -- float, right, bottom, or tab
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

## Commands

| Command           | Description                                 |
| ----------------- | ------------------------------------------- |
| `:Eiwa`           | Open or close the interface                 |
| `:EiwaClose`      | Close the interface and retain its history  |
| `:EiwaClear`      | Clear the current history                   |
| `:EiwaCancel`     | Cancel the active request                   |
| `:EiwaNewSession` | Cancel the active request and clear history |

In the input area, press `Enter` to submit, `Ctrl+C` to cancel, and `Esc` to
close. In Normal mode, `q` closes the interface. `PgUp` and `PgDn` scroll the
history.

## Build the agent

Install the matching release binary, with a local Go build as fallback:

```sh
scripts/install-agent.sh
```

Build for the current platform:

```sh
scripts/build.sh
```

Build all supported targets:

```sh
scripts/build.sh --all
```

Generated binaries:

```text
eiwa-agent-linux-amd64
eiwa-agent-linux-arm64
eiwa-agent-darwin-arm64
```

Tagged pushes trigger the release workflow and upload these binaries to
GitHub Releases.

## Backend protocol

The Lua frontend and Go agent communicate through JSON Lines over standard
input and output.

```json
{"type":"submit","id":"request-1","content":"Hello"}
{"type":"cancel","id":"request-1"}
{"type":"shutdown"}
```

The HTTP backend posts `text`, `style`, and optional `glossary`, then emits
`started`, one `assistant_delta` containing the API's `translation`, and
`assistant_done`. Errors include the API's structured error message. A
placeholder backend remains available with `eiwa-agent serve --provider placeholder`
for UI development. CLI options include `--endpoint`, `--timeout`, `--style`, and
`--glossary`; defaults can also use `EIWA_API_URL`, `EIWA_API_TIMEOUT`,
`EIWA_API_STYLE`, and `EIWA_API_GLOSSARY` environment variables.

## License

MIT
