-- Shift+Enter sends ESC+CR (Alt+Enter), like the Ghostty binding, so shells can tell it from Enter.
rex.bind("shift+enter", "pane.send_key", { key = "alt+enter" })

local home = os.getenv("HOME")
local bin = os.getenv("REX_BIN_DIR")
local state = (os.getenv("XDG_STATE_HOME") or home .. "/.local/state") .. "/rex-snapshots"

-- Run `rex do ARGS` in the background, appending its output to LOG in the
-- state directory. init.lua runs before the server accepts connections and
-- config has no timers, so a shell retries while rex exits 4 (no server yet).
-- An inherited REX_BLOCK or REX_SESSION names a block of another server and
-- makes rex do fail. REX_SERVER goes through -S because rex falls back to the
-- default server when REX_SERVER's socket does not exist yet.
local function do_when_ready(log, ...)
  rex.exec.start({
    "/bin/sh", "-c",
    'unset REX_BLOCK REX_SESSION; log=$1; shift; mkdir -p "${log%/*}"; for _ in $(seq 60); do '
      .. '"$0" ${REX_SERVER:+-S "$REX_SERVER"} --autostart=false do "$@" >>"$log" 2>&1 && exit; '
      .. '[ $? -eq 4 ] || exit; sleep 1; done',
    -- Rex for Mac sets REX_BIN_DIR. The Linux package puts rex on PATH.
    bin and bin .. "/rex" or "rex",
    state .. "/" .. log,
    ...,
  }, { detach = true })
end

-- Name panes after their program and folder; see labels.lua.
do_when_ready("labels.log", "--all", home .. "/.config/rex/labels.lua")
