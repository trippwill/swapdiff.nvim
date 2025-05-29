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

function M.remove_prefix(prefix, str)
  if str:sub(1, #prefix) == prefix then
    return str:sub(#prefix + 1)
  else
    return str
  end
end

return M
