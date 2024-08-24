-- runner.lua

local M = {}

M.options = {
  hotkey = '<leader>str', -- Default hotkey
}

M.runner_hotkey_run = "<leader>r"

-- Function to find the root directory of the project
local function find_project_root()
  local candidates = { '.git', 'project.toml', 'bruno.json', 'package.json' }
  local current_dir = vim.fn.expand('%:p:h')

  while current_dir ~= "/" do
    for _, candidate in ipairs(candidates) do
      if vim.fn.globpath(current_dir, candidate) ~= "" then
        return current_dir
      end
    end
    current_dir = vim.fn.fnamemodify(current_dir, ':h')
  end

  return nil
end

-- Function to create a new file in the .rcfgs directory
local function create_and_edit_file(rcfgs_dir, file_name)
  local file_path = rcfgs_dir .. '/' .. file_name
  -- Create the file
  vim.fn.writefile({}, file_path)
  -- Open the file in a new buffer
  vim.cmd('edit ' .. file_path)
  print("Created and opened new file: " .. file_path)
end

-- Function to run the content of a selected file as a command
local function run_file_as_command(file_path)
  -- Read the content of the file
  local lines = vim.fn.readfile(file_path)
  local command = table.concat(lines, "\n")

  -- Open a new buffer for output window
  vim.cmd('vnew')                      -- Open a new vertical split
  vim.cmd('setlocal buftype=nofile')   -- Buffer is not related to a file
  vim.cmd('setlocal bufhidden=wipe')   -- Wipe buffer when abandoned
  vim.cmd('setlocal nobuflisted')      -- Buffer won't appear in the buffer list
  vim.cmd('setlocal nonumber')         -- Hide line numbers
  vim.cmd('setlocal norelativenumber') -- Hide relative line numbers
  vim.cmd('setlocal nowrap')           -- Don't wrap lines
  vim.cmd('setlocal signcolumn=no')    -- Don't show the sign column

  local bufnr = vim.fn.bufnr()         -- Get the current buffer number

  -- Start a terminal in the new buffer
  vim.fn.termopen(command, {
    on_stdout = function(_, data, _)
      if data then
        -- Append lines to the buffer
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        -- Append lines to the buffer
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
      end
    end,
    on_exit = function(_, code, _)
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "\nProcess exited with code: " .. code })
      vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', ':bd!<CR>', { noremap = true, silent = true }) -- Bind 'q' to close the buffer
    end,
  })

  vim.cmd('startinsert') -- Start in insert mode in terminal
end

-- Main function to be triggered by the key mapping
function M.run()
  local project_root = find_project_root()
  if not project_root then
    print("Project root not found!")
    return
  end

  -- Check if .rcfgs directory exists, if not create it
  local rcfgs_dir = project_root .. "/.rcfgs"
  if vim.fn.isdirectory(rcfgs_dir) == 0 then
    vim.fn.mkdir(rcfgs_dir, "p")
    print("Created directory: " .. rcfgs_dir)
  else
    print(".rcfgs directory already exists at " .. rcfgs_dir)
  end

  -- Use Telescope to display files in the .rcfgs directory
  require('telescope.builtin').find_files({
    prompt_title = "Find files in .rcfgs",
    cwd = rcfgs_dir,
    layout_config = { preview_width = 0.6 },
    previewer = true,
    attach_mappings = function(prompt_bufnr, map)
      local action_state = require('telescope.actions.state')
      local actions = require('telescope.actions')

      -- Add custom mapping for <CR> (Enter key)
      map('i', '<CR>', function()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local selection = action_state.get_selected_entry()

        if selection == nil then
          -- No selection means the list is empty, use the current prompt text as the new file name
          local new_file_name = action_state.get_current_line()

          if new_file_name ~= "" then
            actions.close(prompt_bufnr) -- Close the Telescope prompt
            create_and_edit_file(rcfgs_dir, new_file_name)
          else
            print("No file name provided!")
          end
        else
          -- If a file is selected, run it as a command
          actions.close(prompt_bufnr)
          run_file_as_command(selection.path)
        end
      end)

      return true
    end
  })
end

function M.setup(opts)
  M.options = vim.tbl_extend('force', M.options, opts or {})
  -- Define key mapping for <leader>str
  vim.api.nvim_set_keymap('n', M.options.hotkey, '<cmd>lua require("runner.init").run()<CR>',
    { noremap = true, silent = true })

  -- Automatically call setup when the module is required

  -- Create a Neovim command to call the run function
  vim.api.nvim_create_user_command('RunnerRun', function()
    require('runner.init').run()
  end, { desc = 'Run the Runner plugin function' })
end

return M
