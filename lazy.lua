return {
  'trippwill/swapdiff.nvim',
  dependencies = {
    'folke/noice.nvim',
  },
  init = function()
    print('SwapDiff: Initializing...')
    local swapdiff = require('swapdiff')
    swapdiff.setup()
  end,
}
