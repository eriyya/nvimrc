local uv = vim.uv or vim.loop

local M = {}

local is_windows = package.config:sub(1, 1) == "\\"

local function with_forward_slashes(path)
  return path:gsub("\\", "/")
end

local function normalize_for_compare(path)
  path = with_forward_slashes(path)

  if is_windows then
    return path:lower()
  end

  return path
end

function M.path_key(path)
  return normalize_for_compare(path)
end

function M.normalize(path)
  if not path or path == "" then
    return nil
  end

  local absolute = vim.fn.fnamemodify(path, ":p")
  return vim.fs.normalize(absolute)
end

function M.cwd()
  return M.normalize(vim.fn.getcwd())
end

function M.join(...)
  return vim.fs.normalize(vim.fs.joinpath(...))
end

function M.basename(path)
  return vim.fs.basename(path)
end

function M.dirname(path)
  return vim.fs.dirname(path)
end

function M.exists(path)
  return M.stat(path) ~= nil
end

function M.stat(path)
  local normalized = M.normalize(path)

  if not normalized then
    return nil
  end

  return uv.fs_stat(normalized)
end

function M.is_directory(path)
  local stat = M.stat(path)
  return stat and stat.type == "directory" or false
end

function M.path_equal(left, right)
  if not left or not right then
    return false
  end

  return normalize_for_compare(M.normalize(left)) == normalize_for_compare(M.normalize(right))
end

