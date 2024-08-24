# nvim-runner

**nvim-runner** is a simple yet powerful Neovim plugin that helps you quickly run commands directly from your Neovim environment. It allows you to configure and execute commands from a project-specific directory, making it easy to manage and reuse your most frequently used commands.

## Installation

To install `nvim-runner` using the Lazy package manager, follow the instructions below:

1. Add `nvim-runner` to your Lazy setup in your Neovim configuration (`init.lua` or `init.vim`):

    ```lua
    require('lazy').setup({
      {
        'drunyd/nvim-runner',
        opts = {
          hotkey = '<leader>r',  -- Optional: Customize the hotkey to run the commands
        },
      },
    })
    ```

2. Install the plugin:

    Open Neovim and run the following command:

    ```vim
    :Lazy sync
    ```

## Configuration

You can customize the hotkey used to trigger the `nvim-runner` by setting the `hotkey` option in the `opts` table as shown in the installation example. The default hotkey is `<leader>str`.

## Usage

`nvim-runner` is designed to streamline your workflow by allowing you to quickly run commands from within Neovim. Here's how to use the plugin:

### Running Commands

1. **Define Commands in Project-Specific Files:**

   - Create a `.rcfgs` directory at the root of your project if it doesn't already exist.
   - Inside the `.rcfgs` directory, create text files. Each file should contain a single command that you frequently use.

2. **Open the Command Runner:**

   - Press the configured hotkey (default: `<leader>str`, or your custom hotkey) to open a Telescope window.
   - The left panel will list all the files in the `.rcfgs` directory.
   - The right panel shows a preview of the content of the selected file.

3. **Filter and Select a Command File:**

   - Use the Telescope filter to narrow down the list of files.
   - Select the desired command file and press `<Enter>`.

4. **Create a New Command File (If Needed):**

   - If the filter results are empty and you press `<Enter>`, `nvim-runner` will create a new file in the `.rcfgs` directory with the name you typed and open it for editing.

5. **Execute the Command:**

   - When a command file is selected, `nvim-runner` reads the command in the file and executes it.
   - The output of the command is displayed in a new buffer called `outputwindow`.
   - You can see the live output of the running command, including any progress updates.

6. **Close the Output Window:**

   - After the command has finished running, you can close the `outputwindow` using the `:q` command (standard Neovim buffer close command).

### Example Use Case

Suppose you have a project where you frequently need to run a specific test command. Instead of typing the command repeatedly or keeping a terminal open, you can use `nvim-runner`:

1. Create a `.rcfgs` directory at your project root.
2. Inside `.rcfgs`, create a file named `run_tests.txt` with the following content:

    ```bash
    npm run test
    ```

3. Press `<leader>r` (or your custom hotkey) to open the runner.
4. Select `run_tests.txt` and hit `<Enter>` to execute the command listed in `run_tests.txt`.

`nvim-runner` will automatically run the command and display its output, helping you quickly iterate and test without leaving Neovim.

## Contributing

Feel free to contribute to this plugin by submitting issues or pull requests on [GitHub](https://github.com/drunyd/nvim-runner).

## License

This plugin is released under the MIT License.
