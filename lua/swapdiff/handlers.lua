---@class PrimaryBufferHandler
---@field _pending? SwapDiffPending
---@field _log Logger
local PrimaryBufferHandler = {
  _pending = nil,
  _log = require('swapdiff.log').nil_logger(),
}

---Constructor for PrimaryBufferHandler
---@param self PrimaryBufferHandler
---@param log Logger
---@param pending SwapDiffPending
---@return PrimaryBufferHandler
function PrimaryBufferHandler:new(log, pending)
  local obj = setmetatable({}, { __index = self })
  obj._log = log or require('swapdiff.log').nil_logger()
  obj._pending = pending
  return obj
end

---Handle the BufWinEnter event
---@param self PrimaryBufferHandler
---@param args AutoCmdArgs
---@param force boolean? whether to force the handler to run even if a selection has been made
function PrimaryBufferHandler:onBufWinEnter(args, force)
  local _log = self._log
  local fn = vim.fn
  local abs_path = require('swapdiff.util').abs_path
  local tail_path = require('swapdiff.util').tail_path

  --  _log:print('onBufWinEnter called with args:', vim.inspect(args))

  local filename, swapfiles = self:validate_pending(abs_path(args.file))

  if not force then
    local ok, res = pcall(vim.api.nvim_buf_get_var, args.buf, 'swapdiff_choice')
    if ok and res ~= nil then
      _log:debug("swapdiff_choice is already set for file '%s', skipping SwapDiff", tail_path(filename))
      return
    end
  end

  vim.schedule(function()
    vim.ui.select({
      'Recover and diff all swapfiles',
      'Edit file normally, leaving swapfiles intact',
      'Delete all swapfiles and edit file normally',
    }, {
      prompt = string.format('SwapDiff: found %d dirty swapfile(s) for %s:', #swapfiles, tail_path(filename)),
    }, function(_, idx)
      --_log:printf('User choice: %d %s', idx or -1, item)

      vim.api.nvim_buf_set_var(args.buf, 'swapdiff_choice', idx or -1)

      if idx == 1 then
        require('swapdiff.handler').start_recovery(args, filename, swapfiles)
      elseif idx == 2 then -- just open the file normally, leaving swapfiles intact
        return
      elseif idx == 3 then -- delete all swapfiles and open the file normally
        for _, swapfile in ipairs(swapfiles) do
          _log:notify('Deleting swapfile: %s', swapfile.swappath)
          fn.delete(swapfile.swappath) -- remove the swap file
        end
        return
      else
        return -- unexpected choice, just open the file normally
      end
    end)
  end)
end

---Validate the pending state before proceeding with recovery
---@param self PrimaryBufferHandler
---@param abs_file string
---@return string, SwapDiffSwapInfo[]
function PrimaryBufferHandler:validate_pending(abs_file)
  local pending = assert(self._pending, 'SwapDiff pending state should not be nil when handling BufReadPost')
  local filename = assert(pending.filename, 'SwapDiff pending state should have a filename')
  assert(filename == abs_file, 'SwapDiff pending state filename should match the opened file')
  local swapfiles = assert(pending.swapfiles, 'SwapDiff pending state should have swapfiles')
  assert(#swapfiles > 0, 'SwapDiff pending state should have non-empty swapfiles')
  return filename, swapfiles
end

return {
  PrimaryBufferHandler = PrimaryBufferHandler,
}
