---@diagnostic disable: param-type-mismatch
local util = require('swapdiff.util')

---@module 'plenary.test_harness'
---@diagnostic disable: unused-local
local plenary = nil

describe('util.abs_path', function()
  it('returns empty string for nil or empty input', function()
    assert.are.equal(util.abs_path(nil), '')
    assert.are.equal(util.abs_path(''), '')
  end)
  it('returns absolute path for relative file', function()
    local fname = 'test/test_util.lua'
    local abs = util.abs_path(fname)
    assert.is_true(abs:sub(-#fname) == fname or abs:find(fname, 1, true))
  end)
end)

describe('util.tail_path', function()
  it('returns empty string for nil or empty input', function()
    assert.are.equal(util.tail_path(nil), '')
    assert.are.equal(util.tail_path(''), '')
  end)
  it('returns file name from path', function()
    assert.are.equal(util.tail_path('/foo/bar/baz.txt'), 'baz.txt')
    assert.are.equal(util.tail_path('baz.txt'), 'baz.txt')
  end)
end)

describe('util.abs_dir', function()
  it('returns empty string for nil or empty input', function()
    assert.are.equal(util.abs_dir(nil), '')
    assert.are.equal(util.abs_dir(''), '')
  end)
  it('returns absolute directory for file path', function()
    local fname = 'test/test_util.lua'
    local absdir = util.abs_dir(fname)
    assert.not_nil(absdir:find('test'))
  end)
end)

describe('util.remove_prefix', function()
  it('removes prefix if present', function()
    assert.are.equal(util.remove_prefix('foo/', 'foo/bar.txt'), 'bar.txt')
    assert.are.equal(util.remove_prefix('bar', 'barbaz'), 'baz')
  end)
  it('returns original string if prefix not present', function()
    assert.are.equal(util.remove_prefix('foo/', 'bar.txt'), 'bar.txt')
    assert.are.equal(util.remove_prefix('baz', 'barbaz'), 'barbaz')
  end)
end)

describe('util.assert_pending', function()
  it('returns pending values when input matches', function()
    local pending = {
      relfile = 'foo.txt',
      absfile = '/abs/foo.txt',
      swapinfos = { { swappath = '/tmp/foo.swp', info = {} } },
    }
    local rel, abs, infos = util.assert_pending(pending, '/abs/foo.txt')
    assert.are.equal('foo.txt', rel)
    assert.are.equal('/abs/foo.txt', abs)
    assert.are.equal(pending.swapinfos, infos)
  end)

  it('errors when absfile mismatches', function()
    local pending = {
      relfile = 'foo.txt',
      absfile = '/abs/foo.txt',
      swapinfos = { { swappath = '/tmp/foo.swp', info = {} } },
    }
    local ok, err = pcall(util.assert_pending, pending, '/abs/other.txt')
    assert.is_false(ok)
    assert.is_truthy(err)
  end)
end)
