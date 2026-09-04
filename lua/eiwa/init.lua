local config = require("eiwa.config")
local process = require("eiwa.process")
local renderer = require("eiwa.renderer")
local session = require("eiwa.session")
local ui = require("eiwa.ui")

local M = {}

local configured = false
local sequence = 0

local function render()
  ui.render(session.get_messages(), session.get_status())
end

local function process_error(message)
  session.add_error(message, session.get_active_request())
  session.set_status("error", nil)
  render()
  vim.notify("Eiwa: " .. message, vim.log.levels.ERROR)
end

local function handle_event(event)
  if event.id and event.id ~= session.get_active_request() then
    return
  end
  if event.type == "started" then
    session.set_status("streaming", event.id)
    session.start_assistant(event.id)
  elseif event.type == "assistant_delta" then
    session.append_assistant(event.id, event.content or "")
  elseif event.type == "assistant_done" then
    session.set_status("idle", nil)
  elseif event.type == "cancelled" then
    session.add("system", "Request cancelled.", event.id)
    session.set_status("idle", nil)
  elseif event.type == "error" then
    session.add_error(event.message or "Unknown agent error", event.id)
    session.set_status("error", nil)
  end
  render()
end

local function ensure_setup()
  if not configured then
    M.setup()
  end
end

local function ensure_process()
  return process.start(config.values.command, {
    on_event = handle_event,
    on_error = process_error,
    on_exit = function()
      if session.get_status() == "streaming" or session.get_status() == "submitting" then
        session.set_status("error", nil)
        render()
      end
    end,
  })
end

function M.setup(opts)
  local values = config.setup(opts)
  session.configure(values.history)
  renderer.setup_highlights()
  configured = true
  return M
end

function M.open()
  ensure_setup()
  ui.open(config.values, {
    submit = function()
      M.submit()
    end,
    cancel = M.cancel,
    close = M.close,
    render = render,
    messages = session.get_messages,
    status = session.get_status,
  })
end

function M.close()
  ui.close()
end

function M.toggle()
  if ui.is_open() then
    M.close()
  else
    M.open()
  end
end

function M.submit(content)
  ensure_setup()
  if session.get_status() == "submitting" or session.get_status() == "streaming" then
    vim.notify("Eiwa: a request is already running", vim.log.levels.WARN)
    return false
  end

  content = content or ui.input()
  content = vim.trim(content or "")
  if content == "" then
    return false
  end
  if not ensure_process() then
    return false
  end

  sequence = sequence + 1
  local request_id = tostring((vim.uv or vim.loop).hrtime()) .. "-" .. sequence
  session.add("user", content, request_id)
  session.set_status("submitting", request_id)
  ui.clear_input()
  render()

  local ok, err = process.send({
    type = "submit",
    id = request_id,
    content = content,
  })
  if not ok then
    process_error(err)
    return false
  end
  return true
end

function M.cancel()
  local request_id = session.get_active_request()
  if not request_id then
    return false
  end
  local ok, err = process.send({ type = "cancel", id = request_id })
  if not ok then
    process_error(err)
    return false
  end
  return true
end

function M.clear()
  session.clear()
  render()
end

function M.new_session()
  M.cancel()
  M.clear()
end

function M.get_messages()
  return session.get_messages()
end

function M.get_status()
  return session.get_status()
end

function M.shutdown()
  process.shutdown()
end

return M
