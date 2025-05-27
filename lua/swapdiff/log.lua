---@class LoggerOptions
---@field title? string Defaults to `nil`
---@field level? vim.log.levels Defaults to `vim.log.levels.INFO`

local levels = vim.log.levels

---@class Logger
---@field title? string
---@field level vim.log.levels
Logger = {
  title = nil,
  level = levels.INFO,
}

---@type Logger
NilLogger = {
  title = 'NilLogger',
  level = levels.OFF,
  critical = error,
  error = error,
  warn = function() end,
  debug = function() end,
  trace = function() end,
  info = function() end,
  print = print,
  log = function() end,
  printf = function() end,
  printfn = function() end,
  tracefn = function() end,
  notify = function() end,
  new = function()
    return NilLogger
  end,
}

---Create a new Logger instance.
---@package
---@param opts LoggerOptions
---@return Logger
function Logger:new(opts)
  local instance = setmetatable({}, { __index = self })
  instance.title = opts.title or 'Logger'
  instance.level = opts.level or levels.INFO
  return instance
end

---Notify the user with a formatted message, ignoring the log level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:notify(fmt, ...)
  vim.notify(string.format(fmt, ...), self.level, { title = self.title })
end

---Log a message at the specified level.
---@param self Logger
---@param level vim.log.levels
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:log(level, fmt, ...)
  if self.level <= level then
    vim.notify(string.format(fmt, ...), level, { title = self.title })
  end
end

---Log a message at the TRACE level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:trace(fmt, ...)
  self:log(levels.TRACE, fmt, ...)
end

---Log the result of a function call at the TRACE level.
---@param self Logger
---@param func function(any): any The function to call.
---@param ... any? The arguments to pass to the function.
function Logger:tracefn(func, ...)
  if self.level <= levels.TRACE then
    local ok, res = pcall(func, ...)
    if not ok then
      self:log(levels.ERROR, 'Error in tracefn: %s', res)
    else
      self:log(levels.TRACE, tostring(res))
    end
  end
end

---Log a message at the DEBUG level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:debug(fmt, ...)
  self:log(levels.DEBUG, fmt, ...)
end

---Log a message at the INFO level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:info(fmt, ...)
  self:log(levels.INFO, fmt, ...)
end

---Log a message at the WARN level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:warn(fmt, ...)
  self:log(levels.WARN, fmt, ...)
end

---Log a message at the ERROR level.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:error(fmt, ...)
  self:log(levels.ERROR, fmt, ...)
end

---Log a message at the CRITICAL level.
---Terminates the function with an error.
---@param self Logger
---@param fmt string The format string for the message.
---@param ... any? The values to format into the string.
function Logger:critical(fmt, ...)
  error(string.format(self.title .. ': ' .. fmt, ...), 2)
end

function Logger:print(...)
  print(self.title or '', ...)
end

function Logger:printf(fmt, ...)
  self:print(string.format(fmt, ...))
end

function Logger:printfn(func, ...)
  if self.level <= levels.TRACE then
    local ok, res = pcall(func, ...)
    if not ok then
      self:log(levels.ERROR, 'Error in printfn: %s', res)
    else
      self:print(tostring(res))
    end
  end
end

---@class LogModule
local M = {}

---Create a logger instance with the given options.
---@param opts LoggerOptions
---@return Logger
function M.logger(opts)
  return Logger:new(opts)
end

function M.nil_logger()
  return NilLogger
end

return M
