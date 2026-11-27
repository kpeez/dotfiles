#!/bin/sh
# Update system packages, mise, tools, and plugins.
# Run by `mise update`; see docs/reference.md.
#
# System packages run first (with raw = true in config.toml) because apt asks
# for a password and nothing may write over the prompt. Casks are left out:
# apps update themselves or prompt for updates.

set -e
cd "$(dirname "$0")/.." || exit 1

upgrade_packages() {
  managers=$(mise settings get system_packages.managers 2>/dev/null || true)
  [ "$managers" != "[]" ] || return 0
  case "$(uname -s)" in
  Darwin)
    mise bootstrap packages upgrade --manager brew --yes
    ;;
  Linux)
    command -v apt-get >/dev/null || return 0
    if [ ! -t 0 ] && ! sudo -n true 2>/dev/null; then
      echo "apt: SKIPPED, sudo needs a terminal for the password; run mise update in a terminal" >&2
      return 0
    fi
    sudo apt-get update
    sudo apt-get upgrade --with-new-pkgs --yes
    [ ! -f /var/run/reboot-required ] || echo "apt: reboot required to finish the upgrade"
    ;;
  esac
}

upgrade_packages
mise self-update --yes
mise upgrade --yes
sh scripts/plugins.sh
