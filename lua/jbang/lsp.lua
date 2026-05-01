local M = {}

local function get_jbang_info(filepath)
  local cmd = string.format("jbang info tools %s", vim.fn.shellescape(filepath))
  local handle = io.popen(cmd)
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  
  local ok, decoded = pcall(vim.json.decode, result)
  if not ok then return nil end
  return decoded
end

function M.get_classpath(filepath)
  local info = get_jbang_info(filepath or vim.api.nvim_buf_get_name(0))
  if info and info.resolvedDependencies then
    return info.resolvedDependencies
  end
  return {}
end

--- Integration for nvim-jdtls or lspconfig
--- This can be used to augment the settings passed to the LSP
function M.get_jdtls_config(filepath)
  local classpath = M.get_classpath(filepath)
  if #classpath == 0 then return {} end
  
  return {
    settings = {
      java = {
        project = {
          referencedLibraries = classpath
        }
      }
    }
  }
end

return M
