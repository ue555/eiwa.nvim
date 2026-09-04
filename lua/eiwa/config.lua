local M = {}

local defaults = {
  command = nil,
  window = {
    position = "float",
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
}

M.values = vim.deepcopy(defaults)

local function ratio(name, value)
  assert(type(value) == "number" and value > 0 and value <= 1, name .. " must be between 0 and 1")
end

function M.setup(opts)
  opts = opts or {}
  assert(type(opts) == "table", "eiwa setup options must be a table")
  local values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)

  local positions = { float = true, right = true, bottom = true, tab = true }
  assert(positions[values.window.position], "window.position must be float, right, bottom, or tab")
  ratio("window.width", values.window.width)
  ratio("window.height", values.window.height)
  ratio("window.split_width", values.window.split_width)
  ratio("window.split_height", values.window.split_height)
  assert(
    type(values.window.input_height) == "number"
      and values.window.input_height >= 1
      and values.window.input_height % 1 == 0,
    "window.input_height must be a positive integer"
  )
  assert(
    type(values.history.max_messages) == "number" and values.history.max_messages >= 1,
    "history.max_messages must be a positive number"
  )

  M.values = values
  return values
end

return M
