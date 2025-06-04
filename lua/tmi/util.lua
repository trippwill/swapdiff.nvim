local M = {}

local levels = vim.log.levels

---Map a vim.log.levels value to a string representation.
---@param level vim.log.levels
---@return string
function M.map_level(level)
  local level_names = {
    [levels.TRACE] = 'TRACE',
    [levels.DEBUG] = 'DEBUG',
    [levels.INFO] = 'INFO',
    [levels.WARN] = 'WARN',
    [levels.ERROR] = 'ERROR',
  }
  return level_names[level] or 'UNKNOWN'
end

return M
