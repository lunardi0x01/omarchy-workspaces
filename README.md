# My Workspaces

An Omarchy bar widget for workspaces. The active workspace shows its number
in the theme's accent colour with a short accent line under it, in place of
the built-in widget's layout glyph.

This is a modified copy of Omarchy's built-in `omarchy.workspaces` widget,
made with `omarchy plugin clone`. Everything else works as upstream does:
click a number to switch, scroll to move along the row, and click the active
workspace to cycle its layout (tiling, scrolling, floating), as Super + L does.

## Install

```bash
git clone https://github.com/lunardi0x01/omarchy-workspaces ~/Projects/Omarchy/plugins/lunardi0x01.workspaces
ln -s ~/Projects/Omarchy/plugins/lunardi0x01.workspaces ~/.config/omarchy/plugins/lunardi0x01.workspaces
omarchy-shell shell rescanPlugins
```

Then put `lunardi0x01.workspaces` in the bar in place of `omarchy.workspaces`
(`omarchy bar` or `~/.config/omarchy/shell.json`).

## License

MIT. See [LICENSE](LICENSE), which keeps the upstream Omarchy notice.
