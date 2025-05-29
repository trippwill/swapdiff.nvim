local M = {}

local api, fn, v = vim.api, vim.fn, vim.v
local util = require('swapdiff.util')
local abs_path, abs_dir, remove_prefix = util.abs_path, util.abs_dir, util.remove_prefix

local _log = require('swapdiff.log').nil_logger()

---@param filename string
---@return SwapDiffSwapInfo[]
local function get_swapfiles_for_file(filename)
  local abs_filename = abs_path(filename)
  local swaps = fn.swapfilelist()

  ---@type SwapDiffSwapInfo[]
  local results = {}
  local swap_dir = abs_dir(v.swapname) .. '//' -- get the swap directory from the current swapname
  for _, swap in ipairs(swaps) do
    local abs_swap = abs_path(remove_prefix(swap_dir, swap))

    -- _log:printf('swap path transformed %s -> %s', swap, abs_swap)

    local info = fn.swapinfo(abs_swap)
    local abs_fname = abs_path(info.fname)
    if info and abs_fname == abs_filename and info.dirty ~= 0 then
      table.insert(results, { filepath = abs_fname, info = info, swappath = abs_swap })
    end
  end
  return results
end

---@type autocmd_callback
function M.onSwapExists(args)
  -- _log:printfn(function()
  --   return vim.inspect(vim.api.nvim_get_autocmds({ event = 'SwapExists' }))
  -- end)

  if v.swapchoice and v.swapchoice ~= '' then
    _log:debug("vim.v.swapchoice is already set to '%s' for file '%s', skipping SwapDiff", v.swapchoice, args.file)
    return
  end

  local abs_file = abs_path(args.file)
  local swapfiles = get_swapfiles_for_file(abs_file)

  if #swapfiles == 0 then
    _log:printf('No dirty swapfiles found for %s', abs_file)
    return
  end

  _log:printf('Found %i dirty swapfiles for %s', #swapfiles, abs_file)

  local pending = {
    filename = abs_file,
    swapfiles = swapfiles,
  }

  -- Set up BufReadPost autocmd for handling recovery and diff
  api.nvim_create_autocmd('BufWinEnter', {
    pattern = abs_file,
    callback = function(args2)
      local primary_handler = require('swapdiff.handlers').PrimaryBufferHandler:new(_log, pending)
      return primary_handler:onBufWinEnter(args2, false)
    end,
  })

  api.nvim_buf_create_user_command(args.buf, 'SwapDiffRecover', function()
    local primary_handler = require('swapdiff.handlers').PrimaryBufferHandler:new(_log, pending)
    return primary_handler:onBufWinEnter({ file = abs_file, buf = args.buf }, true)
  end, {
    desc = 'Recover and diff all swapfiles for the current file',
    force = true,
    nargs = 0,
    bang = true,
  })

  v.swapchoice = 'e' -- Open the file normally
end

M.defaults = {
  log_level = vim.log.levels.TRACE, -- Default log level
}

function M.setup(opts)
  print('SwapDiff Handler: Setting up with options:', vim.inspect(opts))
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})
  _log = require('swapdiff.log').logger({
    title = 'SwapDiff',
    level = M.config.log_level,
  })
end

return M
