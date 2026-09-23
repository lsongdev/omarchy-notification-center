# Omarchy Notification Center

A bar widget for reviewing notifications handled by Omarchy's built-in
notification service.

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
- files under `history/` are past notifications, including ones suppressed by
  Do Not Disturb.

The plugin polls these files and presents both stages as one continuous feed.
It does not create a separate read/unread state.

Notification controls use Omarchy's `omarchy-shell notifications` commands:

- the DND switch and right-click on the bar icon toggle Do Not Disturb;
- dismissing one live notification or selecting **Dismiss all** moves it into
  history;
- **Clear** dismisses live notifications and clears history.

The plugin does not replace the notification daemon or store another copy of
notifications.

## Install

```bash
omarchy plugin add https://github.com/omacom/omarchy-notification-center-plugin.git --enable
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

After changing plugin files:

```bash
omarchy plugin rescan
omarchy restart shell
```

## License

MIT
