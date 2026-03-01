local M = {}

function M.now_ms()
  return math.floor(vim.loop.hrtime() / 1e6)
end

function M.read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local s = table.concat(lines, "\n")
  if s == "" then
    return nil
  end
  local ok2, obj = pcall(vim.json.decode, s)
  if not ok2 then
    return nil
  end
  return obj
end

function M.write_json(path, obj)
  local s = vim.json.encode(obj or {})
  local f = assert(io.open(path, "w"))
  f:write(s)
  f:close()
end

function M.basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

function M.file_exists(path)
  local st = vim.loop.fs_stat(path)
  return st ~= nil
end

function M.is_binary(path)
  local fd = io.open(path, "rb")
  if not fd then
    return false
  end
  local chunk = fd:read(8000)
  fd:close()
  if not chunk then
    return false
  end
  return chunk:find("\0", 1, true) ~= nil
end

return M
