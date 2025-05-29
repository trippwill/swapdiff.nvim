---@private
---@alias autocmd_callback fun(args: vim.api.keyset.create_autocmd.callback_args): nil | boolean

local M = {}

local api, fn = vim.api, vim.fn
local open_menu_window = require('swapdiff.ui').open_menu_window

---@private
M.augroup = api.nvim_create_augroup('SwapDiff', { clear = true })

---@private
---@type SwapDiffPending?
M.pending = nil

local _log = require('swapdiff.log').logger({
  level = vim.log.levels.INFO,
  name = 'swapdiff.handler',
})

---@type autocmd_callback
local function onBufWipeout(args)
  _log:printfn('onBufDelete called with args: %s', vim.inspect(args))

  local tmpfile = args.match

  _log:printf('Deleting temporary file %s', tmpfile)
  fn.delete(tmpfile)
end

local function recover_swapfile(swapfile)
  return coroutine.wrap(function()
    local tmpfile = vim.fn.tempname()
    print('Temporary file for recovery %s', tmpfile)

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
      _log:print('Recovered swapfile:', swapfile.swappath, 'to temporary file:', tmpfile)
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
        callback = onBufWipeout,
      })
    end
  end)
end

function M.start_recovery(args, filename, swapfiles)
  vim.cmd.tabnew(args.file) -- Open the file in a new tab
  vim.wo[0].winbar = 'CURRENT'

  print('Recovering %d swapfiles for %s', #swapfiles, filename)

  local main_win = vim.api.nvim_get_current_win()
  vim.cmd('wincmd t')
  open_menu_window({
    {
      desc = 'Delete all swapfiles and return to current file.',
      callback = function()
        _log:print('User chose to delete all swapfiles and edit file normally')
        for _, swapfile in ipairs(swapfiles) do
          _log:printf('Deleting swapfile: %s', swapfile.swappath)
          fn.delete(swapfile.swappath) -- remove the swap file
        end

        -- Close the tab
        pcall(vim.cmd('tabclose!'))
      end,
    },
    {
      desc = 'Exit recovery and return to current file.',
      callback = function()
        _log:print('User chose to exit recovery and return to current file')
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
      recover_swapfile(swapfile)()
    end

    -- Work to do after all swapfiles are processed
    _log:print('All swapfiles recovered.')

    vim.schedule(function()
      api.nvim_set_current_win(main_win)
    end)
  end)()
end

return M
