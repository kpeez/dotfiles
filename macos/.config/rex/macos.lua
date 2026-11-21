-- macOS-only Rex config. Linked only on Macs; init.lua loads it when present.

-- Browser panes (Shift-Cmd-B). Install or update: cd ~/code/rexweb && git pull && REX_CONFIG=~/.config/rex/macos.lua ./install.sh
require("rexweb").setup{}

-- Untracked config for this Mac, such as plugins under development.
local local_config = os.getenv("HOME") .. "/.config/rex/local.lua"
local f = io.open(local_config, "r")
if f then
  f:close()
  dofile(local_config)
end
