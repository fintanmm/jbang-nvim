if vim.g.loaded_jbang_nvim then return end
vim.g.loaded_jbang_nvim = true

local jbang = require('jbang')

-- Subcommands and flags for completion
local SUBCOMMANDS = { 'run', 'build', 'init', 'version', 'setup', 'edit' }
local COMMON_FLAGS = {
  '--insecure', '--preview', '--config=', '--verbose', '--quiet', '--fresh', '--offline',
  '--help', '-h', '--version', '-V', '--preview'
}
local SETUP_KEYS = { 'cmd', 'terminal', 'term_height', 'global_flags', 'shell' }

local function coerce(val)
  if val == 'true' then return true end
  if val == 'false' then return false end
  local num = tonumber(val)
  if num ~= nil then return num end
  return val
end

local function split_at_sep(fargs)
  local sep = nil
  for i, v in ipairs(fargs) do if v == '--' then sep = i break end end
  if not sep then return fargs, {} end
  local left = {}
  local right = {}
  for i = 1, sep - 1 do table.insert(left, fargs[i]) end
  for i = sep + 1, #fargs do table.insert(right, fargs[i]) end
  return left, right
end

-- Find a standalone "--" token before cursor position in cmdline
local function sep_before_cursor(cmdline, cursorpos)
  if not cmdline or #cmdline == 0 then return false end
  local n = #cmdline
  local start = 1
  while true do
    local s, e = cmdline:find('%-%-', start, true)
    if not s then break end
    local before_char = (s > 1) and cmdline:sub(s-1, s-1) or ' '
    local after_char = (e < n) and cmdline:sub(e+1, e+1) or ' '
    local ok_before = before_char:match('%s') ~= nil
    local ok_after = after_char:match('%s') ~= nil
    if ok_before and ok_after then
      return s < cursorpos
    end
    start = e + 1
  end
  return false
end

local function file_completions(arglead)
  -- Use Vim's file completion and filter to relevant types
  local raw = vim.fn.getcompletion(arglead, 'file')
  local res = {}
  for _, v in ipairs(raw) do
    if v:sub(-1) == '/' or v:match('%.java$') or v:match('%.jsh$') or v:match('%.jar$') or v:match('%.groovy$') or v:match('%.kts$') then
      table.insert(res, v)
    end
  end
  return res
end

local function flags_completions(arglead)
  local res = {}
  for _, f in ipairs(COMMON_FLAGS) do
    if f:sub(1, #arglead) == arglead then table.insert(res, f) end
  end
  return res
end

-- Completion used for subcommands that take a target file and flags
local function complete_target_or_flags(arglead, cmdline, cursorpos)
  -- If the user started a flag or is after `--`, complete flags
  local after_sep = sep_before_cursor(cmdline, cursorpos)
  if arglead:sub(1,1) == '-' or after_sep then
    return flags_completions(arglead)
  end
  -- Otherwise complete files (java/jsh/jar etc.)
  return file_completions(arglead)
end

-- Top-level :JBang completion (subcommand -> delegate)
local function complete_jbang(arglead, cmdline, cursorpos)
  -- tokens from cmdline
  local s = cmdline:gsub('^%s+', '')
  local tokens = {}
  for token in s:gmatch('%S+') do table.insert(tokens, token) end

  if #tokens == 0 then
    -- no subcommand typed yet: complete subcommands
    local out = {}
    for _, sc in ipairs(SUBCOMMANDS) do
      if sc:sub(1, #arglead) == arglead then table.insert(out, sc) end
    end
    return out
  end

  local sub = tokens[1]
  -- if the cursor is still on the subcommand itself, suggest subcommands
  if #tokens == 1 and cmdline:sub(-1):match('%s') == nil and arglead ~= '' then
    local out = {}
    for _, sc in ipairs(SUBCOMMANDS) do
      if sc:sub(1, #arglead) == arglead then table.insert(out, sc) end
    end
    return out
  end

  if sub == 'run' or sub == 'build' or sub == 'init' then
    return complete_target_or_flags(arglead, cmdline, cursorpos)
  elseif sub == 'version' then
    return flags_completions(arglead)
  elseif sub == 'setup' then
    local out = {}
    for _, k in ipairs(SETUP_KEYS) do
      local cand = k .. '='
      if cand:sub(1, #arglead) == arglead then table.insert(out, cand) end
    end
    return out
  else
    -- unknown subcommand: suggest subcommands
    local out = {}
    for _, sc in ipairs(SUBCOMMANDS) do
      if sc:sub(1, #arglead) == arglead then table.insert(out, sc) end
    end
    return out
  end
end

-- Helper to parse fargs into target, args, flags
local function parse_target_args_flags(fargs)
  local left, right = split_at_sep(fargs)
  local target = left[1]
  local args = {}
  if #left > 1 then
    for i = 2, #left do table.insert(args, left[i]) end
  end
  return target, args, right
end

-- Backwards-compatible single commands
vim.api.nvim_create_user_command('JBangRun', function(opts)
  local target, args, flags = parse_target_args_flags(opts.fargs)
  jbang.run(target, args, flags)
end, { nargs = '*', complete = complete_target_or_flags })

vim.api.nvim_create_user_command('JBangBuild', function(opts)
  local target, _, flags = parse_target_args_flags(opts.fargs)
  jbang.build(target, flags)
end, { nargs = '*', complete = complete_target_or_flags })

vim.api.nvim_create_user_command('JBangInit', function(opts)
  local target, args, flags = parse_target_args_flags(opts.fargs)
  jbang.init_script(target, args, flags)
end, { nargs = '*', complete = complete_target_or_flags })

vim.api.nvim_create_user_command('JBangVersion', function(opts)
  jbang.version(opts.fargs)
end, { nargs = '*', complete = flags_completions })

vim.api.nvim_create_user_command('JBangSetup', function(opts)
  local cfg = {}
  for _, kv in ipairs(opts.fargs) do
    local k, v = kv:match('([^=]+)=(.+)')
    if k and v then cfg[k] = coerce(v) end
  end
  jbang.setup(cfg)
  print('jbang-nvim configured')
end, { nargs = '*', complete = function(arglead) local out = {} for _, k in ipairs(SETUP_KEYS) do local cand = k .. '=' if cand:sub(1, #arglead) == arglead then table.insert(out, cand) end end return out end })

-- Top-level dispatcher with subcommand completion
vim.api.nvim_create_user_command('JBang', function(opts)
  local fargs = opts.fargs
  local sub = fargs[1]
  if not sub then
    print('Usage: :JBang <run|build|init|version|setup> ...')
    return
  end
  if sub == 'run' then
    table.remove(fargs, 1)
    local target, args, flags = parse_target_args_flags(fargs)
    jbang.run(target, args, flags)
    return
  end
  if sub == 'build' then
    table.remove(fargs, 1)
    local target, _, flags = parse_target_args_flags(fargs)
    jbang.build(target, flags)
    return
  end
  if sub == 'init' then
    table.remove(fargs, 1)
    local target, args, flags = parse_target_args_flags(fargs)
    jbang.init_script(target, args, flags)
    return
  end
  if sub == 'version' then
    table.remove(fargs, 1)
    jbang.version(fargs)
    return
  end
  if sub == 'setup' then
    table.remove(fargs, 1)
    local cfg = {}
    for _, kv in ipairs(fargs) do
      local k, v = kv:match('([^=]+)=(.+)')
      if k and v then cfg[k] = coerce(v) end
    end
    jbang.setup(cfg)
    print('jbang-nvim configured')
    return
  end
  print('Unknown subcommand: ' .. tostring(sub))
end, { nargs = '*', complete = complete_jbang })
