-- runner.lua
local M = {}

M.options = {
  hotkey = '<leader>r',       -- Default hotkey
  output_window = 'vertical', -- Default output window type
}

-- Function to create a new file in the .rcfgs directory
local function create_and_edit_file(rcfgs_dir, file_name)
  local file_path = rcfgs_dir .. '/' .. file_name
  -- Create the file
  vim.fn.writefile({}, file_path)
  -- Open the file in a new buffer
  vim.cmd('edit ' .. file_path)
  print("Created and opened new file: " .. file_path)
end

-- Function to set up the output window for running commands
local function setup_output_window()
  local bufnr

  -- Create different types of windows based on the output_window option
  if M.options.output_window == 'horizontal' then
    vim.cmd('new') -- Open a new horizontal split
  elseif M.options.output_window == 'float' then
    bufnr = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    vim.api.nvim_open_win(bufnr, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'single',
    })
  else
    vim.cmd('vnew') -- Default to vertical split
  end

  if not bufnr then
    bufnr = vim.fn.bufnr() -- Get the current buffer number if not float
  end

  -- Apply window settings
  vim.cmd('setlocal buftype=nofile')
  vim.cmd('setlocal bufhidden=wipe')
  vim.cmd('setlocal nobuflisted')
  vim.cmd('setlocal nonumber')
  vim.cmd('setlocal norelativenumber')
  vim.cmd('setlocal nowrap')
  vim.cmd('setlocal signcolumn=no')

  return bufnr
end

