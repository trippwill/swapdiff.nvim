---@mod log.intro Introduction
---@brief [[
---USAGE EXAMPLES
---
--->
---    local log = require('swapdiff.log')
---
---    -- Create a logger with a title
---    local logger = log.Logger:new('MyPlugin')
---
---    -- Add a file sink for INFO and above
---    logger:add_sink(vim.log.levels.INFO, log.FileLogSink:new('/tmp/myplugin.log'))
---
---    -- Add a Vim message sink for WARN and above
---    logger:add_sink(vim.log.levels.WARN, log.VimLogSink:new())
---
---    -- Simple logging
---    logger:info('Plugin loaded: %s', 'MyPlugin')
---    logger:warn('Something might be wrong: %s', 'details')
---
---    -- Lazy logging (expensive computation only if needed)
---    logger:debug_lazy(function()
---     return string.format('Debug info: %s', vim.inspect({foo = 'bar'}))
---    end)
---
---    -- Critical logging (logs and raises error)
---    logger:critical('Fatal error: %s', 'something bad')
---    -- or lazy:
---    logger:critical_lazy(function() return 'Fatal error: ' .. tostring(something) end)
---
---    -- Enable/disable logging
---    logger:enable(false) -- disables all logging
---    logger:enable(true)  -- enables logging
---<
---@brief ]]

---@mod log.types Types

---@brief [[
---Signature for log methods.
---fun(self: LogSink, level: vim.log.levels, fmt: string, ...: any?)
---@brief ]]
---@alias LogMethod fun(self: LogSink, level: vim.log.levels, fmt: string, ...: any?)

---@brief [[
---Interface for log sinks.
---Override log method to customize logging behavior.
---@brief ]]
---@class LogSink
---@field title string
---@field log LogMethod Log a message at the specified level.

local levels = vim.log.levels

---@param level vim.log.levels
---@return string
local function map_level(level)
  local level_names = {
    [levels.TRACE] = 'TRACE',
    [levels.DEBUG] = 'DEBUG',
    [levels.INFO] = 'INFO',
    [levels.WARN] = 'WARN',
    [levels.ERROR] = 'ERROR',
  }
  return level_names[level] or 'UNKNOWN'
end

---@mod log.sinks Sinks

---@class FileLogSink: LogSink
---@field file_path string The path to the log file.
local FileLogSink = {}

---Create a new FileLogSink instance.
---@param self FileLogSink
---@param file_path string The path to the log file.
---@return FileLogSink
function FileLogSink:new(file_path)
  local instance = setmetatable({}, { __index = self })
  instance.file_path = file_path
  return instance
end

---Log a message to the file at the specified level.
---@type LogMethod
function FileLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  local file = io.open(self.file_path, 'a')
  if file then
    file:write(string.format('%s [%s]: %s\n', os.date('%Y-%m-%d %H:%M:%S'), map_level(level), message))
    file:close()
  else
    print('Error opening log file:', self.file_path)
  end
end

---Open the log file in Vim.
---@param self FileLogSink
function FileLogSink:open()
  -- Open the log file in the default editor
  vim.cmd('edit ' .. self.file_path)
end

---@class VimLogSink: LogSink
---@field prefix string The prefix for the log messages.
local VimLogSink = {}

---Create a new VimLogSink instance.
---@param self VimLogSink
---@return VimLogSink
function VimLogSink:new()
  local instance = setmetatable({}, { __index = self })
  return instance
end

---Log a message to Vim's message area at the specified level.
---@type LogMethod
function VimLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  print(string.format('[%s](%s): %s', self.title, map_level(level), message))
end

---@class NotifyLogSink: LogSink
local NotifyLogSink = {}

---Create a new NotifyLogSink instance.
---@param self NotifyLogSink
---@return NotifyLogSink
function NotifyLogSink:new()
  local instance = setmetatable({}, { __index = self })
  return instance
end

---Log a message using Vim's notify function at the specified level.
---@type LogMethod
function NotifyLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  vim.notify(message, level, { title = self.title })
end

---@class BufferLogSink: LogSink
---@field buffer number The buffer number for the log messages.
local BufferLogSink = {}

