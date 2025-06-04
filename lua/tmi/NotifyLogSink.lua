---@mod tmi.notifylogsink.intro NotifyLogSink Introduction
---@brief [[
--- NotifyLogSink writes log messages using `vim.notify()`.
---
--- This class is used by the tmi logging framework to display log output as Neovim notifications.
---
--- Each NotifyLogSink instance can be given a title, and log messages are formatted with log levels.
---
--- Usage:
---   local NotifyLogSink = require('tmi.NotifyLogSink')
---   local sink = NotifyLogSink:new()
---   sink:log(vim.log.levels.INFO, "Hello, notify log!")
---
--- Typically, you do not need to call log directly on this class. Instead, register
--- an instance with |tmi.logger:add_sink| to capture log messages.
---@brief ]]

---@mod tmi.notifylogsink NotifyLogSink Class

---@class NotifyLogSink: LogSink
local NotifyLogSink = {}

---Create a new NotifyLogSink instance.
---@return NotifyLogSink
function NotifyLogSink:new()
  local obj = setmetatable({}, { __index = self })
  return obj
end

function NotifyLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  vim.notify(message, level, { title = self.title })
end

return NotifyLogSink
