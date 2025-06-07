# SwapDiff.nvim

SwapDiff.nvim is a Neovim plugin that enhances swapfile conflict handling by providing interactive recovery, diffing, and deletion of dirty swapfiles. Avoid data loss and make informed decisions when Neovim detects swapfile conflicts.

## Features

- **Interactive prompt** when swapfile conflicts are detected
- **Diff and recover** changes from dirty swapfiles
- **Delete swapfiles** safely from within Neovim
- **View diagnostic logs** in a floating window or buffer
- **Seamless integration** with Neovim's event system

## Installation

**Requirements:** Neovim 0.9+

Install with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'trippwill/swapdiff.nvim',
}
```

lazy.nvim will use the [lazy.lua](./lazy.lua) file by default which sets up everything to work out of the box. 🤞

The lazy.lua plugin spec includes:
  - init: ensures the SwapExists handler is in the chain when Neovim starts
  - event: ensures the plugin is setup when a swapfile exists
  - cmd: ensures the plugin is loaded for user commands
  - opt: activates the default config function
  - dependencies: ensure UI enhancement plugins load with swapdiff.nvim

To configure the plugin without lazy.nvim, use the lazy.lua as a guide.

## Quickstart

1. Install SwapDiff.nvim as above.
2. Open a file with an existing dirty swapfile.
3. When prompted, choose to recover, diff, delete, or ignore the swapfile.

## Configuration

You can customize SwapDiff in your Neovim config. These are the default settings:

```lua
require('swapdiff').setup({
  prompt_config = {
    style = 'Interactive', -- Options: 'Interactive', 'Notify', 'None'
    once = false, -- Show prompt only once per swapfile
  },
  log_level = levels.DEBUG,
  notify_level = levels.INFO,
  log_win_config = {
    relative = 'editor',
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor((vim.o.lines - vim.o.lines * 0.8) / 2),
    col = math.floor((vim.o.columns - vim.o.columns * 0.8) / 2),
    style = 'minimal',
    border = 'rounded',
    title = 'SwapDiff Log',
    footer = '<q> to close',
    footer_pos = 'right',
  },
})
```

## Commands

- `:SwapDiff` – Starts the interactive prompt if dirty swapfiles are detected for the current buffer. Especially useful when prompt style is set to 'Notify' or 'None'.
- `:SwapDiffLog` – Open a floating window or buffer with the SwapDiff log. Press `q` to close.

## FAQ

**Q: Why don't I see the prompt when opening a file with a swapfile?**  
A: Make sure the plugin is installed and loaded on the `SwapExists` event. Check your lazy.nvim config.

**Q: How do I recover changes from a swapfile?**  
A: Choose "Recover and diff all swapfiles" from the prompt when it appears.

## Contributing

Contributions are welcome! Please open issues or submit pull requests.


## Disclaimer

This plugin is under active development. Use at your own risk.

## License

Copyright 2025 contributors of SwapDiff.nvim

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


See the [LICENSE](LICENSE) file for details.

## How It Works

SwapDiff hooks into Neovim's `SwapExists` event. When you open a file with an existing dirty swapfile, SwapDiff intercepts the default prompt and provides an interactive menu. You can choose to recover, diff, delete, or ignore the swapfile, helping you avoid accidental data loss.

## Advanced Usage

- **Bufferline Integration:**  
  If you use [bufferline.nvim](https://github.com/akinsho/bufferline.nvim), SwapDiff provides a replacement for the default `go_to` function to ensure swapfile checks are triggered when switching buffers.

- **Log Viewing:**  
  Use `:SwapDiffLog` to open the log in a floating window. Change the window config in your setup.

- **Prompt Styles:**  
  The `prompt_config.style` option supports `'Interactive'`, `'Notify'`, or `'None'` for different user experiences.

## Troubleshooting

- **Prompt Not Appearing:**  
  Ensure SwapDiff is loaded on the `SwapExists` event. Check your plugin manager configuration.

- **Log Window Not Opening:**  
  Make sure the log buffer is initialized. Try running `:SwapDiffLog` after triggering a swapfile event.

- **Debug Logging:**  
  Set `log_level = vim.log.levels.DEBUG` in your config for more verbose logs.

## Development

- **Generating Documentation:**  
  Run `sh doc.sh doc/swapdiff.nvim.txt doclist` to generate Vim help docs using [vimcats](https://github.com/triptychlabs/vimcats).

- **File Structure:**
  - `lua/swapdiff/` – Core plugin code
  - `lua/tmi/` – Logging framework
  - `tests/` – Unit tests
  - `README.md` – This file
  - `doc/` – Vim help documentation


## Documentation

- Vim help: `:help swapdiff`
- Inline LuaDoc: See comments in source files


## The tmi logging framework

More logging than you probably need!

SwapDiff.nvim includes the **tmi** logging framework for flexible, multi-sink logging. tmi allows logs to be sent to Neovim notifications, scratch buffers, the message area, or files. See the `lua/tmi/` directory for implementation details and the Vim help docs for usage examples.

Example log sinks:
- BufferLogSink: logs to a scratch buffer (view with `:SwapDiffLog`)
- NotifyLogSink: logs as Neovim notifications
- PrintLogSink: logs to the message area
- FileLogSink: logs to a file on disk

You can add or remove sinks and adjust log levels to suit your workflow.
