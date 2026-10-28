#!/bin/bash
# Installs the kolesnikof-translate command and a starter config.
#
#   ./install.sh                 link the command, create the config
#   ./install.sh --link-plugin   also link this checkout as the shell plugin
#                                (for development; "omarchy plugin add" is the
#                                normal way to install the plugin itself)
#   ./install.sh --uninstall     remove the command link
#
# The plugin is enabled separately: omarchy plugin enable io.github.kolesnikof-ai.translate

set -euo pipefail

PLUGIN_ID="io.github.kolesnikof-ai.translate"
COMMAND="kolesnikof-translate"
ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
BIN_DIR="${OMARCHY_TRANSLATE_BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${OMARCHY_TRANSLATE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/kolesnikof-ai.translate}"
PLUGINS_DIR="${OMARCHY_TRANSLATE_PLUGINS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins}"

link_plugin=0
uninstall=0

for arg in "$@"; do
  case $arg in
    --link-plugin) link_plugin=1 ;;
    --uninstall) uninstall=1 ;;
    -h | --help)
      sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "install.sh: unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if ((uninstall)); then
  if [[ -L $BIN_DIR/$COMMAND ]]; then
    rm -f "$BIN_DIR/$COMMAND"
    echo "Removed $BIN_DIR/$COMMAND"
  fi
  echo "The config in $CONFIG_DIR was left in place."
  exit 0
fi

missing=()
for dependency in curl jq wl-copy wl-paste; do
  command -v "$dependency" >/dev/null 2>&1 || missing+=("$dependency")
done
if ((${#missing[@]})); then
  echo "Warning: missing required tools: ${missing[*]} (wl-copy and wl-paste come from wl-clipboard)" >&2
fi

mkdir -p "$BIN_DIR"
ln -sfn "$ROOT/bin/translate" "$BIN_DIR/$COMMAND"
echo "Linked $BIN_DIR/$COMMAND"

mkdir -p "$CONFIG_DIR"
if [[ ! -f $CONFIG_DIR/config.json ]]; then
  cp "$ROOT/config/config.example.json" "$CONFIG_DIR/config.json"
  echo "Created $CONFIG_DIR/config.json"
fi
chmod 600 "$CONFIG_DIR/config.json"

if ((link_plugin)); then
  mkdir -p "$PLUGINS_DIR"
  if [[ $ROOT != "$PLUGINS_DIR/$PLUGIN_ID" ]]; then
    ln -sfn "$ROOT" "$PLUGINS_DIR/$PLUGIN_ID"
    echo "Linked $PLUGINS_DIR/$PLUGIN_ID"
  fi
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Warning: $BIN_DIR is not in PATH; the hotkey will not find $COMMAND" >&2 ;;
esac
