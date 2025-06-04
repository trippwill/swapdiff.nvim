return {
  'trippwill/swapdiff.nvim',
  dependencies = {
    {
      'folke/snacks.nvim',
    },
    {
      'folke/noice.nvim',
      optional = true,
    },
    {
      'akinsho/bufferline.nvim',
      optional = true,
    },
    {
      'nvim-lua/plenary.nvim',
      optional = true,
    },
  },
  cmd = {
    'SwapDiff',
    'SwapDiffLog',
  },
  event = 'SwapExists',
  opts = {},
  init = function()
    local api = vim.api
    local augrp_id = api.nvim_create_augroup('swapdiff-augrp', { clear = true })
    api.nvim_create_autocmd('SwapExists', {
      group = augrp_id,
      pattern = '*',
      callback = function(args)
        require('swapdiff').onSwapExists(args)
      end,
    })
  end,
}