function M.is_within(root, path)
  local normalized_root = M.normalize(root)
  local normalized_path = M.normalize(path)

  if not normalized_root or not normalized_path then
    return false
  end

  local root_cmp = normalize_for_compare(normalized_root)
  local path_cmp = normalize_for_compare(normalized_path)

  if path_cmp == root_cmp then
    return true
  end

  return path_cmp:sub(1, #root_cmp + 1) == root_cmp .. "/"
end

function M.relative(root, path)
  if not M.is_within(root, path) then
    return nil
  end

  local normalized_root = M.normalize(root)
  local normalized_path = M.normalize(path)

  if M.path_equal(normalized_root, normalized_path) then
    return ""
  end

  local normalized_root_path = with_forward_slashes(normalized_root)
  local normalized_path_path = with_forward_slashes(normalized_path)
  return normalized_path_path:sub(#normalized_root_path + 2)
end

function M.resolve(root, input)
  if not input or input == "" then
    return nil
  end

  if vim.fn.fnamemodify(input, ":p") == input or input:match("^%a:[/\\]") or input:match("^[/\\]") then
    return M.normalize(input)
  end

  return M.join(root, input)
end

function M.mkdir_p(path)
  local normalized = M.normalize(path)

  if not normalized then
    return false, "Invalid directory path"
  end

  local ok = vim.fn.mkdir(normalized, "p")

  if ok == 1 or ok == 2 then
    return true
  end

  return false, ("Failed to create directory: %s"):format(normalized)
end

function M.create_file(path)
  local normalized = M.normalize(path)

  if not normalized then
    return false, "Invalid file path"
  end

  local valid, valid_err = M.validate_path_segments(normalized)
  if not valid then
    return false, valid_err
  end

  local len_ok, len_err = M.check_path_length(normalized)
  if not len_ok then
    return false, len_err
  end

  if M.exists(normalized) then
    return false, ("Path already exists: %s"):format(normalized)
  end

  local parent = M.dirname(normalized)
  local ok, err = M.mkdir_p(parent)

  if not ok then
    return false, err
  end

  local fd, open_err = uv.fs_open(normalized, "w", 420)

  if not fd then
    return false, open_err or ("Failed to create file: %s"):format(normalized)
  end

  uv.fs_close(fd)
  return true
end

function M.create_dir(path)
  local normalized = M.normalize(path)

  if not normalized then
    return false, "Invalid directory path"
  end

  local valid, valid_err = M.validate_path_segments(normalized)
  if not valid then
    return false, valid_err
  end

  local len_ok, len_err = M.check_path_length(normalized)
  if not len_ok then
    return false, len_err
  end

  if M.exists(normalized) then
    return false, ("Path already exists: %s"):format(normalized)
  end

  return M.mkdir_p(normalized)
end

function M.rename(from_path, to_path)
  local normalized_from = M.normalize(from_path)
  local normalized_to = M.normalize(to_path)

  if not normalized_from or not normalized_to then
    return false, "Invalid rename path"
  end

  if not M.exists(normalized_from) then
    return false, ("Path does not exist: %s"):format(normalized_from)
  end

  if M.exists(normalized_to) then
    return false, ("Destination already exists: %s"):format(normalized_to)
  end

  local valid, valid_err = M.validate_path_segments(normalized_to)
  if not valid then
    return false, valid_err
  end

  local len_ok, len_err = M.check_path_length(normalized_to)
  if not len_ok then
    return false, len_err
  end

  local parent = M.dirname(normalized_to)
  local ok, err = M.mkdir_p(parent)

  if not ok then
    return false, err
  end

  local renamed, rename_err = uv.fs_rename(normalized_from, normalized_to)

  if not renamed then
    if rename_err and rename_err:find("EXDEV") then
      local copy_ok, copy_err = M.copy(normalized_from, normalized_to)
      if not copy_ok then
        return false, copy_err
      end
      local remove_ok, remove_err = M.remove(normalized_from)
      if not remove_ok then
        return false, ("Copied to destination but failed to remove source: %s"):format(remove_err)
      end
      return true
    end
    return false, rename_err or ("Failed to move path to: %s"):format(normalized_to)
  end

  return true
end

function M.remove(path)
  local normalized = M.normalize(path)

  if not normalized then
    return false, "Invalid delete path"
  end

  if not M.exists(normalized) then
    return false, ("Path does not exist: %s"):format(normalized)
  end

  local flags = M.is_directory(normalized) and "rf" or ""
  local result = vim.fn.delete(normalized, flags)

  if result ~= 0 then
    return false, ("Failed to delete: %s"):format(normalized)
  end

  return true
end

local function copy_file(from_path, to_path)
  local source_fd, source_err = uv.fs_open(from_path, "r", 438)

  if not source_fd then
    return false, source_err or ("Failed to open file for copy: %s"):format(from_path)
  end

  local stat = uv.fs_fstat(source_fd)

  if not stat then
    uv.fs_close(source_fd)
    return false, ("Failed to stat file for copy: %s"):format(from_path)
  end

  local data, read_err = uv.fs_read(source_fd, stat.size, 0)
  uv.fs_close(source_fd)

  if data == nil then
    return false, read_err or ("Failed to read file for copy: %s"):format(from_path)
  end

  local target_fd, target_err = uv.fs_open(to_path, "w", stat.mode or 420)

  if not target_fd then
    return false, target_err or ("Failed to create copy target: %s"):format(to_path)
  end

  local written, write_err = uv.fs_write(target_fd, data, 0)
  uv.fs_close(target_fd)

  if not written then
    return false, write_err or ("Failed to write copy target: %s"):format(to_path)
  end

  return true
end

function M.copy(from_path, to_path)
  local normalized_from = M.normalize(from_path)
  local normalized_to = M.normalize(to_path)

  if not normalized_from or not normalized_to then
    return false, "Invalid copy path"
  end

  if not M.exists(normalized_from) then
    return false, ("Path does not exist: %s"):format(normalized_from)
  end

  if M.exists(normalized_to) then
    return false, ("Destination already exists: %s"):format(normalized_to)
  end

  local parent = M.dirname(normalized_to)
  local ok, err = M.mkdir_p(parent)

  if not ok then
    return false, err
  end

  if M.is_directory(normalized_from) then
    local dir_ok, dir_err = M.create_dir(normalized_to)

    if not dir_ok then
      return false, dir_err
    end

    for _, child in ipairs(M.scandir(normalized_from)) do
      local copied, copy_err = M.copy(child.path, M.join(normalized_to, child.name))

      if not copied then
        return false, copy_err
      end
    end

    return true
  end

  return copy_file(normalized_from, normalized_to)
end

function M.scandir(path)
  local normalized = M.normalize(path)

  if not normalized then
    return {}
  end

  local handle = uv.fs_scandir(normalized)

  if not handle then
    return {}
  end

  local entries = {}

  while true do
    local name, entry_type = uv.fs_scandir_next(handle)

    if not name then
      break
    end

    local entry_path = M.join(normalized, name)
    local stat = uv.fs_stat(entry_path)

    local kind = entry_type
    if kind == "link" or not kind then
      kind = stat and stat.type or "file"
    end

    if kind == "directory" then
      table.insert(entries, {
        name = name,
        path = entry_path,
        type = "directory",
      })
    else
      table.insert(entries, {
        name = name,
        path = entry_path,
        type = "file",
      })
    end
  end

  table.sort(entries, function(left, right)
    if left.type ~= right.type then
      return left.type == "directory"
    end

    return left.name:lower() < right.name:lower()
  end)

  return entries
end

local WINDOWS_RESERVED_NAMES = {
  CON = true, PRN = true, AUX = true, NUL = true,
  COM1 = true, COM2 = true, COM3 = true, COM4 = true, COM5 = true,
  COM6 = true, COM7 = true, COM8 = true, COM9 = true,
  LPT1 = true, LPT2 = true, LPT3 = true, LPT4 = true, LPT5 = true,
  LPT6 = true, LPT7 = true, LPT8 = true, LPT9 = true,
}

function M.validate_filename(name)
  if not is_windows then
    return true
  end

  if name:find('[<>:"|%?%*]') then
    return false, ("Filename contains invalid Windows character: %s"):format(name)
  end

  local base = name:match("^([^%.]+)") or name
  if WINDOWS_RESERVED_NAMES[base:upper()] then
    return false, ("'%s' is a reserved Windows filename"):format(name)
  end

  if name:match("[%. ]$") then
    return false, "Filenames cannot end with a dot or space on Windows"
  end

  return true
end

function M.validate_path_segments(path)
  if not is_windows then
    return true
  end

  local segments = vim.split(with_forward_slashes(path), "/", { plain = true, trimempty = true })
  local start = 1
  if segments[1] and segments[1]:match("^%a:$") then
    start = 2
  end

  for i = start, #segments do
    local ok, err = M.validate_filename(segments[i])
    if not ok then
      return false, err
    end
  end

  return true
end

function M.check_path_length(path)
  if not is_windows then
    return true
  end

  if #path > 259 then
    return false, ("Path exceeds Windows MAX_PATH limit (%d characters)"):format(#path)
  end

  return true
end

return M
