local Job = require("plenary.job")
local fs = require("sapling.fs")

local M = {}

local status_priority = {
  ignored = 1,
  untracked = 2,
  modified = 3,
}

local function empty_result(repo_root)
  return {
    exact = {},
    exact_counts = {},
    aggregate = {},
    aggregate_counts = {},
    repo_root = repo_root,
  }
end

local function finish(callback, result)
  vim.schedule(function()
    callback(result)
  end)
end

local function merge_status(current, incoming)
  if not current then
    return incoming
  end

  if not incoming then
    return current
  end

  if status_priority[incoming] > status_priority[current] then
    return incoming
  end

  return current
end

local function parse_status(code)
  if code == "!!" then
    return "ignored"
  end

  if code == "??" then
    return "untracked"
  end

  return "modified"
end

local function run_git_job(cwd, args, callback)
  local ok = pcall(function()
    Job:new({
      command = "git",
      args = vim.list_extend({ "-C", cwd }, args),
      on_exit = function(job, code)
        finish(callback, {
          code = code,
          result = job:result(),
        })
      end,
    }):start()
  end)

  if not ok then
    finish(callback, {
      code = 1,
      result = {},
    })
  end
end

function M.collect_async(root, callback)
  local normalized_root = fs.normalize(root)

  if not normalized_root or vim.fn.executable("git") ~= 1 then
    finish(callback, empty_result(nil))
    return
  end

  run_git_job(normalized_root, {
    "rev-parse",
    "--show-toplevel",
  }, function(repo_job)
    if repo_job.code ~= 0 or #repo_job.result == 0 then
      callback(empty_result(nil))
      return
    end

    local repo_root = fs.normalize(repo_job.result[1])

    if not repo_root then
      callback(empty_result(nil))
      return
    end

    run_git_job(normalized_root, {
      "-c",
      "status.relativePaths=false",
      "-c",
      "core.quotePath=false",
      "status",
      "--porcelain=v1",
      "--ignored=matching",
      "--untracked-files=all",
    }, function(status_job)
      if status_job.code ~= 0 then
        callback(empty_result(repo_root))
        return
      end

      local exact = {}
      local exact_counts = {}
      local aggregate = {}
      local aggregate_counts = {}

      for _, line in ipairs(status_job.result) do
        if line ~= "" then
          local code = line:sub(1, 2)
          local path = line:sub(4)

          if code:match("[RC]") then
            path = path:match(" -> (.+)$") or path
          end

          local absolute_path = fs.normalize(fs.join(repo_root, path))

          if absolute_path and fs.is_within(normalized_root, absolute_path) then
            local status = parse_status(code)
            local key = fs.path_key(absolute_path)
            exact[key] = merge_status(exact[key], status)
            exact_counts[key] = (exact_counts[key] or 0) + 1

            local parent = fs.dirname(absolute_path)

            while parent and fs.is_within(normalized_root, parent) and not fs.path_equal(parent, normalized_root) do
              local parent_key = fs.path_key(parent)
              aggregate[parent_key] = merge_status(aggregate[parent_key], status)
              aggregate_counts[parent_key] = (aggregate_counts[parent_key] or 0) + 1
              parent = fs.dirname(parent)
            end
          end
        end
      end

      callback({
        exact = exact,
        exact_counts = exact_counts,
        aggregate = aggregate,
        aggregate_counts = aggregate_counts,
        repo_root = repo_root,
      })
    end)
  end)
end

return M
