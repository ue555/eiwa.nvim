local M = {}

function M.new(on_message, on_error)
  local pending = ""

  return {
    feed = function(_, chunk)
      if not chunk or chunk == "" then
        return
      end
      pending = pending .. chunk
      while true do
        local newline = pending:find("\n", 1, true)
        if not newline then
          break
        end
        local line = pending:sub(1, newline - 1)
        pending = pending:sub(newline + 1)
        if line ~= "" then
          local ok, event = pcall(vim.json.decode, line)
          if ok then
            on_message(event)
          else
            on_error("invalid agent response: " .. line)
          end
        end
      end
    end,
    finish = function(self)
      if pending ~= "" then
        self:feed("\n")
      end
    end,
  }
end

function M.encode(message)
  return vim.json.encode(message) .. "\n"
end

return M
