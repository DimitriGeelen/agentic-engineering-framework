-- termlink-chrome.lua
-- WezTerm plugin for task-aware terminal chrome via TermLink RPC
--
-- Displays active TermLink session metadata (task ID, status, role)
-- in the WezTerm status bar. Queries TermLink via `termlink list --json`.
--
-- Install:
--   1. Copy this file to your WezTerm config directory
--   2. In your wezterm.lua: require("termlink-chrome").apply_to_config(config)

local wezterm = require("wezterm")
local M = {}

-- Configuration defaults
local defaults = {
  -- How often to poll TermLink (milliseconds)
  update_interval = 3000,
  -- Show session count even when no task sessions exist
  show_when_empty = false,
  -- Colors
  colors = {
    task_bg = "#4c566a",
    task_fg = "#88c0d0",
    status_bg = "#3b4252",
    status_fg = "#a3be8c",
    role_bg = "#3b4252",
    role_fg = "#b48ead",
    empty_fg = "#4c566a",
    separator_fg = "#2e3440",
  },
  -- Nerd font icons (set to empty string if no nerd fonts)
  icons = {
    task = "\u{f0ae}",      -- nf-fa-tasks
    session = "\u{f489}",   -- nf-oct-terminal
    role = "\u{f2c2}",      -- nf-fa-id_badge
    separator = " \u{e0b2} ",
  },
}

-- Cache for TermLink data to avoid polling on every status update
local cache = {
  data = nil,
  last_update = 0,
  interval = 3, -- seconds
}

-- Parse task ID from session tags
-- Convention: tags contain "task:T-XXX" for task-tagged sessions
local function extract_task(tags)
  if not tags then return nil end
  if type(tags) == "table" then
    for _, tag in ipairs(tags) do
      local task_id = string.match(tag, "^task:(T%-%d+)$")
      if task_id then return task_id end
    end
  elseif type(tags) == "string" then
    return string.match(tags, "task:(T%-%d+)")
  end
  return nil
end

-- Parse role from session tags or registration
local function extract_role(session)
  if session.role and session.role ~= "" then
    return session.role
  end
  if session.tags then
    if type(session.tags) == "table" then
      for _, tag in ipairs(session.tags) do
        local role = string.match(tag, "^role:(.+)$")
        if role then return role end
      end
    end
  end
  return nil
end

-- Query TermLink for active sessions
local function query_termlink()
  local now = os.time()
  if cache.data and (now - cache.last_update) < cache.interval then
    return cache.data
  end

  local success, stdout, _ = wezterm.run_child_process({
    "termlink", "list", "--json",
  })

  if not success or not stdout or stdout == "" then
    cache.data = nil
    cache.last_update = now
    return nil
  end

  -- Parse JSON
  local ok, parsed = pcall(wezterm.json_parse, stdout)
  if not ok or not parsed then
    cache.data = nil
    cache.last_update = now
    return nil
  end

  cache.data = parsed
  cache.last_update = now
  return parsed
end

-- Build status bar elements from TermLink sessions
local function build_status(sessions, opts)
  if not sessions or #sessions == 0 then
    if opts.show_when_empty then
      return {
        { Foreground = { Color = opts.colors.empty_fg } },
        { Text = opts.icons.session .. " no sessions" },
      }
    end
    return nil
  end

  local elements = {}
  local task_sessions = {}
  local other_count = 0

  -- Categorize sessions
  for _, session in ipairs(sessions) do
    local task_id = extract_task(session.tags)
    if task_id then
      if not task_sessions[task_id] then
        task_sessions[task_id] = { count = 0, roles = {} }
      end
      task_sessions[task_id].count = task_sessions[task_id].count + 1
      local role = extract_role(session)
      if role then
        task_sessions[task_id].roles[role] = true
      end
    else
      other_count = other_count + 1
    end
  end

  -- Build formatted elements for each task
  local first = true
  for task_id, info in pairs(task_sessions) do
    if not first then
      table.insert(elements, { Foreground = { Color = opts.colors.separator_fg } })
      table.insert(elements, { Text = " | " })
    end
    first = false

    -- Task ID
    table.insert(elements, { Background = { Color = opts.colors.task_bg } })
    table.insert(elements, { Foreground = { Color = opts.colors.task_fg } })
    table.insert(elements, { Text = " " .. opts.icons.task .. " " .. task_id .. " " })

    -- Session count if >1
    if info.count > 1 then
      table.insert(elements, { Background = { Color = opts.colors.status_bg } })
      table.insert(elements, { Foreground = { Color = opts.colors.status_fg } })
      table.insert(elements, { Text = " " .. opts.icons.session .. " " .. info.count .. " " })
    end

    -- Roles
    local role_list = {}
    for role, _ in pairs(info.roles) do
      table.insert(role_list, role)
    end
    if #role_list > 0 then
      table.insert(elements, { Background = { Color = opts.colors.role_bg } })
      table.insert(elements, { Foreground = { Color = opts.colors.role_fg } })
      table.insert(elements, { Text = " " .. opts.icons.role .. " " .. table.concat(role_list, ",") .. " " })
    end
  end

  -- Other (non-task) sessions
  if other_count > 0 then
    if not first then
      table.insert(elements, { Foreground = { Color = opts.colors.separator_fg } })
      table.insert(elements, { Text = " | " })
    end
    table.insert(elements, { Background = { Color = opts.colors.status_bg } })
    table.insert(elements, { Foreground = { Color = opts.colors.status_fg } })
    table.insert(elements, { Text = " " .. opts.icons.session .. " " .. other_count .. " other " })
  end

  -- Reset background
  table.insert(elements, { Background = { Color = "none" } })
  table.insert(elements, { Text = " " })

  return elements
end

-- Apply plugin to WezTerm config
function M.apply_to_config(config, user_opts)
  -- Merge user options with defaults
  local opts = {}
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      opts[k] = {}
      for kk, vv in pairs(v) do opts[k][kk] = vv end
      if user_opts and user_opts[k] then
        for kk, vv in pairs(user_opts[k]) do opts[k][kk] = vv end
      end
    else
      opts[k] = (user_opts and user_opts[k]) or v
    end
  end

  -- Set the update interval
  cache.interval = math.floor(opts.update_interval / 1000)
  config.status_update_interval = opts.update_interval

  -- Register the status update event
  wezterm.on("update-status", function(window, _pane)
    local sessions = query_termlink()
    local elements = build_status(sessions, opts)

    if elements then
      window:set_right_status(wezterm.format(elements))
    elseif not opts.show_when_empty then
      window:set_right_status("")
    end
  end)
end

return M
