-- Add to ~/.config/hypr/bindings.lua

-- Translate the current selection. With nothing selected — including a primary
-- buffer left over after the highlight was cleared — the panel opens with an
-- input field. SUPER + SHIFT + T is free in Omarchy 4.0.x defaults.
o.bind("SUPER + SHIFT + T", "Translate selection", "kolesnikof-translate")

-- Optional: always open the input field, whatever is selected.
-- o.bind("SUPER + ALT + T", "Translate typed text", "kolesnikof-translate --input")

-- Optional fallback: copy the last translation to the clipboard from a hotkey.
-- Only needed if Super+C does not reach the open panel on your setup.
-- o.bind("SUPER + ALT + C", "Copy last translation", "kolesnikof-translate --copy")
