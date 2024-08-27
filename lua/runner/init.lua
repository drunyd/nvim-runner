-- runner.lua

local M = {}

M.options = {
  hotkey = '<leader>r', -- Default hotkey
  output_window = 'vertical', -- Default output window type
}

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

-- Function to run multiple commands from a file sequentially
local function run_file_as_command(file_path)
  local lines = vim.fn.readfile(file_path)

  if #lines == 0 then
    print("File is empty!")
    return
  end

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

  -- Function to execute a command and handle the output in the buffer
  local function execute_command(cmd, bufnr)
    vim.fn.termopen(cmd, {
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

        -- Check if there are more commands to run
        if #lines > 0 then
          local next_cmd = table.remove(lines, 1)
          execute_command(next_cmd, bufnr) -- Execute the next command
        end
      end,
    })
  end

  -- Start executing commands from the file
  local first_cmd = table.remove(lines, 1)
  execute_command(first_cmd, bufnr)

  vim.cmd('startinsert') -- Start in insert mode in terminal
end

-- Main function to be triggered by the key mapping
function M.run()
  local project_root = find_project_root()
  if not project_root then
    print("Project root not found!")
    return
  end

  local rcfgs_dir = project_root .. "/.rcfgs"
  if vim.fn.isdirectory(rcfgs_dir) == 0 then
    vim.fn.mkdir(rcfgs_dir, "p")
    print("Created directory: " .. rcfgs_dir)
  else
    print(".rcfgs directory already exists at " .. rcfgs_dir)
  end

  require('telescope.builtin').find_files({
    prompt_title = "Find files in .rcfgs",
    cwd = rcfgs_dir,
    layout_config = { preview_width = 0.6 },
    previewer = true,
    attach_mappings = function(prompt_bufnr, map)
      local action_state = require('telescope.actions.state')
      local actions = require('telescope.actions')

      map('i', '<CR>', function()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
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
