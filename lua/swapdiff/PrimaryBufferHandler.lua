---@mod swapdiff.primarybufferhandler PrimaryBufferHandler Module
---@brief [[
---Support module for handling buffer events in SwapDiff.
---@brief ]]

---@class PrimaryBufferHandler
---@field private _pending? SwapDiffBuffer
---@field private _log Logger
local PrimaryBufferHandler = {}

local RecoveryTabHandler = require('swapdiff.RecoveryTabHandler')

local util = require('swapdiff.util')
local tail_path, abs_path, assert_pending = util.tail_path, util.abs_path, util.assert_pending

---Create a new PrimaryBufferHandler instance
---@param log Logger
---@param pending SwapDiffBuffer
---@return PrimaryBufferHandler
function PrimaryBufferHandler:new(log, pending)
  local obj = setmetatable({}, { __index = self })
  obj._log = log
  obj._pending = pending
  return obj
end

---Handle the BufWinEnter event
---@param args AutoCmdArgs
---@param force boolean? whether to force the handler to run even if a selection has been made
function PrimaryBufferHandler:onBufWinEnter(args, force)
  self._log:trace('onBufWinEnter called with args: %s', vim.inspect(args))
  if not force then
    local ok, res = pcall(vim.api.nvim_buf_get_var, args.buf, 'swapdiff_choice')
    if ok and res ~= nil then
      self._log:debug(
        "swapdiff_choice is already set for file '%s', skipping SwapDiffRecover prompt",
        tail_path(args.file)
      )
      return
    end
  end
  self:prompt()
end

function PrimaryBufferHandler:prompt()
  local _log = self._log
  local fn = vim.fn

  local relfile, absfile, swapinfos = assert_pending(self._pending, abs_path(vim.api.nvim_buf_get_name(0)))

  vim.schedule(function()
    vim.ui.select({
      'Recover and diff all swapfiles',
      'Edit file normally, leaving swapfiles intact',
      'Delete all swapfiles and edit file normally',
    }, {
      prompt = string.format('SwapDiff: found %d dirty swapfile(s) for %s:', #swapinfos, relfile),
    }, function(item, idx)
      _log:trace('User choice: %d %s', idx or -1, item)

      vim.api.nvim_buf_set_var(0, 'swapdiff_choice', idx or -1)

      if idx == 1 then
        local recovery_handler = RecoveryTabHandler:new(_log, self._pending)
        recovery_handler:start_recovery(absfile)
      elseif idx == 2 then -- just open the file normally, leaving swapfiles intact
        return
      elseif idx == 3 then -- delete all swapfiles and open the file normally
        for _, swapinfo in ipairs(swapinfos) do
          _log:info('Deleting swapfile: %s', swapinfo.swappath)
          fn.delete(swapinfo.swappath) -- remove the swap file
        end
        return
      else
        return -- unexpected choice, just open the file normally
      end
    end)
  end)
end

return PrimaryBufferHandler
