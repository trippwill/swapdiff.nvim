---@mod swapdiff.intro SwapDiff Introduction
---@tag :SwapDiff
---@tag :SwapDiffLog
---@brief [[
---SwapDiff is a Neovim plugin providing advanced swap file management and recovery features.
---It enhances the default swap file conflict prompt by allowing users to interactively review,
---diff, and recover changes from swap files. SwapDiff integrates with Neovim's event system to
---detect swap file conflicts, provides user-friendly prompts, and offers tools to inspect, recover,
---or delete swap files safely. The plugin is designed to help users avoid data loss and make
---informed decisions when encountering swap file conflicts, especially in crash scenarios.
---
---User Commands
---|:SwapDiff|
---    Buffer-local command that prompts the user for an action when swap files are detected for the current buffer.
---    Options include recovering and diffing swap files, editing the file normally, or deleting all swap files.
---
---|:SwapDiffLog|
---    Opens a floating window or buffer displaying the SwapDiff log, which contains diagnostic and informational
---    messages about swap file events and plugin actions. Press `q` to close the log window.
---@brief ]]

---@mod swapdiff.types SwapDiff Types

---@alias AutoCmdArgs vim.api.keyset.create_autocmd.callback_args

---Support class for swapdiff.nvim
---@class SwapDiffBuffer
---@field relfile string
---@field absfile string
---@field swapinfos SwapDiffSwapInfo[]

---Support class for swapdiff.nvim
---@class SwapDiffSwapInfo
---@field swappath string
---@field info NvimSwapInfo

---User configuration for SwapDiff command
---@class SwapDiffPromptConfig
---@field style 'None' | 'Notify' | 'Interactive' Action style for SwapDiff prompt
---@field once boolean? Whether to prompt only once per file

---User configuration for SwapDiff module
---@class SwapDiffConfig
---@field prompt_config? SwapDiffPromptConfig Configuration for SwapDiff prompt behavior
---@field log_level? vim.log.levels Logging level for SwapDiffLog
---@field notify_level? vim.log.levels Logging level for user notifications
---@field log_win_config? vim.api.keyset.win_config

---@mod swapdiff.module SwapDiff Module

local M = {}

local Logger = require('tmi.Logger')

local BufferLogSink = require('tmi.BufferLogSink')
local NotifyLogSink = require('tmi.NotifyLogSink')
local PrimaryBufferHandler = require('swapdiff.PrimaryBufferHandler')
local util = require('swapdiff.util')

local api, fn, v = vim.api, vim.fn, vim.v
local levels = vim.log.levels
local abs_path, abs_dir, remove_prefix = util.abs_path, util.abs_dir, util.remove_prefix

local _log = Logger:empty()
---@type table<string, PrimaryBufferHandler>
local _buffer_handlers = {}

---@param filepath string absolute filepath
---@return SwapDiffSwapInfo[]
local function get_swapinfos(filepath)
  local swapfiles = fn.swapfilelist()

  ---@type SwapDiffSwapInfo[]
  local results = {}
  local swap_dir = abs_dir(v.swapname) .. '//' -- get the swap directory from the current swapname
  for _, swapfile in ipairs(swapfiles) do
    local abs_swap = abs_path(remove_prefix(swap_dir, swapfile))
    _log:trace('swap path transformed %s -> %s', swapfile, abs_swap)

    local info = fn.swapinfo(abs_swap) --[[@as NvimSwapInfo]]

    if info and info.fname then
      local abs_fname = abs_path(info.fname)
      if abs_fname == filepath and info.dirty ~= 0 then
        table.insert(results, { info = info, swappath = abs_swap })
      end
    end
  end
  return results
end

---Callback for the SwapExists autocmd
---@param args AutoCmdArgs
function M.onSwapExists(args)
  -- Note: args.buf is always 0 for SwapExists autocmds
  _log:trace('SwapExists autocmd triggered with args: %s', vim.inspect(args))
  _log:trace_lazy(function()
    return vim.inspect(api.nvim_get_autocmds({ event = 'SwapExists' }))
  end)

  if v.swapchoice and v.swapchoice ~= '' then
    _log:debug("vim.v.swapchoice is already set to '%s' for file '%s', skipping SwapDiff", v.swapchoice, args.file)
    return
  end

  local filename = args.file
  if not filename or filename == '' then
    _log:warn('SwapExists triggered with empty filename, skipping SwapDiff')
    return
  end

  local filepath = args.match or abs_path(filename)
  if not filepath or filepath == '' then
    _log:warn('SwapExists triggered with empty filepath, skipping SwapDiff')
    return
  end

  if _buffer_handlers[filepath] then
    _log:debug("SwapDiff already initialized for file '%s', skipping", filepath)
    return
  end

  local swapfiles = get_swapinfos(filepath)
  if #swapfiles == 0 then
    _log:trace('No dirty swapfiles found for %s', filepath)
    return
  end

  _log:debug('Found %d dirty swapfiles for %s', #swapfiles, filepath)

  ---@type SwapDiffBuffer
  local pending = {
    relfile = filename,
    absfile = filepath,
    swapinfos = swapfiles,
  }

  local pbh = PrimaryBufferHandler:new(_log, pending)

  api.nvim_buf_create_user_command(0, 'SwapDiff', function()
    return pbh:prompt()
  end, {
    desc = 'Prompt user for action on swap files',
    force = true,
  })

  api.nvim_create_autocmd('BufDelete', {
    buffer = 0,
    once = true,
    callback = function()
      _log:trace('BufDelete for %s, cleaning up swapdiff state', filepath)
      _buffer_handlers[filepath] = nil
    end,
  })

  local prompt_config = M.config.prompt_config
  if prompt_config then
    if prompt_config.style == 'Interactive' then
      api.nvim_create_autocmd('BufWinEnter', {
        pattern = filepath,
        callback = function(args2)
          return pbh:onBufWinEnter(args2, not prompt_config.once)
        end,
      })
    end
  end

  _buffer_handlers[filepath] = pbh
  v.swapchoice = 'e' -- Open the file normally
end

---@type SwapDiffConfig
M.defaults = {
  prompt_config = {
    style = 'Interactive',
    once = false,
  },
  log_level = levels.DEBUG,
  notify_level = levels.INFO,
  log_win_config = {
    relative = 'editor',
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor((vim.o.lines - vim.o.lines * 0.8) / 2),
    col = math.floor((vim.o.columns - vim.o.columns * 0.8) / 2),
    style = 'minimal',
    border = 'rounded',
    title = 'SwapDiff Log',
    footer = '<q> to close',
    footer_pos = 'right',
  },
}

---Initialize the SwapDiff module with options
---@param opts SwapDiffConfig
function M.setup(opts)
  print('SwapDiff Handler: Setting up with options:', vim.inspect(opts))
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})

  _log = Logger:new('SwapDiff')
  _log:add_sink(M.config.notify_level, NotifyLogSink:new())

  local _buffer_sink = BufferLogSink:new()
  _log:add_sink(M.config.log_level, _buffer_sink)

  api.nvim_create_user_command('SwapDiffLog', function()
    if not _buffer_sink or not _buffer_sink.bufnr then
      _log:critical('SwapDiff buffer sink is not initialized, cannot show log')
      return
    end

    local bufnr = _buffer_sink.bufnr
    api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<cmd>q<CR>', { noremap = true, silent = true })

    local win_config = M.config.log_win_config
    if win_config then
      vim.api.nvim_open_win(bufnr, true, win_config)
    else
      vim.api.nvim_set_current_buf(bufnr)
    end
  end, {
    desc = 'Show the SwapDiff log',
    force = true,
  })
end

return M
