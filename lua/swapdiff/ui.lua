---@class HeaderMenuItem
---@field desc string
---@field callback? fun(): nil

---@class HeaderMenuConfig
---@field prompt_hl? string
---@field option_hl? string
---@field open_cmd? string
---@field ns? string
---@field title? string
---@field ft? string
---@field trace? fun(...): nil

local M = {}

---@type HeaderMenuConfig
M.defaults = {
  prompt_hl = 'Comment',
  option_hl = 'Normal',
  open_cmd = 'topleft split',
  ns = 'headermenu_ns',
  title = 'Menu',
  ft = 'header_menu',
  trace = function(...) end, -- Default trace function does nothing
}

---Opens a menu window with prompts and options.
---@param options HeaderMenuItem[] List of options with descriptions and optional callbacks.
---@param config HeaderMenuConfig? Configuration for the header menu.
function M.open_menu_window(options, config)
  config = vim.tbl_deep_extend('force', M.defaults, config or {})

  local header_buf = vim.api.nvim_create_buf(false, true)

  local lines = {}
  for _, option in ipairs(options) do
    table.insert(lines, option.desc)
  end

  vim.api.nvim_buf_set_lines(header_buf, 0, -1, false, lines)
  vim.bo[header_buf].buftype = 'nofile'
  vim.bo[header_buf].bufhidden = 'wipe'
  vim.bo[header_buf].modifiable = false
  vim.bo[header_buf].readonly = true
  vim.bo[header_buf].filetype = config.ft

  vim.cmd(config.open_cmd)
  vim.api.nvim_win_set_buf(0, header_buf)
  vim.api.nvim_win_set_height(0, #lines + 1)
  vim.wo.winfixheight = true
  vim.wo.cursorline = true
  vim.wo.winhighlight =
    'Normal:Pmenu,NormalNC:Pmenu,CursorLine:PmenuKind,CursorLineNr:PmenuThumb,WinBar:PmenuExtraSel,WinBarNC:PmenuExtra'
  vim.wo.winbar = config.title

  -- Map Enter key to execute the callback for the current option
  local function execute_command()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local option_index = line
    config.trace('Option index:', option_index)
    local option = options[option_index]
    config.trace('Selected option:', vim.inspect(option))
    if option and option.callback then
      option.callback()
    end
  end

  vim.api.nvim_buf_set_keymap(header_buf, 'n', '<CR>', '', {
    noremap = true,
    silent = true,
    callback = execute_command,
  })

  vim.api.nvim_buf_set_keymap(header_buf, 'n', 'q', '', {
    noremap = true,
    silent = true,
    callback = function()
      vim.cmd('close')
    end,
  })

  return {
    buf = header_buf,
    win = vim.api.nvim_get_current_win(),
  }
end

return M
