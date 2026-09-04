local M = {}

local messages = {}
local status = "idle"
local active_request = nil
local max_messages = 100

local function trim()
  while #messages > max_messages do
    table.remove(messages, 1)
  end
end

function M.configure(opts)
  max_messages = opts.max_messages
  trim()
end

function M.add(role, content, request_id)
  table.insert(messages, {
    role = role,
    content = content,
    request_id = request_id,
  })
  trim()
end

function M.start_assistant(request_id)
  M.add("assistant", "", request_id)
end

function M.append_assistant(request_id, content)
  for index = #messages, 1, -1 do
    local item = messages[index]
    if item.role == "assistant" and item.request_id == request_id then
      item.content = item.content .. content
      return
    end
  end
  M.add("assistant", content, request_id)
end

function M.add_error(content, request_id)
  M.add("error", content, request_id)
end

function M.set_status(value, request_id)
  status = value
  active_request = request_id
end

function M.get_status()
  return status
end

function M.get_active_request()
  return active_request
end

function M.get_messages()
  return vim.deepcopy(messages)
end

function M.clear()
  messages = {}
  status = "idle"
  active_request = nil
end

return M