-- Function to run a given command and show its output in the configured window
local function run_command_in_window(command)
  local bufnr = setup_output_window()

  -- Start a terminal in the new buffer
  vim.fn.termopen(command, {
    on_stdout = function(_, data, _)
      if data then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
      end
    end,
    on_stderr = function(_, data, _)
      if data then
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

-- Function to run the content of a selected file as a command
local function run_file_as_command(file_path)
  local lines = vim.fn.readfile(file_path)
  local command = table.concat(lines, "\n")
  run_command_in_window(command)
end

function M.run()
  -- local rcfgs_dir = project_root .. "/.rcfgs"
  local rcfgs_dir = vim.fn.getcwd() .. "/.rcfgs"
  vim.fn.mkdir(rcfgs_dir, "p")

  -- Now launch Telescope find_files, optimized to reduce delay
  require('telescope.builtin').find_files({
    prompt_title = "Find files in .rcfgs",
    cwd = rcfgs_dir,
    layout_config = { preview_width = 0.6 },
    previewer = true, -- Disable the previewer for faster loading (or set to true if necessary)
    attach_mappings = function(prompt_bufnr, map)
      local action_state = require('telescope.actions.state')
      local actions = require('telescope.actions')

      -- Debouncing the mapping for a slight performance boost
      vim.defer_fn(function()
        map('i', '<CR>', function()
          local selection = action_state.get_selected_entry()

          if selection == nil then
            local new_file_name = action_state.get_current_line()

            if new_file_name ~= "" then
              actions.close(prompt_bufnr)
              create_and_edit_file(rcfgs_dir, new_file_name)
            else
              print("No file name provided!")
            end
          else
            actions.close(prompt_bufnr)
            run_file_as_command(selection.path)
          end
        end)
      end, 10) -- Delay to debounce

      return true
    end
  })
end

-- New function to run an exact command directly
function M.run_command(cmd)
  if not cmd or cmd == "" then
    print("No command provided!")
    return
  end

  run_command_in_window(cmd)
end

function M.setup(opts)
  M.options = vim.tbl_extend('force', M.options, opts or {})

  vim.api.nvim_set_keymap('n', M.options.hotkey, '<cmd>lua require("nvim-runner").run()<CR>',
    { noremap = true, silent = true })

  vim.api.nvim_create_user_command('RunnerRun', function()
    require('nvim-runner').run()
  end, { desc = 'Run the Runner plugin function' })

  -- New user command to run an exact command
  vim.api.nvim_create_user_command('RunnerRunCmd', function(args)
    require('nvim-runner').run_command(table.concat(args.fargs, " "))
  end, {
    nargs = '+',
    desc = 'Run a specific command directly',
  })
end

function get_robot_test_case_name()
  local bufnr = vim.api.nvim_get_current_buf()      -- Get the current buffer
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- Get the current cursor position
  local line_num = cursor_pos[1]                    -- Line number (1-based index)

  -- Iterate from the current line upwards to find the test case name
  for i = line_num, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]

    -- Check if the line starts with non-whitespace characters (which is usually a test case header in Robot Framework)
    if line:match("^%S") then
      -- Return the found test case name
      return line
    end
  end

  return nil -- If no test case name is found, return nil
end

-- Function to get the current file path relative to the project root
function get_relative_file_path()
  -- Get the absolute path of the current file
  local filepath = vim.api.nvim_buf_get_name(0)

  -- Use Neovim's built-in functionality to get the project root directory
  local root_dir = vim.fn.finddir(".git", ".;") -- Assuming .git is the project root marker

  if root_dir == "" then
    root_dir = vim.fn.getcwd() -- If .git is not found, use the current working directory
  end

  -- Get the relative file path from the project root
  local relative_path = vim.fn.fnamemodify(filepath, ":." .. root_dir)

  return relative_path
end

-- Helper function to get the content of the "prefix" file if it exists
local function get_prefix_content(rcfgs_dir)
  local prefix_file_path = rcfgs_dir .. "/prefix"
  if vim.fn.filereadable(prefix_file_path) == 1 then
    local lines = vim.fn.readfile(prefix_file_path)
    return table.concat(lines, " ") .. " " -- Join lines with spaces and add a trailing space
  end
  return ""
end

-- Function to build the full command for a specific test case
function M.build_robot_command_test_case()
  local test_case_name = get_robot_test_case_name()
  if not test_case_name then
    print("No test case found")
    return
  end

  local relative_file_path = get_relative_file_path()
  local rcfgs_dir = vim.fn.getcwd() .. "/.rcfgs"
  local prefix_content = get_prefix_content(rcfgs_dir)

  require('telescope.builtin').find_files({
    prompt_title = "Select configuration file",
    cwd = rcfgs_dir,
    layout_config = { preview_width = 0.6 },
    previewer = true,
    attach_mappings = function(prompt_bufnr, map)
      local action_state = require('telescope.actions.state')
      local actions = require('telescope.actions')

      map('i', '<CR>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          actions.close(prompt_bufnr)
          local tc_file_path = selection.path
          local tc_content = ""

          if vim.fn.filereadable(tc_file_path) == 1 then
            local lines = vim.fn.readfile(tc_file_path)
            tc_content = table.concat(lines, " ")
          end

          local command = prefix_content ..
          "robot -t \"" .. test_case_name .. "\" " .. tc_content .. " " .. relative_file_path
          print("Command: " .. command)
          M.run_command(command)
        else
          print("No file selected!")
        end
      end)

      return true
    end
  })
end

-- Function to build the full command for the current file
function M.build_robot_command_ts()
  local relative_file_path = get_relative_file_path()
  local rcfgs_dir = vim.fn.getcwd() .. "/.rcfgs"
  local prefix_content = get_prefix_content(rcfgs_dir)

  require('telescope.builtin').find_files({
    prompt_title = "Select configuration file",
    cwd = rcfgs_dir,
    layout_config = { preview_width = 0.6 },
    previewer = true,
    attach_mappings = function(prompt_bufnr, map)
      local action_state = require('telescope.actions.state')
      local actions = require('telescope.actions')

      map('i', '<CR>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          actions.close(prompt_bufnr)
          local tc_file_path = selection.path
          local tc_content = ""

          if vim.fn.filereadable(tc_file_path) == 1 then
            local lines = vim.fn.readfile(tc_file_path)
            tc_content = table.concat(lines, " ")
          end

          local command = prefix_content .. "robot " .. tc_content .. " " .. relative_file_path
          print("Command: " .. command)
          M.run_command(command)
        else
          print("No file selected!")
        end
      end)

      return true
    end
  })
end

return M
