#!/bin/bash
# Reading the user's text selection. Sourced, never executed.

selection::primary() {
  timeout 1 wl-paste --primary --no-newline --type text 2>/dev/null
}

selection::clipboard() {
  timeout 1 wl-paste --no-newline --type text 2>/dev/null
}

# selection::focused_window -> JSON for the window that has the keyboard,
# or {} when it cannot be read. Captured before the panel opens, so the copy
# shortcut still reaches the window the user was reading.
selection::focused_window() {
  local info
  command -v hyprctl >/dev/null 2>&1 || { echo '{}'; return 0; }
  info=$(hyprctl activewindow -j 2>/dev/null) || info='{}'
  printf '%s' "$info"
}

# Lua expression for `hyprctl dispatch`. Omarchy 4's hyprctl evaluates Lua, so
# the legacy `sendshortcut CTRL, C,` form is a syntax error and the probe
# never copies. Terminals copy with Ctrl+Shift+C; Ctrl+C would be delivered
# to the shell as SIGINT. Hyprland tags are the Omarchy signal, and the class
# check covers a terminal that has not been tagged. The key is sent to that
# window's address so an open overlay does not receive it. Without an address
# the focused surface is used.
#
# The key is the XKB keycode of C (evdev KEY_C is 46, and Hyprland subtracts
# 8 when it injects the key). The name "C" does not resolve while a non-Latin
# layout, such as Russian, is the active group.
#
# Optional argument: JSON from selection::focused_window. Without it the
# focused window is read now.
selection::copy_dispatch() {
  local info=${1:-} mods address
  if [[ -z $info ]]; then
    info=$(hyprctl activewindow -j 2>/dev/null) || info='{}'
  fi
  if jq -e '
    def bare: sub("\\*$"; "");
    def terminal_class:
      test("^(Alacritty|kitty|com\\.mitchellh\\.ghostty|foot|org\\.codeberg\\.dnkl\\.foot|wezterm|org\\.omarchy\\..*|TUI\\..*)$");
    ((.tags // []) | map(bare) | index("terminal")) != null
    or ((.class // "") | terminal_class)
    or ((.initialClass // "") | terminal_class)
  ' <<<"$info" >/dev/null 2>&1; then
    mods="CTRL SHIFT"
  else
    mods="CTRL"
  fi
  address=$(jq -r '.address // empty' <<<"$info" 2>/dev/null) || address=""
  if [[ $address =~ ^0x[0-9a-fA-F]+$ ]]; then
    printf 'hl.dsp.send_shortcut({ mods = "%s", key = "code:54", window = "address:%s" })' "$mods" "$address"
  else
    printf 'hl.dsp.send_shortcut({ mods = "%s", key = "code:54" })' "$mods"
  fi
}

# selection::send_copy -> 0 when Hyprland accepted the shortcut.
# A missing window is a warning with exit 0, so the reply must be exactly ok.
selection::send_copy() {
  local reply info=${1:-}
  reply=$(hyprctl dispatch "$(selection::copy_dispatch "$info")" 2>&1) || return 1
  [[ $reply == ok ]]
}

selection::restore_clipboard() {
  local previous=$1 had_previous=$2
  if ((had_previous)); then
    printf '%s' "$previous" | wl-copy
  else
    wl-copy --clear
  fi
}

# Put the user's clipboard back, then reap the sentinel owner. Restoring
# first releases a foreground wl-copy that is still serving the sentinel;
# waiting on that process before the restore would block.
selection::release_probe() {
  local previous=$1 had_previous=$2 owner=$3
  selection::restore_clipboard "$previous" "$had_previous"
  if ((owner > 0)) && kill -0 "$owner" 2>/dev/null; then
    kill "$owner" 2>/dev/null || true
  fi
  if ((owner > 0)); then
    wait "$owner" 2>/dev/null || true
  fi
}

# selection::capture_copy -> text the focused window copied, or nothing.
# The previous clipboard is restored either way.
#
# A sensitive sentinel is placed on the clipboard first. "Sensitive" keeps it
# out of the shell clipboard history, and it makes a copy of text that was
# already on the clipboard visible: the window has a selection only when the
# clipboard stops being the sentinel. --foreground stays the owner until that
# copy arrives, so the sentinel cannot overwrite the copy afterwards.
selection::capture_copy() {
  local window_info=${1:-} previous="" had_previous=0 sentinel text="" copied="" i owner=0

  command -v hyprctl >/dev/null 2>&1 || return 1

  if previous=$(selection::clipboard); then
    had_previous=1
  fi

  sentinel=$(printf 'kolesnikof-translate-probe-%s-%s' "$$" "$(date +%s%N)")
  printf '%s' "$sentinel" | wl-copy --sensitive --foreground &
  owner=$!

  for ((i = 0; i < 20; i++)); do
    text=$(selection::clipboard) || text=""
    [[ $text == "$sentinel" ]] && break
    sleep 0.05
  done
  if [[ $text != "$sentinel" ]]; then
    selection::release_probe "$previous" "$had_previous" "$owner"
    return 1
  fi

  # Let the hotkey's own modifiers go up before the synthetic chord is sent.
  sleep "${OMARCHY_TRANSLATE_COPY_DELAY:-0.2}"
  if ! selection::send_copy "$window_info"; then
    selection::release_probe "$previous" "$had_previous" "$owner"
    return 1
  fi

  for ((i = 0; i < 10; i++)); do
    text=$(selection::clipboard) || text=""
    if [[ -n $text && $text != "$sentinel" ]]; then
      copied=$text
      break
    fi
    sleep 0.05
  done

  selection::release_probe "$previous" "$had_previous" "$owner"
  [[ -n $copied ]] || return 1
  printf '%s' "$copied"
}

# selection::read -> the text to translate, or nothing when there is none.
# Whitespace-only selections count as empty. Needs TR_CONFIG loaded.
#
# The Wayland primary buffer keeps the last highlight after the user clears
# it. A non-empty buffer is therefore accepted only when the focused window
# copies that same text. Anything else opens the input field. Without
# hyprctl the buffer is trusted, because the check cannot be done.
selection::read() {
  local window_info=${1:-} primary copied

  primary=$(selection::primary) || primary=""
  primary=$(tr::trim "$primary")

  if [[ -n $primary ]]; then
    if ! command -v hyprctl >/dev/null 2>&1; then
      printf '%s' "$primary"
      return 0
    fi
    copied=$(selection::capture_copy "$window_info") || copied=""
    copied=$(tr::trim "$copied")
    if [[ -n $copied && $copied == "$primary" ]]; then
      printf '%s' "$primary"
    fi
    return 0
  fi

  if [[ $(config::get '.copy_fallback') == true ]]; then
    copied=$(selection::capture_copy "$window_info") || copied=""
    primary=$(tr::trim "$copied")
  fi

  printf '%s' "$primary"
}
