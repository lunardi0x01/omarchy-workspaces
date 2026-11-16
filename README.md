# My Workspaces

An Omarchy bar widget for workspaces. Every workspace is shown; the active one
shows its number in the theme's accent colour with a short accent line under
it, workspaces with windows are drawn in full and empty ones dimmed.

This is a modified copy of Omarchy's built-in `omarchy.workspaces` widget,
made with `omarchy plugin clone`. Click a number to switch, scroll to move
along the row, and click the active workspace to cycle its layout (tiling,
scrolling, floating), as Super + L does.

## One widget, two numbering schemes

The same widget runs on a laptop and on a desktop with fixed screens. It
picks its scheme from what Hyprland is configured with, so nothing about a
particular machine lives in this repo.

| Mode | When | Each bar shows |
|------|------|----------------|
| `monitor` | Omarchy's default since 4.5: every monitor has workspaces 1-10 of its own (Hyprland numbers them 1-10, 11-20, ... per monitor). | Its monitor's ten, numbered 1-10, then any workspace visiting from an unplugged monitor. |
| `global` | Plain Hyprland numbering with workspaces pinned to monitors by workspace rules. | The workspaces pinned to its monitor, plus any other workspace that is on it right now. A pinned workspace that a script moved to another screen shows on that screen's bar instead. |

By default (`auto`) the widget uses `global` when Hyprland has rules pinning
numbered workspaces to monitors (`hyprctl workspacerules`), and `monitor`
otherwise.

## Settings

In the widget's entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "lunardi0x01.workspaces",
  "numbering": "auto",
  "labels": { "10": "G" }
}
```

- `numbering`: `"auto"` (default), `"monitor"` or `"global"`.
- `labels`: text to show instead of a number. Keyed by workspace id in
  `global` mode and by slot (1-10) in `monitor` mode. Without a label,
  workspace 10 shows as `0`, matching its key.

## Global numbering on Omarchy 4.5+

Pinning workspaces is not enough on its own: Omarchy 4.5 rebinds Super + 1-0
to per-monitor slots and re-sorts workspaces into per-monitor blocks on start,
config reload and monitor hotplug. To keep plain numbering, add to
`~/.config/hypr/hyprland.lua`, after `require("default.hypr.omarchy")`:

```lua
-- Stop the per-monitor re-sorting (an Omarchy internal: re-check after updates).
if o.workspaces then
  o.workspaces.reconcile = function() end
end

-- Pin workspaces to monitors; the widget reads these.
hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1" })
-- ...
```

and to `~/.config/hypr/bindings.lua` (the binds from Omarchy 4.0):

```lua
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  local ws = tostring(workspace)
  o.rebind("SUPER + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = ws }))
  o.rebind("SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = ws }))
  o.rebind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. workspace, hl.dsp.window.move({ workspace = ws, follow = false }))
end

o.rebind("SUPER + SHIFT + ALT + LEFT", "Move workspace to left monitor", hl.dsp.workspace.move({ monitor = "l" }))
o.rebind("SUPER + SHIFT + ALT + RIGHT", "Move workspace to right monitor", hl.dsp.workspace.move({ monitor = "r" }))
o.rebind("SUPER + SHIFT + ALT + UP", "Move workspace to up monitor", hl.dsp.workspace.move({ monitor = "u" }))
o.rebind("SUPER + SHIFT + ALT + DOWN", "Move workspace to down monitor", hl.dsp.workspace.move({ monitor = "d" }))
```

## Install

```bash
git clone https://github.com/lunardi0x01/omarchy-workspaces ~/Projects/Omarchy/plugins/lunardi0x01.workspaces
ln -s ~/Projects/Omarchy/plugins/lunardi0x01.workspaces ~/.config/omarchy/plugins/lunardi0x01.workspaces
omarchy-shell shell rescanPlugins
```

Then put `lunardi0x01.workspaces` in the bar in place of `omarchy.workspaces`
(`omarchy bar` or `~/.config/omarchy/shell.json`). After pulling an update,
run `omarchy restart shell`: a live reload doesn't always swap the running
widget.

## License

MIT. See [LICENSE](LICENSE), which keeps the upstream Omarchy notice.
