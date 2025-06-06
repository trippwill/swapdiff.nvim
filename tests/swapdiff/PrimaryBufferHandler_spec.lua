local PrimaryBufferHandler = require('swapdiff.PrimaryBufferHandler')
local stub = require('luassert.stub')

describe('PrimaryBufferHandler', function()
  local handler, mock_log, mock_ui, mock_recovery, orig_ui, orig_recovery, orig_fn

  local pending = {
    relfile = 'foo.txt',
    absfile = '/tmp/foo.txt',
    swapinfos = { { swappath = '/tmp/foo.txt.swp', info = {} } },
  }

  before_each(function()
    -- Mock log
    mock_log = {
      trace = function() end,
      debug = function() end,
      info = function() end,
      warn = function() end,
    }
    -- Mock ui
    mock_ui = { open_select = stub.new() }
    orig_ui = package.loaded['swapdiff.ui']
    package.loaded['swapdiff.ui'] = mock_ui
    -- Mock RecoveryTabHandler
    mock_recovery = {
      new = function()
        return setmetatable({
          start_recovery = stub.new(),
        }, { __index = mock_recovery })
      end,
    }
    orig_recovery = package.loaded['swapdiff.RecoveryTabHandler']
    package.loaded['swapdiff.RecoveryTabHandler'] = mock_recovery
    -- Mock vim.fn
    orig_fn = vim.fn
    vim.fn = setmetatable({
      delete = stub.new(),
    }, {
      __index = function()
        return function() end
      end,
    })

    handler = PrimaryBufferHandler:new(mock_log, pending)
  end)

  after_each(function()
    package.loaded['swapdiff.ui'] = orig_ui
    package.loaded['swapdiff.RecoveryTabHandler'] = orig_recovery
    vim.fn = orig_fn
  end)

  it('constructs with correct fields', function()
    assert.is_table(handler)
    assert.same(mock_log, handler._log)
    assert.same(pending, handler._pending)
  end)

  it('calls prompt for Interactive style', function()
    handler.prompt = stub.new()
    handler:onBufWinEnter({ file = 'foo.txt' }, { style = 'Interactive' })
    ---@diagnostic disable-next-line: undefined-field
    assert.stub(handler.prompt).was_called()
  end)

  it('skips prompt if once and _user_choice set', function()
    handler._user_choice = 1
    handler.prompt = stub.new()
    handler:onBufWinEnter({ file = 'foo.txt' }, { style = 'Interactive', once = true })
    ---@diagnostic disable-next-line: undefined-field
    assert.stub(handler.prompt).was_not_called()
  end)

  it('calls notify for Notify style', function()
    handler.notify = stub.new()
    handler:onBufWinEnter({ file = 'foo.txt' }, { style = 'Notify' })
    ---@diagnostic disable-next-line: undefined-field
    assert.stub(handler.notify).was_called()
  end)

  it('warns on unknown style', function()
    handler._log.warn = stub.new()
    handler:onBufWinEnter({ file = 'foo.txt' }, { style = 'Unknown' })
    ---@diagnostic disable-next-line: undefined-field
    assert.stub(handler._log.warn).was_called()
  end)

  it('notify schedules a notification', function()
    local called = false
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(...)
      called = true
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify_once = function(...)
      called = true
    end
    handler:notify({ file = 'foo.txt' }, { once = false })
    vim.wait(10)
    assert.is_true(called)
  end)
end)
