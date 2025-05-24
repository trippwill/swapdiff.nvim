---@class LoggerOptions
---@field title? string
---@field level? vim.log.levels

local notify, levels = vim.notify, vim.log.levels

---@class Logger
---@field title? string
---@field level vim.log.levels
local Logger = {
  title = nil,
  level = levels.INFO,
}

---Create a new Logger instance
---@param opts LoggerOptions
---@return Logger
function Logger:new(opts)
  local instance = setmetatable({}, { __index = self })
  instance.title = opts.title or 'Logger'
  instance.level = opts.level or levels.INFO
  return instance
end

function Logger:log(level, fmt, ...)
  if self.level <= level then
    notify(string.format(fmt, ...), level, { title = self.title })
  end
end

function Logger:trace(fmt, ...)
  self:log(levels.TRACE, fmt, ...)
end

function Logger:debug(fmt, ...)
  self:log(levels.DEBUG, fmt, ...)
end

function Logger:info(fmt, ...)
  self:log(levels.INFO, fmt, ...)
end

function Logger:warn(fmt, ...)
  self:log(levels.WARN, fmt, ...)
end

function Logger:error(fmt, ...)
  self:log(levels.ERROR, fmt, ...)
end

function Logger:critical(fmt, ...)
  notify(string.format('Critical: ' .. fmt, ...), levels.ERROR, { title = self.title })
  error(string.format(fmt, ...), 2)
end

function Logger:print(fmt, ...)
  print(string.format(fmt, ...))
end

---@class LogModule
local M = {}

---@param opts LoggerOptions
function M.logger(opts)
  local logger = Logger:new(opts)
  return logger
end

return setmetatable(M, {
  __call = function(_, opts)
    return M.logger(opts)
  end,
})
