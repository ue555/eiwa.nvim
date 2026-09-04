if vim.g.loaded_eiwa_nvim then
  return
end
vim.g.loaded_eiwa_nvim = true

local eiwa = require("eiwa")

vim.api.nvim_create_user_command("Eiwa", eiwa.toggle, {
  desc = "Open or close Eiwa",
})
vim.api.nvim_create_user_command("EiwaClose", eiwa.close, {
  desc = "Close Eiwa",
})
vim.api.nvim_create_user_command("EiwaClear", eiwa.clear, {
  desc = "Clear the current Eiwa session",
})
vim.api.nvim_create_user_command("EiwaCancel", eiwa.cancel, {
  desc = "Cancel the current Eiwa request",
})
vim.api.nvim_create_user_command("EiwaNewSession", eiwa.new_session, {
  desc = "Start a new Eiwa session",
})

local group = vim.api.nvim_create_augroup("EiwaNvim", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    require("eiwa.ui").resize()
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = eiwa.shutdown,
})
