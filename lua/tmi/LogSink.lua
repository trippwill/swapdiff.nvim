---@meta TooMuchLogSink
---@mod tmi.logsink LogSink Interface
---@brief [[
---Interface for log sinks.
---Override log method to customize logging behavior.
---@brief ]]

---@class LogSink
---@field title string
local LogSink

---Log a message at the specified level.
---@param level vim.log.levels The log level for the message.
---@param fmt string The format string for the message.
---@param ... any The values to format into the string.
---@diagnostic disable-next-line: unused-vararg, unused-local
function LogSink:log(level, fmt, ...)
  error('LogSink:log must be overridden by subclasses')
end

---@export LogSink
