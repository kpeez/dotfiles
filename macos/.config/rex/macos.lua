-- macOS-only Rex config. Linked only on Macs; init.lua loads it when present.

-- Browser panes (Shift-Cmd-B). Install or update: cd ~/code/rexweb && git pull && REX_CONFIG=~/.config/rex/macos.lua ./install.sh
require("rexweb").setup{}
