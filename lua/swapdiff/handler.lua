---@class SwapDiffPending
---@field filename string
---@field swapfiles SwapDiffSwapInfo[]

---@class SwapDiffSwapInfo
---@field filepath string
---@field swappath string
---@field info table

---@private
---@alias autocmd_callback fun(args: vim.api.keyset.create_autocmd.callback_args): nil | boolean

local M = {}

local api, fn, v = vim.api, vim.fn, vim.v
local util = require('swapdiff.util')
local abs_path, tail_path, abs_dir = util.abs_path, util.tail_path, util.abs_dir
local open_menu_window = require('swapdiff.ui').open_menu_window

local _log = require('swapdiff.log').nil_logger()

---@private
M.augroup = api.nvim_create_augroup('SwapDiff', { clear = true })

---@private
---@type SwapDiffPending?
M.pending = nil

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

---Validate the pending state before proceeding with recovery
---@param pending SwapDiffPending?
---@param abs_file string
---@return string, SwapDiffSwapInfo[]
local function validate_pending(pending, abs_file)
  pending = assert(pending, 'SwapDiff pending state should not be nil when handling BufReadPost')
  local filename = assert(pending.filename, 'SwapDiff pending state should have a filename')
  assert(filename == abs_file, 'SwapDiff pending state filename should match the opened file')
  local swapfiles = assert(pending.swapfiles, 'SwapDiff pending state should have swapfiles')
  assert(#swapfiles > 0, 'SwapDiff pending state should have non-empty swapfiles')
  return filename, swapfiles
end

local function start_recovery(args, filename, swapfiles)
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

---@type autocmd_callback
local function onBufReadPost(args)
  _log:print('onBufReadPost called with args:', vim.inspect(args))
  local ok, pending = pcall(vim.deepcopy, M.pending, true) -- noref
  M.pending = nil
  if not ok then
    _log:critical('Failed to deepcopy pending state')
    return
  end

  local filename, swapfiles = validate_pending(pending, abs_path(args.file))

  vim.ui.select({
    'Recover and diff all swapfiles',
    'Edit file normally, leaving swapfiles intact',
    'Delete all swapfiles and edit file normally',
  }, {
    prompt = string.format('SwapDiff: found %d dirty swapfiles for %s:', #swapfiles, tail_path(filename)),
  }, function(item, idx)
    _log:printf('User choice: %d %s', idx or -1, item)

    if idx == 1 then
      start_recovery(args, filename, swapfiles)
    elseif idx == 2 then
      return -- just open the file normally
    elseif idx == 3 then
      for _, swapfile in ipairs(swapfiles) do
        _log:printf('Deleting swapfile: %s', swapfile.swappath)
        fn.delete(swapfile.swappath) -- remove the swap file
      end
      return -- delete the swapfiles and open the file normally
    else
      return -- unexpected choice, do nothing
    end
  end)
end

---@param filename string
---@return SwapDiffSwapInfo[]
local function get_swapfiles_for_file(filename)
  local abs_filename = abs_path(filename)
  local swaps = fn.swapfilelist()

  ---@type SwapDiffSwapInfo[]
  local results = {}
  local swap_dir = abs_dir(v.swapname) .. '//' -- get the swap directory from the current swapname
  for _, swap in ipairs(swaps) do
    local abs_swap = abs_path(swap:sub(#swap_dir > 0 and #swap_dir + 1 or 0))

    _log:printf('swap path transformed %s -> %s', swap, abs_swap)

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
  _log:printfn(function()
    return vim.inspect(vim.api.nvim_get_autocmds({ event = 'SwapExists' }))
  end)

  if v.swapchoice and v.swapchoice ~= '' then
    _log:debug("vim.v.swapchoice is already set to '%s' for file '%s', skipping SwapDiff", v.swapchoice, args.file)
    return
  end

  assert(M.pending == nil, 'SwapDiff: pending state should be nil before handling SwapExists')

  local abs_file = abs_path(args.file)
  local swapfiles = get_swapfiles_for_file(abs_file)

  if #swapfiles == 0 then
    _log:trace('No dirty swapfiles found for %s', abs_file)
    return
  end

  _log:trace('Found %i dirty swapfiles for %s', #swapfiles, abs_file)

  M.pending = {
    filename = abs_file,
    swapfiles = swapfiles,
  }

  -- Set up BufReadPost autocmd for handling recovery and diff
  api.nvim_create_autocmd('BufReadPost', {
    pattern = abs_file,
    once = true,
    callback = onBufReadPost,
  })

  v.swapchoice = 'e' -- Open the file normally
end

M.defaults = {
  log_level = vim.log.levels.INFO, -- Default log level
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})
  _log = require('swapdiff.log').logger({
    title = 'SwapDiff',
    level = M.config.log_level,
  })
end

return M
