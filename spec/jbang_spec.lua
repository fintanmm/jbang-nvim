describe('jbang core (background job behavior)', function()
  local jbang

  before_each(function()
    package.loaded['jbang'] = nil
    -- Minimal `vim` mock for running module outside Neovim
    vim = {
      notify = function() end,
      schedule = function(fn) fn() end,
      log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
      o = { shell = '/bin/sh' },
      api = {
        nvim_buf_get_name = function() return '/tmp/Hello.java' end,
        nvim_get_current_win = function() return 1 end,
        nvim_create_buf = function() return 2 end,
        nvim_win_set_buf = function() end,
        nvim_set_current_win = function() end,
        nvim_buf_is_valid = function() return true end,
        nvim_win_is_valid = function() return true end,
      },
      fn = {}
    }

    vim.fn.shellescape = function(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
    vim.fn.executable = function() return 1 end
    vim.fn.termopen = function() return 111 end
    vim.fn.chansend = function() end
  end)

  it('calls jobstart with proper args when terminal=false and notify disabled', function()
    local captured = {}
    vim.fn.jobstart = function(cmd_args, opts)
      captured.cmd = cmd_args
      captured.opts = opts
      return 42
    end

    jbang = require('jbang')
    jbang.setup({ terminal = false, notify_on_background = false, cmd = 'jbang' })
    jbang.build('Hello.java', {'--quiet'})

    assert.are.same({'jbang', '--quiet', 'build', 'Hello.java'}, captured.cmd)
  end)

  it('sends notification with combined stdout/stderr on non-zero exit', function()
    local notified = {}
    vim.notify = function(msg, level, opts)
      notified.msg = msg
      notified.level = level
      notified.opts = opts
    end

    vim.fn.jobstart = function(cmd_args, opts)
      if opts.on_stdout then opts.on_stdout(1, {'line1','line2'}, 'stdout') end
      if opts.on_stderr then opts.on_stderr(1, {'err1'}, 'stderr') end
      if opts.on_exit then opts.on_exit(1, 2, 'exit') end -- non-zero exit
      return 999
    end

    jbang = require('jbang')
    jbang.setup({ terminal = false, notify_on_background = true, cmd = 'jbang' })
    jbang.run('Hello.java', {}, {})

    assert.is_not_nil(notified.msg)
    assert.is_true(string.find(notified.msg, 'line1') ~= nil)
    assert.is_true(string.find(notified.msg, 'err1') ~= nil)
    assert.are.equal(vim.log.levels.WARN, notified.level)
  end)
end)
