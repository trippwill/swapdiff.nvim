---@mod swapdiff.primarybufferhandler PrimaryBufferHandler Module
---@brief [[
---Support module for handling buffer events in SwapDiff.
---@brief ]]

---@class PrimaryBufferHandler
---@field private _pending? SwapDiffBuffer
---@field private _log Logger
---@field private _recovery_handler? RecoveryTabHandler
---@field private _user_choice? number
local PrimaryBufferHandler = {}

local RecoveryTabHandler = require('swapdiff.RecoveryTabHandler')

local ui = require('swapdiff.ui')
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
---@param config SwapDiffPromptConfig
function PrimaryBufferHandler:onBufWinEnter(args, config)
  local _log = self._log
  _log:trace('onBufWinEnter called with args: %s\n%s', vim.inspect(args), vim.inspect(config))

  if config.style == 'Interactive' then
    if config.once and self._user_choice then
      _log:debug("User choice is already set for file '%s', skipping SwapDiff prompt", tail_path(args.file))
      return
    end
    self:prompt()
  elseif config.style == 'Notify' then
    self:notify(args, config)
  else
    -- TODO: handle 'None' style or other styles
    _log:warn('Unknown prompt style: %s', config.style)
  end
end

---Notify the user about dirty swap files for the buffer.
---@param args AutoCmdArgs
---@param config SwapDiffPromptConfig
function PrimaryBufferHandler:notify(args, config)
  local notify = config.once and vim.notify_once or vim.notify
  vim.schedule(function()
    notify(
      string.format(
        'SwapDiff: %s has dirty swapfiles.\n|:SwapDiff| to activate the recovery prompt.',
        tail_path(args.file)
      ),
      vim.log.levels.WARN,
      {
        id = string.format('swapdiff_%s', args.file),
        title = 'SwapDiff',
        icon = '',
        timeout = 5000,
      }
    )
  end)
end

---Prompt the user to recover or handle swap files for the buffer.
function PrimaryBufferHandler:prompt()
  local _log = self._log

  local relfile, absfile, swapinfos = assert_pending(self._pending, abs_path(vim.api.nvim_buf_get_name(0)))

  local menu_items = {
    {
      'Recover and diff all swapfiles',
      function()
        self._recovery_handler = RecoveryTabHandler:new(_log, self._pending, function(tabpage)
          _log:trace('Recovery tab closed %d, cleaning up handler', tabpage)
          self._recovery_handler = nil
        end)
        self._recovery_handler:start_recovery(absfile)
      end,
    },
    { 'Edit file normally, leaving swapfiles intact', nil },
    {
      'Delete all swapfiles and edit file normally',
      function()
        local fn = vim.fn
        for _, swapinfo in ipairs(swapinfos) do
          _log:info('Deleting swapfile: %s', swapinfo.swappath)
          fn.delete(swapinfo.swappath) -- remove the swap file
        end
      end,
    },
  }

  local open_select = vim.schedule_wrap(ui.open_select)
  open_select(
    string.format('SwapDiff: %s has %d dirty swapfiles:', tail_path(relfile), #swapinfos),
    vim.tbl_map(function(menu_item)
      return menu_item[1]
    end, menu_items),
    function(item, idx)
      self._user_choice = idx
      _log:trace('User selected item: %s (index: %d)', item, idx or 'nil')
      local action = menu_items[idx][2]
      if type(action) == 'function' then
        action()
      end
    end
  )
end

return PrimaryBufferHandler
