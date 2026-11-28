# system-theme — HlwmAccessible GTK theme (stow package)

A GTK 3 + GTK 4 theme derived from the herbstluftwm window theme in
`herbstluftwm/.config/herbstluftwm/theme` (+ `theme.d/titles.theme`,
sourced by `reload_theme` where `BACKGROUND_HEX='#2C001E'`), so GTK
apps like gdebi-gtk look native in the herbst session.

Deployed by stowing this package: `stow -R -t $HOME system-theme`
publishes `.themes/HlwmAccessible/` into `$HOME/.themes/`.

## Palette mapping (hlwm value → GTK token)

| hlwm source | value | GTK token | role |
|---|---|---|---|
| `reload_theme` `BACKGROUND_HEX` | `#2C001E` | `bg_color` | window background (aubergine) |
| `theme.active.inner_color` | `#333333` | `headerbar_bg_color` | title-bar fill |
| `theme.active.outer_color` | `#feef69` | `selected_bg_color` | focused border gold → accent/focus |
| `titles.theme` `theme.title_color` | `#eeeeee` | `fg_color` | title text → all primary text |
| `theme.urgent.title_color` | `#eb4d4b` | `error_color` | urgent red → errors, destructive |
| `theme.urgent.outer_color` | `#a55eea` | `warning_color` | urgent magenta → warnings |
| (derived, base darkened) | `#241119` | `base_color` | entries/views |
| (derived green, dark-bg tuned) | `#6fdd8b` | `success_color` | no hlwm counterpart; token required |
| (derived ink on gold) | `#1a1a1a` | `selected_fg_color` | text on gold accent |

Derived colors stay within the hlwm hue family (dark aubergine depths,
high-contrast inks) and were tuned until every pair cleared WCAG.

## Verified contrast ratios (WCAG 2.x relative luminance)

Computed with a small bun script (kept out of the repo, `/tmp`);
ratios verified numerically:

| pair | ratio | WCAG threshold | pass |
|---|---|---|---|
| `fg_color` on `bg_color` (#EEEEEE / #2C001E) | 16.08 | 4.5 | ✅ |
| `fg_color` on `headerbar_bg_color` (#EEEEEE / #333333) | 10.89 | 4.5 | ✅ |
| `fg_color` on `base_color` (#EEEEEE / #241119) | 15.48 | 4.5 | ✅ |
| `selected_fg_color` on gold (#1A1A1A / #FEEF69) | 14.72 | 4.5 | ✅ |
| gold focus outline on `bg_color` | 15.78 | 3 (UI) | ✅ |
| gold focus outline on `headerbar_bg_color` | 10.69 | 3 (UI) | ✅ |
| `error_color` on `bg_color` | 5.06 | 4.5 | ✅ |
| ink on destructive button (#1A1A1A / #EB4D4B) | 4.72 | 4.5 | ✅ |
| `warning_color` on `bg_color` | 4.79 | 4.5 | ✅ |
| `success_color` on `bg_color` | 11.01 | 4.5 | ✅ |
| unfocused fg on `bg_color` (#B8B8B8 / #2C001E) | 9.40 | 4.5 | ✅ |
| disabled fg on disabled bg (#AC9EA7 / #2A2A2A) | 5.61 | 4.5 | ✅ |
| `borders_color` on `bg_color` (#6E6E6E / #2C001E) | 3.66 | 3 (UI) | ✅ |
| tooltip fg on tooltip bg (#EEEEEE / #333333) | 10.89 | 4.5 | ✅ |

Accessibility features: 2px high-contrast (gold) `:focus`/`:focus-visible`
outlines on buttons, entries, checks/radios and comboboxes; gold borders
mark hover state; selection is gold-on-ink everywhere.

## Activation

Per-invocation:

    GTK_THEME=HlwmAccessible gdebi-gtk

Session-wide (GTK3):

    gsettings set org.gnome.desktop.interface gtk-theme 'HlwmAccessible'

Or `~/.config/gtk-3.0/settings.ini`:

    [Settings]
    gtk-theme-name=HlwmAccessible

GTK4 apps read `~/.config/gtk-4.0/settings.ini` the same way; the theme
ships both `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` (kept in sync — the
GTK3 file is canonical).
