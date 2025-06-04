---@mod tmi.bufferlogsink.intro BufferLogSink Introduction
---@brief [[
--- BufferLogSink writes log messages to a dedicated Neovim buffer.
---
--- This class is used by the tmi logging framework to capture and display log output
--- in a scratch buffer, making it easy to inspect logs interactively within Neovim.
---
--- Each BufferLogSink instance manages its own buffer, which can be opened in a window for
--- real-time log viewing. Log messages are formatted with timestamps and log levels.
---
--- Usage:
---   local BufferLogSink = require('tmi.BufferLogSink')
---   local sink = BufferLogSink:new()
---   sink:log(vim.log.levels.INFO, "Hello, buffer log!")
---
--- Typically, you do not need to call log directly on this class. Instead, register
--- an instance with |tmi.logger:add_sink| to capture log messages.
---@brief ]]

---@mod tmi.bufferlogsink BufferLogSink Class

---@class BufferLogSink: LogSink
---@field bufnr number The buffer number for the log messages.
local BufferLogSink = {}

local util = require('tmi.util')

---Create a new BufferLogSink instance.
---@return BufferLogSink
function BufferLogSink:new()
  local obj = setmetatable({}, { __index = self })
  obj.bufnr = vim.api.nvim_create_buf(false, true) -- Create a new scratch buffer
  obj:log(vim.log.levels.INFO, 'BufferLogSink initialized')
  return obj
end

function BufferLogSink:log(level, fmt, ...)
  local message = string.format(fmt, ...)
  local level_str = util.map_level(level)
  local date_str = os.date('%Y-%m-%d %H:%M:%S')
  for _, m in ipairs(vim.split(message, '\n')) do
    -- Append the message to the buffer
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { string.format('%s [%s]: %s', date_str, level_str, m) })
  end
end

return BufferLogSink
