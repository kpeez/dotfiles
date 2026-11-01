-- Name each pane after what it is doing: "~/.dotfiles", "claude · ~/.dotfiles",
-- "server:~/code/x". init.lua starts it with the server. It only replaces the
-- default "shell" label or one it set itself, so a label you set stays.
--   rex do --all ~/.config/rex/labels.lua
local T = "com.superlogical.terminal"
local home = os.getenv("HOME")
local dir = (os.getenv("XDG_STATE_HOME") or home .. "/.local/state") .. "/rex-snapshots"
local auto_path = dir .. "/labels.json"
local owner_path = dir .. "/labels.owner"
local host = rex.exec({ "/bin/hostname", "-s" }).stdout:gsub("%s+$", "")

local function read_file(path)
  local f = io.open(path)
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function write_file(path, body)
  local out = assert(io.open(path .. ".tmp", "w"))
  out:write(body)
  out:close()
  assert(os.rename(path .. ".tmp", path))
end

-- Every config reload starts a new labeler. The newest one owns the job and
-- the older ones exit when they see the owner file change.
math.randomseed(os.time())
local token = tostring(os.time()) .. "-" .. tostring(math.random(1e9))
rex.exec({ "/bin/mkdir", "-p", dir })
write_file(owner_path, token)
local function still_owner()
  if read_file(owner_path) == token then return true end
  rex.stop(0)
end

-- block ID -> the label this script set, so a hand-set label is left alone.
-- A corrupt file must not stop every future labeler, so it starts empty.
local auto = rex.json.decode(read_file(auto_path) or "{}") or {}
local function save_auto() write_file(auto_path, rex.json.encode(auto)) end

-- A remote home is unknown, so any /home/USER or /Users/USER counts as home.
local function short(path, home_dir)
  path = path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
  if home_dir and path:sub(1, #home_dir) == home_dir and path:sub(#home_dir + 1, #home_dir + 1):match("^/?$") then
    path = "~" .. path:sub(#home_dir + 1)
  elseif not home_dir then
    path = path:gsub("^/home/[^/]+", "~"):gsub("^/Users/[^/]+", "~")
  end
  local tail = #path > 60 and path:match("([^/]+/[^/]+/[^/]+)$")
  if tail and path:sub(1, #path - #tail):match("[^/]") then path = "…/" .. tail end
  return path
end

-- Rex allows 128 characters and trims surrounding whitespace. Cutting at 128
-- bytes stays under the limit; drop the last multibyte character in case the
-- cut split it.
local function fit(label)
  if #label > 128 then label = label:sub(1, 128):gsub("[\192-\255][\128-\191]*$", "") end
  return (label:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function label_for(sid, bid)
  local proc = rex.block.call(T, "process", { session_id = sid, block_id = bid })
  local fg = proc and proc.foreground
  if not fg then return nil end
  local pwd = rex.block.call(T, "pwd", { session_id = sid, block_id = bid })
  local url_host, path = ((pwd and pwd.pwd) or ""):match("^file://([^/]*)(/.*)$")
  if url_host and url_host ~= "" and url_host:match("^[^.]+") ~= host then
    return fit(url_host .. ":" .. short(path))
  end
  path = path or fg.cwd
  if not path then return nil end
  local where = short(path, proc.home)
  local parent = (proc.ancestors or {})[1]
  if fg.name == "login" or (parent and parent.name == "login") then return fit(where) end
  local program = (fg.argv0 or ""):match("[^/]+$") or fg.name
  return fit(program .. " · " .. where)
end

local function relabel(sid, bid)
  if not still_owner() then return end
  local info = rex.call("session.describe_block", { session_id = sid, block_id = bid })
  if not info then return end
  local current = info.block.label
  if current ~= "shell" and current ~= auto[bid] then return end
  local label = label_for(sid, bid)
  if not label or label == current then return end
  if rex.call("session.set_block_label", { session_id = sid, block_id = bid, label = label }) then
    -- Remember what Rex stored, not what was sent: Rex also trims Unicode
    -- spaces and replaces invalid UTF-8, and any difference would make the
    -- label look hand-set and freeze it.
    local stored = rex.call("session.describe_block", { session_id = sid, block_id = bid })
    auto[bid] = stored and stored.block.label or label
    save_auto()
  end
end

-- Wait for a burst of process changes (a pipeline, git's helpers) to settle.
local timers = {}
local function soon(ctx)
  local sid, bid = ctx.session_id, ctx.block_id
  if timers[bid] then timers[bid]:cancel() end
  timers[bid] = rex.after(0.5, function()
    timers[bid] = nil
    relabel(sid, bid)
  end)
end
rex.on("terminal.process_changed", soon)
rex.on("terminal.pwd_changed", soon)
rex.on("block_closed", function(_, ev)
  if auto[ev.block_id] and still_owner() then
    auto[ev.block_id] = nil
    save_auto()
  end
end)
rex.every(5, still_owner)

-- Label every existing pane. An error in one pane must not stop the script,
-- because nothing restarts it until the next reload. A server stop sends no
-- block_closed, so forget panes that no longer exist. list_blocks includes
-- detached panes, which keep running outside any window.
local live, complete = {}, true
for _, s in ipairs(rex.call("session.list", {}).sessions) do
  local listed = rex.call("session.attach", { session_id = s.session_id })
    and rex.call("session.list_blocks", { session_id = s.session_id })
  if not listed then complete = false end
  for _, b in ipairs(listed and listed.blocks or {}) do
    live[b.block_id] = true
    local ok, err = pcall(relabel, s.session_id, b.block_id)
    if not ok then rex.log("labels: " .. tostring(err)) end
  end
end
if complete then
  local pruned = false
  for bid in pairs(auto) do
    if not live[bid] then
      auto[bid] = nil
      pruned = true
    end
  end
  if pruned then save_auto() end
end
