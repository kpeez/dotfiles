-- Shift+Enter sends ESC+CR (Alt+Enter), like the Ghostty binding, so shells can tell it from Enter.
rex.bind("shift+enter", "pane.send_key", { key = "alt+enter" })

local home = os.getenv("HOME")
local bin = os.getenv("REX_BIN_DIR")
local state = (os.getenv("XDG_STATE_HOME") or home .. "/.local/state") .. "/rex-snapshots"

-- The server may start with a minimal PATH and no REX_BIN_DIR, so resolve the
-- CLI once instead of relying on a bare `rex`.
local rex_bin
if bin then
  rex_bin = bin .. "/rex"
else
  local guess = home .. "/.local/bin/rex"
  local f = io.open(guess, "r")
  if f then
    f:close()
    rex_bin = guess
  else
    rex_bin = "rex" -- Linux package install: rex is on PATH
  end
end

-- Run `rex do ARGS` in the background, appending its output to LOG in the
-- state directory. init.lua runs before the server accepts connections and
-- config has no timers, so a shell retries while rex exits 4 (no server yet).
-- Unset REX_BLOCK and REX_SESSION because inherited IDs name a block on
-- another server and make rex do fail.
local function do_when_ready(log, ...)
  rex.exec.start({
    "/bin/sh", "-c",
    'unset REX_BLOCK REX_SESSION; log=$1; shift; mkdir -p "${log%/*}"; for _ in $(seq 60); do '
      .. '"$0" --autostart=false do "$@" >>"$log" 2>&1 && exit; '
      .. '[ $? -eq 4 ] || exit; sleep 1; done',
    rex_bin,
    state .. "/" .. log,
    ...,
  }, { detach = true })
end

-- Name panes after their program and folder; see labels.lua.
do_when_ready("labels.log", "--all", home .. "/.config/rex/labels.lua")
