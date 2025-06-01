---@mod swapdiff.bufferline.intro SwapDiff Bufferline Integration
---@brief [[
---Provides a function to replace the default bufferline.nvim go_to function,
---which ensures that SwapExists is triggered if necessary.
---@brief ]]

---@mod swapdiff.bufferline.module SwapDiff Bufferline Module

local M = {}

---Navigate to a buffer by index.
---Unlike bufferline.nvim go_to, this ensures SwapExists is triggered if necessary.
---@param num number | string
---@param absolute boolean? whether or not to use the elements absolute position or visible positions
function M.go_to(num, absolute)
  local ok, bufferline = pcall(require, 'bufferline')
  if not ok then
    error('Bufferline is not available, cannot go to buffer')
  end

  if not absolute then
    error('go_to function requires absolute position, please set absolute to true')
  end

  num = type(num) == 'string' and tonumber(num) or num
  local elements = bufferline.get_elements()
  local mode = elements.mode

  if mode ~= 'buffers' then
    error('Only buffers mode is supported, cannot go to buffer')
  end

  local list = elements.elements
  local element = list[num]
  if num == -1 or not element then
    element = list[#list]
  end

  if not element then
    error('No buffer found at index: ' .. num, vim.log.levels.WARN)
  end

  local bufnr = element.id
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    -- This will properly trigger SwapExists, etc.
    local filename = vim.api.nvim_buf_get_name(bufnr)
    print('Buffer not loaded, opening:', filename)
    vim.cmd('buffer ' .. bufnr)
  else
    vim.api.nvim_set_current_buf(bufnr)
  end
end

return M
