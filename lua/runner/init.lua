-- lua/runner/init.lua

local M = {}

function M.setup()
  -- Print a message to verify that setup is running
  print("Running setup() function for runner plugin")
  
  -- Define key mapping for <leader>str
  vim.api.nvim_set_keymap('n', '<leader>str', '<cmd>lua require("runner.runner").run()<CR>', { noremap = true, silent = true })
end

-- Automatically call setup when the module is required
M.setup()

return M
