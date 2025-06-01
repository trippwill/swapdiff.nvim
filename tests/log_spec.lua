local log = require('swapdiff.log')

---@module 'plenary.test_harness'
---@diagnostic disable: unused-local
local plenary = nil

local function make_sink()
  return {
    messages = {},
    log = function(self, level, fmt, ...)
      table.insert(self.messages, { level = level, msg = string.format(fmt, ...) })
    end,
  }
end

describe('Logger', function()
  local logger, sink_info, sink_warn

  before_each(function()
    sink_info = make_sink()
    sink_warn = make_sink()
    logger = log.Logger:new('TestLogger')
    logger:add_sink(vim.log.levels.INFO, sink_info)
    logger:add_sink(vim.log.levels.WARN, sink_warn)
    logger:enable(true)
  end)

  it('logs to correct sinks by level', function()
    logger:info('info %d', 1)
    logger:warn('warn %d', 2)
    logger:error('error %d', 3)
    assert.are.equal(3, #sink_info.messages)
    assert.are.equal(2, #sink_warn.messages)
    assert.are.equal('info 1', sink_info.messages[1].msg)
    assert.are.equal('warn 2', sink_warn.messages[1].msg)
  end)

  it('lazy logging only calls function if enabled', function()
    local called = false
    logger:debug_lazy(function()
      called = true
      return 'should not log'
    end)
    assert.is_false(called)
    logger:info_lazy(function()
      called = true
      return 'should log'
    end)
    assert.is_true(called)
    assert.are.equal('should log', sink_info.messages[#sink_info.messages].msg)
  end)

  it('enable/disable works', function()
    logger:enable(false)
    logger:info('should not log')
    assert.are.equal(0, #sink_info.messages)
    logger:enable(true)
    logger:info('should log')
    assert.are.equal(1, #sink_info.messages)
  end)

  it('critical logs and errors', function()
    local ok, err = pcall(function()
      logger:critical('fail %d', 42)
    end)
    assert.is_false(ok)
    ---@diagnostic disable-next-line: need-check-nil
    assert.is_true(err:match('CRITICAL') ~= nil)
    assert.are.equal('fail 42', sink_info.messages[#sink_info.messages].msg)
  end)

  it('critical_lazy logs and errors', function()
    local ok, err = pcall(function()
      logger:critical_lazy(function()
        return 'lazy fail'
      end)
    end)
    assert.is_false(ok)
    ---@diagnostic disable-next-line: need-check-nil
    assert.is_true(err:match('CRITICAL') ~= nil)
    assert.are.equal('lazy fail', sink_info.messages[#sink_info.messages].msg)
  end)
end)
