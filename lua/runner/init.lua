
  -- Print a message to verify that setup is running
  print("Running setup() function for runner plugin")
  
  -- Define key mapping for <leader>str
  vim.api.nvim_set_keymap('n', '<leader>str', '<cmd>lua require("runner.runner").run()<CR>', { noremap = true, silent = true })

-- Automatically call setup when the module is required

-- Create a Neovim command to call the run function
vim.api.nvim_create_user_command('RunnerRun', function()
  require('runner.runner').run()
end, { desc = 'Run the Runner plugin function' })

