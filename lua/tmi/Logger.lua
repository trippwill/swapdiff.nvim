---@mod tmi.logger Logger Class
---@brief [[
---Manages logging with multiple sinks, allowing for different log levels and formats.
---
--->
---   local Logger = require('tmi.Logger')
---   local log = Logger:new('MyLogger')
---   log:add_sink(vim.log.levels.INFO, require('tmi.BufferLogSink'):new())
---   log:add_sink(vim.log.levels.ERROR, require('tmi.NotifyLogSink'):new())
---
---   log:info('This is an info message')
---   log:debug('This is a debug message with a value: %s', some_value)
---   log:critical('This will terminate the current function with an error: %s', error_message)
---
---   -- Disable the logger
---   log:enable(false)
---   -- Re-enable the logger
---   log:enable(true)
---
---   -- Create an empty logger that does nothing
---   local noop_logger = Logger:empty()
---<
---@brief ]]

---@class Logger : LogSink
---@field title string The title for the logger, used in log messages.
---@field sinks table<{level: vim.log.levels, sink: LogSink}> A table mapping log levels to sinks.
---@field enabled boolean Whether the logger is enabled.
local Logger = {}

local levels = vim.log.levels

---Create a new Logger instance.
---@param title string The title for the logger, used in log messages.
---@return Logger
function Logger:new(title)
  local obj = setmetatable({}, { __index = self })
  obj.sinks = {}
  obj.title = title or 'Logger'
  obj.enabled = true
  return obj
end

---Create an empty logger that does nothing.
---@return Logger
function Logger:empty()
  local noop = function() end
  local mt = {
    __index = function()
      return noop
    end,
    __newindex = function() end,
  }
  return setmetatable({}, mt)
end

---Enable or disable the logger.
---@param enable boolean If true, enable the logger; if false, disable it.
function Logger:enable(enable)
  vim.validate('enable', enable, 'boolean')
  self.enabled = enable
end

---Add a log sink with a minimum log level.
---The title for the sink will default to the logger's title if not already set.
---@param level vim.log.levels The minimum log level for the sink.
---@param sink LogSink The log sink to add.
function Logger:add_sink(level, sink)
  sink.title = sink.title or self.title
  table.insert(self.sinks, { level = level, sink = sink })
end

---Log a message safely, catching any errors that occur during logging.
---@private
---@package
---@param entry {level: vim.log.levels, sink: LogSink} The log entry containing the level and sink.
---@param level vim.log.levels The log level for the message.
---@param fmt string The format string for the message.
function Logger:safe_log(entry, level, fmt, ...)
  local ok, err = pcall(entry.sink.log, entry.sink, level, fmt, ...)
  if not ok then
    print(string.format('[%s] Failed to log: (%s) %s', self.title, level, string.format(fmt, ...)))
    print('Sink: ', vim.inspect(entry.sink))
    print(string.format('Error: %s', tostring(err)))
  end
end

---Log a message at the specified level.
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
---@param level vim.log.levels The log level for the message.
---@param fn function A function that returns the message to log.
---@param ... any The values to pass to the function.
---@return string | nil msg The message that was logged, or nil if no sinks were enabled for the level.
function Logger:log_lazy(level, fn, ...)
  if not self.enabled then
    return nil
  end

  local msg = nil
  for _, entry in ipairs(self.sinks) do
    if level >= entry.level then
      if msg == nil then
        local ok, pmsg = pcall(fn, ...)
        if not ok then
          print(string.format('[%s] Error evaluating lazy log function: %s', self.title, tostring(pmsg)))
          return nil
        end
        if type(pmsg) ~= 'string' then
          print(string.format('[%s] Lazy log function did not return a string: %s', self.title, vim.inspect(pmsg)))
          return nil
        end
        msg = pmsg
      end
      self:safe_log(entry, level, msg)
    end
  end

  return msg
end

---Log a message at the TRACE level.
---@param fmt string The format string for the message.
---@param ... any The values to format into the string.
function Logger:trace(fmt, ...)
  self:log(levels.TRACE, fmt, ...)
end

---Log a message at the TRACE level using a lazy evaluation function.
---@param fn function A function that returns the message to log.
---@param ... any The values to pass to the function.
---@return string | nil msg The message that was logged, or nil if no sinks were enabled for the level.
function Logger:trace_lazy(fn, ...)
  return self:log_lazy(levels.TRACE, fn, ...)
end

---Log a message at the DEBUG level.
---@param fmt string The format string for the message.
---@param ... any The values to format into the string.
function Logger:debug(fmt, ...)
  self:log(levels.DEBUG, fmt, ...)
end

---Log a message at the DEBUG level using a lazy evaluation function.
---@param fn function A function that returns the message to log.
---@param ... any The values to pass to the function.
---@return string | nil msg The message that was logged, or nil if no sinks were enabled for the level.
function Logger:debug_lazy(fn, ...)
  return self:log_lazy(levels.DEBUG, fn, ...)
end

---Log a message at the INFO level.
---@param fmt string The format string for the message.
---@param ... any The values to format into the string.
function Logger:info(fmt, ...)
  self:log(levels.INFO, fmt, ...)
end

---Log a message at the INFO level using a lazy evaluation function.
---@param fn function A function that returns the message to log.
---@param ... any The values to pass to the function.
---@return string | nil msg The message that was logged, or nil if no sinks were enabled for the level.
function Logger:info_lazy(fn, ...)
  return self:log_lazy(levels.INFO, fn, ...)
end

---Log a message at the WARN level.
---@param fmt string The format string for the message.
---@param ... any The values to format into the string.
function Logger:warn(fmt, ...)
  self:log(levels.WARN, fmt, ...)
end

---Log a message at the WARN level using a lazy evaluation function.
---@param fn function A function that returns the message to log.
---@param ... any The values to pass to the function.
---@return string | nil msg The message that was logged, or nil if no sinks were enabled for the level.
function Logger:warn_lazy(fn, ...)
  return self:log_lazy(levels.WARN, fn, ...)
end

---Log a message at the ERROR level.
---@param fmt string The format string for the message.
---@param ... any The values to format into the string.
function Logger:error(fmt, ...)
  self:log(levels.ERROR, fmt, ...)
end

---Log a message at the ERROR level using a lazy evaluation function.
---@param fn function A function that returns the message to log.
---@param ... any The values to pass to the function.
---@return string | nil msg The message that was logged, or nil if no sinks were enabled for the level.
function Logger:error_lazy(fn, ...)
  return self:log_lazy(levels.ERROR, fn, ...)
end

---Log a message at the ERROR level.
---Terminates the function with an error.
---@param fmt string The format string for the message.
---@param ... any The values to format into the string.
function Logger:critical(fmt, ...)
  self:log(levels.ERROR, fmt, ...)
  error(string.format('[%s] CRITICAL: %s', self.title, string.format(fmt, ...)))
end

---Log a message at the ERROR level using a lazy evaluation function.
---Terminates the function with an error.
---@param fn function A function that returns the message to log.
---@param ... any The values to pass to the function.
function Logger:critical_lazy(fn, ...)
  local msg = self:log_lazy(levels.ERROR, fn, ...)
  if msg then
    error(string.format('[%s] CRITICAL: %s', self.title, msg))
  else
    error(string.format('[%s] CRITICAL: No message provided', self.title))
  end
end

return Logger
