local protocol = require("eiwa.protocol")

local M = {}

local handle = nil
local callbacks = nil
local stderr = ""

local function plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":p:h:h:h")
end

local function platform()
  local uname = (vim.uv or vim.loop).os_uname()
  local os_name = uname.sysname == "Darwin" and "darwin" or uname.sysname:lower()
  local architectures = {
    x86_64 = "amd64",
    amd64 = "amd64",
    aarch64 = "arm64",
    arm64 = "arm64",
  }
  return os_name, architectures[uname.machine] or uname.machine
end

local function executable(path)
  return path and vim.fn.executable(path) == 1
end

function M.resolve_command(configured)
  if type(configured) == "table" then
    return vim.deepcopy(configured)
  end
  if type(configured) == "string" and configured ~= "" then
    return { configured, "serve" }
  end

  local path = vim.fn.exepath("eiwa-agent")
  if path ~= "" then
    return { path, "serve" }
  end

  local os_name, architecture = platform()
  local candidates = {
    plugin_root() .. "/bin/eiwa-agent-" .. os_name .. "-" .. architecture,
    plugin_root() .. "/bin/eiwa-agent",
  }
  for _, candidate in ipairs(candidates) do
    if executable(candidate) then
      return { candidate, "serve" }
    end
  end

  return nil
end

function M.start(configured, handlers)
  if handle then
    return true
  end

  local command = M.resolve_command(configured)
  if not command or not executable(command[1]) then
    handlers.on_error("eiwa-agent was not found. Build it with scripts/build.sh.")
    return false
  end

  callbacks = handlers
  stderr = ""
  local parser = protocol.new(function(event)
    vim.schedule(function()
      if callbacks then
        callbacks.on_event(event)
      end
    end)
  end, function(err)
    vim.schedule(function()
      if callbacks then
        callbacks.on_error(err)
      end
    end)
  end)

  handle = vim.system(command, {
    stdin = true,
    text = true,
    stdout = function(err, data)
      if err then
        vim.schedule(function()
          if callbacks then
            callbacks.on_error(err)
          end
        end)
        return
      end
      if data then
        parser:feed(data)
      else
        parser:finish()
      end
    end,
    stderr = function(_, data)
      if data then
        stderr = stderr .. data
      end
    end,
  }, function(result)
    vim.schedule(function()
      local previous = callbacks
      handle = nil
      callbacks = nil
      if result.code ~= 0 and previous then
        local detail = vim.trim(stderr)
        previous.on_error("eiwa-agent exited with code " .. result.code .. (detail ~= "" and ": " .. detail or ""))
      end
      if previous and previous.on_exit then
        previous.on_exit(result.code)
      end
    end)
  end)

  return true
end

function M.send(message)
  if not handle then
    return false, "eiwa-agent is not running"
  end
  local ok, err = pcall(handle.write, handle, protocol.encode(message))
  if not ok then
    return false, tostring(err)
  end
  return true
end

function M.shutdown()
  if not handle then
    return
  end
  M.send({ type = "shutdown" })
end

function M.is_running()
  return handle ~= nil
end

return M
