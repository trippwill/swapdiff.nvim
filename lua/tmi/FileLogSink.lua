---@mod tmi.filelogsink.intro FileLogSink Introduction
---@brief [[
--- FileLogSink writes log messages to a file on disk.
---
--- This class is used by the tmi logging framework to persist log output for later inspection.
---
--- Each FileLogSink instance manages its own log file, and log messages are formatted with timestamps and log levels.
---
--- Usage:
---   local FileLogSink = require('tmi.FileLogSink')
---   local sink = FileLogSink:new('/tmp/mylog.txt')
---   sink:log(vim.log.levels.INFO, "Hello, file log!")
---
--- Typically, you do not need to call log directly on this class. Instead, register
--- an instance with |tmi.logger:add_sink| to capture log messages.
---@brief ]]

---@mod tmi.filelogsink FileLogSink Class

---@class FileLogSink: LogSink
---@field file_path string The path to the log file.
local FileLogSink = {}

local util = require('tmi.util')

---Create a new FileLogSink instance.
---@param file_path string The path to the log file.
---@return FileLogSink
function FileLogSink:new(file_path)
  local obj = setmetatable({}, { __index = self })
  obj.file_path = file_path
  return obj
end

---Log a message to the file at the specified log level.
function FileLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  local file = io.open(self.file_path, 'a')
  if file then
    file:write(string.format('%s [%s]: %s\n', os.date('%Y-%m-%d %H:%M:%S'), util.map_level(level), message))
    file:close()
  else
    print('Error opening log file:', self.file_path)
  end
end

return FileLogSink
