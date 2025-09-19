# jbang-nvim

A small Neovim plugin to run and build JBang scripts from within Neovim.

Features
- Run JBang scripts (`.java`, `.jsh`) and jars.
- Build/cached artifacts with `jbang build`.
- Initialize scripts with `jbang init`.
- Reusable bottom terminal split for output.
- Completion for subcommands, file targets, and common flags.
- Minimal Lua configuration via `require('jbang').setup()`.

Requirements
- `jbang` installed and available on your PATH.
- Neovim 0.7+ (for Lua API and termopen).

Installation
Install with your plugin manager of choice (packer/lazy/vim-plug), or add the folder to your runtimepath.

Example (packer.nvim):

```lua
use {
  'fintanmm/jbang-nvim',
  config = function()
    require('jbang').setup({
      cmd = 'jbang',
      terminal = true,
      term_height = 12,
      global_flags = {},
    })
  end,
}
```

Usage
- `:JBangRun [target] [args...] -- [flags...]` — run a script or GAV/alias (defaults to current file).
- `:JBangBuild [target] -- [flags...]` — build and store compiled artifacts.
- `:JBangInit [name] [args...] -- [flags...]` — initialize a new script (defaults to `hello.java`).
- `:JBangVersion [flags...]` — show jbang version.
- `:JBangSetup key=value ...` — configure plugin at runtime.
- `:JBang <subcommand> ...` — top-level dispatcher with completion.

Examples
- Run current file: `:JBangRun`
- Run with args and fresh resources: `:JBangRun MyApp.java arg1 arg2 -- --fresh`
- Build current file quietly: `:JBangBuild -- --quiet`
- Initialize a script: `:JBangInit app.java`

Configuration
Configure in Lua by calling `require('jbang').setup()` early in your config:

```lua
require('jbang').setup({
  cmd = 'jbang',           -- path or name of the jbang executable
  terminal = true,         -- use bottom terminal split
  term_height = 12,        -- terminal split height
  global_flags = { '--quiet' },
  shell = nil,             -- shell to use for the terminal (defaults to vim.o.shell)
  -- When running without the terminal (terminal=false), notify with output on completion
  notify_on_background = true,
  -- Truncate notifications after this many chars
  notify_max_chars = 4096,
})
```

Testing
Run the test suite with `busted` from the project root. The test suite uses a small `vim` mock and validates background job behavior:

```sh
busted
```

License
This project is licensed under the MIT License — see `LICENSE`.
