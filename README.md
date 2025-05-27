# SwapDiff.nvim

SwapDiff.nvim is a Neovim plugin designed to improve swapfile handling by providing recovery and diffing capabilities for dirty swapfiles. This plugin is still in development and is not yet ready for production use.

## Installation
To install SwapDiff.nvim using [lazy.nvim](https://github.com/folke/lazy.nvim), add the following configuration to your lazy.nvim setup:

```lua
{
  'trippwill/swapdiff.nvim',
  init = function()
    local swapdiff = require('swapdiff')
    swapdiff.setup()
  end,
}
```

## Usage
SwapDiff.nvim currently works by watching for the `SwapExists` event in Neovim. When a swapfile conflict is detected, the plugin prompts the user with options to recover and diff the swapfiles, delete them, or edit the file normally.

Currently, the plugin is in development and additional instructions will be provided once it is stable.

## Contributing
Contributions are welcome! Feel free to open issues or submit pull requests.

## Disclaimer
This plugin is under active development. Use it at your own risk.

