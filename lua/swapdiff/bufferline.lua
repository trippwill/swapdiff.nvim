local M = {}

---Navigate to a buffer by index.
---Unlike bufferline.nvim go_to, this ensures SwapExists is triggered if necessary.
---@param num number | string
---@param absolute boolean? whether or not to use the elements absolute position or visible positions
function M.go_to(num, absolute)
  local ok, bufferline = pcall(require, 'bufferline')
  if not ok then
    vim.notify('Bufferline is not available, cannot go to buffer')
    return
  end

  if not absolute then
    vim.notify('Only absolute index is supported, cannot go to buffer')
    return
  end

  num = type(num) == 'string' and tonumber(num) or num
  local elements = bufferline.get_elements()
  local mode = elements.mode

  if mode ~= 'buffers' then
    vim.notify('Only buffers mode is supported, cannot go to buffer')
    return
  end

  local list = elements.elements
  local element = list[num]
  if num == -1 or not element then
    element = list[#list]
  end

  if not element then
    vim.notify('No buffer found at index: ' .. num)
    return
  end

  if element then
    local bufnr = element.id
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      -- This will properly trigger SwapExists, etc.
      local filename = vim.api.nvim_buf_get_name(bufnr)
      print('Buffer not loaded, opening:', filename)
      vim.cmd('buffer ' .. bufnr)
    else
      vim.api.nvim_set_current_buf(bufnr)
    end
  else
    vim.notify('No buffer found at index:', num)
  end
end

return M
