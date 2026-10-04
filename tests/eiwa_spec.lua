local eiwa = require("eiwa")
local protocol = require("eiwa.protocol")
local session = require("eiwa.session")
local ui = require("eiwa.ui")

local function assert_equal(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error((message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local function windows_with_filetype(filetype)
  local windows = {}
  for _, window in ipairs(vim.api.nvim_list_wins()) do
    local buffer = vim.api.nvim_win_get_buf(window)
    if vim.bo[buffer].filetype == filetype then
      table.insert(windows, window)
    end
  end
  return windows
end

assert_equal(2, vim.fn.exists(":Eiwa"))
assert_equal(2, vim.fn.exists(":EiwaClose"))
assert_equal(2, vim.fn.exists(":EiwaClear"))
assert_equal(2, vim.fn.exists(":EiwaCancel"))
assert_equal(2, vim.fn.exists(":EiwaNewSession"))

local decoded = {}
local decoder = protocol.new(function(event)
  table.insert(decoded, event)
end, function(err)
  error(err)
end)
decoder:feed('{"type":"started",')
decoder:feed('"id":"1"}\n{"type":"assistant_done","id":"1"}\n')
assert_equal(2, #decoded, "protocol must parse fragmented JSON Lines")

session.clear()
session.configure({ max_messages = 2 })
session.add("user", "one", "1")
session.add("assistant", "two", "1")
session.add("user", "three", "2")
assert_equal(2, #session.get_messages(), "session must enforce its history limit")
session.clear()

local root = vim.fn.getcwd()
local agent = root .. "/bin/eiwa-agent" .. (vim.fn.has("win32") == 1 and ".exe" or "")
local initial_listed_buffers = #vim.tbl_filter(function(buffer)
  return vim.bo[buffer].buflisted
end, vim.api.nvim_list_bufs())
local invalid_height = pcall(eiwa.setup, {
  window = { input_height = 1.5 },
})
assert_equal(false, invalid_height, "fractional input heights must be rejected")

for _, position in ipairs({ "float", "right", "bottom", "tab" }) do
  eiwa.setup({
    command = { agent, "serve", "--provider", "placeholder" },
    window = { position = position },
  })
  eiwa.open()
  assert_equal(true, ui.is_open(), position .. " layout must open")
  eiwa.close()
  assert_equal(false, ui.is_open(), position .. " layout must close")
  local listed_buffers = #vim.tbl_filter(function(buffer)
    return vim.bo[buffer].buflisted
  end, vim.api.nvim_list_bufs())
  assert_equal(initial_listed_buffers, listed_buffers, position .. " layout must not leak listed buffers")
end

eiwa.setup({
  command = { agent, "serve", "--provider", "placeholder" },
  window = { position = "float" },
})
eiwa.open()
local input_windows = windows_with_filetype("eiwa-input")
assert_equal(1, #input_windows)
vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(input_windows[1]), 0, -1, false, { "draft" })
ui.resize()
assert_equal("draft", ui.input(), "resize must preserve the input draft")
vim.api.nvim_win_close(input_windows[1], true)
eiwa.open()
assert_equal(1, #windows_with_filetype("eiwa-history"), "reopen must remove an orphaned history window")
assert_equal(1, #windows_with_filetype("eiwa-input"), "reopen must create one input window")
eiwa.close()

eiwa.setup({
  command = { agent, "serve", "--provider", "placeholder" },
  window = { position = "tab" },
})
eiwa.open()
vim.cmd("tabclose 1")
local closed_last_tab = pcall(eiwa.close)
assert_equal(true, closed_last_tab, "closing Eiwa must work when its tab is the last tab")
assert_equal(false, ui.is_open())

eiwa.setup({
  command = { agent, "serve", "--provider", "placeholder" },
  window = { position = "float" },
  history = { max_messages = 100 },
})
eiwa.open()
assert(eiwa.submit("Hello"))
assert(vim.wait(3000, function()
  return eiwa.get_status() == "idle"
end, 10), "agent response timed out")

local messages = eiwa.get_messages()
assert_equal(2, #messages)
assert_equal("user", messages[1].role)
assert_equal("Hello", messages[1].content)
assert_equal("assistant", messages[2].role)
assert_equal("Translation backend is not implemented yet.", messages[2].content)

eiwa.close()
eiwa.shutdown()
print("eiwa.nvim tests passed")
