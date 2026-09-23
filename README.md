# Omarchy Notification Center

A compact notification center for Omarchy, built on top of Omarchy's existing
notification service.

This fork keeps the notification backend untouched and focuses on making the
bar popup feel like a native Omarchy panel.

It provides:

- one unified notification list instead of separate Pending / Recently tabs;
- live notifications highlighted in the same list;
- a Do Not Disturb switch using Omarchy's native `ToggleSwitch`;
- a compact panel width matching the Network, Bluetooth and Audio panels;
- dismissal for notifications that are still live;
- `Dismiss all` and `Clear` actions at the bottom.

The notification daemon, toast popups, history storage and DND state remain
owned by Omarchy itself. This plugin is only a UI for browsing and managing
that state.

## Notification state

Current Omarchy persists notification state under
`~/.local/state/omarchy/notifications/`:

- JSON files directly in that directory are notifications still live on screen;
- files under `history/` are notifications that have left the screen.

The plugin reads those persisted files and presents both stages as one
continuous notification feed. It deliberately does not invent a separate
read/unread state that Omarchy itself does not expose.

The plugin uses Omarchy's public boundaries rather than private service models:

- DND binds to the notification service proxy exposed to third-party bar widgets;
- **Dismiss all** calls `omarchy-shell notifications dismissAll`, which
  lets Omarchy archive live notifications into history;
- **Clear** dismisses live notifications and clears recorded history.

The plugin does not replace the notification daemon or maintain a second
notification database, and it does not depend on private first-party service
models.

## Install

```bash
omarchy plugin add https://github.com/lsongdev/omarchy-notification-center.git --enable
```

The widget can be positioned explicitly:

```bash
omarchy bar plugin move omacom.notification-center --section right
```

## Development

Validate the manifest and entry point:

```bash
omarchy plugin validate .
```

Files under `~/.config/omarchy/plugins/` are reloaded automatically while
developing. For a clean full-shell reload after larger QML changes:

```bash
omarchy restart shell
```

## License

MIT
