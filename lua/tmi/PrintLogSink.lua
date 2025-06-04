---@mod tmi.printlogsink.intro PrintLogSink Introduction
---@brief [[
--- PrintLogSink writes log messages to the Neovim message area using `print()`.
---
--- This class is used by the tmi logging framework to display log output directly in the Neovim command area.
---
--- Each PrintLogSink instance can be given a title, and log messages are formatted with log levels.
---
--- Usage:
---   local PrintLogSink = require('tmi.PrintLogSink')
---   local sink = PrintLogSink:new()
---   sink:log(vim.log.levels.INFO, "Hello, print log!")
---
--- Typically, you do not need to call log directly on this class. Instead, register
--- an instance with |tmi.logger:add_sink| to capture log messages.
---@brief ]]

---@mod tmi.printlogsink PrintLogSink Class

---@class PrintLogSink: LogSink
local PrintLogSink = {}

local map_level = require('tmi.util').map_level

---Create a new PrintLogSink instance.
---@return PrintLogSink
function PrintLogSink:new()
  return setmetatable({}, { __index = self })
end

function PrintLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  print(string.format('[%s](%s): %s', self.title, map_level(level), message))
end

return PrintLogSink
