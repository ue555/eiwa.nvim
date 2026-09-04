local renderer = require("eiwa.renderer")

local M = {}

local history_buffer = nil
local input_buffer = nil
local history_window = nil
local input_window = nil
local origin_window = nil
local plugin_tab = nil
local options = nil
local handlers = nil

local function valid_window(window)
  return window and vim.api.nvim_win_is_valid(window)
end

local function valid_buffer(buffer)
  return buffer and vim.api.nvim_buf_is_valid(buffer)
end

local function new_buffer(filetype, modifiable)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].modifiable = modifiable
  vim.bo[buffer].filetype = filetype
  return buffer
end

local function set_window_options(window)
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].signcolumn = "no"
  vim.wo[window].wrap = true
end

local function float_configs()
  local columns = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight
  local outer_width = math.max(30, math.min(columns - 2, math.floor(columns * options.window.width)))
  local outer_height = math.max(8, math.min(lines - 2, math.floor(lines * options.window.height)))
  local input_height = math.min(options.window.input_height, outer_height - 5)
  local history_height = outer_height - input_height - 4
  local row = math.max(0, math.floor((lines - outer_height) / 2))
  local col = math.max(0, math.floor((columns - outer_width) / 2))
  local content_width = outer_width - 2

  return {
    relative = "editor",
    row = row,
    col = col,
    width = content_width,
    height = history_height,
    style = "minimal",
    border = options.window.border,
    title = " Eiwa ",
    title_pos = "center",
  }, {
    relative = "editor",
    row = row + history_height + 2,
    col = col,
    width = content_width,
    height = input_height,
    style = "minimal",
    border = options.window.border,
    title = " Input ",
    title_pos = "left",
  }
end

local function float_layout()
  local history_config, input_config = float_configs()
  history_window = vim.api.nvim_open_win(history_buffer, false, history_config)
  input_window = vim.api.nvim_open_win(input_buffer, true, input_config)
end

local function split_input()
  vim.cmd("belowright " .. options.window.input_height .. "split")
  input_window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input_window, input_buffer)
end

local function split_layout(position)
  local temporary_buffer = nil
  if position == "right" then
    vim.cmd("botright vsplit")
    history_window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(history_window, math.max(30, math.floor(vim.o.columns * options.window.split_width)))
  elseif position == "bottom" then
    vim.cmd("botright new")
    history_window = vim.api.nvim_get_current_win()
    temporary_buffer = vim.api.nvim_win_get_buf(history_window)
    vim.api.nvim_win_set_height(history_window, math.max(6, math.floor(vim.o.lines * options.window.split_height)))
  else
    vim.cmd.tabnew()
    plugin_tab = vim.api.nvim_get_current_tabpage()
    history_window = vim.api.nvim_get_current_win()
    temporary_buffer = vim.api.nvim_win_get_buf(history_window)
  end
  vim.api.nvim_win_set_buf(history_window, history_buffer)
  if temporary_buffer and vim.api.nvim_buf_is_valid(temporary_buffer) then
    vim.api.nvim_buf_delete(temporary_buffer, { force = true })
  end
  split_input()
end

local function scroll_history(amount)
  if not valid_window(history_window) then
    return
  end
  vim.api.nvim_win_call(history_window, function()
    local view = vim.fn.winsaveview()
    view.topline = math.max(1, view.topline + amount)
    vim.fn.winrestview(view)
  end)
end

local function page_size()
  if not valid_window(history_window) then
    return 1
  end
  return math.max(1, vim.api.nvim_win_get_height(history_window) - 2)
end

local function dismiss_window(window)
  if not valid_window(window) then
    return
  end
  local tab = vim.api.nvim_win_get_tabpage(window)
  if #vim.api.nvim_tabpage_list_wins(tab) > 1 then
    vim.api.nvim_win_close(window, true)
    return
  end
  vim.api.nvim_win_set_buf(window, vim.api.nvim_create_buf(true, false))
