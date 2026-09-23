# Omarchy Notification Center

A compact notification center for Omarchy, built on top of Omarchy's existing
notification service.

This fork keeps the notification backend untouched and focuses on making the
bar popup feel like a native Omarchy panel.

It provides:

- one unified notification list instead of separate Pending / Recently tabs;
- unread notifications highlighted in the same list;
- a Do Not Disturb switch using Omarchy's native `ToggleSwitch`;
- a compact panel width matching the Network, Bluetooth and Audio panels;
- per-notification dismissal;
- `Mark all as read` and `Clear` actions at the bottom.

The notification daemon, toast popups, history storage and DND state remain
owned by Omarchy itself. This plugin is only a UI for browsing and managing
that state.

## Notification state

Current Omarchy keeps notifications in two stages:

- `popupModel` contains notifications that are still live on screen;
- once a popup leaves the screen, Omarchy archives it under `historyDir`.

The UI presents both stages as one continuous notification feed. Live
notifications are treated as unread; **Mark all as read** dismisses the live
popup stack, which lets Omarchy archive those notifications into history.
**Clear** removes both live notifications and stored history.

The plugin does not replace the notification daemon or maintain a second
notification database.

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

After changing plugin files:

```bash
omarchy plugin rescan
omarchy restart shell
```

## License

MIT
