local M = {}

local default_config = {
  cmd = "jbang",
  terminal = true,
  term_height = 12,
  global_flags = {},
  shell = nil, -- defaults to vim.o.shell
}

M._config = vim.deepcopy(default_config)
M._term = nil

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", default_config, opts or {})
end

local function build_args(subcmd, args, flags)
  local cfg = M._config
  local result = {}
  table.insert(result, cfg.cmd)
  if flags and #flags > 0 then
    for _, f in ipairs(flags) do table.insert(result, f) end
  end
  if subcmd and #subcmd > 0 then table.insert(result, subcmd) end
  if args and #args > 0 then
    for _, a in ipairs(args) do table.insert(result, a) end
  end
  return result
end

local function ensure_binary()
  local cmd = M._config.cmd
  if type(cmd) == "table" then
    cmd = cmd[1]
  end
  if vim.fn.executable(cmd) == 1 then return true end
  vim.notify(("jbang-nvim: '%s' not found in PATH. Configure with require('jbang').setup{ cmd = 'path/to/jbang' }"):format(cmd), vim.log.levels.ERROR)
  return false
end

local function shell_path()
  return M._config.shell or vim.o.shell or os.getenv("SHELL") or "/bin/sh"
end

local function ensure_term()
  if not M._config.terminal then return nil end
  if M._term and vim.api.nvim_buf_is_valid(M._term.buf) and vim.api.nvim_win_is_valid(M._term.win) then
    return M._term
  end
  local cur_win = vim.api.nvim_get_current_win()
  vim.cmd("botright " .. M._config.term_height .. "split")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  local chan = vim.fn.termopen(shell_path())
  M._term = { buf = buf, win = vim.api.nvim_get_current_win(), chan = chan, prev = cur_win }
  return M._term
end

local function escape_join(argv)
  local parts = {}
  for _, a in ipairs(argv) do table.insert(parts, vim.fn.shellescape(a)) end
  return table.concat(parts, " ")
end

local function term_send(cmd_args)
  if M._config.terminal then
    local term = ensure_term()
    if not term then return end
    if not vim.api.nvim_win_is_valid(term.win) then
      vim.cmd("botright " .. M._config.term_height .. "split")
      term.win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(term.win, term.buf)
    end
    vim.api.nvim_set_current_win(term.win)
    local cmdline = escape_join(cmd_args)
    local ok = pcall(vim.fn.chansend, term.chan, cmdline .. "\n")
    if not ok then
      -- Recreate shell if channel is dead
      vim.api.nvim_win_set_buf(term.win, term.buf)
      term.chan = vim.fn.termopen(shell_path())
      vim.fn.chansend(term.chan, cmdline .. "\n")
    end
    vim.cmd("normal! G")
  else
    -- Direct jobstart without shell for better quoting
    vim.fn.jobstart(cmd_args, { detach = false })
  end
end

local function current_script()
  local name = vim.api.nvim_buf_get_name(0)
  if name == nil or name == "" then return nil end
  if name:match("%.java$") or name:match("%.jsh$") then return name end
  return nil
end

-- Public API
function M.run(target, args, flags)
  if not ensure_binary() then return end
  local tgt = target
  if not tgt or #tgt == 0 then tgt = current_script() end
  if not tgt or #tgt == 0 then
    vim.notify("JBangRun: no target; open a .java/.jsh or pass one", vim.log.levels.WARN)
    return
  end
  local a = { tgt }
  if args and #args > 0 then for _,v in ipairs(args) do table.insert(a, v) end end
  local f = {}
  if M._config.global_flags and #M._config.global_flags > 0 then
    for _,g in ipairs(M._config.global_flags) do table.insert(f, g) end
  end
  if flags and #flags > 0 then for _,v in ipairs(flags) do table.insert(f, v) end end
  term_send(build_args("run", a, f))
end

function M.build(target, flags)
  if not ensure_binary() then return end
  local tgt = target
  if not tgt or #tgt == 0 then tgt = current_script() end
  if not tgt or #tgt == 0 then
    vim.notify("JBangBuild: no target; open a .java/.jsh or pass one", vim.log.levels.WARN)
    return
  end
  local a = { tgt }
  local f = {}
  if M._config.global_flags and #M._config.global_flags > 0 then
    for _,g in ipairs(M._config.global_flags) do table.insert(f, g) end
  end
  if flags and #flags > 0 then for _,v in ipairs(flags) do table.insert(f, v) end end
  term_send(build_args("build", a, f))
end

function M.init_script(name, args, flags)
  if not ensure_binary() then return end
  local a = { name or "hello.java" }
  if args and #args > 0 then for _,v in ipairs(args) do table.insert(a, v) end end
  local f = {}
  if M._config.global_flags and #M._config.global_flags > 0 then
    for _,g in ipairs(M._config.global_flags) do table.insert(f, g) end
  end
  if flags and #flags > 0 then for _,v in ipairs(flags) do table.insert(f, v) end end
  term_send(build_args("init", a, f))
end

function M.version(flags)
  if not ensure_binary() then return end
  local f = { "--version" }
  if M._config.global_flags and #M._config.global_flags > 0 then
    for _,g in ipairs(M._config.global_flags) do table.insert(f, g) end
  end
  if flags and #flags > 0 then for _,v in ipairs(flags) do table.insert(f, v) end end
  term_send(build_args(nil, nil, f))
end

return M