---Create a new BufferLogSink instance.
---@param self BufferLogSink
---@return BufferLogSink
function BufferLogSink:new()
  local instance = setmetatable({}, { __index = self })
  instance.buffer = vim.api.nvim_create_buf(false, true) -- Create a new scratch buffer
  return instance
end

---Log a message to the buffer at the specified level.
---@type LogMethod
function BufferLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  local level_str = map_level(level)
  local date_str = os.date('%Y-%m-%d %H:%M:%S')
  for _, m in ipairs(vim.split(message, '\n')) do
    -- Append the message to the buffer
    vim.api.nvim_buf_set_lines(self.buffer, -1, -1, false, { string.format('%s [%s]: %s', date_str, level_str, m) })
  end
end

---Open the buffer in a floating window or set it as the current buffer.
---@param self BufferLogSink
---@param float boolean If true, open in a floating window; otherwise, set as current buffer.
function BufferLogSink:open(float)
  if float then
    vim.api.nvim_open_win(self.buffer, true, {
      relative = 'editor',
      width = math.floor(vim.o.columns * 0.8),
      height = math.floor(vim.o.lines * 0.8),
      row = math.floor((vim.o.lines - vim.o.lines * 0.8) / 2),
      col = math.floor((vim.o.columns - vim.o.columns * 0.8) / 2),
      style = 'minimal',
    })
  else
    vim.api.nvim_set_current_buf(self.buffer)
  end
end

---@mod log.logger Logger

---@class Logger
---@field title string The title for the logger, used in log messages.
---@field sinks table<{level: vim.log.levels, sink: LogSink}> A table mapping log levels to sinks.
---@field enabled boolean Whether the logger is enabled.
local Logger = {}

---Create a new Logger instance.
---@param title string The title for the logger, used in log messages.
---@return Logger
function Logger:new(title)
  local instance = setmetatable({}, { __index = self })
  instance.sinks = {}
  instance.title = title or 'Logger'
  instance.enabled = true
  return instance
end

---Enable or disable the logger.
---@param self Logger
---@param enable boolean If true, enable the logger; if false, disable it.
function Logger:enable(enable)
  vim.validate('enable', enable, 'boolean')
  self.enabled = enable
end

---Check if the logger is enabled for a specific log level.
---@param self Logger
---@param level vim.log.levels The log level to check.
---@return boolean True if the logger is enabled for the specified level, false otherwise.
function Logger:level_enabled(level)
  if not self.enabled then
    return false
  end
  for _, entry in ipairs(self.sinks) do
    if level >= entry.level then
      return true
    end
  end
  return false
end

---Add a log sink with a minimum log level.
---@param self Logger
---@param level vim.log.levels The minimum log level for the sink.
---@param sink LogSink The log sink to add.
function Logger:add_sink(level, sink)
  sink.title = sink.title or self.title
  table.insert(self.sinks, { level = level, sink = sink })
end

---Log a message safely, catching any errors that occur during logging.
---@private
---@package
---@param self Logger
---@param entry {level: vim.log.levels, sink: LogSink} The log entry containing the level and sink.
---@param level vim.log.levels The log level for the message.
---@param fmt string The format string for the message.
function Logger:safe_log(entry, level, fmt, ...)
  local ok, err = pcall(entry.sink.log, entry.sink, level, fmt, ...)
  if not ok then
    print(string.format('[%s] Failed to log: (%s) %s', self.title, map_level(level), string.format(fmt, ...)))
    print('Sink: ', vim.inspect(entry.sink))
    print(string.format('Error: %s', tostring(err)))
  end
end

---Log a message at the specified level.
---@param self Logger
---@param level vim.log.levels The log level for the message.
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:log(level, fmt, ...)
  if not self.enabled then
    return
  end

  for _, entry in ipairs(self.sinks) do
    if level >= entry.level then
      self:safe_log(entry, level, fmt, ...)
    end
  end
end

---Log a message at the specified level using a lazy evaluation function.
---@param self Logger
---@param level vim.log.levels The log level for the message.
---@param fn function A function that returns the message to log.
---@param ... any? The values to pass to the function.
---@return string? The message that was logged, or nil if no sinks were enabled for the level.
function Logger:log_lazy(level, fn, ...)
  if not self.enabled then
    return nil
  end

  local msg = nil
  for _, entry in ipairs(self.sinks) do
    if level >= entry.level then
      if msg == nil then
        msg = fn(...)
      end
      self:safe_log(entry, level, msg)
    end
  end

  return msg
