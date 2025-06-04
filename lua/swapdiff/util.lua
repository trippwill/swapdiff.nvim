---@mod swapdiff.util Utility Functions for SwapDiff
local M = {}

local fn = vim.fn

---Get the absolute path of a file.
---@param filename string
---@return string
function M.abs_path(filename)
  if not filename or filename == '' then
    return ''
  end
  return fn.fnamemodify(filename, ':p')
end

---Get the file name without the directory path.
---@param filepath string
---@return string
function M.tail_path(filepath)
  if not filepath or filepath == '' then
    return ''
  end
  return fn.fnamemodify(filepath, ':t')
end

---Get the absolute directory path of a file.
---@param filepath string
---@return string
function M.abs_dir(filepath)
  if not filepath or filepath == '' then
    return ''
  end

  return fn.fnamemodify(filepath, ':p:h')
end

---Remove a prefix from a string.
---@param prefix string
---@param str string
---@return string
function M.remove_prefix(prefix, str)
  if str:sub(1, #prefix) == prefix then
    return str:sub(#prefix + 1)
  else
    return str
  end
end

---Validate pending SwapDiffBuffer state
---@private
---@param pending SwapDiffBuffer
---@param absfile string
---@return string relfile
---@return string absfile
---@return SwapDiffSwapInfo[] swapinfos
function M.assert_pending(pending, absfile)
  local _pending = assert(pending, 'SwapDiff pending state should not be nil')
  local _absfile = assert(_pending.absfile, 'SwapDiff pending state should have a filename')
  assert(_absfile == absfile, 'SwapDiff pending state filename should match the opened file')
  local relfile = assert(_pending.relfile, 'SwapDiff pending state should have a relative filename')
  local swapinfos = assert(_pending.swapinfos, 'SwapDiff pending state should have swapfiles')
  assert(#swapinfos > 0, 'SwapDiff pending state should have non-empty swapfiles')
  return relfile, _absfile, swapinfos
end

return M