end

local function set_mappings()
  local keymaps = options.keymaps
  local input_opts = { buffer = input_buffer, silent = true }
  vim.keymap.set({ "n", "i" }, keymaps.submit, function()
    handlers.submit()
  end, input_opts)
  vim.keymap.set({ "n", "i" }, keymaps.cancel, function()
    handlers.cancel()
  end, input_opts)
  vim.keymap.set("n", keymaps.close, function()
    handlers.close()
  end, input_opts)
  vim.keymap.set({ "n", "i" }, "<Esc>", function()
    handlers.close()
  end, input_opts)
  vim.keymap.set({ "n", "i" }, "<PageUp>", function()
    scroll_history(-page_size())
  end, input_opts)
  vim.keymap.set({ "n", "i" }, "<PageDown>", function()
    scroll_history(page_size())
  end, input_opts)

  local history_opts = { buffer = history_buffer, silent = true }
  vim.keymap.set("n", keymaps.close, handlers.close, history_opts)
  vim.keymap.set("n", "<Esc>", handlers.close, history_opts)
  vim.keymap.set("n", keymaps.cancel, handlers.cancel, history_opts)
  vim.keymap.set("n", "i", function()
    if valid_window(input_window) then
      vim.api.nvim_set_current_win(input_window)
      vim.cmd.startinsert()
    end
  end, history_opts)
end

function M.open(config, callbacks)
  if M.is_open() then
    vim.api.nvim_set_current_win(input_window)
    vim.cmd.startinsert()
    return
  end
  if valid_window(history_window) or valid_window(input_window) then
    M.close()
  end

  options = config
  handlers = callbacks
  origin_window = vim.api.nvim_get_current_win()
  history_buffer = new_buffer("eiwa-history", false)
  input_buffer = new_buffer("eiwa-input", true)
  vim.api.nvim_buf_set_lines(input_buffer, 0, -1, false, { "" })

  if options.window.position == "float" then
    float_layout()
  else
    split_layout(options.window.position)
  end

  set_window_options(history_window)
  set_window_options(input_window)
  set_mappings()
  callbacks.render()
  vim.api.nvim_set_current_win(input_window)
  vim.schedule(function()
    if valid_window(input_window) then
      vim.cmd.startinsert()
    end
  end)
end

function M.close()
  if plugin_tab and vim.api.nvim_tabpage_is_valid(plugin_tab) then
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.api.nvim_set_current_tabpage(plugin_tab)
      vim.cmd.tabclose()
    else
      dismiss_window(input_window)
      dismiss_window(history_window)
    end
  else
    dismiss_window(input_window)
    dismiss_window(history_window)
  end

  history_window = nil
  input_window = nil
  history_buffer = nil
  input_buffer = nil
  plugin_tab = nil
  if valid_window(origin_window) then
    vim.api.nvim_set_current_win(origin_window)
  end
  origin_window = nil
end

function M.is_open()
  return valid_window(history_window) == true and valid_window(input_window) == true
end

function M.input()
  if not valid_buffer(input_buffer) then
    return ""
  end
  return vim.trim(table.concat(vim.api.nvim_buf_get_lines(input_buffer, 0, -1, false), "\n"))
end

function M.clear_input()
  if valid_buffer(input_buffer) then
    vim.api.nvim_buf_set_lines(input_buffer, 0, -1, false, { "" })
  end
end

function M.render(messages, status)
  renderer.render(history_buffer, messages, status)
  if valid_window(history_window) then
    local count = vim.api.nvim_buf_line_count(history_buffer)
    vim.api.nvim_win_set_cursor(history_window, { math.max(1, count), 0 })
  end
end

function M.resize()
  if not M.is_open() or options.window.position ~= "float" then
    return
  end
  local history_config, input_config = float_configs()
  vim.api.nvim_win_set_config(history_window, history_config)
  vim.api.nvim_win_set_config(input_window, input_config)
end

return M
