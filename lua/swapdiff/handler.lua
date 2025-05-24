---@class SwapDiffPending
---@field filename string
---@field swapfile string
---@field recovered_job? vim.SystemObj
---@field recoveredfile? string
---@field open_in_pid integer | false

---@class SwapDiffSwapInfo
---@field path string
---@field info table

---@private
---@alias autocmd_callback fun(args: vim.api.keyset.create_autocmd.callback_args): nil | boolean

local M = {}

local api, fn, v = vim.api, vim.fn, vim.v
local _log = require('swapdiff.log').logger({
  title = 'SwapDiff',
  level = vim.log.levels.TRACE,
})

---@private
M.augroup = api.nvim_create_augroup('SwapDiff', { clear = true })

---@private
---@type SwapDiffPending?
M.pending = nil

local function abs_path(filename)
  if not filename or filename == '' then
    return ''
  end
  return fn.fnamemodify(filename, ':p')
end

---@param filename string
---@return SwapDiffSwapInfo[]
local function get_swapfiles_for_file(filename)
  local abs_filename = abs_path(filename)
  local swaps = fn.swapfilelist()
  local results = {}

  -- find where neovim stores swap files
  local swap_dir = ''
  if vim.o.directory then
    --split on commas
    local possible_dirs = vim.split(vim.o.directory, ',')
    if #possible_dirs == 1 then
      swap_dir = possible_dirs[1]
    else
      for _, dir in ipairs(possible_dirs) do
        -- check if the directory exists and neovim can write to it
        if fn.isdirectory(dir) == 1 and fn.filewritable(dir) == 2 then
          swap_dir = dir
          break
        end
      end
    end
  end

  swap_dir = abs_path(swap_dir)

  for _, swap in ipairs(swaps) do
    local real_swap = swap:sub(#swap_dir > 0 and #swap_dir + 1 or 0)
    local info = fn.swapinfo(abs_path(real_swap))
    local abs_fname = abs_path(info.fname)
    if info and abs_fname == abs_filename and info.dirty ~= 0 then
      table.insert(results, { path = abs_fname, info = info })
    end
  end
  return results
end

---@param swapfile string
---@return vim.SystemObj, string
local function recover_swapfile_async(swapfile)
  local tmpfile = fn.tempname()
  local cmd = {
    'nvim',
    '--headless',
    '--noplugin',
    '+recover',
    ('"+w! %s"'):format(tmpfile),
    '+q!',
    swapfile,
  }

  local job = vim.system(cmd, { text = true })
  return job, tmpfile
end

---@param filename string
---@return boolean, fun() | vim.SystemObj
function M.validate_pending(filename)
  if not M.pending then
    return false,
      function()
        _log:error('Unrecoverable: no pending swapfile recovery found for %s', filename)
      end
  end

  if M.pending.filename ~= filename then
    return false,
      function()
        _log:error('Unrecoverable: pending swapfile recovery does not match expected %s', filename)
      end
  end

  if M.pending.open_in_pid then
    return false,
      function()
        _log:info('File is open in another Neovim instance (PID: %d)', M.pending.open_in_pid)
      end
  end

  local recovered_job = M.pending.recovered_job
  if not recovered_job then
    return false,
      function()
        _log:error('Unrecoverable: no pending swapfile recovery found for %s', filename)
      end
  end

  return true, recovered_job
end

---@type autocmd_callback
local function onBufReadPost(args)
  local filename = abs_path(args.file)

  local valid, res = M.validate_pending(filename)
  if not valid then
    M.pending = nil
    if type(res) == 'function' then
      res()
    end
    return true
  end

  local recovered_job = res

  -- Wait for recovery job if not done

  local tmpfile = M.pending.recoveredfile
  local completed_job = recovered_job:wait(1 * 1000)

  local code = completed_job.code
  if code ~= 0 then
    _log:error('Swapfile recovery failed for %s\n%s', filename, vim.inspect(completed_job))
    M.pending = nil
    return true
  end

  if not tmpfile or fn.filereadable(tmpfile) == 1 then
    _log:error('Recovered temp file not found or not readable: %s', tmpfile)
    M.pending = nil
    return true
  end

  -- Diff UI
  vim.cmd('tabnew')
  vim.cmd('edit ' .. fn.fnameescape(filename))
  vim.wo.winbar = '[DISK] ' .. fn.fnamemodify(filename, ':t')
  vim.cmd('vsplit ' .. fn.fnameescape(tmpfile))
  vim.wo.winbar = '[RECOVERED] ' .. fn.fnamemodify(filename, ':t') .. ' (swap)'
  vim.cmd('windo diffthis')
  vim.cmd('wincmd h')

  -- Prompt user for a decision
  local choice = fn.input('Choose version to keep:\n[D]isk (left), [R]ecovered (right), [Q]uit: '):lower()
  choice = choice:lower()

  vim.cmd('tabclose')

  if choice == 'r' then
    -- Edit recovered as original (buffer name only, no write)
    vim.cmd('edit ' .. fn.fnameescape(tmpfile))
    vim.cmd('file ' .. fn.fnameescape(filename))
  elseif choice == 'd' then
    vim.cmd('edit ' .. fn.fnameescape(filename))
  else
    vim.cmd('quit')
  end

  fn.delete(tmpfile)
  --fn.delete(M.pending.swapfile)

  -- Clean up
  M.pending = nil
  return true
end

---@type autocmd_callback
function M.onSwapExists(args)
  print('SwapDiff on_SwapExists called')
  local filename = abs_path(args.file)
  local swapfiles = get_swapfiles_for_file(filename)

  --  __trace('Swap files for %s: %s', filename, vim.inspect(swapfiles))

  if #swapfiles == 0 then
    print('No swap files found for ', filename)
    return
  end

  if #swapfiles == 1 then
    local swapfile = swapfiles[1]

    if swapfile.info.pid and swapfile.info.pid ~= 0 then
      _log:trace('Swap file %s is open in another Neovim instance (PID: %d).', swapfile.path, swapfile.info.pid)
      -- File is open in another Neovim instance
      M.pending = {
        filename = filename,
        swapfile = swapfile.path,
        open_in_pid = swapfile.info.pid,
      }
      return
    end
  end

  local prompt = ('**SwapDiff** Swap file detected for %s.\n[S]wapDiff [O]pen Readonly [R]ecover [E]dit Anyway [D]elete Swapfile [Q]uit [A]bort: '):format(
    filename
  )
  local resp = fn.input(prompt):lower()

  if resp == 's' then
    local select_swapfile = function(cb)
      if #swapfiles == 1 then
        cb(swapfiles[1])
      else
        local items = vim.tbl_map(function(s)
          local inf = s.info
          return string.format(
            '%s [dirty:%s mtime:%s pid:%d]',
            s.path,
            inf.dirty == 1 and 'yes' or 'no',
            os.date('%c', inf.mtime or 0),
            inf.pid or 0
          )
        end, swapfiles)
        vim.ui.select(items, { prompt = 'Select swapfile to diff:' }, function(_, idx)
          if idx then
            cb(swapfiles[idx])
          end
        end)
      end
    end

    select_swapfile(function(selected)
      if not selected then
        v.swapchoice = 'q'
        return
      end
      M.pending = {
        filename = filename,
        swapfile = selected.path,
        open_in_pid = false,
      }
      -- Async recovery
      M.pending.recovered_job, M.pending.recoveredfile = recover_swapfile_async(selected.path)

      -- Set up BufReadPost for just this file, once
      api.nvim_create_autocmd('BufReadPost', {
        pattern = filename,
        once = true,
        callback = onBufReadPost,
      })
      -- Open readonly buffer for diffing
      v.swapchoice = 'o'
    end)
    return
  end

  local valid = { o = true, r = true, e = true, d = true, q = true, a = true }
  v.swapchoice = valid[resp] and resp or ''
end

return M
