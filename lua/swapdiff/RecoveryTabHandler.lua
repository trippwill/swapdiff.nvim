---@mod swapdiff.recoverytabhandler RecoveryTabHandler Module
---@brief [[
---Support module for managing recovery tabs in SwapDiff.
---@brief ]]

---@class RecoveryTabHandler
---@field private _augroup integer
---@field _log Logger
---@field _pending SwapDiffBuffer?
local RecoveryTabHandler = {}

local api, fn = vim.api, vim.fn
local open_menu_window = require('swapdiff.ui').open_menu_window
local util = require('swapdiff.util')
local tail_path, assert_pending = util.tail_path, util.assert_pending

function RecoveryTabHandler:new(log, pending)
  local obj = setmetatable({}, { __index = self })
  obj._augroup = api.nvim_create_augroup('SwapDiffRecovery', { clear = false })
  obj._log = log or require('tmi.Logger'):empty()
  obj._pending = pending
  return obj
end

---@private
---@param args AutoCmdArgs
function RecoveryTabHandler:onBufWipeout(args)
  self._log:trace('onBufDelete called with args: %s', vim.inspect(args))
  local tmpfile = args.match

  self._log:trace('Deleting temporary file %s', tmpfile)
  fn.delete(tmpfile)
end

---@private
---@param swapfile SwapDiffSwapInfo
function RecoveryTabHandler:recover_swapfile(swapfile)
  local _log = self._log

  ---@async
  return coroutine.wrap(function()
    local tmpfile = vim.fn.tempname()
    _log:trace('Temporary file for recovery %s', tmpfile)

    local cmd = {
      'nvim',
      '--noplugin', -- no config
      '--headless',
      '-n', -- no swapfile,
      '-r',
      string.format('+w! %s', tmpfile), -- write to a temporary file
      '+q!', -- quit after writing
      swapfile.swappath, -- swap file to recover
    }

    local co = coroutine.running()

    -- Start vim.system and yield control
    vim.system(cmd, { text = true }, function(out)
      vim.schedule(function()
        coroutine.resume(co, out)
      end)
    end)

    -- Yield until vim.system callback resumes the coroutine
    local out = coroutine.yield()

    if out.code ~= 0 then
      _log:warn('Failed to recover swapfile', swapfile.swappath, out.code, out.stderr)
      vim.cmd.vnew()
      api.nvim_buf_set_lines(0, 0, 0, false, { 'Failed to recover swapfile: ' .. swapfile.swappath, out.stderr })
    else
      _log:trace('Recovered swapfile: %s to temporary file %s', swapfile.swappath, tmpfile)
      vim.cmd('vert noswapfile diffsplit ' .. tmpfile)

      local title = 'RECOVERED: ' .. tmpfile
      vim.wo.winbar = title
      vim.bo.readonly = true
      vim.bo.modifiable = false
      vim.bo.bufhidden = 'wipe'

      local bufnr = api.nvim_get_current_buf()

      api.nvim_buf_set_var(bufnr, 'swappath', swapfile.swappath)
      api.nvim_create_autocmd('BufWipeout', {
        buffer = bufnr,
        once = true,
        callback = function(args)
          self:onBufWipeout(args)
        end,
      })
    end
  end)
end

---@async
---@param fpath string expected absolute file path to recover
function RecoveryTabHandler:start_recovery(fpath)
  local _log = self._log
  local filename, _, swapfiles = assert_pending(self._pending, fpath)
  vim.cmd.tabnew(filename) -- Open the file in a new tab
  vim.wo[0].winbar = 'CURRENT: ' .. tail_path(filename)
  _log:info('Recovering %d swapfiles for %s', #swapfiles, filename)

  local main_win = vim.api.nvim_get_current_win()
  vim.cmd('wincmd t')
  open_menu_window({
    {
      desc = 'Delete all swapfiles and return to current file.',
      callback = function()
        _log:trace('User chose to delete all swapfiles and edit file normally')
        for _, swapfile in ipairs(swapfiles) do
          _log:trace('Deleting swapfile: %s', swapfile.swappath)
          fn.delete(swapfile.swappath) -- remove the swap file
        end

        -- Close the tab
        pcall(vim.cmd('tabclose!'))
      end,
    },
    {
      desc = 'Exit recovery and return to current file.',
      callback = function()
        _log:trace('User chose to exit recovery and return to current file')
        -- Just close the tab, no further action needed
        vim.cmd('tabclose!')
      end,
    },
  }, {
    ns = 'swapdiff_recovery_ns',
    title = 'SwapDiff Recovery - Options:',
    ft = 'swapdiff_recovery_ft',
    trace = function(...)
      _log:trace(...)
    end,
  })

  vim.api.nvim_set_current_win(main_win)

  -- Process all swapfiles sequentially
  coroutine.wrap(function()
    for _, swapfile in ipairs(swapfiles) do
      self:recover_swapfile(swapfile)()
    end

    -- Work to do after all swapfiles are processed
    _log:trace('All swapfiles recovered.')

    vim.schedule(function()
      api.nvim_set_current_win(main_win)
    end)
  end)()
end

return RecoveryTabHandler
