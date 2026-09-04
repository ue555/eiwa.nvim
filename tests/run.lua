local ok, err = xpcall(function()
  dofile("tests/eiwa_spec.lua")
end, debug.traceback)

if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end

vim.defer_fn(function()
  vim.cmd("qa!")
end, 100)
