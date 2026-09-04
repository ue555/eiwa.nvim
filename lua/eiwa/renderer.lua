local M = {}

local namespace = vim.api.nvim_create_namespace("eiwa-renderer")

local labels = {
  user = "> You",
  assistant = "> Assistant",
  error = "> Error",
  system = "> System",
}

local highlights = {
  user = "EiwaUser",
  assistant = "EiwaAssistant",
  error = "EiwaError",
  system = "EiwaSystem",
}

local function content_lines(content)
  if content == "" then
    return { "" }
  end
  return vim.split(content, "\n", { plain = true })
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "EiwaUser", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "EiwaAssistant", { default = true, link = "DiagnosticOk" })
  vim.api.nvim_set_hl(0, "EiwaError", { default = true, link = "DiagnosticError" })
  vim.api.nvim_set_hl(0, "EiwaSystem", { default = true, link = "Comment" })
end

function M.render(buffer, messages, status)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return
  end

  local lines = {}
  local marks = {}
  if #messages == 0 then
    lines = {
      "Enter English text in the input area.",
      "Translation is not implemented yet.",
    }
    marks[1] = "system"
  else
    for _, message in ipairs(messages) do
      local line = #lines
      table.insert(lines, labels[message.role] or ("> " .. message.role))
      marks[#marks + 1] = { line = line, role = message.role }
      vim.list_extend(lines, content_lines(message.content))
      table.insert(lines, "")
    end
  end

  if status ~= "idle" then
    table.insert(lines, "[" .. status .. "]")
  end

  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  for _, mark in ipairs(marks) do
    if type(mark) == "table" then
      vim.api.nvim_buf_set_extmark(buffer, namespace, mark.line, 0, {
        end_col = #lines[mark.line + 1],
        hl_group = highlights[mark.role] or "EiwaSystem",
      })
    end
  end
  vim.bo[buffer].modifiable = false
end

return M