end

---Log a message at the TRACE level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:trace(fmt, ...)
  self:log(levels.TRACE, fmt, ...)
end

---Log a message at the TRACE level using a lazy evaluation function.
---@param self Logger
---@param fn function A function that returns the message to log.
---@param ... any? The values to pass to the function.
---@return _ string? The message that was logged, or nil if no sinks were enabled for the level.
function Logger:trace_lazy(fn, ...)
  return self:log_lazy(levels.TRACE, fn, ...)
end

---Log a message at the DEBUG level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:debug(fmt, ...)
  self:log(levels.DEBUG, fmt, ...)
end

---Log a message at the DEBUG level using a lazy evaluation function.
---@param self Logger
---@param fn function A function that returns the message to log.
---@param ... any? The values to pass to the function.
---@return _ string? The message that was logged, or nil if no sinks were enabled for the level.
function Logger:debug_lazy(fn, ...)
  return self:log_lazy(levels.DEBUG, fn, ...)
end

---Log a message at the INFO level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:info(fmt, ...)
  self:log(levels.INFO, fmt, ...)
end

---Log a message at the INFO level using a lazy evaluation function.
---@param self Logger
---@param fn function A function that returns the message to log.
---@param ... any? The values to pass to the function.
---@return _ string? The message that was logged, or nil if no sinks were enabled for the level.
function Logger:info_lazy(fn, ...)
  return self:log_lazy(levels.INFO, fn, ...)
end

---Log a message at the WARN level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:warn(fmt, ...)
  self:log(levels.WARN, fmt, ...)
end

---Log a message at the WARN level using a lazy evaluation function.
---@param self Logger
---@param fn function A function that returns the message to log.
---@param ... any? The values to pass to the function.
---@return _ string? The message that was logged, or nil if no sinks were enabled for the level.
function Logger:warn_lazy(fn, ...)
  return self:log_lazy(levels.WARN, fn, ...)
end

---Log a message at the ERROR level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:error(fmt, ...)
  local msg = string.format(fmt, ...)
  self:log(levels.ERROR, msg)
end

---Log a message at the ERROR level using a lazy evaluation function.
---@param self Logger
---@param fn function A function that returns the message to log.
---@param ... any? The values to pass to the function.
---@return _ string? The message that was logged, or nil if no sinks were enabled for the level.
function Logger:error_lazy(fn, ...)
  return self:log_lazy(levels.ERROR, fn, ...)
end

---Log a message at the CRITICAL level.
---Terminates the function with an error.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:critical(fmt, ...)
  self:log(levels.ERROR, fmt, ...)
  error(string.format('[%s] CRITICAL: %s', self.title, string.format(fmt, ...)))
end

---Log a message at the CRITICAL level using a lazy evaluation function.
---Terminates the function with an error.
---@param self Logger
---@param fn function A function that returns the message to log.
---@param ... any? The values to pass to the function.
function Logger:critical_lazy(fn, ...)
  local msg = self:log_lazy(levels.ERROR, fn, ...)
  if msg then
    error(string.format('[%s] CRITICAL: %s', self.title, msg))
  else
    error(string.format('[%s] CRITICAL: No message provided', self.title))
  end
end

---@mod log.module Log Module

---@class LogModule
---@field Logger Logger Logger with convenience methods for logging to LogSinks.
---@field FileLogSink FileLogSink File sink for logging to a file.
---@field VimLogSink VimLogSink Vim message sink for logging to Vim's message area.
---@field NotifyLogSink NotifyLogSink Notify sink for logging using Vim's notify function.
---@field BufferLogSink BufferLogSink Buffer sink for logging to a scratch buffer.
local M = {
  Logger = Logger,
  FileLogSink = FileLogSink,
  VimLogSink = VimLogSink,
  NotifyLogSink = NotifyLogSink,
  BufferLogSink = BufferLogSink,
}

setmetatable(M, {
  __call = function(_, ...)
    return M.Logger:new(...)
  end,
})

return M
