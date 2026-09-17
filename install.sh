#!/usr/bin/env sh
# Link `welcome` into ~/.local/bin, write a starter config, and (optionally)
# enable the systemd user timer that keeps the cache warm.
#
#   ./install.sh            # link + starter config
#   ./install.sh --timer    # also install & enable welcome-prefetch.timer
set -eu

here=$(cd "$(dirname "$0")" && pwd)
bin="${HOME}/.local/bin"
mkdir -p "$bin"
ln -sf "$here/welcome" "$bin/welcome"
echo "linked $bin/welcome -> $here/welcome"

case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "note: $bin is not on your PATH — add it to your shell rc" ;;
esac

"$bin/welcome" --init || true

if [ "${1:-}" = "--timer" ]; then
  units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$units"
  cp "$here/systemd/welcome-prefetch.service" "$here/systemd/welcome-prefetch.timer" "$units/"
  systemctl --user daemon-reload
  systemctl --user enable --now welcome-prefetch.timer
  echo "enabled welcome-prefetch.timer — set fetch_on_launch = false in your config"
fi

cat <<MSG

Add this to the end of ~/.zshrc (or ~/.bashrc):

$(cat "$here/shell/welcome.zsh")
MSG
