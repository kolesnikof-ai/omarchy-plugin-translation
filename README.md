# Translation (Omarchy plugin)

Translation plugin for Omarchy 4 (plugin id `io.github.kolesnikof-ai.translate`). Press a hotkey to translate the selected text, or type text into a small panel. Each request goes to exactly one provider: DeepL (default), Microsoft, Google, Yandex or LibreTranslate.

![Translation panel](preview.jpg)

## Install

```bash
omarchy plugin add https://github.com/kolesnikof-ai/omarchy-plugin-translation.git --enable
~/.config/omarchy/plugins/io.github.kolesnikof-ai.translate/install.sh
```

`install.sh` links `kolesnikof-translate` into `~/.local/bin` and creates `~/.config/kolesnikof-ai.translate/config.json` (mode 600). Put your API key there, then add the hotkey from `config/bindings.example.lua` to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + T", "Translate selection", "kolesnikof-translate")
```

## Remove

```bash
~/.config/omarchy/plugins/io.github.kolesnikof-ai.translate/install.sh --uninstall
omarchy plugin remove io.github.kolesnikof-ai.translate
```

`install.sh --uninstall` removes the `~/.local/bin/kolesnikof-translate` link and leaves `~/.config/kolesnikof-ai.translate/config.json` in place. `omarchy plugin remove` disables the plugin and deletes its checkout. Run the uninstall first, while that checkout is still on disk.

## Use

- Select text anywhere and press the hotkey. With nothing selected, the panel opens with an input field.
- In the input field Enter translates and Shift+Enter inserts a line break. Esc or a click outside closes the panel.
- Copy the translation with the copy button, Ctrl+C or Super+C while the panel is open.
- `kolesnikof-translate --stdin` translates standard input and prints JSON; `--input` always opens the input field; `--copy` copies the last translation.

## Configuration

See `config/config.example.json`. Language codes are lowercase ISO 639-1 (`ru`, `en`, `de`). Words get part-of-speech variants only with the `microsoft` provider (`ui.max_variants` per part of speech). Set `ui.show_language_switcher` to `true` for source/target dropdowns inside the panel. `libretranslate_url` must be an `https://` URL without credentials; plain `http://` is accepted only for `localhost`, `127.0.0.1` and `[::1]`, because the API key is sent to that address.

## Dependencies

Required: `curl`, `jq`, `wl-clipboard` (`wl-copy` and `wl-paste`), `bash`, and `sha256sum`.

Omarchy provides `omarchy-shell` and `omarchy-notification-send`. `hyprctl` is optional and supplies the cursor position and the active window. `notify-send` is used only when `omarchy-notification-send` is missing.

There is no remote build. `omarchy plugin add` clones this repository and does not run an install hook.

## Privileges

The plugin is unsandboxed and runs with your user permissions. `install.sh` does not call sudo, does not download code, and does not replace an existing config file. When the file is already there, the script only sets its mode to `600`.

Each request sends the API key and the source text to exactly one configured provider: DeepL, Microsoft, Google, Yandex, or the LibreTranslate URL. You add the hotkey to `~/.config/hypr/bindings.lua` yourself.

## Tests

```bash
bats tests
```

The tests mock `curl` and the Wayland/Omarchy commands, so they run without Omarchy. The QML panel can only be checked for syntax outside a live Omarchy session.
