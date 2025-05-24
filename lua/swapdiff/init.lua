local M = {}

function M.setup()
  local api = vim.api
  local handlers = require('swapdiff.handler')
  api.nvim_create_autocmd('SwapExists', {
    group = handlers.augroup,
    pattern = '*',
    callback = handlers.onSwapExists,
    desc = 'SwapDiff: Handle Swap Exists',
  })
end

return M
