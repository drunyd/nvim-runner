-- runner.lua
local M = {}

M.options = {
  hotkey = '<leader>r', -- Default hotkey
  output_window = 'vertical', -- Default output window type
}

-- Function to find the root directory of the Git project
local function find_project_root()
  -- Search for the .git directory from the current file's path upwards
  local git_root = vim.fn.finddir(".git", ".;")
  
  if git_root == "" then
    -- If .git is not found, print a message and return nil
    print("Project root not found! Not a Git repository.")
    return nil
  else
    -- Return the root directory (strip the .git from the path)
    return vim.fn.fnamemodify(git_root, ":h")
  end
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
  local lines = vim.fn.readfile(file_path)
  local command = table.concat(lines, "\n")

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

  vim.cmd('setlocal buftype=nofile')
  vim.cmd('setlocal bufhidden=wipe')
  vim.cmd('setlocal nobuflisted')
  vim.cmd('setlocal nonumber')
  vim.cmd('setlocal norelativenumber')
  vim.cmd('setlocal nowrap')
  vim.cmd('setlocal signcolumn=no')

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

function M.run()
  -- Finding project root and handling when it's not found
  local project_root = find_project_root()
  if not project_root then
    print("Project root not found!")
    return
  end

  local rcfgs_dir = project_root .. "/.rcfgs"

  -- Check if the directory exists, create if necessary
  -- if vim.fn.isdirectory(rcfgs_dir) == 0 then
  --   vim.fn.mkdir(rcfgs_dir, "p")
  --   print("Created directory: " .. rcfgs_dir)
  -- else
  --   print(".rcfgs directory already exists at " .. rcfgs_dir)
  -- end

  -- Now launch Telescope find_files, optimized to reduce delay
  require('telescope.builtin').find_files({
    prompt_title = "Find files in .rcfgs",
    cwd = rcfgs_dir,
    layout_config = { preview_width = 0.6 },
    previewer = true,  -- Disable the previewer for faster loading (or set to true if necessary)
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

function M.setup(opts)
  M.options = vim.tbl_extend('force', M.options, opts or {})

  vim.api.nvim_set_keymap('n', M.options.hotkey, '<cmd>lua require("runner").run()<CR>',
    { noremap = true, silent = true })

  vim.api.nvim_create_user_command('RunnerRun', function()
    require('runner').run()
  end, { desc = 'Run the Runner plugin function' })
end

return M
