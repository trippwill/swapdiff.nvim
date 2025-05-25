return {
  'trippwill/swapdiff.nvim',
  lazy = false,
  priority = 1000,
  dependencies = {
    'folke/noice.nvim',
  },
  init = function()
    print('SwapDiff: Configuring...')
    local swapdiff = require('swapdiff')
    swapdiff.setup()
  end,
}
